import Foundation
import MetrolistCore

// MARK: - InnerTube Client Configuration

/// YouTube Music client profiles for the InnerTube API.
/// Each profile represents a different client identity used for various API calls.
public enum YouTubeClientProfile: Sendable {
    case webRemix    // Primary music client (ID 67)
    case web         // Standard web client (ID 1)
    case ios         // iOS client (ID 5)
    case android     // Android client (ID 3)
    case tvhtml5     // TV client for age-restricted content (ID 7)

    public var clientName: String {
        switch self {
        case .webRemix: "WEB_REMIX"
        case .web: "WEB"
        case .ios: "IOS"
        case .android: "ANDROID"
        case .tvhtml5: "TVHTML5_SIMPLY_EMBEDDED_PLAYER"
        }
    }

    public var clientVersion: String {
        switch self {
        case .webRemix: "1.20241111.01.00"
        case .web: "2.20241111.01.00"
        case .ios: "20.03.02"
        case .android: "19.47.53"
        case .tvhtml5: "2.0"
        }
    }

    public var clientId: Int {
        switch self {
        case .webRemix: 67
        case .web: 1
        case .ios: 5
        case .android: 3
        case .tvhtml5: 85
        }
    }

    public var userAgent: String {
        switch self {
        case .webRemix, .web:
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15"
        case .ios:
            "com.google.ios.youtubemusic/\(clientVersion) (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)"
        case .android:
            "com.google.android.youtube/\(clientVersion) (Linux; U; Android 14; en_US; Pixel 8 Build/UQ1A.240205.002) gzip"
        case .tvhtml5:
            "Mozilla/5.0 (SmartTV; SMART-TV; LG)"
        }
    }
}

// MARK: - InnerTube Context

/// The context payload required by all InnerTube API calls.
public struct InnerTubeContext: Codable, Sendable {
    public let client: Client
    public var thirdParty: ThirdParty?

    public struct Client: Codable, Sendable {
        public let clientName: String
        public let clientVersion: String
        public let gl: String
        public let hl: String
        public var visitorData: String?
        public var userAgent: String?
    }

    public struct ThirdParty: Codable, Sendable {
        public let embedUrl: String?
    }

    public init(profile: YouTubeClientProfile, locale: YouTubeLocale, visitorData: String? = nil) {
        self.client = Client(
            clientName: profile.clientName,
            clientVersion: profile.clientVersion,
            gl: locale.gl,
            hl: locale.hl,
            visitorData: visitorData,
            userAgent: profile.userAgent
        )
        self.thirdParty = nil
    }
}

/// YouTube locale settings.
public struct YouTubeLocale: Codable, Sendable {
    public var gl: String // geographic location (country code)
    public var hl: String // host language

    public init(gl: String = "US", hl: String = "en") {
        self.gl = gl
        self.hl = hl
    }
}

// MARK: - Authentication

/// Manages SAPISIDHASH authentication for YouTube Music API.
public actor InnerTubeAuth {
    private var cookie: String?
    private var sapisid: String?
    private let origin = "https://music.youtube.com"

    public init() {}

    public func setCookie(_ cookie: String?) {
        self.cookie = cookie
        // Extract SAPISID from cookie string
        if let cookie = cookie {
            let parts = cookie.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for part in parts {
                if part.hasPrefix("SAPISID=") || part.hasPrefix("__Secure-3PAPISID=") {
                    self.sapisid = String(part.split(separator: "=", maxSplits: 1).last ?? "")
                    return
                }
            }
        }
        self.sapisid = nil
    }

    public var isLoggedIn: Bool {
        sapisid != nil
    }

    /// Generate SAPISIDHASH authorization header value.
    public func authorizationHeader() -> String? {
        guard let sapisid else { return nil }
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let hashInput = "\(timestamp) \(sapisid) \(origin)"
        let hash = hashInput.sha1
        return "SAPISIDHASH \(timestamp)_\(hash)"
    }

    public var cookieHeader: String? {
        cookie
    }
}
