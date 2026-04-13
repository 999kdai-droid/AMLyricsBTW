import SwiftUI
import MusicKit
import Combine

// MARK: - Sync Clock
@MainActor
@Observable
final class SyncClock {
    
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    
    var currentTime: Double = 0.0
    var userOffset: Double = 0.0 {
        didSet {
            UserDefaults.standard.set(userOffset, forKey: "lyricsOffset")
        }
    }
    var currentLineIndex: Int = 0
    var currentWordProgress: Double = 0.0
    var isPlaying: Bool = false
    
    private var lyrics: [LyricsLine] = []
    
    init() {
        userOffset = UserDefaults.standard.double(forKey: "lyricsOffset")
        setupMusicKitObservers()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Start/Stop
    func start() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Update Lyrics
    func updateLyrics(_ lyrics: [LyricsLine]) {
        self.lyrics = lyrics
        updateCurrentLine()
    }
    
    // MARK: - CADisplayLink Callback
    @objc private func tick() {
        guard isPlaying else { return }
        
        // Get current playback time from MusicKit
        let playbackTime = ApplicationMusicPlayer.shared.playbackTime
        currentTime = playbackTime + userOffset
        
        updateCurrentLine()
    }
    
    // MARK: - Update Current Line
    private func updateCurrentLine() {
        guard !lyrics.isEmpty else { return }
        
        let adjustedTime = currentTime
        
        // Find current line
        var newIndex = 0
        for (index, line) in lyrics.enumerated() {
            if adjustedTime >= line.start && adjustedTime <= line.end {
                newIndex = index
                break
            } else if adjustedTime > line.end {
                newIndex = index + 1
            }
        }
        
        // Clamp to valid range
        newIndex = max(0, min(newIndex, lyrics.count - 1))
        
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
        
        // Update word progress for current line
        updateWordProgress(for: newIndex)
    }
    
    // MARK: - Update Word Progress
    private func updateWordProgress(for lineIndex: Int) {
        guard lineIndex < lyrics.count else {
            currentWordProgress = 0.0
            return
        }
        
        let line = lyrics[lineIndex]
        guard let words = line.words, !words.isEmpty else {
            currentWordProgress = 0.0
            return
        }
        
        let adjustedTime = currentTime
        
        // Find current word
        var totalDuration = line.end - line.start
        var elapsedInLine = adjustedTime - line.start
        
        if elapsedInLine < 0 {
            currentWordProgress = 0.0
        } else if elapsedInLine > totalDuration {
            currentWordProgress = 1.0
        } else {
            currentWordProgress = elapsedInLine / totalDuration
        }
    }
    
    // MARK: - MusicKit Observers
    private func setupMusicKitObservers() {
        NotificationCenter.default.publisher(for: .playbackStateDidChange)
            .sink { [weak self] _ in
                self?.handlePlaybackStateChange()
            }
            .store(in: &cancellables)
        
        handlePlaybackStateChange()
    }
    
    private func handlePlaybackStateChange() {
        let state = ApplicationMusicPlayer.shared.state.playbackStatus
        
        switch state {
        case .playing:
            isPlaying = true
            start()
        case .paused, .stopped:
            isPlaying = false
            stop()
        case .interrupted:
            isPlaying = false
            stop()
        @unknown default:
            break
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}

struct ContentView: View {
    @State private var clock = SyncClock()
    
    var body: some View {
        VStack {
            Text("Current Time: \(clock.currentTime, specifier: "%.2f")s")
            Text("Line Index: \(clock.currentLineIndex)")
            Text("Word Progress: \(clock.currentWordProgress, specifier: "%.2f")")
            Text("User Offset: \(clock.userOffset, specifier: "%.1f")s")
            Text("Is Playing: \(clock.isPlaying ? "Yes" : "No")")
            
            Button("Simulate Play") {
                clock.isPlaying = true
                clock.start()
            }
            
            Button("Simulate Pause") {
                clock.isPlaying = false
                clock.stop()
            }
        }
        .padding()
    }
}
