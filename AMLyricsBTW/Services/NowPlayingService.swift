import Foundation
import Combine

@MainActor
class NowPlayingService: ObservableObject {
    @Published var currentTrack: Track = .empty
    @Published var playerPosition: Double = 0
    @Published var isPlaying: Bool = false

    private var timer: Timer?
    private var displayTimer: Timer?
    private var lastPollTime: Date = Date()
    private var lastPollPosition: Double = 0

    func start() {
        poll()
        // ポーリング：0.016秒（60fps）で更新
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollOrInterpolate() }
        }
    }

    func stop() { timer?.invalidate() }

    private func pollOrInterpolate() {
        let elapsed = Date().timeIntervalSince(lastPollTime)
        if elapsed >= 1.0 {
            // 1秒ごとに実際にAppleScriptで取得
            poll()
        } else if isPlaying {
            // その間は線形補間で推定（スムーズなアニメーション）
            playerPosition = lastPollPosition + elapsed
        }
    }

    private func poll() {
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set t to name of current track
                set ar to artist of current track
                set al to album of current track
                set pos to player position
                set pstate to (player state is playing) as string
                return t & "|||" & ar & "|||" & al & "|||" & (pos as string) & "|||" & pstate
            else
                return "STOPPED"
            end if
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
        } catch { return }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              raw != "STOPPED", !raw.isEmpty else {
            isPlaying = false
            return
        }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 5 else { return }
        let pos = Double(parts[3]) ?? 0
        let isPlayingStr = parts[4].lowercased()
        
        // 時刻を記録して補間用に保存
        lastPollTime = Date()
        lastPollPosition = pos
        playerPosition = pos
        isPlaying = isPlayingStr == "true"
        
        if parts[0] != currentTrack.title || parts[1] != currentTrack.artist {
            currentTrack = Track(
                title: parts[0],
                artist: parts[1],
                album: parts[2],
                artworkURL: currentTrack.artworkURL,
                playerPosition: pos
            )
        }
    }
    
    func setPlayerPosition(_ position: Double) {
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set player position to \(position)
                return "OK"
            end if
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return }
        // 即座に更新
        playerPosition = position
        lastPollPosition = position
        lastPollTime = Date()
    }
    
    func togglePlayPause() {
        let script = """
        tell application "Music"
            playpause
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return }
        
        // 状態を更新するために poll() を呼び出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.poll()
        }
    }
    
    func nextTrack() {
        let script = """
        tell application "Music"
            next track
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.poll()
        }
    }
    
    func previousTrack() {
        let script = """
        tell application "Music"
            previous track
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.poll()
        }
    }
    
    func playTrack(named trackName: String) {
        let script = """
        tell application "Music"
            set found to false
            repeat with t in (every track)
                if (name of t) = "\(trackName)" then
                    play t
                    set found to true
                    exit repeat
                end if
            end repeat
            return found as string
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.poll()
        }
    }
}
