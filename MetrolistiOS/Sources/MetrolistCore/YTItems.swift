import Foundation

// MARK: - YTItem Protocol

/// Protocol for all YouTube Music item types (songs, albums, artists, playlists).
public protocol YTItem: Sendable {
    var id: String { get }
    var title: String { get }
    var thumbnails: [Thumbnail] { get }
    var subtitle: String? { get }
}

// MARK: - Thumbnail

public struct Thumbnail: Sendable {
    public let url: String
    public let width: Int?
    public let height: Int?

    public init(url: String, width: Int? = nil, height: Int? = nil) {
        self.url = url
        self.width = width
        self.height = height
    }
}

// MARK: - Concrete YTItem Types

public struct SongItem: YTItem {
    public let id: String
    public let title: String
    public let thumbnails: [Thumbnail]
    public let subtitle: String?
    public var artists: [ArtistItem]
    public var album: AlbumItem?
    public var duration: Int?
    public var isExplicit: Bool

    public init(
        id: String, title: String, thumbnails: [Thumbnail] = [],
        subtitle: String? = nil, artists: [ArtistItem] = [],
        album: AlbumItem? = nil, duration: Int? = nil, isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.thumbnails = thumbnails
        self.subtitle = subtitle
        self.artists = artists
        self.album = album
        self.duration = duration
        self.isExplicit = isExplicit
    }
}

public struct AlbumItem: YTItem {
    public let id: String
    public let title: String
    public let thumbnails: [Thumbnail]
    public let subtitle: String?
    public var browseId: String
    public var artists: [ArtistItem]
    public var year: Int?
    public var isExplicit: Bool

    public init(
        id: String, title: String, thumbnails: [Thumbnail] = [],
        subtitle: String? = nil, browseId: String = "",
        artists: [ArtistItem] = [], year: Int? = nil, isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.thumbnails = thumbnails
        self.subtitle = subtitle
        self.browseId = browseId
        self.artists = artists
        self.year = year
        self.isExplicit = isExplicit
    }
}

public struct ArtistItem: YTItem {
    public let id: String
    public let title: String
    public let thumbnails: [Thumbnail]
    public let subtitle: String?
    public var subscriberCount: String?

    public init(
        id: String, title: String, thumbnails: [Thumbnail] = [],
        subtitle: String? = nil, subscriberCount: String? = nil
    ) {
        self.id = id
        self.title = title
        self.thumbnails = thumbnails
        self.subtitle = subtitle
        self.subscriberCount = subscriberCount
    }
}

public struct PlaylistItem: YTItem {
    public let id: String
    public let title: String
    public let thumbnails: [Thumbnail]
    public let subtitle: String?
    public var songCount: Int?
    public var author: ArtistItem?

    public init(
        id: String, title: String, thumbnails: [Thumbnail] = [],
        subtitle: String? = nil, songCount: Int? = nil, author: ArtistItem? = nil
    ) {
        self.id = id
        self.title = title
        self.thumbnails = thumbnails
        self.subtitle = subtitle
        self.songCount = songCount
        self.author = author
    }
}

public struct PodcastItem: YTItem {
    public let id: String
    public let title: String
    public let thumbnails: [Thumbnail]
    public let subtitle: String?
    public var author: ArtistItem?

    public init(
        id: String, title: String, thumbnails: [Thumbnail] = [],
        subtitle: String? = nil, author: ArtistItem? = nil
    ) {
        self.id = id
        self.title = title
        self.thumbnails = thumbnails
        self.subtitle = subtitle
        self.author = author
    }
}

public struct EpisodeItem: YTItem {
    public let id: String
    public let title: String
    public let thumbnails: [Thumbnail]
    public let subtitle: String?
    public var podcast: PodcastItem?
    public var duration: Int?

    public init(
        id: String, title: String, thumbnails: [Thumbnail] = [],
        subtitle: String? = nil, podcast: PodcastItem? = nil, duration: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.thumbnails = thumbnails
        self.subtitle = subtitle
        self.podcast = podcast
        self.duration = duration
    }
}

// MARK: - Browse Endpoint

public struct BrowseEndpoint: Sendable {
    public let browseId: String
    public var params: String?

    public init(browseId: String, params: String? = nil) {
        self.browseId = browseId
        self.params = params
    }
}

// MARK: - Search

public enum SearchFilter: String, CaseIterable, Sendable {
    case all
    case songs
    case videos
    case albums
    case artists
    case playlists
    case communityPlaylists
    case featuredPlaylists
}

public struct SearchSuggestions: Sendable {
    public let queries: [String]
    public let recommendedItems: [any YTItem]

    public init(queries: [String] = [], recommendedItems: [any YTItem] = []) {
        self.queries = queries
        self.recommendedItems = recommendedItems
    }
}
