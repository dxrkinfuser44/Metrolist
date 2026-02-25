import Foundation
import MetrolistCore

// MARK: - Album Detail ViewModel

@Observable
public final class AlbumViewModel {
    public var album: AlbumPage?
    public var songs: [SongItem] = []
    public var artists: [ArtistItem] = []
    public var isLoading = false
    public var errorMessage: String?
    public var isInLibrary = false
    public var isLiked = false

    public let browseId: String
    private let ytMusic: YouTubeMusic
    private let database: MusicDatabase

    public init(browseId: String, ytMusic: YouTubeMusic = YouTubeMusic(), database: MusicDatabase) {
        self.browseId = browseId
        self.ytMusic = ytMusic
        self.database = database
    }

    @MainActor
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let page = try await ytMusic.album(browseId: browseId)
            self.album = page
            self.songs = page.songs
            self.artists = page.artists

            // Check local library state
            if let model = database.album(id: browseId) {
                isInLibrary = model.inLibrary != nil
                isLiked = model.likedDate != nil
            }
        } catch {
            errorMessage = error.localizedDescription
            MetrolistLogger.network.error("Album fetch failed: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Artist Detail ViewModel

@Observable
public final class ArtistViewModel {
    public var artist: ArtistPage?
    public var topSongs: [SongItem] = []
    public var albums: [AlbumItem] = []
    public var singles: [AlbumItem] = []
    public var similarArtists: [ArtistItem] = []
    public var isLoading = false
    public var errorMessage: String?
    public var isBookmarked = false

    public let channelId: String
    private let ytMusic: YouTubeMusic
    private let database: MusicDatabase

    public init(channelId: String, ytMusic: YouTubeMusic = YouTubeMusic(), database: MusicDatabase) {
        self.channelId = channelId
        self.ytMusic = ytMusic
        self.database = database
    }

    @MainActor
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let page = try await ytMusic.artist(channelId: channelId)
            self.artist = page
            self.topSongs = page.songs
            self.albums = page.albums
            self.singles = page.singles
            self.similarArtists = page.similar

            if let model = database.artist(id: channelId) {
                isBookmarked = model.bookmarkedAt != nil
            }
        } catch {
            errorMessage = error.localizedDescription
            MetrolistLogger.network.error("Artist fetch failed: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Playlist Detail ViewModel

@Observable
public final class PlaylistViewModel {
    public var playlist: PlaylistPage?
    public var songs: [SongItem] = []
    public var isLoading = false
    public var errorMessage: String?
    public var continuationToken: String?
    public var isInLibrary = false

    public let playlistId: String
    private let ytMusic: YouTubeMusic
    private let database: MusicDatabase

    public init(playlistId: String, ytMusic: YouTubeMusic = YouTubeMusic(), database: MusicDatabase) {
        self.playlistId = playlistId
        self.ytMusic = ytMusic
        self.database = database
    }

    @MainActor
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let page = try await ytMusic.playlist(browseId: playlistId)
            self.playlist = page
            self.songs = page.songs
            self.continuationToken = page.continuationToken

            if database.playlist(id: playlistId) != nil {
                isInLibrary = true
            }
        } catch {
            errorMessage = error.localizedDescription
            MetrolistLogger.network.error("Playlist fetch failed: \(error)")
        }

        isLoading = false
    }

    @MainActor
    public func loadMore() async {
        guard let token = continuationToken, !isLoading else { return }
        isLoading = true

        do {
            let more = try await ytMusic.playlistContinuation(token: token)
            self.songs.append(contentsOf: more.songs)
            self.continuationToken = more.continuationToken
        } catch {
            MetrolistLogger.network.error("Playlist continuation failed: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Stats ViewModel

@Observable
public final class StatsViewModel {
    public var topSongs: [SongModel] = []
    public var topArtists: [ArtistModel] = []
    public var totalPlayTime: Int64 = 0
    public var totalSongs: Int = 0
    public var period: StatsPeriod = .week
    public var isLoading = false

    private let database: MusicDatabase

    public init(database: MusicDatabase) {
        self.database = database
    }

    @MainActor
    public func loadStats() {
        isLoading = true

        let allSongs = database.allSongs()
        totalSongs = allSongs.count
        totalPlayTime = allSongs.reduce(0) { $0 + $1.totalPlayTime }

        // Top songs by play time
        topSongs = Array(allSongs.sorted { $0.totalPlayTime > $1.totalPlayTime }.prefix(10))

        isLoading = false
    }
}

// MARK: - Settings ViewModel

@Observable
public final class SettingsViewModel {
    public let preferences: UserPreferences
    public var showLoginSheet = false
    public var showBackupSheet = false
    public var showAboutSheet = false

    public init(preferences: UserPreferences) {
        self.preferences = preferences
    }
}
