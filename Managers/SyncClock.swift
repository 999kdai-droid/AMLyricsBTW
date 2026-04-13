import SwiftUI
import MusicKit
import Combine

// MARK: - Sync Clock
@Observable
final class SyncClock: @unchecked Sendable {
    
    private var timer: Timer?
    @MainActor private var cancellables = Set<AnyCancellable>()
    
    @MainActor var currentTime: Double = 0.0
    @MainActor var userOffset: Double = 0.0 {
        didSet {
            UserDefaults.standard.set(userOffset, forKey: "lyricsOffset")
        }
    }
    @MainActor var currentLineIndex: Int = 0
    @MainActor var currentWordProgress: Double = 0.0
    @MainActor var isPlaying: Bool = false
    
    @MainActor private var lyrics: [LyricsLine] = []
    
    @MainActor
    init() {
        userOffset = UserDefaults.standard.double(forKey: "lyricsOffset")
        setupMusicKitObservers()
    }
    
    deinit {
        // Cleanup timer without main actor
        // Timer cleanup is safe even without @MainActor
    }
    
    // MARK: - Start/Stop
    @MainActor
    func start() {
        guard timer == nil else { return }
        
        // Use Timer instead of CADisplayLink for macOS compatibility
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    @MainActor
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Update Lyrics
    @MainActor
    func updateLyrics(_ lyrics: [LyricsLine]) {
        self.lyrics = lyrics
        updateCurrentLine()
    }
    
    // MARK: - Timer Callback
    @MainActor
    private func tick() {
        guard isPlaying else { return }
        
        // Get current playback time from MusicKit
        let playbackTime = ApplicationMusicPlayer.shared.playbackTime
        currentTime = playbackTime + userOffset
        
        updateCurrentLine()
    }
    
    // MARK: - Update Current Line
    @MainActor
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
    @MainActor
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
        let totalDuration = line.end - line.start
        let elapsedInLine = adjustedTime - line.start
        
        if elapsedInLine < 0 {
            currentWordProgress = 0.0
        } else if elapsedInLine > totalDuration {
            currentWordProgress = 1.0
        } else {
            currentWordProgress = elapsedInLine / totalDuration
        }
    }
    
    // MARK: - MusicKit Observers
    @MainActor
    private func setupMusicKitObservers() {
        // Use application state observation for macOS
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkPlaybackState()
            }
            .store(in: &cancellables)
        
        checkPlaybackState()
    }
    
    @MainActor
    private func checkPlaybackState() {
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
        case .seekingForward, .seekingBackward:
            // Continue current state during seeking
            break
        @unknown default:
            break
        }
    }
}

