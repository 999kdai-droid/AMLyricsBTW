import Foundation
import AVFoundation
import Accelerate
import SwiftUI

@MainActor
class BeatDetectionService: ObservableObject {
    @Published var kickPulse: Double = 0   // 40-100Hz（キック）
    @Published var bassPulse: Double = 0   // 100-300Hz（ベース）
    @Published var highPulse: Double = 0   // 3000-10000Hz（ハイ）
    @Published var isActive: Bool = false

    private var engine: AVAudioEngine?
    private var fftSetup: FFTSetup?
    private let log2n = 11  // 2048
    private let bufferSize: AVAudioFrameCount = 2048

    private var kickHistory = [Double](repeating: 0, count: 30)
    private var bassHistory = [Double](repeating: 0, count: 30)
    private var highHistory = [Double](repeating: 0, count: 30)
    private var historyIdx = 0

    private var kickDecay: Double = 0
    private var bassDecay: Double = 0
    private var highDecay: Double = 0

    func start() {
        guard !isActive else { return }
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))
        let eng = AVAudioEngine()
        let inputNode = eng.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer, sampleRate: sampleRate)
        }
        do {
            try eng.start()
            engine = eng
            isActive = true
            print("🎵 BeatDetection: 開始")
        } catch {
            print("🎵 BeatDetection エラー: \(error)")
            if let s = fftSetup { vDSP_destroy_fftsetup(s); fftSetup = nil }
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        if let s = fftSetup { vDSP_destroy_fftsetup(s); fftSetup = nil }
        isActive = false
        kickPulse = 0; bassPulse = 0; highPulse = 0
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Float) {
        guard let channelData = buffer.floatChannelData?[0],
              let setup = fftSetup else { return }
        let n = 1 << log2n
        // サンプルコピー + Hannウィンドウ
        var samples = [Float](repeating: 0, count: n)
        let count = min(Int(buffer.frameLength), n)
        samples.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.initialize(from: channelData, count: count)
        }
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(n))
        // FFT
        var real = [Float](repeating: 0, count: n/2)
        var imag = [Float](repeating: 0, count: n/2)
        for i in 0..<n/2 { real[i] = samples[2*i]; imag[i] = samples[2*i+1] }
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        vDSP_fft_zrip(setup, &splitComplex, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
        var magnitudes = [Float](repeating: 0, count: n/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))
        let freqRes = sampleRate / Float(n)

        func bandEnergy(_ lo: Float, _ hi: Float) -> Double {
            let iLo = max(0, Int(lo / freqRes))
            let iHi = min(n/2 - 1, Int(hi / freqRes))
            guard iHi > iLo else { return 0 }
            var sum: Float = 0
            for i in iLo..<iHi { sum += magnitudes[i] }
            return Double(sqrtf(sum / Float(iHi - iLo)))
        }

        let kick = bandEnergy(40, 100)
        let bass = bandEnergy(100, 300)
        let high = bandEnergy(3000, 10000)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let idx = self.historyIdx % 30
            self.kickHistory[idx] = kick
            self.bassHistory[idx] = bass
            self.highHistory[idx] = high
            self.historyIdx += 1
            let avgKick = self.kickHistory.reduce(0,+) / 30
            let avgBass = self.bassHistory.reduce(0,+) / 30
            let avgHigh = self.highHistory.reduce(0,+) / 30
            let kBeat = avgKick > 0.001 ? max(0, min(1, (kick/avgKick - 1.0) / 1.5)) : 0
            let bBeat = avgBass > 0.001 ? max(0, min(1, (bass/avgBass - 1.0) / 1.5)) : 0
            let hBeat = avgHigh > 0.001 ? max(0, min(1, (high/avgHigh - 1.0) / 1.5)) : 0
            // 急速アタック・緩やかリリース
            self.kickDecay = max(kBeat, self.kickDecay * 0.82)
            self.bassDecay = max(bBeat, self.bassDecay * 0.86)
            self.highDecay = max(hBeat, self.highDecay * 0.80)
            self.kickPulse = self.kickDecay
            self.bassPulse = self.bassDecay
            self.highPulse = self.highDecay
        }
    }
}
