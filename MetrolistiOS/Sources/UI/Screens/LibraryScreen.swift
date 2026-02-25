import SwiftUI
import MetrolistCore

// MARK: - Library Screen

/// Tabbed library screen with Songs, Artists, Albums, and Playlists sections.
public struct LibraryScreen: View {
    @State private var selectedTab: LibraryTab = .songs
    @State private var songsVM: LibrarySongsViewModel
    @State private var artistsVM: LibraryArtistsViewModel
    @State private var albumsVM: LibraryAlbumsViewModel
    @State private var playlistsVM: LibraryPlaylistsViewModel

    public enum LibraryTab: String, CaseIterable {
        case songs = "Songs"
        case artists = "Artists"
        case albums = "Albums"
        case playlists = "Playlists"

        var icon: String {
            switch self {
            case .songs: return "music.note"
            case .artists: return "music.mic"
            case .albums: return "square.stack"
            case .playlists: return "music.note.list"
            }
        }
    }

    public init(database: MusicDatabase) {
        self._songsVM = State(initialValue: LibrarySongsViewModel(database: database))
        self._artistsVM = State(initialValue: LibraryArtistsViewModel(database: database))
        self._albumsVM = State(initialValue: LibraryAlbumsViewModel(database: database))
        self._playlistsVM = State(initialValue: LibraryPlaylistsViewModel(database: database))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab picker — on iOS 26, Picker with .segmented style gets Liquid Glass automatically
            Picker("Library Section", selection: $selectedTab) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            switch selectedTab {
            case .songs:
                LibrarySongsView(viewModel: songsVM)
            case .artists:
                LibraryArtistsView(viewModel: artistsVM)
            case .albums:
                LibraryAlbumsView(viewModel: albumsVM)
            case .playlists:
                LibraryPlaylistsView(viewModel: playlistsVM)
            }
        }
        .navigationTitle("Library")
    }
}

// MARK: - Songs List

struct LibrarySongsView: View {
    @Bindable var viewModel: LibrarySongsViewModel

    var body: some View {
        List {
            ForEach(viewModel.songs, id: \.id) { song in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(song.albumName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if song.isLiked {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        viewModel.toggleLike(songId: song.id)
                    } label: {
                        Label(
                            song.isLiked ? "Unlike" : "Like",
                            systemImage: song.isLiked ? "heart.slash" : "heart"
                        )
                    }
                    .tint(song.isLiked ? .gray : .red)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchQuery, prompt: "Filter songs...")
        .onChange(of: viewModel.searchQuery) {
            viewModel.loadSongs()
        }
        .onAppear { viewModel.loadSongs() }
    }
}

// MARK: - Artists List

struct LibraryArtistsView: View {
    @Bindable var viewModel: LibraryArtistsViewModel

    var body: some View {
        List {
            ForEach(viewModel.artists, id: \.id) { artist in
                NavigationLink(value: Route.artist(id: artist.id)) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: artist.thumbnailUrl ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(.quaternary)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())

                        Text(artist.name)
                            .font(.body)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchQuery, prompt: "Filter artists...")
        .onChange(of: viewModel.searchQuery) {
            viewModel.loadArtists()
        }
        .onAppear { viewModel.loadArtists() }
    }
}

// MARK: - Albums Grid

struct LibraryAlbumsView: View {
    @Bindable var viewModel: LibraryAlbumsViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.albums, id: \.id) { album in
                    NavigationLink(value: Route.album(id: album.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            AsyncImage(url: URL(string: album.thumbnailUrl ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                            }
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(album.title)
                                .font(.footnote.weight(.medium))
                                .lineLimit(2)

                            if let year = album.year {
                                Text(String(year))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Filter albums...")
        .onChange(of: viewModel.searchQuery) {
            viewModel.loadAlbums()
        }
        .onAppear { viewModel.loadAlbums() }
    }
}

// MARK: - Playlists List

struct LibraryPlaylistsView: View {
    @Bindable var viewModel: LibraryPlaylistsViewModel

    var body: some View {
        List {
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("Create Playlist", systemImage: "plus")
            }

            ForEach(viewModel.playlists, id: \.id) { playlist in
                NavigationLink(value: Route.playlist(id: playlist.id)) {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading) {
                            Text(playlist.name)
                                .font(.body)
                            Text("\(playlist.songMaps.count) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchQuery, prompt: "Filter playlists...")
        .onChange(of: viewModel.searchQuery) {
            viewModel.loadPlaylists()
        }
        .onAppear { viewModel.loadPlaylists() }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreatePlaylistSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Create Playlist Sheet

struct CreatePlaylistSheet: View {
    @Bindable var viewModel: LibraryPlaylistsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Playlist name", text: $viewModel.newPlaylistName)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createPlaylist(name: viewModel.newPlaylistName)
                        viewModel.newPlaylistName = ""
                        dismiss()
                    }
                    .disabled(viewModel.newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
