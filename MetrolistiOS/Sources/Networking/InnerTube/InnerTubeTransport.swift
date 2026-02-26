import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MetrolistCore

// MARK: - InnerTube HTTP Transport

/// Low-level HTTP transport for InnerTube API calls.
/// Equivalent to Android's `InnerTube` class. All methods return raw response data.
public actor InnerTubeTransport {
    private let baseURL = URL(string: "https://music.youtube.com/youtubei/v1/")!
    private let session: URLSession
    private let auth: InnerTubeAuth
    private var locale: YouTubeLocale
    private var visitorData: String?

    private let maxRetries = 3
    private let initialRetryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    public init(auth: InnerTubeAuth, locale: YouTubeLocale = YouTubeLocale()) {
        self.auth = auth
        self.locale = locale

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate",
            "Accept-Language": "en-US,en;q=0.9",
        ]
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024,
            diskPath: nil
        )
        self.session = URLSession(configuration: config)
    }

    public func setLocale(_ locale: YouTubeLocale) {
        self.locale = locale
    }

    public func setVisitorData(_ data: String?) {
        self.visitorData = data
    }

    // MARK: - Core Request Builder

    private func buildRequest(
        endpoint: String,
        body: Encodable,
        profile: YouTubeClientProfile = .webRemix,
        requiresAuth: Bool = false
    ) async throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(profile.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("1", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        request.setValue(String(profile.clientId), forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(profile.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")

        if let visitorData {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        if requiresAuth {
            if let authHeader = await auth.authorizationHeader() {
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            }
            if let cookie = await auth.cookieHeader {
                request.setValue(cookie, forHTTPHeaderField: "Cookie")
            }
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        return request
    }

    // MARK: - Execute with Retry

    private func execute(_ request: URLRequest) async throws -> Data {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw InnerTubeError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw InnerTubeError.httpError(statusCode: httpResponse.statusCode, data: data)
                }
                return data
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = initialRetryDelay * UInt64(1 << attempt)
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? InnerTubeError.unknownError
    }

    // MARK: - API Endpoints

    public func search(query: String?, params: String? = nil, profile: YouTubeClientProfile = .webRemix) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let query: String?
            let params: String?
        }
        let body = Body(context: makeContext(profile: profile), query: query, params: params)
        let request = try await buildRequest(endpoint: "search", body: body, profile: profile)
        return try await execute(request)
    }

    public func player(videoId: String, playlistId: String? = nil, profile: YouTubeClientProfile = .ios, sigTimestamp: Int? = nil, poToken: String? = nil) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let videoId: String
            let playlistId: String?
            let contentCheckOk: Bool
            let racyCheckOk: Bool
            let playbackContext: PlaybackContext?

            struct PlaybackContext: Codable {
                let contentPlaybackContext: ContentPlaybackContext

                struct ContentPlaybackContext: Codable {
                    let signatureTimestamp: Int?
                }
            }
        }
        let playbackContext = sigTimestamp.map {
            Body.PlaybackContext(contentPlaybackContext: .init(signatureTimestamp: $0))
        }
        let body = Body(
            context: makeContext(profile: profile),
            videoId: videoId,
            playlistId: playlistId,
            contentCheckOk: true,
            racyCheckOk: true,
            playbackContext: playbackContext
        )
        let request = try await buildRequest(endpoint: "player", body: body, profile: profile, requiresAuth: true)
        return try await execute(request)
    }

    public func browse(browseId: String? = nil, params: String? = nil, continuation: String? = nil, profile: YouTubeClientProfile = .webRemix) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let browseId: String?
            let params: String?
            let continuation: String?
        }
        let body = Body(context: makeContext(profile: profile), browseId: browseId, params: params, continuation: continuation)
        let request = try await buildRequest(endpoint: "browse", body: body, profile: profile, requiresAuth: true)
        return try await execute(request)
    }

    public func next(videoId: String? = nil, playlistId: String? = nil, continuation: String? = nil, profile: YouTubeClientProfile = .webRemix) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let videoId: String?
            let playlistId: String?
            let continuation: String?
        }
        let body = Body(context: makeContext(profile: profile), videoId: videoId, playlistId: playlistId, continuation: continuation)
        let request = try await buildRequest(endpoint: "next", body: body, profile: profile, requiresAuth: true)
        return try await execute(request)
    }

    public func getSearchSuggestions(input: String) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let input: String
        }
        let body = Body(context: makeContext(profile: .webRemix), input: input)
        let request = try await buildRequest(endpoint: "music/get_search_suggestions", body: body)
        return try await execute(request)
    }

    public func getQueue(videoIds: [String]? = nil, playlistId: String? = nil) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let videoIds: [String]?
            let playlistId: String?
        }
        let body = Body(context: makeContext(profile: .webRemix), videoIds: videoIds, playlistId: playlistId)
        let request = try await buildRequest(endpoint: "music/get_queue", body: body)
        return try await execute(request)
    }

    public func like(videoId: String) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let target: Target
            struct Target: Codable { let videoId: String }
        }
        let body = Body(context: makeContext(profile: .webRemix), target: .init(videoId: videoId))
        let request = try await buildRequest(endpoint: "like/like", body: body, requiresAuth: true)
        return try await execute(request)
    }

    public func removeLike(videoId: String) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let target: Target
            struct Target: Codable { let videoId: String }
        }
        let body = Body(context: makeContext(profile: .webRemix), target: .init(videoId: videoId))
        let request = try await buildRequest(endpoint: "like/removelike", body: body, requiresAuth: true)
        return try await execute(request)
    }

    public func createPlaylist(title: String, privacyStatus: String = "PRIVATE", videoIds: [String]? = nil) async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let title: String
            let privacyStatus: String
            let videoIds: [String]?
        }
        let body = Body(context: makeContext(profile: .webRemix), title: title, privacyStatus: privacyStatus, videoIds: videoIds)
        let request = try await buildRequest(endpoint: "playlist/create", body: body, requiresAuth: true)
        return try await execute(request)
    }

    public func accountMenu() async throws -> Data {
        struct Body: Codable {
            let context: InnerTubeContext
            let deviceTheme: String
            let userInterfaceTheme: String
        }
        let body = Body(context: makeContext(profile: .webRemix), deviceTheme: "DEVICE_THEME_SELECTED", userInterfaceTheme: "USER_INTERFACE_THEME_DARK")
        let request = try await buildRequest(endpoint: "account/account_menu", body: body, requiresAuth: true)
        return try await execute(request)
    }

    // MARK: - Context Factory

    private func makeContext(profile: YouTubeClientProfile) -> InnerTubeContext {
        InnerTubeContext(profile: profile, locale: locale, visitorData: visitorData)
    }
}

// MARK: - Errors

public enum InnerTubeError: Error, LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(String)
    case unknownError
    case notPlayable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code, _): "HTTP error \(code)"
        case .decodingError(let msg): "Decoding error: \(msg)"
        case .unknownError: "Unknown error"
        case .notPlayable(let reason): "Not playable: \(reason)"
        }
    }
}
