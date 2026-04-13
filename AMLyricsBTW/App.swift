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
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var showSettings = false
    
    var body: some View {
        VStack {
            if showLyrics {
                LyricsView(track: MusicItemCollection([]), songName: songName, artistName: artistName)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                showLyrics = false
                            }
                        }
                    }
            } else if showSettings {
                ServerSettingsView(serverURL: $serverURL, apiKey: $apiKey, isPresented: $showSettings)
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
                    
                    Button("Server Settings") {
                        showSettings = true
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .onAppear {
            // Load saved settings
            serverURL = UserDefaults.standard.string(forKey: "serverBaseURL") ?? "http://192.168.x.x:8000"
            apiKey = UserDefaults.standard.string(forKey: "serverAPIKey") ?? ""
        }
    }
}

struct ServerSettingsView: View {
    @Binding var serverURL: String
    @Binding var apiKey: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Server Settings")
                .font(.title)
            
            Text("Enter your iMac's local IP address")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("Server URL (e.g., http://192.168.1.100:8000)", text: $serverURL)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)
            
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Save") {
                    UserDefaults.standard.set(serverURL, forKey: "serverBaseURL")
                    UserDefaults.standard.set(apiKey, forKey: "serverAPIKey")
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Find iMac IP: System Settings → Network → Wi-Fi → Details")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 300)
    }
}
