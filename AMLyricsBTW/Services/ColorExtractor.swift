import AppKit
import SwiftUI

struct ColorExtractor {
    static func extract(from image: NSImage, count: Int = 3) -> [Color] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return defaults()
        }
        let w = 60, h = 60
        var raw = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &raw, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return defaults() }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        // 全ピクセルをサンプリング
        var samples: [(r: Double, g: Double, b: Double)] = []
        for y in stride(from: 0, to: h, by: 3) {
            for x in stride(from: 0, to: w, by: 3) {
                let o = (y * w + x) * 4
                let r = Double(raw[o]) / 255.0
                let g = Double(raw[o+1]) / 255.0
                let b = Double(raw[o+2]) / 255.0
                // 暗すぎ・明るすぎを除外、彩度が高いものを優先
                let brightness = (r + g + b) / 3
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                if brightness > 0.08 && brightness < 0.92 && saturation > 0.15 {
                    samples.append((r, g, b))
                }
            }
        }
        guard !samples.isEmpty else { return defaults() }

        // K-means クラスタリング（10回反復）
        var centroids: [(r: Double, g: Double, b: Double)] = []
        let step = max(1, samples.count / count)
        for i in 0..<count { centroids.append(samples[min(i * step, samples.count - 1)]) }

        for _ in 0..<15 {
            var clusters = Array(repeating: [(r: Double, g: Double, b: Double)](), count: count)
            for s in samples {
                var minD = Double.infinity; var nearest = 0
                for (i, c) in centroids.enumerated() {
                    let d = pow(s.r-c.r,2)+pow(s.g-c.g,2)+pow(s.b-c.b,2)
                    if d < minD { minD = d; nearest = i }
                }
                clusters[nearest].append(s)
            }
            for i in 0..<count where !clusters[i].isEmpty {
                let n = Double(clusters[i].count)
                centroids[i] = (
                    clusters[i].map{$0.r}.reduce(0,+)/n,
                    clusters[i].map{$0.g}.reduce(0,+)/n,
                    clusters[i].map{$0.b}.reduce(0,+)/n
                )
            }
        }

        // 彩度で降順ソート（一番鮮やかな色を前に）
        let sorted = centroids.sorted {
            let s0 = max($0.r,$0.g,$0.b) - min($0.r,$0.g,$0.b)
            let s1 = max($1.r,$1.g,$1.b) - min($1.r,$1.g,$1.b)
            return s0 > s1
        }
        return sorted.map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }

    static func defaults() -> [Color] { [
        Color(hue: 0.75, saturation: 0.6, brightness: 0.5),
        Color(hue: 0.6,  saturation: 0.7, brightness: 0.4),
        Color(hue: 0.55, saturation: 0.5, brightness: 0.3)
    ]}
}
