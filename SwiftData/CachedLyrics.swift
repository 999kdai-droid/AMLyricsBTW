import Foundation
import SwiftData

// MARK: - Cached Lyrics Model
@Model
final class CachedLyrics {
    var trackId: String
    var title: String
    var artist: String
    var lyricsJSON: Data
    var cachedAt: Date
    
    init(trackId: String, title: String, artist: String, lyricsJSON: Data, cachedAt: Date = Date()) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.lyricsJSON = lyricsJSON
        self.cachedAt = cachedAt
    }
    
    // MARK: - Convert to TrackLyrics
    func toTrackLyrics() throws -> TrackLyrics {
        let decoder = JSONDecoder()
        return try decoder.decode(TrackLyrics.self, from: lyricsJSON)
    }
    
    // MARK: - Create from TrackLyrics
    static func from(trackLyrics: TrackLyrics) throws -> CachedLyrics {
        let encoder = JSONEncoder()
        let lyricsJSON = try encoder.encode(trackLyrics)
        
        return CachedLyrics(
            trackId: trackLyrics.trackId,
            title: trackLyrics.title,
            artist: trackLyrics.artist,
            lyricsJSON: lyricsJSON,
            cachedAt: Date()
        )
    }
    
    // MARK: - Cleanup Old Cache
    static func cleanupOldCache(context: ModelContext, retentionDays: Int = 30) -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<CachedLyrics>(
            predicate: #Predicate { $0.cachedAt < cutoffDate }
        )
        
        let oldEntries = try? context.fetch(descriptor)
        var deletedCount = 0
        
        for entry in oldEntries ?? [] {
            context.delete(entry)
            deletedCount += 1
        }
        
        try? context.save()
        return deletedCount
    }
}

// MARK: - SwiftData Container Extension
extension ModelContext {
    func getCachedLyrics(trackId: String) -> TrackLyrics? {
        let descriptor = FetchDescriptor<CachedLyrics>(
            predicate: #Predicate { $0.trackId == trackId }
        )
        
        guard let cached = try? fetch(descriptor).first else {
            return nil
        }
        
        return try? cached.toTrackLyrics()
    }
    
    func cacheLyrics(_ trackLyrics: TrackLyrics) throws {
        // Remove existing cache if present
        let existingDescriptor = FetchDescriptor<CachedLyrics>(
            predicate: #Predicate { $0.trackId == trackLyrics.trackId }
        )
        
        if let existing = try? fetch(existingDescriptor).first {
            delete(existing)
        }
        
        // Create new cache entry
        let cached = try CachedLyrics.from(trackLyrics: trackLyrics)
        insert(cached)
        try save()
    }
}
