#if canImport(SwiftUI)
import SwiftUI
import os
import MetrolistNetworking
import MetrolistPlayback
import MetrolistPersistence

private let logger = Logger(subsystem: "com.metrolist.music", category: "general")

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
            let innerAuth = InnerTubeAuth()
            let ytMusic = YouTubeMusic(auth: innerAuth)
            playerService.setStreamResolver { [preferences, ytMusic] videoId in
                // Call the player API which returns a Result<PlayerResponse, Error>
                let result = await ytMusic.player(videoId: videoId)
                let response = try result.get()

                guard let format = (response.streamingData?.adaptiveFormats ?? [])
                    .filter({ $0.mimeType.contains("audio") })
                    .sorted(by: { $0.bitrate ?? 0 > $1.bitrate ?? 0 })
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

            logger.info("Metrolist iOS initialized successfully")
        } catch {
            initError = error.localizedDescription
            logger.error("Initialization failed: \(error.localizedDescription)")
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

#endif
