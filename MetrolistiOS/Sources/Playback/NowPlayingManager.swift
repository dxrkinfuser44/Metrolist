import Foundation
import MediaPlayer
import UIKit
import MetrolistCore

// MARK: - Now Playing Manager

/// Integrates with Apple's MediaPlayer framework for lock screen controls,
/// Control Center, and CarPlay. Equivalent to Android's MediaSession integration.
///
/// Uses:
///   - MPNowPlayingInfoCenter  → lock screen / Control Center metadata
///   - MPRemoteCommandCenter   → play/pause/skip remote controls
///   - MPMediaItemArtwork      → static artwork for Now Playing info
@Observable
public final class NowPlayingManager {
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private weak var playerService: AudioPlayerService?

    /// Currently displayed artwork. Used for lock screen static image.
    private var currentArtworkImage: UIImage?

    public init() {}

    /// Bind to an AudioPlayerService to sync state with the system.
    public func bind(to player: AudioPlayerService) {
        self.playerService = player
        registerRemoteCommands()
    }

    // MARK: - Update Now Playing Info

    /// Call this whenever the current track or playback position changes.
    public func updateNowPlayingInfo(
        metadata: MediaMetadata?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        playbackRate: Float = 1.0
    ) {
        guard let metadata else {
            infoCenter.nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0,
            MPMediaItemPropertyMediaType: MPMediaType.music.rawValue,
        ]

        // Artist names
        let artists = metadata.artists.map(\.name).joined(separator: ", ")
        if !artists.isEmpty {
            info[MPMediaItemPropertyArtist] = artists
        }

        // Album
        if let albumName = metadata.album?.name {
            info[MPMediaItemPropertyAlbumTitle] = albumName
        }

        // Artwork
        if let artwork = currentArtworkImage {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            info[MPMediaItemPropertyArtwork] = mpArtwork
        }

        // Song ID for external identification
        info[MPMediaItemPropertyPersistentID] = metadata.id.hashValue

        infoCenter.nowPlayingInfo = info
    }

    /// Update the artwork displayed on the lock screen.
    /// Downloads asynchronously from the thumbnail URL.
    public func updateArtwork(from url: URL?) async {
        guard let url else {
            currentArtworkImage = nil
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.currentArtworkImage = image
                    // Re-push now playing info with new artwork
                    if var info = self.infoCenter.nowPlayingInfo {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        info[MPMediaItemPropertyArtwork] = artwork
                        self.infoCenter.nowPlayingInfo = info
                    }
                }
            }
        } catch {
            MetrolistLogger.playback.error("Failed to download artwork: \(error)")
        }
    }

    /// Provide a pre-loaded UIImage for the artwork (e.g. from cache).
    public func setArtwork(_ image: UIImage?) {
        currentArtworkImage = image
    }

    // MARK: - Remote Command Handlers

    private func registerRemoteCommands() {
        // Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playerService?.play()
            return .success
        }

        // Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playerService?.pause()
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.playerService?.togglePlayPause()
            return .success
        }

        // Next track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playerService?.skipToNext()
            return .success
        }

        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playerService?.skipToPrevious()
            return .success
        }

        // Seek
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.playerService?.seekTo(event.positionTime)
            return .success
        }

        // Repeat mode toggle via bookmark command (a common pattern for 3rd-party players)
        commandCenter.repeatCommand.isEnabled = true
        commandCenter.repeatCommand.addTarget { [weak self] _ in
            guard let player = self?.playerService else { return .commandFailed }
            switch player.repeatMode {
            case .off: player.repeatMode = .queue
            case .queue: player.repeatMode = .one
            case .one: player.repeatMode = .off
            }
            return .success
        }

        // Shuffle toggle
        commandCenter.shuffleCommand.isEnabled = true
        commandCenter.shuffleCommand.addTarget { [weak self] _ in
            guard let player = self?.playerService else { return .commandFailed }
            player.shuffleEnabled.toggle()
            return .success
        }

        // Like/dislike (rating)
        commandCenter.ratingCommand.isEnabled = true
        commandCenter.ratingCommand.maximumRating = 1
        commandCenter.ratingCommand.minimumRating = 0
        commandCenter.ratingCommand.addTarget { [weak self] event in
            guard let ratingEvent = event as? MPRatingCommandEvent else { return .commandFailed }
            // rating 1 = liked, 0 = unliked — delegate to database layer via callback
            let isLiked = ratingEvent.rating >= 1
            self?.onLikeToggled?(isLiked)
            return .success
        }

        // Skip interval for AirPods double/triple tap
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let player = self?.playerService else { return .commandFailed }
            player.seekTo(player.currentTime + skipEvent.interval)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let player = self?.playerService else { return .commandFailed }
            player.seekTo(max(0, player.currentTime - skipEvent.interval))
            return .success
        }
    }

    /// Callback for like/unlike from lock screen rating command.
    public var onLikeToggled: ((Bool) -> Void)?

    // MARK: - Cleanup

    public func teardown() {
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.repeatCommand.removeTarget(nil)
        commandCenter.shuffleCommand.removeTarget(nil)
        commandCenter.ratingCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        infoCenter.nowPlayingInfo = nil
    }
}
