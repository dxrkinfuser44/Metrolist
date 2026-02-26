#if canImport(SwiftData)
import Foundation
import SwiftData
import MetrolistCore

// MARK: - Music Database

/// The main persistence layer, equivalent to Android's `MusicDatabase` wrapper.
/// Provides typed query methods over SwiftData's `ModelContext`.
@MainActor
public final class MusicDatabase {
    public let modelContainer: ModelContainer
    public let modelContext: ModelContext

    public init() throws {
        let schema = Schema([
            SongModel.self, ArtistModel.self, AlbumModel.self, PlaylistModel.self,
            SongArtistMapModel.self, SongAlbumMapModel.self, AlbumArtistMapModel.self,
            PlaylistSongMapModel.self, LyricsModel.self, AudioFormatModel.self,
            PlayEventModel.self, SearchHistoryModel.self, RecognitionHistoryModel.self,
            SpeedDialItemModel.self,
        ])
        let config = ModelConfiguration("MetrolistMusic", schema: schema, isStoredInMemoryOnly: false)
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = modelContainer.mainContext
    }

    // MARK: - Song CRUD

    public func song(id: String) -> SongModel? {
        let predicate = #Predicate<SongModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    public func upsertSong(_ entity: Song) {
        if let existing = song(id: entity.id) {
            existing.title = entity.title
            existing.duration = entity.duration
            existing.thumbnailUrl = entity.thumbnailUrl
            existing.albumId = entity.albumId
            existing.albumName = entity.albumName
            existing.isExplicit = entity.isExplicit
            existing.year = entity.year
            existing.isLiked = entity.isLiked
            existing.likedDate = entity.likedDate
            existing.totalPlayTime = entity.totalPlayTime
            existing.inLibrary = entity.inLibrary
            existing.isDownloaded = entity.isDownloaded
            existing.isUploaded = entity.isUploaded
            existing.isVideo = entity.isVideo
        } else {
            let model = SongModel(
                id: entity.id, title: entity.title, duration: entity.duration,
                thumbnailUrl: entity.thumbnailUrl, albumId: entity.albumId, albumName: entity.albumName,
                isExplicit: entity.isExplicit, year: entity.year, date: entity.date,
                dateModified: entity.dateModified, isLiked: entity.isLiked, likedDate: entity.likedDate,
                totalPlayTime: entity.totalPlayTime, inLibrary: entity.inLibrary,
                dateDownload: entity.dateDownload, isLocal: entity.isLocal,
                libraryAddToken: entity.libraryAddToken, libraryRemoveToken: entity.libraryRemoveToken,
                lyricsOffset: entity.lyricsOffset, romanizeLyrics: entity.romanizeLyrics,
                isDownloaded: entity.isDownloaded, isUploaded: entity.isUploaded, isVideo: entity.isVideo
            )
            modelContext.insert(model)
        }
        try? modelContext.save()
    }

    public func deleteSong(id: String) {
        guard let model = song(id: id) else { return }
        modelContext.delete(model)
        try? modelContext.save()
    }

    public func allSongs(filter: SongFilter? = nil, sortBy: SongSortType = .createDate, ascending: Bool = false) -> [SongModel] {
        var descriptor = FetchDescriptor<SongModel>()

        switch filter {
        case .liked:
            descriptor.predicate = #Predicate<SongModel> { $0.isLiked == true }
        case .library:
            descriptor.predicate = #Predicate<SongModel> { $0.inLibrary != nil }
        case .downloaded:
            descriptor.predicate = #Predicate<SongModel> { $0.isDownloaded == true }
        case .uploaded:
            descriptor.predicate = #Predicate<SongModel> { $0.isUploaded == true }
        case nil:
            break
        }

        switch sortBy {
        case .name:
            descriptor.sortBy = [SortDescriptor(\SongModel.title, order: ascending ? .forward : .reverse)]
        case .playTime:
            descriptor.sortBy = [SortDescriptor(\SongModel.totalPlayTime, order: ascending ? .forward : .reverse)]
        case .dateAdded:
            descriptor.sortBy = [SortDescriptor(\SongModel.inLibrary, order: ascending ? .forward : .reverse)]
        default:
            descriptor.sortBy = [SortDescriptor(\SongModel.date, order: ascending ? .forward : .reverse)]
        }

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func toggleLike(songId: String) {
        guard let song = song(id: songId) else { return }
        song.isLiked.toggle()
        song.likedDate = song.isLiked ? .now : nil
        try? modelContext.save()
    }

    // MARK: - Artist CRUD

    public func artist(id: String) -> ArtistModel? {
        let predicate = #Predicate<ArtistModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    public func upsertArtist(_ entity: Artist) {
        if let existing = artist(id: entity.id) {
            existing.name = entity.name
            existing.thumbnailUrl = entity.thumbnailUrl
            existing.channelId = entity.channelId
            existing.lastUpdateTime = entity.lastUpdateTime
        } else {
            let model = ArtistModel(id: entity.id, name: entity.name, thumbnailUrl: entity.thumbnailUrl,
                                    channelId: entity.channelId, lastUpdateTime: entity.lastUpdateTime,
                                    bookmarkedAt: entity.bookmarkedAt, isLocal: entity.isLocal)
            modelContext.insert(model)
        }
        try? modelContext.save()
    }

    public func allArtists(filter: ArtistFilter? = nil, sortBy: ArtistSortType = .createDate, ascending: Bool = false) -> [ArtistModel] {
        var descriptor = FetchDescriptor<ArtistModel>()

        switch filter {
        case .liked:
            descriptor.predicate = #Predicate<ArtistModel> { $0.bookmarkedAt != nil }
        case .library:
            break // All artists with songs in library
        case nil:
            break
        }

        switch sortBy {
        case .name:
            descriptor.sortBy = [SortDescriptor(\ArtistModel.name, order: ascending ? .forward : .reverse)]
        default:
            descriptor.sortBy = [SortDescriptor(\ArtistModel.lastUpdateTime, order: ascending ? .forward : .reverse)]
        }

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Album CRUD

    public func album(id: String) -> AlbumModel? {
        let predicate = #Predicate<AlbumModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    public func upsertAlbum(_ entity: Album) {
        if let existing = album(id: entity.id) {
            existing.title = entity.title
            existing.year = entity.year
            existing.thumbnailUrl = entity.thumbnailUrl
            existing.songCount = entity.songCount
            existing.duration = entity.duration
            existing.lastUpdateTime = entity.lastUpdateTime
        } else {
            let model = AlbumModel(id: entity.id, playlistId: entity.playlistId, title: entity.title,
                                   year: entity.year, thumbnailUrl: entity.thumbnailUrl,
                                   themeColor: entity.themeColor, songCount: entity.songCount,
                                   duration: entity.duration, isExplicit: entity.isExplicit,
                                   lastUpdateTime: entity.lastUpdateTime, bookmarkedAt: entity.bookmarkedAt,
                                   likedDate: entity.likedDate, inLibrary: entity.inLibrary,
                                   isLocal: entity.isLocal, isUploaded: entity.isUploaded)
            modelContext.insert(model)
        }
        try? modelContext.save()
    }

    public func allAlbums(filter: AlbumFilter? = nil, sortBy: AlbumSortType = .createDate, ascending: Bool = false) -> [AlbumModel] {
        var descriptor = FetchDescriptor<AlbumModel>()

        switch filter {
        case .liked:
            descriptor.predicate = #Predicate<AlbumModel> { $0.likedDate != nil }
        case .library:
            descriptor.predicate = #Predicate<AlbumModel> { $0.inLibrary != nil }
        case .uploaded:
            descriptor.predicate = #Predicate<AlbumModel> { $0.isUploaded == true }
        case nil:
            break
        }

        switch sortBy {
        case .name:
            descriptor.sortBy = [SortDescriptor(\AlbumModel.title, order: ascending ? .forward : .reverse)]
        case .year:
            descriptor.sortBy = [SortDescriptor(\AlbumModel.year, order: ascending ? .forward : .reverse)]
        default:
            descriptor.sortBy = [SortDescriptor(\AlbumModel.lastUpdateTime, order: ascending ? .forward : .reverse)]
        }

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Playlist CRUD

    public func playlist(id: String) -> PlaylistModel? {
        let predicate = #Predicate<PlaylistModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    public func allPlaylists(sortBy: PlaylistSortType = .createDate, ascending: Bool = false) -> [PlaylistModel] {
        var descriptor = FetchDescriptor<PlaylistModel>()

        switch sortBy {
        case .name:
            descriptor.sortBy = [SortDescriptor(\PlaylistModel.name, order: ascending ? .forward : .reverse)]
        default:
            descriptor.sortBy = [SortDescriptor(\PlaylistModel.createdAt, order: ascending ? .forward : .reverse)]
        }

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Lyrics

    public func lyrics(id: String) -> LyricsModel? {
        let predicate = #Predicate<LyricsModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    public func upsertLyrics(id: String, lyrics: String, provider: String) {
        if let existing = self.lyrics(id: id) {
            existing.lyrics = lyrics
            existing.provider = provider
        } else {
            modelContext.insert(LyricsModel(id: id, lyrics: lyrics, provider: provider))
        }
        try? modelContext.save()
    }

    // MARK: - Search History

    public func searchHistory(limit: Int = 20) -> [SearchHistoryModel] {
        var descriptor = FetchDescriptor<SearchHistoryModel>(
            sortBy: [SortDescriptor(\SearchHistoryModel.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func addSearchHistory(query: String) {
        // Remove duplicate if exists
        let predicate = #Predicate<SearchHistoryModel> { $0.query == query }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.timestamp = .now
        } else {
            modelContext.insert(SearchHistoryModel(query: query))
        }
        try? modelContext.save()
    }

    public func clearSearchHistory() {
        let descriptor = FetchDescriptor<SearchHistoryModel>()
        if let all = try? modelContext.fetch(descriptor) {
            for item in all { modelContext.delete(item) }
        }
        try? modelContext.save()
    }

    // MARK: - Play Events

    public func recordPlayEvent(songId: String, playTime: Int64) {
        let event = PlayEventModel(songId: songId, playTime: playTime)
        modelContext.insert(event)

        // Also update total play time on the song
        if let song = song(id: songId) {
            song.totalPlayTime += playTime
        }
        try? modelContext.save()
    }

    public func recentEvents(limit: Int = 50) -> [PlayEventModel] {
        var descriptor = FetchDescriptor<PlayEventModel>(
            sortBy: [SortDescriptor(\PlayEventModel.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Speed Dial

    public func speedDialItems() -> [SpeedDialItemModel] {
        let descriptor = FetchDescriptor<SpeedDialItemModel>(
            sortBy: [SortDescriptor(\SpeedDialItemModel.createDate, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func addSpeedDialItem(_ item: SpeedDialItem) {
        let model = SpeedDialItemModel(
            id: item.id, secondaryId: item.secondaryId, title: item.title,
            subtitle: item.subtitle, thumbnailUrl: item.thumbnailUrl,
            type: item.type.rawValue, isExplicit: item.isExplicit, createDate: item.createDate
        )
        modelContext.insert(model)
        try? modelContext.save()
    }

    public func removeSpeedDialItem(id: String) {
        let predicate = #Predicate<SpeedDialItemModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let item = try? modelContext.fetch(descriptor).first {
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
}

#endif
