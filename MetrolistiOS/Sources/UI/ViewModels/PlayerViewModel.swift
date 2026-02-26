#if canImport(SwiftUI)
import Foundation
import MetrolistCore
import MetrolistNetworking
import MetrolistPlayback

// MARK: - Player ViewModel

/// Central ViewModel coordinating playback, now-playing UI, lyrics,
/// and animated artwork display.
@Observable
public final class PlayerViewModel {
    // Player service binding
    public let playerService: AudioPlayerService
    public let nowPlayingManager: NowPlayingManager

    // Lyrics state
    public var currentLyrics: String?
    public var syncedLyrics: [(time: TimeInterval, text: String)] = []
    public var currentLyricIndex: Int = 0
    public var isLoadingLyrics = false
    public var lyricsProvider: String?

    // Animated artwork state
    public var animatedArtworkURL: URL?
    public var isLoadingAnimatedArtwork = false

    // Queue sheet
    public var showQueue = false
    public var showLyrics = false

    // UI state
    public var showSleepTimerSheet = false
    public var showSpeedSheet = false
    public var playbackSpeed: Float = 1.0

    private let lyricsHelper: LyricsHelper
    private let artworkFetcher: AnimatedArtworkFetcher
    private let artworkCache: AnimatedArtworkCacheService

    public init(
        playerService: AudioPlayerService,
        nowPlayingManager: NowPlayingManager,
        lyricsHelper: LyricsHelper = LyricsHelper(),
        artworkFetcher: AnimatedArtworkFetcher = AnimatedArtworkFetcher(),
        artworkCache: AnimatedArtworkCacheService = AnimatedArtworkCacheService()
    ) {
        self.playerService = playerService
        self.nowPlayingManager = nowPlayingManager
        self.lyricsHelper = lyricsHelper
        self.artworkFetcher = artworkFetcher
        self.artworkCache = artworkCache
    }

    // MARK: - Convenience Properties

    public var currentItem: MediaMetadata? { playerService.currentItem }
    public var isPlaying: Bool { playerService.state.isPlaying }
    public var currentTime: TimeInterval { playerService.currentTime }
    public var duration: TimeInterval { playerService.duration }
    public var queue: [MediaMetadata] { playerService.queue }
    public var currentIndex: Int { playerService.currentIndex }
    public var repeatMode: RepeatMode {
        get { playerService.repeatMode }
        set { playerService.repeatMode = newValue }
    }
    public var shuffleEnabled: Bool {
        get { playerService.shuffleEnabled }
        set { playerService.shuffleEnabled = newValue }
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    public var formattedCurrentTime: String {
        formatDuration(currentTime)
    }

    public var formattedDuration: String {
        formatDuration(duration)
    }

    // MARK: - Playback Controls

    public func play() { playerService.play() }
    public func pause() { playerService.pause() }
    public func togglePlayPause() { playerService.togglePlayPause() }
    public func skipToNext() { playerService.skipToNext() }
    public func skipToPrevious() { playerService.skipToPrevious() }
    public func seekTo(_ time: TimeInterval) { playerService.seekTo(time) }

    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .queue
        case .queue: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Track Change Handler

    /// Called when the current track changes to load metadata, lyrics, and artwork.
    @MainActor
    public func onTrackChanged() async {
        guard let item = currentItem else { return }

        // Update Now Playing info
        nowPlayingManager.updateNowPlayingInfo(
            metadata: item,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying
        )

        // Load artwork for lock screen
        if let urlStr = item.thumbnailUrl, let url = URL(string: urlStr) {
            await nowPlayingManager.updateArtwork(from: url)
        }

        // Load lyrics
        await loadLyrics(for: item)

        // Load animated artwork
        await loadAnimatedArtwork(for: item)
    }

    // MARK: - Lyrics

    @MainActor
    private func loadLyrics(for item: MediaMetadata) async {
        isLoadingLyrics = true
        currentLyrics = nil
        syncedLyrics = []
        currentLyricIndex = 0

        let artistName = item.artists.first?.name ?? ""
        if let (lyrics, provider) = await lyricsHelper.getLyrics(
            title: item.title, artist: artistName, duration: Int(duration)
        ) {
            self.currentLyrics = lyrics
            self.lyricsProvider = provider
            self.syncedLyrics = parseSyncedLyrics(lyrics)
        } else {
            MetrolistLogger.lyrics.error("Failed to load lyrics for: \(item.title)")
        }

        isLoadingLyrics = false
    }

    /// Updates the current highlighted lyric line based on playback position.
    public func updateLyricPosition(at time: TimeInterval) {
        guard !syncedLyrics.isEmpty else { return }
        let newIndex = syncedLyrics.lastIndex(where: { $0.time <= time }) ?? 0
        if newIndex != currentLyricIndex {
            currentLyricIndex = newIndex
        }
    }

    /// Parses LRC-format synced lyrics into (time, text) pairs.
    private func parseSyncedLyrics(_ raw: String) -> [(time: TimeInterval, text: String)] {
        let pattern = /\[(\d+):(\d+)\.(\d+)\](.*)/
        return raw.components(separatedBy: .newlines).compactMap { line in
            guard let match = line.firstMatch(of: pattern) else { return nil }
            let minutes = Double(match.1) ?? 0
            let seconds = Double(match.2) ?? 0
            let millis = Double(match.3) ?? 0
            let time = minutes * 60 + seconds + millis / (match.3.count <= 2 ? 100 : 1000)
            let text = String(match.4).trimmingCharacters(in: .whitespaces)
            return (time, text)
        }
    }

    // MARK: - Animated Artwork

    @MainActor
    private func loadAnimatedArtwork(for item: MediaMetadata) async {
        isLoadingAnimatedArtwork = true
        animatedArtworkURL = nil

        // Search Apple Music for the track
        let query = "\(item.title) \(item.artists.first?.name ?? "")"
        let searchURL = "https://music.apple.com/search?term=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        guard let url = URL(string: searchURL) else {
            isLoadingAnimatedArtwork = false
            return
        }

        do {
            let hasCached = await artworkCache.hasCachedArtwork(for: searchURL)
            if hasCached {
                let cachedURL = try await artworkCache.getOrDownload(albumId: searchURL, videoURL: url)
                self.animatedArtworkURL = cachedURL
            } else {
                let result = await artworkFetcher.fetchAnimatedArtworkURL(from: url)
                if case .success(let videoURL) = result {
                    let localURL = try await artworkCache.getOrDownload(albumId: searchURL, videoURL: videoURL)
                    self.animatedArtworkURL = localURL
                }
            }
        } catch {
            MetrolistLogger.animatedArtwork.error("Animated artwork fetch failed: \(error)")
        }

        isLoadingAnimatedArtwork = false
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#endif
