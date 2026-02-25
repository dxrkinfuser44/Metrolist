import Foundation
import Combine

// MARK: - User Preferences

/// Central preferences store equivalent to Android's DataStore.
/// Uses @AppStorage-compatible UserDefaults under the hood, organized by category.
/// Publishes changes via Combine for reactive UI updates.
public final class UserPreferences: ObservableObject {
    public static let shared = UserPreferences()

    private let defaults: UserDefaults
    private static let suiteName = "com.metrolist.music.preferences"

    public init() {
        self.defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.audioQuality: AudioQuality.auto.rawValue,
            Keys.persistentQueue: true,
            Keys.skipSilence: false,
            Keys.normalizeLoudness: true,
            Keys.autoLoadMore: true,
            Keys.autoSkipNextOnError: false,
            Keys.stopMusicOnTaskClear: false,
            Keys.enableLoudnessNormalization: true,
            Keys.loudnessBaseGain: 5.0,
            Keys.crossfadeDuration: 0.0,
            Keys.pauseOnHeadphonesDisconnect: true,
            Keys.sleepTimerMinutes: -1,

            Keys.darkMode: DarkMode.system.rawValue,
            Keys.dynamicTheme: true,
            Keys.enableSquigglySlider: true,
            Keys.swipeThumbnailToShowLyricsOrQueue: true,
            Keys.showLikeAndDislikeButtons: true,
            Keys.playerBackgroundStyle: "DEFAULT",
            Keys.showNavigationLabels: true,
            Keys.liquidGlassEnabled: true,

            Keys.enableLyrics: true,
            Keys.lyricsTextPosition: "CENTER",
            Keys.lyricsClickChange: false,
            Keys.enableKugou: true,
            Keys.preferSyncedLyrics: true,
            Keys.romanizeLyrics: false,

            Keys.proxyEnabled: false,
            Keys.proxyType: "HTTP",
            Keys.proxyUrl: "",

            Keys.enableLastFm: false,
            Keys.lastFmUsername: "",
            Keys.lastFmSessionKey: "",
            Keys.scrobbleEnabled: false,

            Keys.enableDiscordRPC: false,
            Keys.listenTogetherEnabled: false,

            Keys.autoBackup: false,
            Keys.autoBackupInterval: 24,

            Keys.contentLanguage: "en",
            Keys.contentCountry: "US",
        ])
    }

    // MARK: - Keys

    private enum Keys {
        // Playback
        static let audioQuality = "audioQuality"
        static let persistentQueue = "persistentQueue"
        static let skipSilence = "skipSilence"
        static let normalizeLoudness = "normalizeLoudness"
        static let autoLoadMore = "autoLoadMore"
        static let autoSkipNextOnError = "autoSkipNextOnError"
        static let stopMusicOnTaskClear = "stopMusicOnTaskClear"
        static let enableLoudnessNormalization = "enableLoudnessNormalization"
        static let loudnessBaseGain = "loudnessBaseGain"
        static let crossfadeDuration = "crossfadeDuration"
        static let pauseOnHeadphonesDisconnect = "pauseOnHeadphonesDisconnect"
        static let sleepTimerMinutes = "sleepTimerMinutes"

        // UI
        static let darkMode = "darkMode"
        static let dynamicTheme = "dynamicTheme"
        static let enableSquigglySlider = "enableSquigglySlider"
        static let swipeThumbnailToShowLyricsOrQueue = "swipeThumbnailToShowLyricsOrQueue"
        static let showLikeAndDislikeButtons = "showLikeAndDislikeButtons"
        static let playerBackgroundStyle = "playerBackgroundStyle"
        static let showNavigationLabels = "showNavigationLabels"
        static let liquidGlassEnabled = "liquidGlassEnabled"

        // Lyrics
        static let enableLyrics = "enableLyrics"
        static let lyricsTextPosition = "lyricsTextPosition"
        static let lyricsClickChange = "lyricsClickChange"
        static let enableKugou = "enableKugou"
        static let preferSyncedLyrics = "preferSyncedLyrics"
        static let romanizeLyrics = "romanizeLyrics"

        // Proxy
        static let proxyEnabled = "proxyEnabled"
        static let proxyType = "proxyType"
        static let proxyUrl = "proxyUrl"

        // Last.fm
        static let enableLastFm = "enableLastFm"
        static let lastFmUsername = "lastFmUsername"
        static let lastFmSessionKey = "lastFmSessionKey"
        static let scrobbleEnabled = "scrobbleEnabled"

        // Social
        static let enableDiscordRPC = "enableDiscordRPC"
        static let listenTogetherEnabled = "listenTogetherEnabled"

        // Backup
        static let autoBackup = "autoBackup"
        static let autoBackupInterval = "autoBackupInterval"

        // Locale
        static let contentLanguage = "contentLanguage"
        static let contentCountry = "contentCountry"

        // Auth
        static let innerTubeVisitorData = "innerTubeVisitorData"
        static let innerTubeCookie = "innerTubeCookie"
        static let accountName = "accountName"
        static let accountEmail = "accountEmail"
        static let accountChannelHandle = "accountChannelHandle"
    }

    // MARK: - Playback Settings

    @Published public var audioQuality: AudioQuality {
        didSet { defaults.set(audioQuality.rawValue, forKey: Keys.audioQuality) }
    }

    @Published public var persistentQueue: Bool {
        didSet { defaults.set(persistentQueue, forKey: Keys.persistentQueue) }
    }

    @Published public var skipSilence: Bool {
        didSet { defaults.set(skipSilence, forKey: Keys.skipSilence) }
    }

    @Published public var normalizeLoudness: Bool {
        didSet { defaults.set(normalizeLoudness, forKey: Keys.normalizeLoudness) }
    }

    @Published public var autoLoadMore: Bool {
        didSet { defaults.set(autoLoadMore, forKey: Keys.autoLoadMore) }
    }

    @Published public var autoSkipNextOnError: Bool {
        didSet { defaults.set(autoSkipNextOnError, forKey: Keys.autoSkipNextOnError) }
    }

    @Published public var enableLoudnessNormalization: Bool {
        didSet { defaults.set(enableLoudnessNormalization, forKey: Keys.enableLoudnessNormalization) }
    }

    @Published public var loudnessBaseGain: Double {
        didSet { defaults.set(loudnessBaseGain, forKey: Keys.loudnessBaseGain) }
    }

    @Published public var crossfadeDuration: Double {
        didSet { defaults.set(crossfadeDuration, forKey: Keys.crossfadeDuration) }
    }

    @Published public var pauseOnHeadphonesDisconnect: Bool {
        didSet { defaults.set(pauseOnHeadphonesDisconnect, forKey: Keys.pauseOnHeadphonesDisconnect) }
    }

    @Published public var sleepTimerMinutes: Int {
        didSet { defaults.set(sleepTimerMinutes, forKey: Keys.sleepTimerMinutes) }
    }

    // MARK: - UI Settings

    @Published public var darkMode: DarkMode {
        didSet { defaults.set(darkMode.rawValue, forKey: Keys.darkMode) }
    }

    @Published public var dynamicTheme: Bool {
        didSet { defaults.set(dynamicTheme, forKey: Keys.dynamicTheme) }
    }

    @Published public var enableSquigglySlider: Bool {
        didSet { defaults.set(enableSquigglySlider, forKey: Keys.enableSquigglySlider) }
    }

    @Published public var swipeThumbnailToShowLyricsOrQueue: Bool {
        didSet { defaults.set(swipeThumbnailToShowLyricsOrQueue, forKey: Keys.swipeThumbnailToShowLyricsOrQueue) }
    }

    @Published public var showLikeAndDislikeButtons: Bool {
        didSet { defaults.set(showLikeAndDislikeButtons, forKey: Keys.showLikeAndDislikeButtons) }
    }

    @Published public var playerBackgroundStyle: String {
        didSet { defaults.set(playerBackgroundStyle, forKey: Keys.playerBackgroundStyle) }
    }

    @Published public var showNavigationLabels: Bool {
        didSet { defaults.set(showNavigationLabels, forKey: Keys.showNavigationLabels) }
    }

    @Published public var liquidGlassEnabled: Bool {
        didSet { defaults.set(liquidGlassEnabled, forKey: Keys.liquidGlassEnabled) }
    }

    // MARK: - Lyrics Settings

    @Published public var enableLyrics: Bool {
        didSet { defaults.set(enableLyrics, forKey: Keys.enableLyrics) }
    }

    @Published public var preferSyncedLyrics: Bool {
        didSet { defaults.set(preferSyncedLyrics, forKey: Keys.preferSyncedLyrics) }
    }

    @Published public var enableKugou: Bool {
        didSet { defaults.set(enableKugou, forKey: Keys.enableKugou) }
    }

    @Published public var romanizeLyrics: Bool {
        didSet { defaults.set(romanizeLyrics, forKey: Keys.romanizeLyrics) }
    }

    // MARK: - Proxy Settings

    @Published public var proxyEnabled: Bool {
        didSet { defaults.set(proxyEnabled, forKey: Keys.proxyEnabled) }
    }

    @Published public var proxyUrl: String {
        didSet { defaults.set(proxyUrl, forKey: Keys.proxyUrl) }
    }

    // MARK: - Last.fm Settings

    @Published public var enableLastFm: Bool {
        didSet { defaults.set(enableLastFm, forKey: Keys.enableLastFm) }
    }

    @Published public var lastFmUsername: String {
        didSet { defaults.set(lastFmUsername, forKey: Keys.lastFmUsername) }
    }

    @Published public var lastFmSessionKey: String {
        didSet { defaults.set(lastFmSessionKey, forKey: Keys.lastFmSessionKey) }
    }

    @Published public var scrobbleEnabled: Bool {
        didSet { defaults.set(scrobbleEnabled, forKey: Keys.scrobbleEnabled) }
    }

    // MARK: - Social Settings

    @Published public var enableDiscordRPC: Bool {
        didSet { defaults.set(enableDiscordRPC, forKey: Keys.enableDiscordRPC) }
    }

    @Published public var listenTogetherEnabled: Bool {
        didSet { defaults.set(listenTogetherEnabled, forKey: Keys.listenTogetherEnabled) }
    }

    // MARK: - Locale Settings

    @Published public var contentLanguage: String {
        didSet { defaults.set(contentLanguage, forKey: Keys.contentLanguage) }
    }

    @Published public var contentCountry: String {
        didSet { defaults.set(contentCountry, forKey: Keys.contentCountry) }
    }

    // MARK: - Auth

    public var innerTubeVisitorData: String? {
        get { defaults.string(forKey: Keys.innerTubeVisitorData) }
        set { defaults.set(newValue, forKey: Keys.innerTubeVisitorData) }
    }

    public var innerTubeCookie: String? {
        get { defaults.string(forKey: Keys.innerTubeCookie) }
        set { defaults.set(newValue, forKey: Keys.innerTubeCookie) }
    }

    public var accountName: String? {
        get { defaults.string(forKey: Keys.accountName) }
        set { defaults.set(newValue, forKey: Keys.accountName) }
    }

    public var accountEmail: String? {
        get { defaults.string(forKey: Keys.accountEmail) }
        set { defaults.set(newValue, forKey: Keys.accountEmail) }
    }

    public var accountChannelHandle: String? {
        get { defaults.string(forKey: Keys.accountChannelHandle) }
        set { defaults.set(newValue, forKey: Keys.accountChannelHandle) }
    }

    // MARK: - Helpers

    /// Whether the user is signed in to YouTube Music.
    public var isLoggedIn: Bool {
        innerTubeCookie?.isEmpty == false
    }

    /// Reset all preferences to defaults.
    public func resetAll() {
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleId)
        }
        registerDefaults()
    }

    /// Load stored values on init. Called after `registerDefaults()`.
    private func loadStoredValues() {
        audioQuality = AudioQuality(rawValue: defaults.string(forKey: Keys.audioQuality) ?? "") ?? .auto
        persistentQueue = defaults.bool(forKey: Keys.persistentQueue)
        skipSilence = defaults.bool(forKey: Keys.skipSilence)
        normalizeLoudness = defaults.bool(forKey: Keys.normalizeLoudness)
        autoLoadMore = defaults.bool(forKey: Keys.autoLoadMore)
        autoSkipNextOnError = defaults.bool(forKey: Keys.autoSkipNextOnError)
        enableLoudnessNormalization = defaults.bool(forKey: Keys.enableLoudnessNormalization)
        loudnessBaseGain = defaults.double(forKey: Keys.loudnessBaseGain)
        crossfadeDuration = defaults.double(forKey: Keys.crossfadeDuration)
        pauseOnHeadphonesDisconnect = defaults.bool(forKey: Keys.pauseOnHeadphonesDisconnect)
        sleepTimerMinutes = defaults.integer(forKey: Keys.sleepTimerMinutes)

        darkMode = DarkMode(rawValue: defaults.string(forKey: Keys.darkMode) ?? "") ?? .system
        dynamicTheme = defaults.bool(forKey: Keys.dynamicTheme)
        enableSquigglySlider = defaults.bool(forKey: Keys.enableSquigglySlider)
        swipeThumbnailToShowLyricsOrQueue = defaults.bool(forKey: Keys.swipeThumbnailToShowLyricsOrQueue)
        showLikeAndDislikeButtons = defaults.bool(forKey: Keys.showLikeAndDislikeButtons)
        playerBackgroundStyle = defaults.string(forKey: Keys.playerBackgroundStyle) ?? "DEFAULT"
        showNavigationLabels = defaults.bool(forKey: Keys.showNavigationLabels)
        liquidGlassEnabled = defaults.bool(forKey: Keys.liquidGlassEnabled)

        enableLyrics = defaults.bool(forKey: Keys.enableLyrics)
        preferSyncedLyrics = defaults.bool(forKey: Keys.preferSyncedLyrics)
        enableKugou = defaults.bool(forKey: Keys.enableKugou)
        romanizeLyrics = defaults.bool(forKey: Keys.romanizeLyrics)

        proxyEnabled = defaults.bool(forKey: Keys.proxyEnabled)
        proxyUrl = defaults.string(forKey: Keys.proxyUrl) ?? ""

        enableLastFm = defaults.bool(forKey: Keys.enableLastFm)
        lastFmUsername = defaults.string(forKey: Keys.lastFmUsername) ?? ""
        lastFmSessionKey = defaults.string(forKey: Keys.lastFmSessionKey) ?? ""
        scrobbleEnabled = defaults.bool(forKey: Keys.scrobbleEnabled)

        enableDiscordRPC = defaults.bool(forKey: Keys.enableDiscordRPC)
        listenTogetherEnabled = defaults.bool(forKey: Keys.listenTogetherEnabled)

        contentLanguage = defaults.string(forKey: Keys.contentLanguage) ?? "en"
        contentCountry = defaults.string(forKey: Keys.contentCountry) ?? "US"
    }
}
