package com.metrolist.wear.playback

import android.app.PendingIntent
import android.content.Intent
import android.os.Binder
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.metrolist.wear.MainActivity
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * Standalone music playback service for Wear OS
 * Allows the watch to play music independently without phone connection
 */
@AndroidEntryPoint
class WearMusicService : MediaSessionService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var player: ExoPlayer
    private lateinit var mediaSession: MediaSession
    private val binder = MusicBinder()

    override fun onCreate() {
        super.onCreate()
        
        // Create ExoPlayer for Wear OS
        player = ExoPlayer.Builder(this)
            .build()
            .apply {
                prepare()
            }

        // Create MediaSession
        mediaSession = MediaSession.Builder(this, player)
            .setSessionActivity(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession {
        return mediaSession
    }

    override fun onBind(intent: Intent?) = super.onBind(intent) ?: binder

    override fun onDestroy() {
        mediaSession.release()
        player.release()
        super.onDestroy()
    }

    inner class MusicBinder : Binder() {
        val service: WearMusicService
            get() = this@WearMusicService
        
        val player: Player
            get() = this@WearMusicService.player
    }

    /**
     * Play a media item
     */
    fun playMediaItem(mediaItem: MediaItem) {
        player.setMediaItem(mediaItem)
        player.prepare()
        player.play()
    }

    /**
     * Add media item to queue
     */
    fun addToQueue(mediaItem: MediaItem) {
        player.addMediaItem(mediaItem)
    }
}
