import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MetrolistCore

// MARK: - YouTube Music API Facade

/// High-level YouTube Music API client.
/// Equivalent to Android's `YouTube` object — the main entry point for all YTM operations.
/// Wraps `InnerTubeTransport` and provides parsed, typed results.
public actor YouTubeMusic {
    private let transport: InnerTubeTransport
    private let auth: InnerTubeAuth
    private let decoder: JSONDecoder

    public init(auth: InnerTubeAuth, locale: YouTubeLocale = YouTubeLocale()) {
        self.auth = auth
        self.transport = InnerTubeTransport(auth: auth, locale: locale)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - Search

    public func searchSuggestions(query: String) async -> Result<SearchSuggestions, Error> {
        do {
            let data = try await transport.getSearchSuggestions(input: query)
            // Parse suggestions from the nested InnerTube response
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            var queries: [String] = []
            var items: [any YTItem] = []

            if let contents = json?["contents"] as? [[String: Any]] {
                for content in contents {
                    if let renderer = content["searchSuggestionsSectionRenderer"] as? [String: Any],
                       let sectionContents = renderer["contents"] as? [[String: Any]] {
                        for item in sectionContents {
                            if let suggestion = item["searchSuggestionRenderer"] as? [String: Any],
                               let runs = (suggestion["suggestion"] as? [String: Any])?["runs"] as? [[String: Any]] {
                                let text = runs.compactMap { $0["text"] as? String }.joined()
                                queries.append(text)
                            }
                        }
                    }
                }
            }

            return .success(SearchSuggestions(queries: queries, recommendedItems: items))
        } catch {
            return .failure(error)
        }
    }

    public func search(query: String, filter: SearchFilter = .all) async -> Result<SearchResult, Error> {
        do {
            let params = filter == .all ? nil : searchFilterParam(for: filter)
            let data = try await transport.search(query: query, params: params)
            return .success(try parseSearchResponse(data: data))
        } catch {
            return .failure(error)
        }
    }

    public func searchContinuation(_ continuation: String) async -> Result<SearchResult, Error> {
        do {
            let data = try await transport.search(query: nil, params: continuation)
            return .success(try parseSearchResponse(data: data))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Browse

    public func album(browseId: String) async -> Result<AlbumPage, Error> {
        do {
            let data = try await transport.browse(browseId: browseId)
            return .success(try parseAlbumPage(data: data))
        } catch {
            return .failure(error)
        }
    }

    public func artist(browseId: String) async -> Result<ArtistPage, Error> {
        do {
            let data = try await transport.browse(browseId: browseId)
            return .success(try parseArtistPage(data: data))
        } catch {
            return .failure(error)
        }
    }

    public func playlist(playlistId: String) async -> Result<PlaylistPage, Error> {
        do {
            let adjustedId = playlistId.hasPrefix("VL") ? playlistId : "VL\(playlistId)"
            let data = try await transport.browse(browseId: adjustedId)
            return .success(try parsePlaylistPage(data: data))
        } catch {
            return .failure(error)
        }
    }

    public func home(continuation: String? = nil) async -> Result<HomePage, Error> {
        do {
            let data: Data
            if let continuation {
                data = try await transport.browse(continuation: continuation)
            } else {
                data = try await transport.browse(browseId: "FEmusic_home")
            }
            return .success(try parseHomePage(data: data))
        } catch {
            return .failure(error)
        }
    }

    public func explore() async -> Result<ExplorePage, Error> {
        do {
            let data = try await transport.browse(browseId: "FEmusic_explore")
            return .success(try parseExplorePage(data: data))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Player

    public func player(videoId: String, playlistId: String? = nil) async -> Result<PlayerResponse, Error> {
        do {
            let data = try await transport.player(videoId: videoId, playlistId: playlistId)
            return .success(try decoder.decode(PlayerResponse.self, from: data))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Queue & Next

    public func next(videoId: String?, playlistId: String? = nil, continuation: String? = nil) async -> Result<NextResult, Error> {
        do {
            let data = try await transport.next(videoId: videoId, playlistId: playlistId, continuation: continuation)
            return .success(try parseNextResult(data: data))
        } catch {
            return .failure(error)
        }
    }

    public func queue(videoIds: [String]? = nil, playlistId: String? = nil) async -> Result<[SongItem], Error> {
        do {
            let data = try await transport.getQueue(videoIds: videoIds, playlistId: playlistId)
            return .success(try parseQueueResponse(data: data))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Browse Continuation

    public func browseContinuation(token: String) async -> Result<BrowseContinuationResult, Error> {
        do {
            let data = try await transport.browse(continuation: token)
            let items = try parseBrowseContinuationItems(data: data)
            return .success(items)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Library Actions

    public func likeVideo(videoId: String) async -> Result<Void, Error> {
        do {
            _ = try await transport.like(videoId: videoId)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    public func unlikeVideo(videoId: String) async -> Result<Void, Error> {
        do {
            _ = try await transport.removeLike(videoId: videoId)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    public func createPlaylist(title: String, videoIds: [String]? = nil) async -> Result<String, Error> {
        do {
            let data = try await transport.createPlaylist(title: title, videoIds: videoIds)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let playlistId = json?["playlistId"] as? String else {
                throw InnerTubeError.decodingError("Missing playlistId in response")
            }
            return .success(playlistId)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Account

    public func accountInfo() async -> Result<AccountInfo, Error> {
        do {
            let data = try await transport.accountMenu()
            return .success(try parseAccountInfo(data: data))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Configuration

    public func setLocale(_ locale: YouTubeLocale) async {
        await transport.setLocale(locale)
    }

    public func setVisitorData(_ data: String?) async {
        await transport.setVisitorData(data)
    }

    public func setCookie(_ cookie: String?) async {
        await auth.setCookie(cookie)
    }

    public var isLoggedIn: Bool {
        get async { await auth.isLoggedIn }
    }
}

// MARK: - Response Types

public struct SearchResult: Sendable {
    public let items: [any YTItem]
    public let continuation: String?

    public init(items: [any YTItem] = [], continuation: String? = nil) {
        self.items = items
        self.continuation = continuation
    }
}

public struct AlbumPage: Sendable {
    public let album: AlbumItem
    public let songs: [SongItem]
    public let otherVersions: [AlbumItem]
    public let description: String?

    public init(album: AlbumItem, songs: [SongItem] = [], otherVersions: [AlbumItem] = [], description: String? = nil) {
        self.album = album
        self.songs = songs
        self.otherVersions = otherVersions
        self.description = description
    }
}

public struct ArtistPage: Sendable {
    public let artist: ArtistItem
    public let sections: [ArtistSection]
    public let description: String?
    public let subscriberCount: String?

    public struct ArtistSection: Sendable {
        public let title: String
        public let items: [any YTItem]
        public let moreEndpoint: BrowseEndpoint?
    }

    public init(artist: ArtistItem, sections: [ArtistSection] = [], description: String? = nil, subscriberCount: String? = nil) {
        self.artist = artist
        self.sections = sections
        self.description = description
        self.subscriberCount = subscriberCount
    }
}

public struct PlaylistPage: Sendable {
    public let playlist: PlaylistItem
    public let songs: [SongItem]
    public let continuation: String?

    public init(playlist: PlaylistItem, songs: [SongItem] = [], continuation: String? = nil) {
        self.playlist = playlist
        self.songs = songs
        self.continuation = continuation
    }
}

public struct HomePage: Sendable {
    public let sections: [HomeSection]
    public let continuation: String?

    public struct HomeSection: Sendable {
        public let title: String?
        public let items: [any YTItem]
    }

    public init(sections: [HomeSection] = [], continuation: String? = nil) {
        self.sections = sections
        self.continuation = continuation
    }
}

public struct ExplorePage: Sendable {
    public let newReleaseAlbums: [AlbumItem]
    public let moodAndGenres: [MoodAndGenre]

    public init(newReleaseAlbums: [AlbumItem] = [], moodAndGenres: [MoodAndGenre] = []) {
        self.newReleaseAlbums = newReleaseAlbums
        self.moodAndGenres = moodAndGenres
    }
}

public struct MoodAndGenre: Sendable {
    public let title: String
    public let items: [MoodAndGenreItem]

    public struct MoodAndGenreItem: Sendable {
        public let title: String
        public let endpoint: BrowseEndpoint
        public let color: Int?
    }
}

public struct NextResult: Sendable {
    public let songs: [SongItem]
    public let continuation: String?
    public let lyrics: BrowseEndpoint?
    public let related: BrowseEndpoint?

    public init(songs: [SongItem] = [], continuation: String? = nil, lyrics: BrowseEndpoint? = nil, related: BrowseEndpoint? = nil) {
        self.songs = songs
        self.continuation = continuation
        self.lyrics = lyrics
        self.related = related
    }
}

public struct BrowseContinuationResult: Sendable {
    public let items: [any YTItem]
    public let continuation: String?

    public init(items: [any YTItem] = [], continuation: String? = nil) {
        self.items = items
        self.continuation = continuation
    }
}

public struct AccountInfo: Sendable {
    public let name: String
    public let email: String?
    public let channelHandle: String?
    public let thumbnailUrl: String?

    public init(name: String, email: String? = nil, channelHandle: String? = nil, thumbnailUrl: String? = nil) {
        self.name = name
        self.email = email
        self.channelHandle = channelHandle
        self.thumbnailUrl = thumbnailUrl
    }
}

// MARK: - Player Response

public struct PlayerResponse: Codable, Sendable {
    public let playabilityStatus: PlayabilityStatus?
    public let streamingData: StreamingData?
    public let videoDetails: VideoDetails?

    public struct PlayabilityStatus: Codable, Sendable {
        public let status: String
        public let reason: String?

        public var isPlayable: Bool { status == "OK" }
    }

    public struct StreamingData: Codable, Sendable {
        public let adaptiveFormats: [Format]?
        public let expiresInSeconds: String?

        public struct Format: Codable, Sendable {
            public let itag: Int
            public let url: String?
            public let mimeType: String
            public let bitrate: Int?
            public let contentLength: String?
            public let audioSampleRate: String?
            public let loudnessDb: Double?
            public let signatureCipher: String?
            public let audioTrack: AudioTrack?

            public struct AudioTrack: Codable, Sendable {
                public let displayName: String?
                public let id: String?
                public let audioIsDefault: Bool?
            }

            public var isAudioOnly: Bool {
                mimeType.hasPrefix("audio/")
            }
        }
    }

    public struct VideoDetails: Codable, Sendable {
        public let videoId: String
        public let title: String?
        public let author: String?
        public let channelId: String?
        public let lengthSeconds: String?
        public let musicVideoType: String?
    }
}

// MARK: - Private Parsing Helpers

extension YouTubeMusic {

    private func searchFilterParam(for filter: SearchFilter) -> String? {
        switch filter {
        case .all: nil
        case .songs: "EgWKAQIIAWoOEAMQBBAJEA4QChAFEBU%3D"
        case .videos: "EgWKAQIQAWoOEAMQBBAJEA4QChAFEBU%3D"
        case .albums: "EgWKAQIYAWoOEAMQBBAJEA4QChAFEBU%3D"
        case .artists: "EgWKAQIgAWoOEAMQBBAJEA4QChAFEBU%3D"
        case .playlists: "EgeKAQQoAEABag4QAxAEEAkQDhAKEAUQFQ%3D%3D"
        case .communityPlaylists: "EgeKAQQoAEABag4QAxAEEAkQDhAKEAUQFQ%3D%3D"
        case .featuredPlaylists: "EgeKAQQoADgBag4QAxAEEAkQDhAKEAUQFQ%3D%3D"
        }
    }

    // Stub parsers — full implementations would parse the deeply nested InnerTube JSON.
    // These provide the structural foundation for complete parsing.

    private func parseSearchResponse(data: Data) throws -> SearchResult {
        // In production, this would parse MusicShelfRenderer contents
        SearchResult()
    }

    private func parseAlbumPage(data: Data) throws -> AlbumPage {
        // Parse MusicResponsiveHeaderRenderer + MusicShelfRenderer
        let placeholder = AlbumItem(id: "", title: "", browseId: "")
        return AlbumPage(album: placeholder)
    }

    private func parseArtistPage(data: Data) throws -> ArtistPage {
        let placeholder = ArtistItem(id: "", title: "")
        return ArtistPage(artist: placeholder)
    }

    private func parsePlaylistPage(data: Data) throws -> PlaylistPage {
        let placeholder = PlaylistItem(id: "", title: "")
        return PlaylistPage(playlist: placeholder)
    }

    private func parseHomePage(data: Data) throws -> HomePage {
        HomePage()
    }

    private func parseExplorePage(data: Data) throws -> ExplorePage {
        ExplorePage()
    }

    private func parseNextResult(data: Data) throws -> NextResult {
        NextResult()
    }

    private func parseQueueResponse(data: Data) throws -> [SongItem] {
        []
    }

    private func parseAccountInfo(data: Data) throws -> AccountInfo {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // Navigate deeply nested response to find account info
        let name = "Unknown"
        return AccountInfo(name: name)
    }

    private func parseBrowseContinuationItems(data: Data) throws -> BrowseContinuationResult {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // Parse continuation response for items and next continuation token
        var items: [any YTItem] = []
        var continuation: String?

        if let continuationContents = json?["continuationContents"] as? [String: Any] {
            if let sectionList = continuationContents["musicPlaylistShelfContinuation"] as? [String: Any] {
                if let contents = sectionList["contents"] as? [[String: Any]] {
                    items = contents.compactMap { parseSongRenderer($0) }
                }
                if let conts = sectionList["continuations"] as? [[String: Any]],
                   let next = conts.first?["nextContinuationData"] as? [String: Any] {
                    continuation = next["continuation"] as? String
                }
            }
        }

        return BrowseContinuationResult(items: items, continuation: continuation)
    }

    private func parseSongRenderer(_ json: [String: Any]) -> SongItem? {
        guard let renderer = json["musicResponsiveListItemRenderer"] as? [String: Any] ?? json["playlistPanelVideoRenderer"] as? [String: Any] else {
            return nil
        }
        let videoId = (renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String
            ?? renderer["videoId"] as? String ?? ""
        let title = extractText(from: renderer, key: "flexColumns", index: 0) ?? "Unknown"
        return SongItem(id: videoId, title: title)
    }

    private func extractText(from renderer: [String: Any], key: String, index: Int) -> String? {
        guard let columns = renderer[key] as? [[String: Any]],
              index < columns.count,
              let textRenderer = columns[index]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
              let text = textRenderer["text"] as? [String: Any],
              let runs = text["runs"] as? [[String: Any]] else {
            return nil
        }
        return runs.compactMap { $0["text"] as? String }.joined()
    }
}
