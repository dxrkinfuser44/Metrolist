import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MetrolistCore

// MARK: - Last.fm Scrobbling Service

/// Handles Last.fm authentication and scrobbling.
/// Equivalent to Android's `LastFM` singleton object.
public actor LastFMService {
    private let session: URLSession
    private let baseURL = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    private var apiKey: String = ""
    private var apiSecret: String = ""
    public var sessionKey: String?

    public static let shared = LastFMService()

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Metrolist (https://github.com/MetrolistGroup/Metrolist)",
        ]
        self.session = URLSession(configuration: config)
    }

    public func initialize(apiKey: String, secret: String) {
        self.apiKey = apiKey
        self.apiSecret = secret
    }

    public var isAuthenticated: Bool {
        sessionKey != nil
    }

    // MARK: - Authentication

    public func getToken() async throws -> String {
        let params: [String: String] = [
            "method": "auth.getToken",
            "api_key": apiKey,
        ]
        let data = try await signedRequest(params: params)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String else {
            throw LastFMError.authFailed("No token in response")
        }
        return token
    }

    public func authURL(token: String) -> URL {
        URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)")!
    }

    public func getSession(token: String) async throws -> String {
        let params: [String: String] = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token,
        ]
        let data = try await signedRequest(params: params)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let session = json?["session"] as? [String: Any],
              let key = session["key"] as? String else {
            throw LastFMError.authFailed("No session key in response")
        }
        self.sessionKey = key
        return key
    }

    // MARK: - Scrobbling

    public func updateNowPlaying(artist: String, track: String, album: String? = nil, duration: Int? = nil) async throws {
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "api_key": apiKey,
            "sk": sessionKey ?? "",
            "artist": artist,
            "track": track,
        ]
        if let album { params["album"] = album }
        if let duration { params["duration"] = String(duration) }

        _ = try await signedRequest(params: params)
    }

    public func scrobble(artist: String, track: String, timestamp: Int, album: String? = nil, duration: Int? = nil) async throws {
        var params: [String: String] = [
            "method": "track.scrobble",
            "api_key": apiKey,
            "sk": sessionKey ?? "",
            "artist": artist,
            "track": track,
            "timestamp": String(timestamp),
        ]
        if let album { params["album"] = album }
        if let duration { params["duration"] = String(duration) }

        _ = try await signedRequest(params: params)
    }

    public func setLoveStatus(artist: String, track: String, love: Bool) async throws {
        let method = love ? "track.love" : "track.unlove"
        let params: [String: String] = [
            "method": method,
            "api_key": apiKey,
            "sk": sessionKey ?? "",
            "artist": artist,
            "track": track,
        ]
        _ = try await signedRequest(params: params)
    }

    // MARK: - Private

    /// Build and execute a signed Last.fm API request.
    private func signedRequest(params: [String: String]) async throws -> Data {
        var allParams = params
        allParams["format"] = "json"

        // Generate API signature: sort params alphabetically, concatenate key+value, append secret, MD5
        let sigString = allParams
            .filter { $0.key != "format" }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)\($0.value)" }
            .joined() + apiSecret

        allParams["api_sig"] = sigString.md5

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = allParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            // Try to parse error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["message"] as? String {
                throw LastFMError.apiError(errorMsg)
            }
            throw LastFMError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - Last.fm Errors

public enum LastFMError: Error, LocalizedError, Sendable {
    case authFailed(String)
    case apiError(String)
    case httpError(Int)

    public var errorDescription: String? {
        switch self {
        case .authFailed(let msg): "Authentication failed: \(msg)"
        case .apiError(let msg): "Last.fm API error: \(msg)"
        case .httpError(let code): "HTTP error \(code)"
        }
    }
}

// MARK: - MD5 Extension

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
