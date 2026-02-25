import Foundation
import SwiftData
import MetrolistCore

// MARK: - SwiftData Models
// These @Model classes are the SwiftData equivalents of Room entities.
// SwiftData manages the schema, migrations, and persistence automatically.

@Model
public final class SongModel {
    @Attribute(.unique) public var id: String
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

    // Relationships
    @Relationship(inverse: \SongArtistMapModel.song) public var artistMaps: [SongArtistMapModel]
    @Relationship(inverse: \SongAlbumMapModel.song) public var albumMaps: [SongAlbumMapModel]
    @Relationship(inverse: \PlaylistSongMapModel.song) public var playlistMaps: [PlaylistSongMapModel]

    public init(
        id: String,
        title: String,
        duration: Int = -1,
        thumbnailUrl: String? = nil,
        albumId: String? = nil,
        albumName: String? = nil,
        isExplicit: Bool = false,
        year: Int? = nil,
        date: Date? = nil,
        dateModified: Date? = nil,
        isLiked: Bool = false,
        likedDate: Date? = nil,
        totalPlayTime: Int64 = 0,
        inLibrary: Date? = nil,
        dateDownload: Date? = nil,
        isLocal: Bool = false,
        libraryAddToken: String? = nil,
        libraryRemoveToken: String? = nil,
        lyricsOffset: Int = 0,
        romanizeLyrics: Bool = true,
        isDownloaded: Bool = false,
        isUploaded: Bool = false,
        isVideo: Bool = false
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
        self.artistMaps = []
        self.albumMaps = []
        self.playlistMaps = []
    }

    /// Convert to the plain Core model.
    public func toEntity() -> Song {
        Song(
            id: id, title: title, duration: duration, thumbnailUrl: thumbnailUrl,
            albumId: albumId, albumName: albumName, isExplicit: isExplicit, year: year,
            date: date, dateModified: dateModified, isLiked: isLiked, likedDate: likedDate,
            totalPlayTime: totalPlayTime, inLibrary: inLibrary, dateDownload: dateDownload,
            isLocal: isLocal, libraryAddToken: libraryAddToken, libraryRemoveToken: libraryRemoveToken,
            lyricsOffset: lyricsOffset, romanizeLyrics: romanizeLyrics,
            isDownloaded: isDownloaded, isUploaded: isUploaded, isVideo: isVideo
        )
    }
}

@Model
public final class ArtistModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var thumbnailUrl: String?
    public var channelId: String?
    public var lastUpdateTime: Date
    public var bookmarkedAt: Date?
    public var isLocal: Bool

    @Relationship(inverse: \SongArtistMapModel.artist) public var songMaps: [SongArtistMapModel]
    @Relationship(inverse: \AlbumArtistMapModel.artist) public var albumMaps: [AlbumArtistMapModel]

    public init(id: String, name: String, thumbnailUrl: String? = nil, channelId: String? = nil,
                lastUpdateTime: Date = .now, bookmarkedAt: Date? = nil, isLocal: Bool = false) {
        self.id = id
        self.name = name
        self.thumbnailUrl = thumbnailUrl
        self.channelId = channelId
        self.lastUpdateTime = lastUpdateTime
        self.bookmarkedAt = bookmarkedAt
        self.isLocal = isLocal
        self.songMaps = []
        self.albumMaps = []
    }

    public func toEntity() -> Artist {
        Artist(id: id, name: name, thumbnailUrl: thumbnailUrl, channelId: channelId,
               lastUpdateTime: lastUpdateTime, bookmarkedAt: bookmarkedAt, isLocal: isLocal)
    }
}

@Model
public final class AlbumModel {
    @Attribute(.unique) public var id: String
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

    @Relationship(inverse: \SongAlbumMapModel.album) public var songMaps: [SongAlbumMapModel]
    @Relationship(inverse: \AlbumArtistMapModel.album) public var albumArtistMaps: [AlbumArtistMapModel]

    public init(id: String, playlistId: String? = nil, title: String, year: Int? = nil,
                thumbnailUrl: String? = nil, themeColor: Int? = nil, songCount: Int = 0,
                duration: Int = 0, isExplicit: Bool = false, lastUpdateTime: Date = .now,
                bookmarkedAt: Date? = nil, likedDate: Date? = nil, inLibrary: Date? = nil,
                isLocal: Bool = false, isUploaded: Bool = false) {
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
        self.songMaps = []
        self.albumArtistMaps = []
    }

    public func toEntity() -> Album {
        Album(id: id, playlistId: playlistId, title: title, year: year, thumbnailUrl: thumbnailUrl,
              themeColor: themeColor, songCount: songCount, duration: duration, isExplicit: isExplicit,
              lastUpdateTime: lastUpdateTime, bookmarkedAt: bookmarkedAt, likedDate: likedDate,
              inLibrary: inLibrary, isLocal: isLocal, isUploaded: isUploaded)
    }
}

@Model
public final class PlaylistModel {
    @Attribute(.unique) public var id: String
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

    @Relationship(inverse: \PlaylistSongMapModel.playlist) public var songMaps: [PlaylistSongMapModel]

    public init(id: String = Playlist.generatePlaylistId(), name: String, browseId: String? = nil,
                createdAt: Date? = .now, lastUpdateTime: Date? = .now, isEditable: Bool = true,
                bookmarkedAt: Date? = nil, remoteSongCount: Int? = nil, playEndpointParams: String? = nil,
                thumbnailUrl: String? = nil, shuffleEndpointParams: String? = nil,
                radioEndpointParams: String? = nil, isLocal: Bool = false, isAutoSync: Bool = false) {
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
        self.songMaps = []
    }

    public func toEntity() -> Playlist {
        Playlist(id: id, name: name, browseId: browseId, createdAt: createdAt,
                 lastUpdateTime: lastUpdateTime, isEditable: isEditable, bookmarkedAt: bookmarkedAt,
                 remoteSongCount: remoteSongCount, playEndpointParams: playEndpointParams,
                 thumbnailUrl: thumbnailUrl, shuffleEndpointParams: shuffleEndpointParams,
                 radioEndpointParams: radioEndpointParams, isLocal: isLocal, isAutoSync: isAutoSync)
    }
}

// MARK: - Join Table Models

@Model
public final class SongArtistMapModel {
    public var song: SongModel?
    public var artist: ArtistModel?
    public var position: Int

    public init(song: SongModel? = nil, artist: ArtistModel? = nil, position: Int = 0) {
        self.song = song
        self.artist = artist
        self.position = position
    }
}

@Model
public final class SongAlbumMapModel {
    public var song: SongModel?
    public var album: AlbumModel?
    public var index: Int

    public init(song: SongModel? = nil, album: AlbumModel? = nil, index: Int = 0) {
        self.song = song
        self.album = album
        self.index = index
    }
}

@Model
public final class AlbumArtistMapModel {
    public var album: AlbumModel?
    public var artist: ArtistModel?
    public var order: Int

    public init(album: AlbumModel? = nil, artist: ArtistModel? = nil, order: Int = 0) {
        self.album = album
        self.artist = artist
        self.order = order
    }
}

@Model
public final class PlaylistSongMapModel {
    public var playlist: PlaylistModel?
    public var song: SongModel?
    public var position: Int
    public var setVideoId: String?

    public init(playlist: PlaylistModel? = nil, song: SongModel? = nil, position: Int = 0, setVideoId: String? = nil) {
        self.playlist = playlist
        self.song = song
        self.position = position
        self.setVideoId = setVideoId
    }
}

// MARK: - Standalone Models

@Model
public final class LyricsModel {
    @Attribute(.unique) public var id: String
    public var lyrics: String
    public var provider: String
    public var translatedLyrics: String
    public var translationLanguage: String
    public var translationMode: String

    public init(id: String, lyrics: String, provider: String = "Unknown",
                translatedLyrics: String = "", translationLanguage: String = "", translationMode: String = "") {
        self.id = id
        self.lyrics = lyrics
        self.provider = provider
        self.translatedLyrics = translatedLyrics
        self.translationLanguage = translationLanguage
        self.translationMode = translationMode
    }
}

@Model
public final class AudioFormatModel {
    @Attribute(.unique) public var id: String
    public var itag: Int
    public var mimeType: String
    public var codecs: String
    public var bitrate: Int
    public var sampleRate: Int?
    public var contentLength: Int64
    public var loudnessDb: Double?
    public var perceptualLoudnessDb: Double?

    public init(id: String, itag: Int, mimeType: String, codecs: String, bitrate: Int,
                sampleRate: Int? = nil, contentLength: Int64, loudnessDb: Double? = nil,
                perceptualLoudnessDb: Double? = nil) {
        self.id = id
        self.itag = itag
        self.mimeType = mimeType
        self.codecs = codecs
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.contentLength = contentLength
        self.loudnessDb = loudnessDb
        self.perceptualLoudnessDb = perceptualLoudnessDb
    }
}

@Model
public final class PlayEventModel {
    public var songId: String
    public var timestamp: Date
    public var playTime: Int64

    public init(songId: String, timestamp: Date = .now, playTime: Int64) {
        self.songId = songId
        self.timestamp = timestamp
        self.playTime = playTime
    }
}

@Model
public final class SearchHistoryModel {
    @Attribute(.unique) public var query: String
    public var timestamp: Date

    public init(query: String, timestamp: Date = .now) {
        self.query = query
        self.timestamp = timestamp
    }
}

@Model
public final class RecognitionHistoryModel {
    public var trackId: String
    public var title: String
    public var artist: String
    public var album: String?
    public var coverArtUrl: String?
    public var coverArtHqUrl: String?
    public var genre: String?
    public var releaseDate: String?
    public var label: String?
    public var shazamUrl: String?
    public var appleMusicUrl: String?
    public var spotifyUrl: String?
    public var isrc: String?
    public var youtubeVideoId: String?
    public var recognizedAt: Date
    public var isLiked: Bool

    public init(trackId: String, title: String, artist: String, album: String? = nil,
                coverArtUrl: String? = nil, coverArtHqUrl: String? = nil, genre: String? = nil,
                releaseDate: String? = nil, label: String? = nil, shazamUrl: String? = nil,
                appleMusicUrl: String? = nil, spotifyUrl: String? = nil, isrc: String? = nil,
                youtubeVideoId: String? = nil, recognizedAt: Date = .now, isLiked: Bool = false) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.coverArtUrl = coverArtUrl
        self.coverArtHqUrl = coverArtHqUrl
        self.genre = genre
        self.releaseDate = releaseDate
        self.label = label
        self.shazamUrl = shazamUrl
        self.appleMusicUrl = appleMusicUrl
        self.spotifyUrl = spotifyUrl
        self.isrc = isrc
        self.youtubeVideoId = youtubeVideoId
        self.recognizedAt = recognizedAt
        self.isLiked = isLiked
    }
}

@Model
public final class SpeedDialItemModel {
    @Attribute(.unique) public var id: String
    public var secondaryId: String?
    public var title: String
    public var subtitle: String?
    public var thumbnailUrl: String?
    public var type: String
    public var isExplicit: Bool
    public var createDate: Int64

    public init(id: String, secondaryId: String? = nil, title: String, subtitle: String? = nil,
                thumbnailUrl: String? = nil, type: String, isExplicit: Bool = false,
                createDate: Int64 = Int64(Date.now.timeIntervalSince1970 * 1000)) {
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
