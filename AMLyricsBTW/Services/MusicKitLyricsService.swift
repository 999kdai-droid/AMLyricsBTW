import Foundation

struct MusicKitLyricsService {

    static func fetchLyrics(title: String, artist: String) async -> [LyricLine] {
        // Music.appから直接歌詞を取得（AppleScript）
        if let lines = fetchFromMusicApp() {
            print("✅ 歌詞ソース: Music.app（Apple Music同期歌詞）\(lines.count)行")
            return lines
        }
        return []
    }

    static func fetchCurrentLyrics() -> [LyricLine] {
        return fetchFromMusicApp() ?? []
    }

    private static func fetchFromMusicApp() -> [LyricLine]? {
        let script = """
        tell application "Music"
            if player state is playing then
                try
                    set lyr to lyrics of current track
                    return lyr
                on error
                    return ""
                end try
            end if
            return ""
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run(); task.waitUntilExit() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        // Music.appの歌詞は通常プレーンテキスト（タイムスタンプなし）
        // → 3秒間隔で仮タイムスタンプを付ける
        let lines = raw.components(separatedBy: "\n")
            .enumerated()
            .compactMap { i, line -> LyricLine? in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return nil }
                return LyricLine(timestamp: Double(i) * 3.0, text: t)
            }
        return lines.isEmpty ? nil : lines
    }
}
