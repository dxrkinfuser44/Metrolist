#if canImport(SwiftUI)
import Foundation
import MetrolistCore
import MetrolistPersistence

// MARK: - Library ViewModels

/// Manages the songs library tab with sorting, filtering, and search.
@Observable
public final class LibrarySongsViewModel {
    public var songs: [SongModel] = []
    public var sortType: SongSortType = .createDate
    public var sortAscending = false
    public var filter: SongFilter? = nil
    public var searchQuery = ""
    public var isLoading = false

    private let database: MusicDatabase

    public init(database: MusicDatabase) {
        self.database = database
    }

    @MainActor
    public func loadSongs() {
        isLoading = true
        songs = database.allSongs(filter: filter, sortBy: sortType, ascending: sortAscending)
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            songs = songs.filter { $0.title.lowercased().contains(query) }
        }
        isLoading = false
    }

    @MainActor
    public func toggleLike(songId: String) {
        database.toggleLike(songId: songId)
        loadSongs()
    }
}

/// Manages the artists library tab.
@Observable
public final class LibraryArtistsViewModel {
    public var artists: [ArtistModel] = []
    public var sortType: ArtistSortType = .createDate
    public var sortAscending = false
    public var searchQuery = ""
    public var isLoading = false

    private let database: MusicDatabase

    public init(database: MusicDatabase) {
        self.database = database
    }

    @MainActor
    public func loadArtists() {
        isLoading = true
        artists = database.allArtists(sortBy: sortType, ascending: sortAscending)
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            artists = artists.filter { $0.name.lowercased().contains(query) }
        }
        isLoading = false
    }
}

/// Manages the albums library tab.
@Observable
public final class LibraryAlbumsViewModel {
    public var albums: [AlbumModel] = []
    public var sortType: AlbumSortType = .createDate
    public var sortAscending = false
    public var searchQuery = ""
    public var isLoading = false

    private let database: MusicDatabase

    public init(database: MusicDatabase) {
        self.database = database
    }

    @MainActor
    public func loadAlbums() {
        isLoading = true
        albums = database.allAlbums(sortBy: sortType, ascending: sortAscending)
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            albums = albums.filter { $0.title.lowercased().contains(query) }
        }
        isLoading = false
    }
}

/// Manages the playlists library tab.
@Observable
public final class LibraryPlaylistsViewModel {
    public var playlists: [PlaylistModel] = []
    public var sortType: PlaylistSortType = .createDate
    public var sortAscending = false
    public var searchQuery = ""
    public var isLoading = false
    public var showCreateSheet = false
    public var newPlaylistName = ""

    private let database: MusicDatabase

    public init(database: MusicDatabase) {
        self.database = database
    }

    @MainActor
    public func loadPlaylists() {
        isLoading = true
        playlists = database.allPlaylists(sortBy: sortType, ascending: sortAscending)
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            playlists = playlists.filter { $0.name.lowercased().contains(query) }
        }
        isLoading = false
    }

    @MainActor
    public func createPlaylist(name: String) {
        let playlist = Playlist(name: name)
        let model = PlaylistModel(id: playlist.id, name: name)
        database.modelContext.insert(model)
        try? database.modelContext.save()
        loadPlaylists()
    }
}

#endif
