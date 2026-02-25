import SwiftUI

// MARK: - App Entry Point

/// Metrolist iOS application root.
/// Initializes all services and dependency graph, then presents the main UI.
@main
struct MetrolistApp: App {
    @State private var database: MusicDatabase?
    @State private var playerService = AudioPlayerService()
    @State private var nowPlayingManager = NowPlayingManager()
    @State private var preferences = UserPreferences.shared
    @State private var initError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let database {
                    let playerVM = PlayerViewModel(
                        playerService: playerService,
                        nowPlayingManager: nowPlayingManager
                    )
                    let homeVM = HomeViewModel()
                    let searchVM = SearchViewModel()

                    MainTabView(
                        homeVM: homeVM,
                        searchVM: searchVM,
                        playerVM: playerVM,
                        database: database,
                        preferences: preferences
                    )
                    .tint(.pink)
                    .preferredColorScheme(colorScheme)
                } else if let error = initError {
                    ContentUnavailableView {
                        Label("Initialization Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { initialize() }
                    }
                } else {
                    ProgressView("Loading...")
                        .task { initialize() }
                }
            }
        }
    }

    private func initialize() {
        do {
            let db = try MusicDatabase()
            self.database = db

            // Bind now playing manager to player service
            nowPlayingManager.bind(to: playerService)

            // Configure stream resolver
            playerService.setStreamResolver { [preferences] videoId in
                let ytMusic = YouTubeMusic()
                let response = try await ytMusic.player(videoId: videoId)
                guard let format = response.streamingData?.adaptiveFormats
                    .filter({ $0.mimeType.contains("audio") })
                    .sorted(by: { $0.bitrate > $1.bitrate })
                    .first,
                      let urlString = format.url,
                      let url = URL(string: urlString) else {
                    throw PlayerError.noStreamAvailable
                }
                return url
            }

            // Apply preferences to player
            playerService.skipSilence = preferences.skipSilence
            playerService.normalizeLoudness = preferences.normalizeLoudness
            playerService.loudnessBaseGain = Float(preferences.loudnessBaseGain)
            playerService.crossfadeDuration = preferences.crossfadeDuration

            MetrolistLogger.general.info("Metrolist iOS initialized successfully")
        } catch {
            initError = error.localizedDescription
            MetrolistLogger.general.error("Initialization failed: \(error)")
        }
    }

    private var colorScheme: ColorScheme? {
        switch preferences.darkMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Player Errors

enum PlayerError: Error, LocalizedError {
    case noStreamAvailable

    var errorDescription: String? {
        switch self {
        case .noStreamAvailable: return "No audio stream available for this track"
        }
    }
}
