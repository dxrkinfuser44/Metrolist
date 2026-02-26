import Foundation

// MARK: - Media Metadata

/// Represents metadata for a playable media item in the queue.
/// Used by AudioPlayerService, NowPlayingManager, and PlayerViewModel.
public struct MediaMetadata: Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var artists: [MediaArtist]
    public var album: MediaAlbum?
    public var thumbnailUrl: String?
    public var duration: TimeInterval?
    public var isExplicit: Bool

    public init(
        id: String, title: String, artists: [MediaArtist] = [],
        album: MediaAlbum? = nil, thumbnailUrl: String? = nil,
        duration: TimeInterval? = nil, isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.album = album
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.isExplicit = isExplicit
    }

    public static func == (lhs: MediaMetadata, rhs: MediaMetadata) -> Bool {
        lhs.id == rhs.id
    }
}

/// Artist info attached to a media item.
public struct MediaArtist: Sendable, Equatable {
    public let id: String?
    public let name: String

    public init(id: String? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

/// Album info attached to a media item.
public struct MediaAlbum: Sendable, Equatable {
    public let id: String?
    public let name: String

    public init(id: String? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Repeat Mode

public enum RepeatMode: Sendable {
    case off
    case one
    case queue
}

// MARK: - Persist Player State

/// Serializable player state for queue persistence across launches.
public struct PersistPlayerState: Sendable {
    public let queue: [MediaMetadata]
    public let currentIndex: Int
    public let position: TimeInterval
    public let repeatMode: RepeatMode
    public let shuffled: Bool

    public init(
        queue: [MediaMetadata], currentIndex: Int, position: TimeInterval,
        repeatMode: RepeatMode, shuffled: Bool
    ) {
        self.queue = queue
        self.currentIndex = currentIndex
        self.position = position
        self.repeatMode = repeatMode
        self.shuffled = shuffled
    }
}
