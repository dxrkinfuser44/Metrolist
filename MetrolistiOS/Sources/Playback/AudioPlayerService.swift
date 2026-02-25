import Foundation
import AVFoundation
import Combine
import MetrolistCore

// MARK: - Player State

public enum PlayerState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case error(String)

    public var isPlaying: Bool {
        self == .playing
    }
}

// MARK: - Audio Player Service

/// Core playback engine built on AVQueuePlayer.
/// Equivalent to Android's MusicService (3300 lines) — manages queue, streaming,
/// crossfade, skip silence, loudness normalization, and background audio.
@Observable
public final class AudioPlayerService {
    // MARK: - Published Properties
    public private(set) var state: PlayerState = .idle
    public private(set) var currentItem: MediaMetadata?
    public private(set) var queue: [MediaMetadata] = []
    public private(set) var currentIndex: Int = -1
    public private(set) var duration: TimeInterval = 0
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var bufferedTime: TimeInterval = 0
    public var repeatMode: RepeatMode = .off
    public var shuffleEnabled: Bool = false {
        didSet { onShuffleChanged() }
    }
    public var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    // MARK: - Configuration
    public var skipSilence: Bool = false {
        didSet {
            player.currentItem?.audioTimePitchAlgorithm = skipSilence ? .timeDomain : .spectral
        }
    }
    public var crossfadeDuration: TimeInterval = 0
    public var normalizeLoudness: Bool = true
    public var loudnessBaseGain: Float = 5.0

    // MARK: - Internal State
    private let player = AVQueuePlayer()
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    private var itemDidEndObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    private var originalQueue: [MediaMetadata] = []
    private var autoLoadMoreHandler: (() async -> [MediaMetadata])?
    private var resolveStreamURL: ((String) async throws -> URL)?

    // Sleep timer
    private var sleepTimerTask: Task<Void, Never>?
    public private(set) var sleepTimerEndDate: Date?

    // Crossfade support
    private var crossfadePlayer: AVPlayer?
    private var crossfadeTimer: Timer?

    public init() {
        configureAudioSession()
        setupTimeObserver()
        setupNotificationObservers()
    }

    deinit {
        teardown()
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            MetrolistLogger.playback.error("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Time Observer

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds.isNaN ? 0 : time.seconds

            // Crossfade trigger
            if self.crossfadeDuration > 0, self.duration > 0 {
                let remaining = self.duration - self.currentTime
                if remaining <= self.crossfadeDuration && remaining > 0 {
                    self.beginCrossfade()
                }
            }
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Track ended
        itemDidEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onTrackEnded()
            }
        }

        // Audio interruption (phone call, Siri, etc.)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // Route change (headphones disconnect)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    // MARK: - Public Playback Controls

    /// Set the stream URL resolver called when a track needs to start playing.
    public func setStreamResolver(_ resolver: @escaping (String) async throws -> URL) {
        self.resolveStreamURL = resolver
    }

    /// Set handler for loading more tracks when queue is nearly exhausted.
    public func setAutoLoadMoreHandler(_ handler: @escaping () async -> [MediaMetadata]) {
        self.autoLoadMoreHandler = handler
    }

    /// Play a list of tracks starting at the given index.
    public func playQueue(_ items: [MediaMetadata], startIndex: Int = 0) {
        guard !items.isEmpty, startIndex >= 0, startIndex < items.count else { return }
        self.originalQueue = items
        self.queue = shuffleEnabled ? items.shuffledKeeping(index: startIndex) : items
        self.currentIndex = shuffleEnabled ? 0 : startIndex
        playCurrentItem()
    }

    /// Add tracks to the end of the queue.
    public func addToQueue(_ items: [MediaMetadata]) {
        queue.append(contentsOf: items)
        originalQueue.append(contentsOf: items)
    }

    /// Insert a track after the current one.
    public func playNext(_ item: MediaMetadata) {
        let insertIndex = currentIndex + 1
        queue.insert(item, at: min(insertIndex, queue.count))
        originalQueue.insert(item, at: min(insertIndex, originalQueue.count))
    }

    public func play() {
        player.play()
        state = .playing
    }

    public func pause() {
        player.pause()
        state = .paused
    }

    public func togglePlayPause() {
        if state.isPlaying { pause() } else { play() }
    }

    public func seekTo(_ time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.currentTime = time
        }
    }

    public func skipToNext() {
        guard !queue.isEmpty else { return }
        let nextIndex: Int
        switch repeatMode {
        case .one:
            nextIndex = currentIndex
        case .queue:
            nextIndex = (currentIndex + 1) % queue.count
        case .off:
            nextIndex = currentIndex + 1
        }

        guard nextIndex < queue.count else {
            pause()
            seekTo(0)
            return
        }

        currentIndex = nextIndex
        playCurrentItem()
    }

    public func skipToPrevious() {
        // If more than 3 seconds in, restart the current track
        if currentTime > 3 {
            seekTo(0)
            return
        }
        guard currentIndex > 0 else {
            seekTo(0)
            return
        }
        currentIndex -= 1
        playCurrentItem()
    }

    public func skipToIndex(_ index: Int) {
        guard index >= 0, index < queue.count else { return }
        currentIndex = index
        playCurrentItem()
    }

    public func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            playCurrentItem()
        }
    }

    public func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        // Adjust currentIndex accordingly
        if let first = source.first {
            if first == currentIndex {
                currentIndex = destination > first ? destination - 1 : destination
            } else if first < currentIndex && destination > currentIndex {
                currentIndex -= 1
            } else if first > currentIndex && destination <= currentIndex {
                currentIndex += 1
            }
        }
    }

    // MARK: - Sleep Timer

    public func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        guard minutes > 0 else { return }
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            self?.pause()
            self?.sleepTimerEndDate = nil
        }
    }

    public func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndDate = nil
    }

    // MARK: - Queue Persistence

    /// Serialize current queue state for persistence across launches.
    public func persistedState() -> PersistPlayerState {
        PersistPlayerState(
            queue: queue,
            currentIndex: currentIndex,
            position: currentTime,
            repeatMode: repeatMode,
            shuffled: shuffleEnabled
        )
    }

    /// Restore queue from persisted state (does NOT auto-play).
    public func restoreState(_ state: PersistPlayerState) {
        self.queue = state.queue
        self.originalQueue = state.queue
        self.currentIndex = state.currentIndex
        self.repeatMode = state.repeatMode
        self.shuffleEnabled = state.shuffled
        if currentIndex >= 0, currentIndex < queue.count {
            self.currentItem = queue[currentIndex]
        }
    }

    // MARK: - Private Helpers

    private func playCurrentItem() {
        guard currentIndex >= 0, currentIndex < queue.count else {
            state = .idle
            currentItem = nil
            return
        }

        let metadata = queue[currentIndex]
        currentItem = metadata
        state = .loading
        duration = 0
        currentTime = 0

        player.removeAllItems()

        Task { @MainActor in
            do {
                guard let resolve = resolveStreamURL else {
                    state = .error("No stream resolver configured")
                    return
                }

                let streamURL = try await resolve(metadata.id)
                let asset = AVURLAsset(url: streamURL)
                let playerItem = AVPlayerItem(asset: asset)

                if skipSilence {
                    playerItem.audioTimePitchAlgorithm = .timeDomain
                }

                observePlayerItem(playerItem)
                player.replaceCurrentItem(with: playerItem)
                player.play()
                state = .playing

                // Auto-load more if near end of queue
                if currentIndex >= queue.count - 2 {
                    if let handler = autoLoadMoreHandler {
                        let more = await handler()
                        if !more.isEmpty {
                            addToQueue(more)
                        }
                    }
                }
            } catch {
                MetrolistLogger.playback.error("Failed to resolve stream: \(error)")
                state = .error(error.localizedDescription)
            }
        }
    }

    private func observePlayerItem(_ item: AVPlayerItem) {
        statusObservation?.invalidate()
        durationObservation?.invalidate()
        bufferObservation?.invalidate()

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                    if self.normalizeLoudness {
                        self.applyLoudnessNormalization(to: item)
                    }
                case .failed:
                    let message = item.error?.localizedDescription ?? "Unknown playback error"
                    self.state = .error(message)
                    MetrolistLogger.playback.error("AVPlayerItem failed: \(message)")
                default:
                    break
                }
            }
        }

        bufferObservation = item.observe(\AVPlayerItem.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let range = item.loadedTimeRanges.first?.timeRangeValue else { return }
                self?.bufferedTime = range.start.seconds + range.duration.seconds
            }
        }
    }

    private func applyLoudnessNormalization(to item: AVPlayerItem) {
        // AVAudioMix-based volume adjustment for loudness normalization
        guard let track = item.asset.tracks(withMediaType: .audio).first else { return }

        let params = AVMutableAudioMixInputParameters(track: track)
        let targetGain = pow(10, loudnessBaseGain / 20.0)
        params.setVolume(targetGain, at: .zero)

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [params]
        item.audioMix = audioMix
    }

    private func onTrackEnded() {
        switch repeatMode {
        case .one:
            seekTo(0)
            play()
        case .queue:
            currentIndex = (currentIndex + 1) % max(queue.count, 1)
            playCurrentItem()
        case .off:
            if currentIndex < queue.count - 1 {
                currentIndex += 1
                playCurrentItem()
            } else {
                state = .idle
            }
        }
    }

    private func onShuffleChanged() {
        guard !queue.isEmpty else { return }
        if shuffleEnabled {
            let current = currentItem
            queue.shuffle()
            if let current, let idx = queue.firstIndex(where: { $0.id == current.id }) {
                queue.swapAt(0, idx)
                currentIndex = 0
            }
        } else {
            let current = currentItem
            queue = originalQueue
            if let current {
                currentIndex = queue.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
    }

    // MARK: - Crossfade

    private func beginCrossfade() {
        guard crossfadePlayer == nil else { return }
        let nextIdx = (currentIndex + 1) % queue.count
        guard nextIdx != currentIndex, nextIdx < queue.count else { return }

        let nextItem = queue[nextIdx]
        Task { @MainActor in
            guard let resolve = resolveStreamURL else { return }
            do {
                let url = try await resolve(nextItem.id)
                let cfPlayer = AVPlayer(url: url)
                cfPlayer.volume = 0
                cfPlayer.play()
                self.crossfadePlayer = cfPlayer

                // Fade volumes over crossfadeDuration
                let steps = 20
                let stepDuration = crossfadeDuration / Double(steps)
                for i in 1...steps {
                    try? await Task.sleep(for: .seconds(stepDuration))
                    let progress = Float(i) / Float(steps)
                    self.player.volume = 1.0 - progress
                    cfPlayer.volume = progress
                }

                // Swap: crossfade player becomes the main player
                self.player.pause()
                self.currentIndex = nextIdx
                self.currentItem = nextItem
                self.crossfadePlayer = nil

                // Re-resolve for the main player
                let asset = AVURLAsset(url: url)
                let item = AVPlayerItem(asset: asset)
                self.player.replaceCurrentItem(with: item)
                self.player.volume = 1.0
                self.player.play()
                self.state = .playing
            } catch {
                MetrolistLogger.playback.error("Crossfade failed: \(error)")
            }
        }
    }

    // MARK: - Audio Route / Interruption

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            // Headphones were disconnected
            pause()
        }
    }

    // MARK: - Teardown

    private func teardown() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        statusObservation?.invalidate()
        durationObservation?.invalidate()
        bufferObservation?.invalidate()

        if let obs = itemDidEndObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = routeChangeObserver { NotificationCenter.default.removeObserver(obs) }

        cancelSleepTimer()
        player.pause()
    }
}

// MARK: - Helpers

private extension Array where Element == MediaMetadata {
    /// Shuffle keeping the element at `index` first.
    func shuffledKeeping(index: Int) -> [MediaMetadata] {
        guard indices.contains(index) else { return shuffled() }
        var copy = self
        let kept = copy.remove(at: index)
        copy.shuffle()
        copy.insert(kept, at: 0)
        return copy
    }
}
