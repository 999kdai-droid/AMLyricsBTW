import SwiftUI
import MusicKit

// MARK: - Main Lyrics View
struct LyricsView: View {
    @State private var trackLyrics: TrackLyrics?
    @State private var dominantColors: [NSColor] = []
    @State private var currentLineIndex: Int = 0
    @State private var currentTime: Double = 0.0
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    let track: MusicItemCollection<Track>
    
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
            loadArtworkColors()
            loadLyrics()
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
            colors: dominantColors.isEmpty ? 
                [Color.blue.opacity(0.3), Color.purple.opacity(0.3), Color.pink.opacity(0.3)] :
                Array(dominantColors.prefix(3).map { Color(nsColor: $0).opacity(0.4) } + 
                      Array(repeating: Color.black.opacity(0.2), count: max(0, 6 - dominantColors.count)))
        )
        .animation(.easeInOut(duration: 1.5), value: dominantColors)
    }
    
    // MARK: - Lyrics Scroll View
    private func lyricsScrollView(_ lyrics: TrackLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(lyrics.lyrics.enumerated()), id: \.offset) { index, line in
                        let isActive = index == currentLineIndex
                        
                        if line.words != nil && !line.words!.isEmpty {
                            KaraokeLineView(
                                line: line,
                                currentTime: currentTime,
                                isActive: isActive
                            )
                            .id("line-\(index)")
                        } else {
                            LyricsLineView(
                                line: line,
                                isActive: isActive,
                                currentTime: currentTime
                            )
                            .id("line-\(index)")
                        }
                    }
                }
                .padding(.vertical, 40)
            }
            .onChange(of: currentLineIndex) { _, newIndex in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    proxy.scrollTo("line-\(newIndex)", anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading lyrics...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No lyrics available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    private func loadArtworkColors() {
        Task { @MainActor in
            guard let firstTrack = track.first,
                  let artwork = firstTrack.artwork else {
                dominantColors = []
                return
            }
            
            let image = await artwork.load()
            if let nsImage = image {
                dominantColors = ColorExtractor.extractDominantColors(from: nsImage)
            }
        }
    }
    
    private func loadLyrics() {
        // This will be connected to LyricProvider in the full implementation
        // For now, use mock data
        Task { @MainActor in
            isLoading = true
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate loading
            
            trackLyrics = TrackLyrics.mock
            isLoading = false
        }
    }
}

// MARK: - Preview
#Preview {
    LyricsView(track: [])
}
