import Foundation

// 単語やフレーズ単位のタイミング情報
struct TimedWord {
    let text: String
    let startTime: Double  // 秒
    let duration: Double   // 秒
}

struct LyricLine: Identifiable {
    let id = UUID()
    let timestamp: Double       // 行全体のタイムスタンプ（秒）
    let text: String           // 行全体のテキスト
    var translation: String?
    
    // オプション：単語ごとのタイミング（正確なカラオケ用）
    var timedWords: [TimedWord]?
    
    // 行の推定される終了時刻
    var estimatedEndTime: Double {
        if let words = timedWords, !words.isEmpty {
            return words.last!.startTime + words.last!.duration
        }
        // デフォルト：テキストの長さに基づいた推定時間
        // 英語の音声速度は通常200-250単語/分
        let wordCount = Double(text.split(separator: " ").count)
        let estimatedDuration = max(wordCount / 3.0, 3.0)  // 最小3秒
        return timestamp + estimatedDuration
    }
}
