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
    @State private var songName = ""
    @State private var artistName = ""
    @State private var showLyrics = false
    
    var body: some View {
        VStack {
            if showLyrics {
                LyricsView(track: MusicItemCollection([]), songName: songName, artistName: artistName)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("AMLyricsBTW")
                        .font(.largeTitle)
                    
                    TextField("Song Name", text: $songName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    
                    TextField("Artist Name", text: $artistName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    
                    Button("Search Lyrics") {
                        showLyrics = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(songName.isEmpty || artistName.isEmpty)
                }
                .padding()
            }
        }
    }
}
