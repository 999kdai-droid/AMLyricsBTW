import Foundation

struct AlbumTrack: Identifiable {
    let id = UUID()
    let discNumber: Int
    let trackNumber: Int
    let name: String
    let artist: String
    let duration: TimeInterval
}

class AlbumTracksService {
    static func fetchAlbumTracks(albumName: String, artist: String) async -> [AlbumTrack] {
        let script = """
        tell application "Music"
            set foundTracks to ""
            try
                if player state is playing or player state is paused then
                    set currentAlbum to album of current track
                    set currentArtist to artist of current track
                    if currentAlbum = "\(albumName)" and currentArtist = "\(artist)" then
                        set allTracks to {}
                        repeat with t in (every track)
                            if (album of t) = currentAlbum and (artist of t) = currentArtist then
                                set allTracks to allTracks & {t}
                            end if
                        end repeat
                        repeat with t in allTracks
                            set dn to disc number of t
                            set tn to track number of t
                            set nn to name of t
                            set dur to (duration of t as string)
                            set foundTracks to foundTracks & (dn as string) & "|||" & (tn as string) & "|||" & nn & "|||" & dur & linefeed
                        end repeat
                    end if
                end if
            end try
            return foundTracks
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return []
        }
        
        let trackLines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        var tracks: [AlbumTrack] = []
        var seenTracks = Set<String>()
        
        for line in trackLines {
            let parts = line.components(separatedBy: "|||")
            if parts.count >= 4 {
                let discNum = Int(parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "{}"))) ?? 1
                let trackNum = Int(parts[1]) ?? 0
                let trackName = parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                let duration = TimeInterval(parts[3]) ?? 0
                
                let trackKey = "\(discNum)-\(trackNum)-\(trackName)"
                guard !seenTracks.contains(trackKey) else { continue }
                seenTracks.insert(trackKey)
                
                tracks.append(AlbumTrack(
                    discNumber: discNum,
                    trackNumber: trackNum,
                    name: trackName,
                    artist: artist,
                    duration: duration
                ))
            }
        }
        
        return tracks.sorted { a, b in
            if a.discNumber != b.discNumber {
                return a.discNumber < b.discNumber
            }
            return a.trackNumber < b.trackNumber
        }
    }
}
