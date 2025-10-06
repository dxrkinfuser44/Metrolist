package com.metrolist.music.metrosync.models

import kotlinx.serialization.Serializable

/**
 * Base message type for MetroSync protocol
 */
@Serializable
sealed class MetroSyncMessage {
    abstract val timestamp: Long
    abstract val deviceId: String
}

/**
 * Device discovery announcement
 */
@Serializable
data class DeviceAnnouncement(
    override val deviceId: String,
    override val timestamp: Long = System.currentTimeMillis(),
    val deviceName: String,
    val deviceType: DeviceType,
    val capabilities: List<DeviceCapability>,
) : MetroSyncMessage()

/**
 * Device types supported by MetroSync
 */
@Serializable
enum class DeviceType {
    PHONE,
    TABLET,
    WEAR_OS,
    DESKTOP,
    OTHER
}

/**
 * Capabilities that a device can support
 */
@Serializable
enum class DeviceCapability {
    PLAYBACK_CONTROL,
    QUEUE_MANAGEMENT,
    LIBRARY_SYNC,
    OFFLINE_MODE,
    VOLUME_CONTROL,
    LYRICS_DISPLAY
}

/**
 * Playback state synchronization
 */
@Serializable
data class PlaybackState(
    override val deviceId: String,
    override val timestamp: Long = System.currentTimeMillis(),
    val isPlaying: Boolean,
    val position: Long,
    val duration: Long,
    val currentSong: SongInfo?,
    val repeatMode: Int,
    val shuffleEnabled: Boolean,
    val volume: Float,
) : MetroSyncMessage()

/**
 * Song information
 */
@Serializable
data class SongInfo(
    val id: String,
    val title: String,
    val artist: String,
    val album: String?,
    val thumbnailUrl: String?,
    val duration: Long,
)

/**
 * Playback control command
 */
@Serializable
data class PlaybackCommand(
    override val deviceId: String,
    override val timestamp: Long = System.currentTimeMillis(),
    val action: PlaybackAction,
    val value: String? = null,
) : MetroSyncMessage()

/**
 * Playback actions
 */
@Serializable
enum class PlaybackAction {
    PLAY,
    PAUSE,
    NEXT,
    PREVIOUS,
    SEEK,
    SET_VOLUME,
    TOGGLE_SHUFFLE,
    TOGGLE_REPEAT,
    PLAY_SONG
}

/**
 * Queue synchronization
 */
@Serializable
data class QueueSync(
    override val deviceId: String,
    override val timestamp: Long = System.currentTimeMillis(),
    val queue: List<SongInfo>,
    val currentIndex: Int,
) : MetroSyncMessage()

/**
 * Device connection status
 */
@Serializable
data class ConnectionStatus(
    override val deviceId: String,
    override val timestamp: Long = System.currentTimeMillis(),
    val status: ConnectionState,
    val message: String? = null,
) : MetroSyncMessage()

/**
 * Connection states
 */
@Serializable
enum class ConnectionState {
    CONNECTED,
    DISCONNECTED,
    RECONNECTING,
    ERROR
}
