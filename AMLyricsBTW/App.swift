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
    @State private var showLyrics = false
    
    var body: some View {
        VStack {
            if showLyrics {
                // Use mock track for now to demonstrate lyrics display
                LyricsView(track: MusicItemCollection([]))
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("AMLyricsBTW")
                        .font(.largeTitle)
                    
                    Button("Show Demo Lyrics") {
                        showLyrics = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
