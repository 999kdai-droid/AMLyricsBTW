import Foundation

// MARK: - Word Timestamp
struct WordTimestamp: Codable, Sendable {
    let word: String
    let start: Double
    let end: Double
}

// MARK: - Lyrics Line
struct LyricsLine: Codable, Sendable, Identifiable {
    let id = UUID()
    let lineIndex: Int
    let start: Double
    let end: Double
    let text: String
    var translation: String
    let words: [WordTimestamp]?
    
    enum CodingKeys: String, CodingKey {
        case lineIndex = "line_index"
        case start, end, text, translation, words
    }
}

// MARK: - Track Lyrics
struct TrackLyrics: Codable, Sendable {
    let trackId: String
    let title: String
    let artist: String
    let silenceOffset: Double
    let lyrics: [LyricsLine]
    let cachedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case title, artist
        case silenceOffset = "silence_offset"
        case lyrics
        case cachedAt = "cached_at"
    }
}

// MARK: - Spotify Lyrics Response (for fallback)
struct SpotifyLyricsResponse: Codable, Sendable {
    let lines: [SpotifyLyricsLine]
    let syncType: String
    
    struct SpotifyLyricsLine: Codable, Sendable {
        let startTimeMs: Int
        let words: String
        
        enum CodingKeys: String, CodingKey {
            case startTimeMs = "startTimeMs"
            case words
        }
    }
}

// MARK: - Job Response
struct JobResponse: Codable, Sendable {
    let jobId: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
    }
}

// MARK: - Job Status Response
struct JobStatusResponse: Codable, Sendable {
    let jobId: String
    let status: String
    let result: TrackLyrics?
    let error: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status, result, error
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Queue Status Response
struct QueueStatusResponse: Codable, Sendable {
    let queued: Int
    let processing: [QueueProcessingJob]
    let totalJobs: Int
    
    enum CodingKeys: String, CodingKey {
        case queued, processing
        case totalJobs = "total_jobs"
    }
    
    struct QueueProcessingJob: Codable, Sendable {
        let jobId: String
        let trackId: String
        let title: String
        let artist: String
        
        enum CodingKeys: String, CodingKey {
            case jobId = "job_id"
            case trackId = "track_id"
            case title, artist
        }
    }
}

// MARK: - Preview Data
extension TrackLyrics {
    static let mock = TrackLyrics(
        trackId: "mock-track-id",
        title: "Juicy",
        artist: "The Notorious B.I.G.",
        silenceOffset: 0.42,
        lyrics: [
            LyricsLine(
                lineIndex: 0,
                start: 12.34,
                end: 14.80,
                text: "It was all a dream",
                translation: "あれは全部夢だった",
                words: [
                    WordTimestamp(word: "It", start: 12.34, end: 12.50),
                    WordTimestamp(word: "was", start: 12.51, end: 12.70),
                    WordTimestamp(word: "all", start: 12.71, end: 12.90),
                    WordTimestamp(word: "a", start: 12.91, end: 13.00),
                    WordTimestamp(word: "dream", start: 13.01, end: 13.80)
                ]
            ),
            LyricsLine(
                lineIndex: 1,
                start: 15.0,
                end: 18.5,
                text: "I used to read Word Up! magazine",
                translation: "俺はWord Up!雑誌を読んでた",
                words: [
                    WordTimestamp(word: "I", start: 15.0, end: 15.2),
                    WordTimestamp(word: "used", start: 15.2, end: 15.5),
                    WordTimestamp(word: "to", start: 15.5, end: 15.7),
                    WordTimestamp(word: "read", start: 15.7, end: 16.0),
                    WordTimestamp(word: "Word", start: 16.0, end: 16.3),
                    WordTimestamp(word: "Up!", start: 16.3, end: 16.8),
                    WordTimestamp(word: "magazine", start: 17.0, end: 18.5)
                ]
            )
        ],
        cachedAt: nil
    )
}

extension LyricsLine {
    static let mockWithoutWords = LyricsLine(
        lineIndex: 0,
        start: 0.0,
        end: 3.0,
        text: "Sample lyrics line",
        translation: "サンプル歌詞行",
        words: nil
    )
}
