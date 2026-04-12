import Foundation

struct LRCParser {
    // "[01:23.45] Hello world" → LyricLine
    // 拡張フォーマット: "[01:23.45][01:24.10]Hello[01:24.50]world" もサポート
    static func parse(_ lrc: String) -> [LyricLine] {
        let lines = lrc.components(separatedBy: "\n")
        var result: [LyricLine] = []
        
        // 基本的なLRCパターン
        let basicRegex = try? NSRegularExpression(
            pattern: #"^\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)"#
        )
        
        // 拡張フォーマット（単語ごとのタイムコード付き）
        let extendedRegex = try? NSRegularExpression(
            pattern: #"^\[(\d{2}):(\d{2})\.(\d{2,3})\](.+)"#
        )
        
        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(line.startIndex..., in: line)
            
            // 拡張フォーマットをチェック（複数のタイムコード）
            if let _ = extendedRegex?.firstMatch(in: line, range: range),
               line.contains("]") && line.filter({ $0 == "[" }).count > 1 {
                if let lyricLine = parseExtendedFormat(line) {
                    result.append(lyricLine)
                }
            }
            // 基本フォーマット
            else if let match = basicRegex?.firstMatch(in: line, range: range) {
                let min = Double((line as NSString).substring(with: match.range(at: 1))) ?? 0
                let sec = Double((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let msStr = (line as NSString).substring(with: match.range(at: 3))
                let ms = Double(msStr) ?? 0
                let msFactor = msStr.count == 2 ? 100.0 : 1.0
                let timestamp = min * 60 + sec + ms / msFactor
                let text = (line as NSString).substring(with: match.range(at: 4))
                    .trimmingCharacters(in: .whitespaces)
                
                if !text.isEmpty {
                    result.append(LyricLine(
                        timestamp: timestamp,
                        text: text,
                        timedWords: nil
                    ))
                }
            }
        }
        
        return result.sorted { $0.timestamp < $1.timestamp }
    }
    
    // 拡張フォーマット: [MM:SS.ms][MM:SS.ms]word1[MM:SS.ms]word2...
    private static func parseExtendedFormat(_ line: String) -> LyricLine? {
        var currentText = ""
        var timedWords: [TimedWord] = []
        var lineTimestamp: Double? = nil
        
        let pattern = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]"#)
        guard let pattern = pattern else { return nil }
        
        var lastEndIndex = line.startIndex
        var matches: [(NSRange, Double)] = []
        
        // すべてのタイムコードとそのタイムスタンプを抽出
        let nsLine = line as NSString
        let fullRange = NSRange(line.startIndex..., in: line)
        pattern.enumerateMatches(in: line, range: fullRange) { match, _, _ in
            guard let match = match else { return }
            
            let min = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
            let sec = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
            let msStr = nsLine.substring(with: match.range(at: 3))
            let ms = Double(msStr) ?? 0
            let msFactor = msStr.count == 2 ? 100.0 : 1.0
            let timestamp = min * 60 + sec + ms / msFactor
            
            matches.append((match.range, timestamp))
            
            if lineTimestamp == nil {
                lineTimestamp = timestamp
            }
        }
        
        guard let startTimestamp = lineTimestamp, !matches.isEmpty else { return nil }
        
        // テキストとタイムスタンプを対応させる
        var textIndex = 0
        while textIndex < matches.count {
            let (currentMatch, currentTime) = matches[textIndex]
            let nextTime = textIndex + 1 < matches.count ? matches[textIndex + 1].1 : currentTime + 0.5
            
            // 現在のタイムコードの直後にあるテキストを抽出
            let endOfCurrentMatch = currentMatch.location + currentMatch.length
            var textEnd = endOfCurrentMatch
            
            // 次のタイムコードが見つかるまでのテキストを抽出
            if textIndex + 1 < matches.count {
                textEnd = matches[textIndex + 1].0.location
            } else {
                textEnd = line.count
            }
            
            let textRange = NSRange(location: endOfCurrentMatch, length: textEnd - endOfCurrentMatch)
            let word = nsLine.substring(with: textRange).trimmingCharacters(in: .whitespaces)
            
            if !word.isEmpty {
                timedWords.append(TimedWord(
                    text: word,
                    startTime: currentTime,
                    duration: nextTime - currentTime
                ))
            }
            
            textIndex += 1
        }
        
        let fullText = timedWords.map { $0.text }.joined(separator: " ")
        
        if !fullText.isEmpty {
            return LyricLine(
                timestamp: startTimestamp,
                text: fullText,
                timedWords: timedWords.isEmpty ? nil : timedWords
            )
        }
        
        return nil
    }
}
