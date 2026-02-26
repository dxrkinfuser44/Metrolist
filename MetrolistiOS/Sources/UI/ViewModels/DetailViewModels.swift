import Foundation
import MetrolistCore
import MetrolistNetworking
import MetrolistPersistence

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

    public init(browseId: String, ytMusic: YouTubeMusic? = nil, database: MusicDatabase) {
        self.browseId = browseId
        self.ytMusic = ytMusic ?? YouTubeMusic(auth: InnerTubeAuth())
        self.database = database
    }

    @MainActor
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let page = try await ytMusic.album(browseId: browseId).get()
            self.album = page
            self.songs = page.songs
            self.artists = [page.album.artists.first].compactMap { $0 }

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

    public init(channelId: String, ytMusic: YouTubeMusic? = nil, database: MusicDatabase) {
        self.channelId = channelId
        self.ytMusic = ytMusic ?? YouTubeMusic(auth: InnerTubeAuth())
        self.database = database
    }

    @MainActor
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let page = try await ytMusic.artist(browseId: channelId).get()
            self.artist = page
            // Extract items from sections by title
            for section in page.sections {
                let songItems = section.items.compactMap { $0 as? SongItem }
                let albumItems = section.items.compactMap { $0 as? AlbumItem }
                let artistItems = section.items.compactMap { $0 as? ArtistItem }
                let title = section.title.lowercased()
                if title.contains("song") && self.topSongs.isEmpty {
                    self.topSongs = songItems
                } else if title.contains("album") && self.albums.isEmpty {
                    self.albums = albumItems
                } else if title.contains("single") {
                    self.singles = albumItems
                } else if title.contains("similar") || title.contains("fan") {
                    self.similarArtists = artistItems
                }
            }

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

    public init(playlistId: String, ytMusic: YouTubeMusic? = nil, database: MusicDatabase) {
        self.playlistId = playlistId
        self.ytMusic = ytMusic ?? YouTubeMusic(auth: InnerTubeAuth())
        self.database = database
    }

    @MainActor
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let page = try await ytMusic.playlist(playlistId: playlistId).get()
            self.playlist = page
            self.songs = page.songs
            self.continuationToken = page.continuation

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
            let more = try await ytMusic.playlist(playlistId: "\(playlistId)&continuation=\(token)").get()
            self.songs.append(contentsOf: more.songs)
            self.continuationToken = more.continuation
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
