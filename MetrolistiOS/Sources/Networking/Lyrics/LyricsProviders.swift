import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MetrolistCore

// MARK: - KuGou Lyrics Service

/// Fetches synchronized lyrics from KuGou's public API.
/// Equivalent to Android's `KuGou` singleton object.
public actor KuGouLyrics {
    public static let shared = KuGouLyrics()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate",
        ]
        self.session = URLSession(configuration: config)
    }

    /// Fetch best-matching lyrics for a song.
    public func getLyrics(title: String, artist: String, duration: Int, album: String? = nil) async -> Result<String, Error> {
        do {
            // Step 1: Search for song hash
            let hash = try await searchSongHash(title: title, artist: artist, duration: duration)

            // Step 2: Search for lyrics candidates using hash
            let candidates = try await searchLyricsCandidates(hash: hash, duration: duration)

            // Step 3: Download best matching lyrics
            guard let best = candidates.first else {
                throw LyricsError.notFound
            }

            return .success(try await downloadLyrics(id: best.id, accessKey: best.accessKey))
        } catch {
            return .failure(error)
        }
    }

    /// Search and stream all available lyrics options.
    public func getAllLyricsOptions(title: String, artist: String, duration: Int, album: String? = nil) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    let hash = try await searchSongHash(title: title, artist: artist, duration: duration)
                    let candidates = try await searchLyricsCandidates(hash: hash, duration: duration)

                    for candidate in candidates {
                        if let lyrics = try? await downloadLyrics(id: candidate.id, accessKey: candidate.accessKey) {
                            continuation.yield(lyrics)
                        }
                    }
                } catch {
                    MetrolistLogger.lyrics.error("KuGou lyrics search failed: \(error.localizedDescription)")
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private API Calls

    private func searchSongHash(title: String, artist: String, duration: Int) async throws -> String {
        var components = URLComponents(string: "https://mobileservice.kugou.com/api/v3/search/song")!
        components.queryItems = [
            URLQueryItem(name: "keyword", value: "\(title) \(artist)"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "10"),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let dataObj = json?["data"] as? [String: Any],
              let info = dataObj["info"] as? [[String: Any]] else {
            throw LyricsError.notFound
        }

        // Find best match by duration
        let target = duration
        let match = info
            .filter { abs(($0["duration"] as? Int ?? 0) - target) <= 5 }
            .first ?? info.first

        guard let hash = match?["hash"] as? String else {
            throw LyricsError.notFound
        }

        return hash
    }

    private struct LyricsCandidate {
        let id: String
        let accessKey: String
        let duration: Int
    }

    private func searchLyricsCandidates(hash: String, duration: Int) async throws -> [LyricsCandidate] {
        var components = URLComponents(string: "https://lyrics.kugou.com/search")!
        components.queryItems = [
            URLQueryItem(name: "ver", value: "1"),
            URLQueryItem(name: "man", value: "yes"),
            URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "hash", value: hash),
            URLQueryItem(name: "duration", value: String(duration * 1000)),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let candidates = json?["candidates"] as? [[String: Any]] else {
            return []
        }

        return candidates.compactMap { c in
            guard let id = c["id"] as? String ?? (c["id"] as? Int).map(String.init),
                  let accessKey = c["accesskey"] as? String else { return nil }
            return LyricsCandidate(id: id, accessKey: accessKey, duration: c["duration"] as? Int ?? 0)
        }
    }

    private func downloadLyrics(id: String, accessKey: String) async throws -> String {
        var components = URLComponents(string: "https://lyrics.kugou.com/download")!
        components.queryItems = [
            URLQueryItem(name: "ver", value: "1"),
            URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "accesskey", value: accessKey),
            URLQueryItem(name: "fmt", value: "lrc"),
            URLQueryItem(name: "charset", value: "utf8"),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let content = json?["content"] as? String,
              let decoded = Data(base64Encoded: content),
              let lyrics = String(data: decoded, encoding: .utf8) else {
            throw LyricsError.decodingFailed
        }

        return lyrics
    }
}

// MARK: - LrcLib Lyrics Service

/// Fetches synchronized lyrics from LRCLIB's public API.
/// Equivalent to Android's `LrcLib` singleton object.
public actor LrcLibLyrics {
    public static let shared = LrcLibLyrics()

    private let baseURL = URL(string: "https://lrclib.net/api/search")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Metrolist iOS (https://github.com/MetrolistGroup/Metrolist)",
        ]
        self.session = URLSession(configuration: config)
    }

    public func getLyrics(title: String, artist: String, duration: Int, album: String? = nil) async -> Result<String, Error> {
        do {
            // Multi-strategy search: cleaned → original → broad
            let strategies: [(String?, String?, String?, String?)] = [
                (nil, title.cleanedTitle, artist, album),
                (nil, title, artist, nil),
                ("\(title) \(artist)", nil, nil, nil),
            ]

            for (q, trackName, artistName, albumName) in strategies {
                if let tracks = try? await queryLyrics(q: q, trackName: trackName, artistName: artistName, albumName: albumName) {
                    let match = tracks
                        .filter { track in
                            let durationDiff = abs(Int(track.duration) - duration)
                            return durationDiff <= 5
                        }
                        .first(where: { $0.syncedLyrics != nil })
                        ?? tracks.first(where: { $0.syncedLyrics != nil })

                    if let syncedLyrics = match?.syncedLyrics {
                        return .success(syncedLyrics)
                    }
                    if let plainLyrics = match?.plainLyrics {
                        return .success(plainLyrics)
                    }
                }
            }

            throw LyricsError.notFound
        } catch {
            return .failure(error)
        }
    }

    public func getAllLyrics(title: String, artist: String, duration: Int, album: String? = nil) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                if let tracks = try? await queryLyrics(trackName: title, artistName: artist, albumName: album) {
                    var seen = Set<String>()
                    for track in tracks {
                        if let synced = track.syncedLyrics, !seen.contains(synced) {
                            seen.insert(synced)
                            continuation.yield(synced)
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    private struct LrcLibTrack: Codable {
        let id: Int
        let trackName: String
        let artistName: String
        let duration: Double
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private func queryLyrics(q: String? = nil, trackName: String? = nil, artistName: String? = nil, albumName: String? = nil) async throws -> [LrcLibTrack] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        if let q { queryItems.append(URLQueryItem(name: "q", value: q)) }
        if let trackName { queryItems.append(URLQueryItem(name: "track_name", value: trackName)) }
        if let artistName { queryItems.append(URLQueryItem(name: "artist_name", value: artistName)) }
        if let albumName { queryItems.append(URLQueryItem(name: "album_name", value: albumName)) }
        components.queryItems = queryItems

        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([LrcLibTrack].self, from: data)
    }
}

// MARK: - SimpMusic Lyrics Service

public actor SimpMusicLyrics {
    public static let shared = SimpMusicLyrics()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "SimpMusicLyrics/1.0",
        ]
        self.session = URLSession(configuration: config)
    }

    public func getLyrics(videoId: String, duration: Int) async -> Result<String, Error> {
        do {
            let url = URL(string: "https://api-lyrics.simpmusic.org/v1/\(videoId)")!
            let (data, _) = try await session.data(from: url)

            struct Response: Codable {
                let type: String?
                let data: [LyricsData]

                struct LyricsData: Codable {
                    let syncedLyrics: String?
                    let plainLyrics: String?
                    let richSyncLyrics: String?
                }
            }

            let response = try JSONDecoder().decode(Response.self, from: data)
            guard response.type == "success", let first = response.data.first else {
                throw LyricsError.notFound
            }

            // Priority: richSync → synced → plain
            if let rich = first.richSyncLyrics, !rich.isEmpty { return .success(rich) }
            if let synced = first.syncedLyrics, !synced.isEmpty { return .success(synced) }
            if let plain = first.plainLyrics, !plain.isEmpty { return .success(plain) }

            throw LyricsError.notFound
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Lyrics Error

public enum LyricsError: Error, LocalizedError, Sendable {
    case notFound
    case decodingFailed
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound: "Lyrics not found"
        case .decodingFailed: "Failed to decode lyrics"
        case .networkError(let msg): "Network error: \(msg)"
        }
    }
}

// MARK: - Lyrics Helper

/// Coordinates lyrics fetching across multiple providers.
/// Equivalent to Android's `LyricsHelper`.
public actor LyricsHelper {
    private let enableKugou: Bool
    private let enableLrcLib: Bool
    private let enableSimpMusic: Bool

    public init(enableKugou: Bool = true, enableLrcLib: Bool = true, enableSimpMusic: Bool = true) {
        self.enableKugou = enableKugou
        self.enableLrcLib = enableLrcLib
        self.enableSimpMusic = enableSimpMusic
    }

    /// Fetch lyrics from the first provider that returns a result.
    public func getLyrics(title: String, artist: String, duration: Int, videoId: String? = nil, album: String? = nil) async -> (String, String)? {
        // Try SimpMusic first if videoId is available
        if enableSimpMusic, let videoId {
            if case .success(let lyrics) = await SimpMusicLyrics.shared.getLyrics(videoId: videoId, duration: duration) {
                return (lyrics, "SimpMusic")
            }
        }

        // Try LrcLib
        if enableLrcLib {
            if case .success(let lyrics) = await LrcLibLyrics.shared.getLyrics(title: title, artist: artist, duration: duration, album: album) {
                return (lyrics, "LrcLib")
            }
        }

        // Try KuGou
        if enableKugou {
            if case .success(let lyrics) = await KuGouLyrics.shared.getLyrics(title: title, artist: artist, duration: duration, album: album) {
                return (lyrics, "KuGou")
            }
        }

        return nil
    }
}
