import Foundation

// MARK: - Filter Enums

public enum SongFilter: String, CaseIterable, Sendable {
    case liked
    case library
    case downloaded
    case uploaded
}

public enum ArtistFilter: String, CaseIterable, Sendable {
    case liked
    case library
}

public enum AlbumFilter: String, CaseIterable, Sendable {
    case liked
    case library
    case uploaded
}

// MARK: - Sort Enums

public enum SongSortType: String, CaseIterable, Sendable {
    case createDate
    case name
    case artist
    case playTime
    case dateAdded
}

public enum ArtistSortType: String, CaseIterable, Sendable {
    case createDate
    case name
}

public enum AlbumSortType: String, CaseIterable, Sendable {
    case createDate
    case name
    case year
}

public enum PlaylistSortType: String, CaseIterable, Sendable {
    case createDate
    case name
}

// MARK: - Stats

public enum StatsPeriod: String, CaseIterable, Sendable {
    case week
    case month
    case threeMonths
    case sixMonths
    case year
    case allTime
}
