import Foundation

// MARK: - Server Client
@MainActor
final class ServerClient: Sendable {
    
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    
    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 600.0 // 10 minutes for long-running jobs
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Analyze Track
    func analyzeTrack(
        trackId: String,
        title: String,
        artist: String,
        isFavorite: Bool
    ) async throws -> JobResponse {
        let endpoint = "/analyze"
        let body = [
            "track_id": trackId,
            "title": title,
            "artist": artist,
            "is_favorite": isFavorite
        ] as [String: Any]
        
        let response: JobResponse = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body
        )
        
        return response
    }
    
    // MARK: - Get Job Status
    func getJobStatus(jobId: String) async throws -> JobStatusResponse {
        let endpoint = "/status/\(jobId)"
        
        let response: JobStatusResponse = try await performRequest(
            endpoint: endpoint,
            method: "GET"
        )
        
        return response
    }
    
    // MARK: - Get Cached Lyrics
    func getCachedLyrics(trackId: String) async throws -> TrackLyrics {
        let endpoint = "/cache/\(trackId)"
        
        let response: TrackLyrics = try await performRequest(
            endpoint: endpoint,
            method: "GET"
        )
        
        return response
    }
    
    // MARK: - Get Queue Status
    func getQueueStatus() async throws -> QueueStatusResponse {
        let endpoint = "/queue"
        
        let response: QueueStatusResponse = try await performRequest(
            endpoint: endpoint,
            method: "GET"
        )
        
        return response
    }
    
    // MARK: - Perform Request
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        retries: Int = 1
    ) async throws -> T {
        let urlString = baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw ServerError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServerError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            case 401:
                throw ServerError.unauthorized
            case 403:
                throw ServerError.forbidden
            case 404:
                throw ServerError.notFound
            default:
                throw ServerError.serverError(httpResponse.statusCode)
            }
        } catch {
            if retries > 0 {
                // Retry once after 3 seconds
                try await Task.sleep(nanoseconds: 3_000_000_000)
                return try await performRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    retries: retries - 1
                )
            }
            throw error
        }
    }
}

// MARK: - Server Error
enum ServerError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - check API key"
        case .forbidden:
            return "Forbidden - access denied"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - UserDefaults Extension for Configuration
extension UserDefaults {
    enum Keys {
        static let serverBaseURL = "serverBaseURL"
        static let serverAPIKey = "serverAPIKey"
    }
    
    var serverBaseURL: String {
        get { string(forKey: Keys.serverBaseURL) ?? "http://192.168.1.100:8000" }
        set { set(newValue, forKey: Keys.serverBaseURL) }
    }
    
    var serverAPIKey: String {
        get { string(forKey: Keys.serverAPIKey) ?? "" }
        set { set(newValue, forKey: Keys.serverAPIKey) }
    }
}

// MARK: - Shared Instance
extension ServerClient {
    static let shared: ServerClient = {
        let defaults = UserDefaults.standard
        return ServerClient(
            baseURL: defaults.serverBaseURL,
            apiKey: defaults.serverAPIKey
        )
    }()
}
