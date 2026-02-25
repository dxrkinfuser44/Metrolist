import Foundation
import MetrolistCore

// MARK: - Animated Artwork Fetcher

/// Fetches animated album artwork from Apple Music web pages using a 3-layer fallback system.
/// Layer 1: HTML tag parsing (<amp-ambient-video>, <video>)
/// Layer 2: Embedded JSON extraction (ambientVideo, cdn.apple.com references)
/// Layer 3: HLS manifest fallback (parse .m3u8, select highest quality)
public actor AnimatedArtworkFetcher {

    /// Feature flag to globally disable animated artwork fetching.
    public var isEnabled: Bool = true

    private let session: URLSession
    private let maxFileSize: Int = 20 * 1024 * 1024 // 20 MB

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            // Realistic Safari iOS User-Agent
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Interface

    /// Attempt to fetch the animated artwork video URL for an Apple Music page.
    /// Returns the URL of the video file (mp4), or nil if no animated artwork exists.
    public func fetchAnimatedArtworkURL(from appleMusicURL: URL) async -> Result<URL, AnimatedArtworkError> {
        guard isEnabled else {
            return .failure(.disabled)
        }

        do {
            let html = try await fetchHTML(from: appleMusicURL)

            // Layer 1: HTML tag parsing
            if let url = parseHTMLTags(html: html) {
                if try await validateVideoURL(url) {
                    return .success(url)
                }
            }

            // Layer 2: Embedded JSON extraction
            if let url = extractFromJSON(html: html) {
                if try await validateVideoURL(url) {
                    return .success(url)
                }
            }

            // Layer 3: HLS manifest fallback
            if let m3u8URL = findM3U8URL(html: html) {
                if let videoURL = try await resolveHLSManifest(m3u8URL) {
                    return .success(videoURL)
                }
            }

            return .failure(.noAnimatedArtwork)
        } catch let error as AnimatedArtworkError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Layer 1: HTML Tag Parsing

    private func parseHTMLTags(html: String) -> URL? {
        // Look for <amp-ambient-video> tags
        if let url = extractVideoURL(from: html, tagPattern: #"<amp-ambient-video[^>]*\bsrc="([^"]+)"#) {
            return url
        }

        // Look for <video> tags with ambient/animated art context
        if let url = extractVideoURL(from: html, tagPattern: #"<video[^>]*\bsrc="([^"]+\.(?:mp4|m3u8)[^"]*)"#) {
            return url
        }

        // Look for source tags inside video elements
        if let url = extractVideoURL(from: html, tagPattern: #"<source[^>]*\bsrc="([^"]+\.(?:mp4|m3u8)[^"]*)"#) {
            return url
        }

        return nil
    }

    private func extractVideoURL(from html: String, tagPattern: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        if let match = regex.firstMatch(in: html, range: range),
           let urlRange = Range(match.range(at: 1), in: html) {
            let urlString = String(html[urlRange])
            return URL(string: urlString)
        }
        return nil
    }

    // MARK: - Layer 2: Embedded JSON Extraction

    private func extractFromJSON(html: String) -> URL? {
        // Find script tags containing JSON with video references
        let scriptPattern = #"<script[^>]*>\s*(\{[\s\S]*?\})\s*</script>"#
        guard let regex = try? NSRegularExpression(pattern: scriptPattern, options: []) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        let matches = regex.matches(in: html, range: range)
        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange])

            // Search for ambientVideo or video asset URLs
            if let url = findVideoURLInJSON(jsonString) {
                return url
            }
        }

        // Also try searching the entire HTML for JSON blobs containing video references
        let patterns = [
            #""ambientVideo"\s*:\s*\{\s*"url"\s*:\s*"([^"]+)"#,
            #""videoUrl"\s*:\s*"([^"]+)"#,
            #"(https?://[^"]*cdn\.apple\.com[^"]*\.(?:mp4|m3u8)[^"]*)"#,
            #"(https?://[^"]*is\d+-ssl\.mzstatic\.com[^"]*\.(?:mp4|m3u8)[^"]*)"#,
        ]

        for pattern in patterns {
            if let url = extractVideoURL(from: html, tagPattern: pattern) {
                return url
            }
        }

        return nil
    }

    private func findVideoURLInJSON(_ json: String) -> URL? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }

        return searchForVideoURL(in: obj)
    }

    /// Recursively search a JSON object tree for video URLs.
    private func searchForVideoURL(in obj: Any, depth: Int = 0) -> URL? {
        guard depth < 15 else { return nil } // Prevent infinite recursion

        if let dict = obj as? [String: Any] {
            // Check for known video keys
            for key in ["ambientVideo", "animatedArtwork", "videoUrl", "videoAssetUrl", "url"] {
                if let urlString = dict[key] as? String,
                   (urlString.contains(".mp4") || urlString.contains(".m3u8")),
                   let url = URL(string: urlString) {
                    return url
                }
            }

            // Check nested objects
            if let ambient = dict["ambientVideo"] as? [String: Any] {
                if let urlString = ambient["url"] as? String, let url = URL(string: urlString) {
                    return url
                }
            }

            // Recurse into all values
            for value in dict.values {
                if let url = searchForVideoURL(in: value, depth: depth + 1) {
                    return url
                }
            }
        } else if let array = obj as? [Any] {
            for item in array {
                if let url = searchForVideoURL(in: item, depth: depth + 1) {
                    return url
                }
            }
        }

        return nil
    }

    // MARK: - Layer 3: HLS Manifest Fallback

    private func findM3U8URL(html: String) -> URL? {
        let pattern = #"(https?://[^"'\s]+\.m3u8[^"'\s]*)"#
        return extractVideoURL(from: html, tagPattern: pattern)
    }

    private func resolveHLSManifest(_ m3u8URL: URL) async throws -> URL? {
        let (data, _) = try await session.data(from: m3u8URL)
        guard let manifest = String(data: data, encoding: .utf8) else { return nil }

        // Parse the master playlist to find the highest quality variant
        let lines = manifest.split(separator: "\n")
        var bestBandwidth = 0
        var bestURL: URL?

        var nextIsBandwidthURL = false
        for line in lines {
            let lineStr = String(line)

            if lineStr.hasPrefix("#EXT-X-STREAM-INF:") {
                // Extract bandwidth
                if let bandwidthMatch = lineStr.range(of: #"BANDWIDTH=(\d+)"#, options: .regularExpression) {
                    let bandwidthStr = lineStr[bandwidthMatch].replacingOccurrences(of: "BANDWIDTH=", with: "")
                    if let bandwidth = Int(bandwidthStr), bandwidth > bestBandwidth {
                        bestBandwidth = bandwidth
                        nextIsBandwidthURL = true
                    }
                }
            } else if nextIsBandwidthURL && !lineStr.hasPrefix("#") {
                nextIsBandwidthURL = false
                if lineStr.hasPrefix("http") {
                    bestURL = URL(string: lineStr)
                } else {
                    // Relative URL
                    bestURL = m3u8URL.deletingLastPathComponent().appendingPathComponent(lineStr)
                }
            }
        }

        return bestURL
    }

    // MARK: - Validation

    private func validateVideoURL(_ url: URL) async throws -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }

        // Must be HTTP 200
        guard httpResponse.statusCode == 200 else { return false }

        // Check content type — must be video
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            let validTypes = ["video/mp4", "video/quicktime", "application/x-mpegURL", "video/mp2t"]
            guard validTypes.contains(where: { contentType.contains($0) }) else { return false }
        }

        // Check file size — must be under 20 MB
        if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           let size = Int(contentLength), size > maxFileSize {
            return false
        }

        return true
    }

    // MARK: - Helpers

    private func fetchHTML(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AnimatedArtworkError.networkError("Failed to fetch page: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw AnimatedArtworkError.parsingFailed("Unable to decode HTML")
        }

        return html
    }
}

// MARK: - Errors

public enum AnimatedArtworkError: Error, LocalizedError, Sendable {
    case disabled
    case noAnimatedArtwork
    case networkError(String)
    case parsingFailed(String)
    case invalidVideo(String)
    case fileTooLarge

    public var errorDescription: String? {
        switch self {
        case .disabled: "Animated artwork feature is disabled"
        case .noAnimatedArtwork: "No animated artwork found"
        case .networkError(let msg): "Network error: \(msg)"
        case .parsingFailed(let msg): "Parsing failed: \(msg)"
        case .invalidVideo(let msg): "Invalid video: \(msg)"
        case .fileTooLarge: "Video file exceeds size limit"
        }
    }
}
