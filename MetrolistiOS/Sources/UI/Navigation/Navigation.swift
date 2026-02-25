import SwiftUI

// MARK: - Route Definitions

/// Type-safe navigation routes matching the Android NavGraph destinations.
public enum Route: Hashable {
    // Main tabs
    case home
    case search
    case library
    case listenTogether

    // Detail screens
    case album(id: String)
    case artist(id: String)
    case playlist(id: String)
    case onlinePlaylist(id: String)

    // Utility screens
    case settings
    case stats
    case history
    case youTubeLogin
    case backup
}

// MARK: - Mini Player

/// Persistent mini-player bar displayed above the tab bar.
/// Tapping expands to the full PlayerScreen. Matches Android's MiniPlayer composable.
public struct MiniPlayerBar: View {
    @Bindable var viewModel: PlayerViewModel
    @Binding var showFullPlayer: Bool

    public var body: some View {
        if viewModel.currentItem != nil {
            VStack(spacing: 0) {
                // Progress bar at top edge
                GeometryReader { geo in
                    Rectangle()
                        .fill(.tint)
                        .frame(width: geo.size.width * viewModel.progress, height: 2)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Thumbnail
                    if let urlStr = viewModel.currentItem?.thumbnailUrl,
                       let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    // Track info
                    VStack(alignment: .leading, spacing: 1) {
                        Text(viewModel.currentItem?.title ?? "")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(viewModel.currentItem?.artists.map(\.name).joined(separator: ", ") ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Play/Pause
                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    // Next
                    Button(action: viewModel.skipToNext) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial) // Liquid Glass: .ultraThinMaterial adapts
            .contentShape(Rectangle())
            .onTapGesture {
                showFullPlayer = true
            }
        }
    }
}

// MARK: - Main Tab View

/// Root navigation container with bottom tab bar.
/// iOS 26: TabView automatically gets Liquid Glass treatment.
public struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showFullPlayer = false
    @State private var navigationPath = NavigationPath()

    // Dependencies — injected from App
    let homeVM: HomeViewModel
    let searchVM: SearchViewModel
    let playerVM: PlayerViewModel
    let database: MusicDatabase
    let preferences: UserPreferences

    public enum Tab: String, CaseIterable, Identifiable {
        case home = "Home"
        case search = "Search"
        case library = "Library"
        case settings = "Settings"

        public var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house"
            case .search: return "magnifyingglass"
            case .library: return "music.note.list"
            case .settings: return "gearshape"
            }
        }
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Home
                NavigationStack(path: $navigationPath) {
                    HomeScreen(viewModel: homeVM)
                        .navigationDestination(for: Route.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

                // Search
                NavigationStack {
                    SearchScreen(viewModel: searchVM)
                        .navigationDestination(for: Route.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Label(Tab.search.rawValue, systemImage: Tab.search.icon)
                }
                .tag(Tab.search)

                // Library
                NavigationStack {
                    LibraryScreen(database: database)
                        .navigationDestination(for: Route.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Label(Tab.library.rawValue, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)

                // Settings
                NavigationStack {
                    SettingsScreen(viewModel: SettingsViewModel(preferences: preferences))
                }
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
            }

            // Mini player sits above the tab bar
            VStack(spacing: 0) {
                Spacer()
                MiniPlayerBar(viewModel: playerVM, showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 49) // TabBar approximate height
            }
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            PlayerScreen(viewModel: playerVM)
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .album(let id):
            AlbumDetailScreen(viewModel: AlbumViewModel(browseId: id, database: database))
        case .artist(let id):
            ArtistDetailScreen(viewModel: ArtistViewModel(channelId: id, database: database))
        case .playlist(let id):
            Text("Playlist: \(id)") // Placeholder for PlaylistDetailScreen
        case .settings:
            SettingsScreen(viewModel: SettingsViewModel(preferences: preferences))
        case .stats:
            Text("Stats") // Placeholder
        case .history:
            Text("History") // Placeholder
        default:
            Text("Coming Soon")
        }
    }
}
