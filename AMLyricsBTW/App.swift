import SwiftUI
import MusicKit
import SwiftData
import Combine

@main
struct AMLyricsBTWApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CachedLyrics.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct ContentView: View {
    @State private var currentSongName: String = ""
    @State private var currentArtistName: String = ""
    @State private var isPlaying: Bool = false
    @State private var timer: Timer? = nil
    
    var body: some View {
        Group {
            if currentSongName.isEmpty {
                // No music playing
                VStack(spacing: 20) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("No music playing")
                        .font(.headline)
                    
                    Text("Play a song in Apple Music to see lyrics")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                // Show lyrics for current track
                LyricsView(
                    track: MusicItemCollection([]),
                    songName: currentSongName,
                    artistName: currentArtistName
                )
            }
        }
        .onAppear {
            startMonitoringMusic()
        }
        .onDisappear {
            stopMonitoringMusic()
        }
    }
    
    @MainActor
    private func startMonitoringMusic() {
        // Check immediately
        Task { @MainActor in
            await checkNowPlaying()
        }
        
        // Check every 3 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                await checkNowPlaying()
            }
        }
    }
    
    @MainActor
    private func stopMonitoringMusic() {
        timer?.invalidate()
        timer = nil
    }
    
    @MainActor
    private func checkNowPlaying() async {
        // Request authorization if needed
        let status = MusicAuthorization.currentStatus
        if status == .notDetermined {
            _ = await MusicAuthorization.request()
        }
        
        // Use ApplicationMusicPlayer for macOS
        let player = ApplicationMusicPlayer.shared
        let queue = player.queue
        
        if let entry = queue.currentEntry, let item = entry.item {
            // Use description which typically contains "Title - Artist"
            let description = item.description
            // Try to parse "Title - Artist" format
            let components = description.components(separatedBy: " - ")
            if components.count >= 2 {
                currentSongName = components[0].trimmingCharacters(in: .whitespaces)
                currentArtistName = components[1].trimmingCharacters(in: .whitespaces)
            } else {
                currentSongName = description
                currentArtistName = "Unknown Artist"
            }
            isPlaying = player.state.playbackStatus == .playing
        } else {
            // Nothing playing
            currentSongName = ""
            currentArtistName = ""
            isPlaying = false
        }
    }
}

