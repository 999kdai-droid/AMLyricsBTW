import SwiftUI
import MusicKit
import SwiftData

// MARK: - Lyric Provider
@MainActor
@Observable
final class LyricProvider {
    
    private let serverClient: ServerClient
    private let modelContext: ModelContext
    
    var isLoading: Bool = false
    var errorMessage: String?
    var trackLyrics: TrackLyrics?
    
    init(serverClient: ServerClient = .shared, modelContext: ModelContext) {
        self.serverClient = serverClient
        self.modelContext = modelContext
    }
    
    // MARK: - Fetch Lyrics with Priority Chain
    func fetchLyrics(
        trackId: String,
        title: String,
        artist: String,
        isFavorite: Bool
    ) async {
        isLoading = true
        errorMessage = nil
        
        // Priority 1: SwiftData local cache
        if let cached = modelContext.getCachedLyrics(trackId: trackId) {
            trackLyrics = cached
            isLoading = false
            return
        }
        
        // Priority 2: Server cache
        do {
            let serverCached = try await serverClient.getCachedLyrics(trackId: trackId)
            trackLyrics = serverCached
            
            // Save to local cache
            try? modelContext.cacheLyrics(serverCached)
            
            isLoading = false
            return
        } catch {
            // Continue to next priority
        }
        
        // Priority 3: New analysis request
        do {
            let jobResponse = try await serverClient.analyzeTrack(
                trackId: trackId,
                title: title,
                artist: artist,
                isFavorite: isFavorite
            )
            
            // Poll for job completion
            let result = try await pollJobStatus(jobId: jobResponse.jobId)
            
            if let lyrics = result {
                trackLyrics = lyrics
                
                // Save to local cache
                try? modelContext.cacheLyrics(lyrics)
            }
            
            isLoading = false
            return
        } catch {
            // Continue to fallback
        }
        
        // Priority 4: Fallback to Spotify-Lyric-API
        do {
            let spotifyLyrics = try await fetchSpotifyLyrics(trackId: trackId, title: title, artist: artist)
            trackLyrics = spotifyLyrics
            
            // Save to local cache (without word-level timestamps)
            try? modelContext.cacheLyrics(spotifyLyrics)
            
            isLoading = false
            return
        } catch {
            errorMessage = "Failed to fetch lyrics from all sources"
        }
        
        isLoading = false
    }
    
    // MARK: - Poll Job Status
    private func pollJobStatus(jobId: String) async throws -> TrackLyrics? {
        let pollingInterval: TimeInterval = 3.0
        let timeout: TimeInterval = 600.0 // 10 minutes
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let status = try await serverClient.getJobStatus(jobId: jobId)
            
            switch status.status {
            case "queued", "processing":
                // Continue polling
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
                
            case "done":
                if let result = status.result {
                    return result
                } else {
                    throw LyricProviderError.noResult
                }
                
            case "error":
                if let error = status.error {
                    throw LyricProviderError.analysisFailed(error)
                } else {
                    throw LyricProviderError.unknownError
                }
                
            default:
                throw LyricProviderError.unknownError
            }
        }
        
        throw LyricProviderError.timeout
    }
    
    // MARK: - Spotify-Lyric-API Fallback
    private func fetchSpotifyLyrics(trackId: String, title: String, artist: String) async throws -> TrackLyrics {
        // Use Spotify-Lyric-API from akashrchandran
        // This API requires a Spotify track ID, so we need to search first
        // Format: https://spotify-lyrics-api.akashrchandran.vercel.app/?trackid=spotify:track:TRACK_ID
        
        // First, search for the track to get Spotify ID
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchUrlString = "https://spotify-lyrics-api.akashrchandran.vercel.app/?q=\(query)"
        
        guard let searchUrl = URL(string: searchUrlString) else {
            throw LyricProviderError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: searchUrl)
        let spotifyResponse = try JSONDecoder().decode(SpotifyLyricsResponse.self, from: data)
        
        // Check if lyrics are available
        if spotifyResponse.lines.isEmpty {
            throw LyricProviderError.noResult
        }
        
        // Convert to TrackLyrics format (without word-level timestamps)
        let lyrics = spotifyResponse.lines.enumerated().map { index, line in
            LyricsLine(
                lineIndex: index,
                start: Double(line.startTimeMs) / 1000.0,
                end: 0.0, // Spotify API doesn't provide end times
                text: line.words,
                translation: "", // No translation from Spotify API
                words: nil // No word-level timestamps
            )
        }
        
        // Estimate end times
        let lyricsWithEndTimes = estimateEndTimes(for: lyrics)
        
        return TrackLyrics(
            trackId: trackId,
            title: spotifyResponse.lines.first?.words ?? title,
            artist: artist,
            silenceOffset: 0.0,
            lyrics: lyricsWithEndTimes,
            cachedAt: nil
        )
    }
    
    // MARK: - Helper: Estimate End Times
    private func estimateEndTimes(for lyrics: [LyricsLine]) -> [LyricsLine] {
        var result: [LyricsLine] = []
        
        for (index, line) in lyrics.enumerated() {
            var end = line.end
            
            if index < lyrics.count - 1 {
                // Use the next line's start as this line's end
                end = lyrics[index + 1].start
            } else {
                // Last line: estimate based on text length
                end = line.start + Double(line.text.count) * 0.15
            }
            
            result.append(LyricsLine(
                lineIndex: line.lineIndex,
                start: line.start,
                end: end,
                text: line.text,
                translation: line.translation,
                words: line.words
            ))
        }
        
        return result
    }
}

// MARK: - Lyric Provider Error
enum LyricProviderError: LocalizedError {
    case noResult
    case analysisFailed(String)
    case timeout
    case invalidURL
    case networkError(Error)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .noResult:
            return "No lyrics result returned"
        case .analysisFailed(let message):
            return "Analysis failed: \(message)"
        case .timeout:
            return "Request timed out"
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
