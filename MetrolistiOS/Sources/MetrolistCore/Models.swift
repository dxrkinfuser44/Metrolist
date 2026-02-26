import Foundation

// MARK: - Core Data Models (Plain structs, not SwiftData)

/// Plain song entity used as a transfer object between layers.
public struct Song: Sendable, Identifiable {
    public let id: String
    public var title: String
    public var duration: Int
    public var thumbnailUrl: String?
    public var albumId: String?
    public var albumName: String?
    public var isExplicit: Bool
    public var year: Int?
    public var date: Date?
    public var dateModified: Date?
    public var isLiked: Bool
    public var likedDate: Date?
    public var totalPlayTime: Int64
    public var inLibrary: Date?
    public var dateDownload: Date?
    public var isLocal: Bool
    public var libraryAddToken: String?
    public var libraryRemoveToken: String?
    public var lyricsOffset: Int
    public var romanizeLyrics: Bool
    public var isDownloaded: Bool
    public var isUploaded: Bool
    public var isVideo: Bool

    public init(
        id: String, title: String, duration: Int = -1, thumbnailUrl: String? = nil,
        albumId: String? = nil, albumName: String? = nil, isExplicit: Bool = false,
        year: Int? = nil, date: Date? = nil, dateModified: Date? = nil,
        isLiked: Bool = false, likedDate: Date? = nil, totalPlayTime: Int64 = 0,
        inLibrary: Date? = nil, dateDownload: Date? = nil, isLocal: Bool = false,
        libraryAddToken: String? = nil, libraryRemoveToken: String? = nil,
        lyricsOffset: Int = 0, romanizeLyrics: Bool = true,
        isDownloaded: Bool = false, isUploaded: Bool = false, isVideo: Bool = false
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.thumbnailUrl = thumbnailUrl
        self.albumId = albumId
        self.albumName = albumName
        self.isExplicit = isExplicit
        self.year = year
        self.date = date
        self.dateModified = dateModified
        self.isLiked = isLiked
        self.likedDate = likedDate
        self.totalPlayTime = totalPlayTime
        self.inLibrary = inLibrary
        self.dateDownload = dateDownload
        self.isLocal = isLocal
        self.libraryAddToken = libraryAddToken
        self.libraryRemoveToken = libraryRemoveToken
        self.lyricsOffset = lyricsOffset
        self.romanizeLyrics = romanizeLyrics
        self.isDownloaded = isDownloaded
        self.isUploaded = isUploaded
        self.isVideo = isVideo
    }
}

/// Plain artist entity.
public struct Artist: Sendable, Identifiable {
    public let id: String
    public var name: String
    public var thumbnailUrl: String?
    public var channelId: String?
    public var lastUpdateTime: Date
    public var bookmarkedAt: Date?
    public var isLocal: Bool

    public init(
        id: String, name: String, thumbnailUrl: String? = nil, channelId: String? = nil,
        lastUpdateTime: Date = .now, bookmarkedAt: Date? = nil, isLocal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.thumbnailUrl = thumbnailUrl
        self.channelId = channelId
        self.lastUpdateTime = lastUpdateTime
        self.bookmarkedAt = bookmarkedAt
        self.isLocal = isLocal
    }
}

/// Plain album entity.
public struct Album: Sendable, Identifiable {
    public let id: String
    public var playlistId: String?
    public var title: String
    public var year: Int?
    public var thumbnailUrl: String?
    public var themeColor: Int?
    public var songCount: Int
    public var duration: Int
    public var isExplicit: Bool
    public var lastUpdateTime: Date
    public var bookmarkedAt: Date?
    public var likedDate: Date?
    public var inLibrary: Date?
    public var isLocal: Bool
    public var isUploaded: Bool

    public init(
        id: String, playlistId: String? = nil, title: String, year: Int? = nil,
        thumbnailUrl: String? = nil, themeColor: Int? = nil, songCount: Int = 0,
        duration: Int = 0, isExplicit: Bool = false, lastUpdateTime: Date = .now,
        bookmarkedAt: Date? = nil, likedDate: Date? = nil, inLibrary: Date? = nil,
        isLocal: Bool = false, isUploaded: Bool = false
    ) {
        self.id = id
        self.playlistId = playlistId
        self.title = title
        self.year = year
        self.thumbnailUrl = thumbnailUrl
        self.themeColor = themeColor
        self.songCount = songCount
        self.duration = duration
        self.isExplicit = isExplicit
        self.lastUpdateTime = lastUpdateTime
        self.bookmarkedAt = bookmarkedAt
        self.likedDate = likedDate
        self.inLibrary = inLibrary
        self.isLocal = isLocal
        self.isUploaded = isUploaded
    }
}

/// Plain playlist entity.
public struct Playlist: Sendable, Identifiable {
    public let id: String
    public var name: String
    public var browseId: String?
    public var createdAt: Date?
    public var lastUpdateTime: Date?
    public var isEditable: Bool
    public var bookmarkedAt: Date?
    public var remoteSongCount: Int?
    public var playEndpointParams: String?
    public var thumbnailUrl: String?
    public var shuffleEndpointParams: String?
    public var radioEndpointParams: String?
    public var isLocal: Bool
    public var isAutoSync: Bool

    public init(
        id: String = Playlist.generatePlaylistId(), name: String, browseId: String? = nil,
        createdAt: Date? = .now, lastUpdateTime: Date? = .now, isEditable: Bool = true,
        bookmarkedAt: Date? = nil, remoteSongCount: Int? = nil, playEndpointParams: String? = nil,
        thumbnailUrl: String? = nil, shuffleEndpointParams: String? = nil,
        radioEndpointParams: String? = nil, isLocal: Bool = false, isAutoSync: Bool = false
    ) {
        self.id = id
        self.name = name
        self.browseId = browseId
        self.createdAt = createdAt
        self.lastUpdateTime = lastUpdateTime
        self.isEditable = isEditable
        self.bookmarkedAt = bookmarkedAt
        self.remoteSongCount = remoteSongCount
        self.playEndpointParams = playEndpointParams
        self.thumbnailUrl = thumbnailUrl
        self.shuffleEndpointParams = shuffleEndpointParams
        self.radioEndpointParams = radioEndpointParams
        self.isLocal = isLocal
        self.isAutoSync = isAutoSync
    }

    /// Generate a unique local playlist ID.
    public static func generatePlaylistId() -> String {
        "LP\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))"
    }
}

/// Speed dial item entity.
public struct SpeedDialItem: Sendable, Identifiable {
    public let id: String
    public var secondaryId: String?
    public var title: String
    public var subtitle: String?
    public var thumbnailUrl: String?
    public var type: SpeedDialItemType
    public var isExplicit: Bool
    public var createDate: Int64

    public init(
        id: String, secondaryId: String? = nil, title: String, subtitle: String? = nil,
        thumbnailUrl: String? = nil, type: SpeedDialItemType, isExplicit: Bool = false,
        createDate: Int64 = Int64(Date.now.timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.secondaryId = secondaryId
        self.title = title
        self.subtitle = subtitle
        self.thumbnailUrl = thumbnailUrl
        self.type = type
        self.isExplicit = isExplicit
        self.createDate = createDate
    }
}

public enum SpeedDialItemType: String, Codable, Sendable {
    case song = "SONG"
    case album = "ALBUM"
    case artist = "ARTIST"
    case playlist = "PLAYLIST"
}
