import SwiftUI
import MusicKit
import SwiftData

// MARK: - Main Lyrics View
struct LyricsView: View {
    @State private var trackLyrics: TrackLyrics?
    @State private var dominantColors: [NSColor] = []
    @State private var currentLineIndex: Int = 0
    @State private var currentTime: Double = 0.0
    @State private var currentWordProgress: Double = 0.0
    @State private var errorMessage: String?
    
    @State private var lyricProvider: LyricProvider?
    @State private var syncClock = SyncClock()
    
    // Use computed property to get isLoading from provider
    private var isLoading: Bool {
        lyricProvider?.isLoading ?? false
    }
    
    let track: MusicItemCollection<Track>
    let songName: String
    let artistName: String
    
    var body: some View {
        ZStack {
            // Background with mesh gradient
            meshGradientBackground
                .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let lyrics = trackLyrics {
                lyricsScrollView(lyrics)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                emptyView
            }
            
            // Offset adjustment overlay
            VStack {
                Spacer()
                OffsetAdjustView()
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            setupLyricProvider()
            loadArtworkColors()
            loadLyrics()
            setupSyncClock()
        }
    }
    
    // MARK: - Background
    private var meshGradientBackground: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0) : dominantColors[0]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.3, green: 0.25, blue: 0.4, alpha: 1.0) : dominantColors[1]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0) : dominantColors[2]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.3, green: 0.25, blue: 0.4, alpha: 1.0) : dominantColors[1]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0) : dominantColors[0]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0) : dominantColors[2]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0) : dominantColors[2]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0) : dominantColors[0]),
                Color(nsColor: dominantColors.isEmpty ? NSColor(red: 0.3, green: 0.25, blue: 0.4, alpha: 1.0) : dominantColors[1])
            ]
        )
        .animation(.easeInOut(duration: 1.5), value: dominantColors)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading lyrics...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Error")
                .font(.headline)
            
            ScrollView {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxHeight: 200)
            
            Button("Retry") {
                errorMessage = nil
                loadLyrics()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Back to Search") {
                errorMessage = nil
                trackLyrics = nil
            }
            .buttonStyle(.borderless)
            .padding(.top, 10)
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No lyrics available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Lyrics Scroll View
    private func lyricsScrollView(_ lyrics: TrackLyrics) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(lyrics.lyrics) { line in
                    LyricsLineView(
                        line: line,
                        isActive: line.lineIndex == currentLineIndex,
                        currentTime: currentLineIndex == line.lineIndex ? currentTime : 0.0
                    )
                }
            }
            .padding(.vertical, 40)
        }
        .scrollPosition(id: .constant(currentLineIndex))
    }
    
    // MARK: - Helper Methods
    private func setupLyricProvider() {
        guard let modelContext = try? ModelContainer(for: CachedLyrics.self).mainContext else {
            return
        }
        lyricProvider = LyricProvider(modelContext: modelContext)
    }
    
    private func loadArtworkColors() {
        Task { @MainActor in
            guard let firstTrack = track.first,
                  let artwork = firstTrack.artwork,
                  let url = artwork.url(width: 512, height: 512) else {
                dominantColors = []
                return
            }
            
            // Load artwork image from URL
            if let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                dominantColors = ColorExtractor.extractDominantColors(from: image)
            } else {
                dominantColors = []
            }
        }
    }
    
    private func loadLyrics() {
        Task { @MainActor in
            guard let provider = lyricProvider else {
                errorMessage = "Lyric provider not initialized"
                return
            }
            
            // Clear previous state
            errorMessage = nil
            trackLyrics = nil
            
            // Use provided song name and artist name
            let title = songName.isEmpty ? "Unknown" : songName
            let artist = artistName.isEmpty ? "Unknown" : artistName
            
            await provider.fetchLyrics(
                trackId: UUID().uuidString, // Generate a unique ID for this search
                title: title,
                artist: artist,
                isFavorite: false
            )
            
            // Get results from provider
            trackLyrics = provider.trackLyrics
            errorMessage = provider.errorMessage
            
            // Update sync clock with lyrics
            if let lyrics = trackLyrics {
                syncClock.updateLyrics(lyrics.lyrics)
            }
        }
    }
    
    private func setupSyncClock() {
        syncClock.updateLyrics(trackLyrics?.lyrics ?? [])
    }
}

// MARK: - Preview
#Preview {
    LyricsView(track: [], songName: "Demo Song", artistName: "Demo Artist")
}
