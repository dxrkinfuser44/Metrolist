#if canImport(SwiftUI)
import SwiftUI
import NukeUI
import MetrolistCore

// MARK: - Album Detail Screen

public struct AlbumDetailScreen: View {
    @State private var viewModel: AlbumViewModel

    public init(viewModel: AlbumViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                if let album = viewModel.album {
                    albumHeader(album)
                }

                // Actions
                HStack(spacing: 16) {
                    Button {
                        // Play all
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        // Shuffle
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        // Add to library
                    } label: {
                        Image(systemName: viewModel.isInLibrary ? "checkmark" : "plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // Songs
                ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(song.title)
                                    .font(.body)
                                    .lineLimit(1)
                                if song.isExplicit {
                                    Image(systemName: "e.square.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let subtitle = song.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            // More options
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Play from index
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func albumHeader(_ album: AlbumPage) -> some View {
        VStack(spacing: 12) {
            if let url = URL(string: album.thumbnailUrl ?? "") {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                    }
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10, y: 4)
            }

            Text(album.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(album.artists.map(\.name).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let year = album.year {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Artist Detail Screen

public struct ArtistDetailScreen: View {
    @State private var viewModel: ArtistViewModel

    public init(viewModel: ArtistViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Header
                if let artist = viewModel.artist {
                    artistHeader(artist)
                }

                // Top Songs
                if !viewModel.topSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Songs")
                            .font(.title3.weight(.bold))
                            .padding(.horizontal)

                        ForEach(viewModel.topSongs.prefix(5), id: \.id) { song in
                            SongRowView(song: song, onTap: {
                                // Play
                            })
                            .padding(.horizontal)
                        }
                    }
                }

                // Albums
                if !viewModel.albums.isEmpty {
                    HorizontalSection("Albums") {
                        ForEach(viewModel.albums, id: \.id) { album in
                            ItemCardView(
                                title: album.title,
                                subtitle: album.year.map(String.init),
                                thumbnailURL: album.thumbnails.last?.url
                            ) {
                                // Navigate to album
                            }
                        }
                    }
                }

                // Singles
                if !viewModel.singles.isEmpty {
                    HorizontalSection("Singles & EPs") {
                        ForEach(viewModel.singles, id: \.id) { single in
                            ItemCardView(
                                title: single.title,
                                subtitle: single.year.map(String.init),
                                thumbnailURL: single.thumbnails.last?.url
                            ) {
                                // Navigate
                            }
                        }
                    }
                }

                // Similar Artists
                if !viewModel.similarArtists.isEmpty {
                    HorizontalSection("Similar Artists") {
                        ForEach(viewModel.similarArtists, id: \.id) { artist in
                            ItemCardView(
                                title: artist.title,
                                thumbnailURL: artist.thumbnails.last?.url,
                                isRound: true
                            ) {
                                // Navigate to artist
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func artistHeader(_ artist: ArtistPage) -> some View {
        VStack(spacing: 12) {
            if let url = URL(string: artist.thumbnailUrl ?? "") {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Circle().fill(.quaternary)
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .shadow(radius: 10, y: 4)
            }

            Text(artist.name)
                .font(.title.weight(.bold))

            HStack(spacing: 16) {
                Button {
                    // Shuffle play
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    // Radio
                } label: {
                    Label("Radio", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Settings Screen

public struct SettingsScreen: View {
    @Bindable var viewModel: SettingsViewModel

    public var body: some View {
        Form {
            // Playback
            Section("Playback") {
                Picker("Audio Quality", selection: $viewModel.preferences.audioQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }

                Toggle("Persistent Queue", isOn: $viewModel.preferences.persistentQueue)
                Toggle("Skip Silence", isOn: $viewModel.preferences.skipSilence)
                Toggle("Normalize Loudness", isOn: $viewModel.preferences.normalizeLoudness)
                Toggle("Auto-Load More", isOn: $viewModel.preferences.autoLoadMore)
                Toggle("Pause on Disconnect", isOn: $viewModel.preferences.pauseOnHeadphonesDisconnect)

                HStack {
                    Text("Crossfade")
                    Spacer()
                    Text(viewModel.preferences.crossfadeDuration > 0
                         ? "\(Int(viewModel.preferences.crossfadeDuration))s" : "Off")
                        .foregroundStyle(.secondary)
                }
            }

            // Appearance
            Section("Appearance") {
                Picker("Dark Mode", selection: $viewModel.preferences.darkMode) {
                    Text("System").tag(DarkMode.system)
                    Text("Light").tag(DarkMode.light)
                    Text("Dark").tag(DarkMode.dark)
                }
                Toggle("Dynamic Theme", isOn: $viewModel.preferences.dynamicTheme)
                Toggle("Liquid Glass", isOn: $viewModel.preferences.liquidGlassEnabled)
                Toggle("Navigation Labels", isOn: $viewModel.preferences.showNavigationLabels)
            }

            // Lyrics
            Section("Lyrics") {
                Toggle("Show Lyrics", isOn: $viewModel.preferences.enableLyrics)
                Toggle("Prefer Synced Lyrics", isOn: $viewModel.preferences.preferSyncedLyrics)
                Toggle("Enable KuGou", isOn: $viewModel.preferences.enableKugou)
            }

            // Last.fm
            Section("Last.fm") {
                Toggle("Enable Last.fm", isOn: $viewModel.preferences.enableLastFm)
                if viewModel.preferences.enableLastFm {
                    if viewModel.preferences.lastFmSessionKey.isEmpty {
                        Button("Sign In") {
                            viewModel.showLoginSheet = true
                        }
                    } else {
                        HStack {
                            Text("Username")
                            Spacer()
                            Text(viewModel.preferences.lastFmUsername)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("Scrobble", isOn: $viewModel.preferences.scrobbleEnabled)
                    }
                }
            }

            // Account
            Section("Account") {
                if viewModel.preferences.isLoggedIn {
                    HStack {
                        Text("Signed in as")
                        Spacer()
                        Text(viewModel.preferences.accountName ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                    Button("Sign Out", role: .destructive) {
                        viewModel.preferences.innerTubeCookie = nil
                        viewModel.preferences.accountName = nil
                        viewModel.preferences.accountEmail = nil
                    }
                } else {
                    Button("Sign In to YouTube Music") {
                        viewModel.showLoginSheet = true
                    }
                }
            }

            // Backup
            Section("Backup") {
                Button("Export Database") {
                    viewModel.showBackupSheet = true
                }
                Button("Import Database") {
                    viewModel.showBackupSheet = true
                }
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

private extension AudioQuality {
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .high: return "High"
        case .low: return "Low"
        }
    }
}

#endif
