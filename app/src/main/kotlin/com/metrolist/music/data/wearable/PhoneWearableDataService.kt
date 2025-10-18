package com.metrolist.music.data.wearable

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.*
import com.metrolist.music.db.MusicDatabase
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Phone-side wearable data service for syncing to watch
 */
@Singleton
class PhoneWearableDataService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val database: MusicDatabase
) {
    private val dataClient: DataClient = Wearable.getDataClient(context)
    private val messageClient: MessageClient = Wearable.getMessageClient(context)
    
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    
    companion object {
        private const val TAG = "PhoneWearableDataService"
        
        // Data paths
        private const val PATH_PLAYLISTS = "/metrolist/playlists"
        private const val PATH_FAVORITES = "/metrolist/favorites"
        private const val PATH_SETTINGS = "/metrolist/settings"
        
        // Message paths
        private const val PATH_REQUEST_SYNC = "/metrolist/request_sync"
        private const val PATH_PLAYBACK_COMMAND = "/metrolist/playback_command"
    }
    
    init {
        setupMessageListener()
    }
    
    /**
     * Setup message listener for watch requests
     */
    private fun setupMessageListener() {
        messageClient.addListener { messageEvent ->
            when (messageEvent.path) {
                PATH_REQUEST_SYNC -> {
                    Log.d(TAG, "Received sync request from watch")
                    syncAllDataToWatch()
                }
                PATH_PLAYBACK_COMMAND -> {
                    handlePlaybackCommand(messageEvent.data)
                }
            }
        }
    }
    
    /**
     * Sync all user data to watch
     */
    fun syncAllDataToWatch() {
        scope.launch {
            syncPlaylists()
            syncFavorites()
            syncSettings()
        }
    }
    
    /**
     * Sync playlists to watch
     */
    private suspend fun syncPlaylists() {
        try {
            val playlists = database.playlistDao().getAll()
            val jsonArray = JSONArray()
            
            playlists.take(20).forEach { playlist -> // Limit to 20 for watch storage
                val json = JSONObject().apply {
                    put("id", playlist.id)
                    put("name", playlist.playlist.name)
                    put("songCount", playlist.songCount)
                    playlist.thumbnails.firstOrNull()?.let {
                        put("thumbnailUrl", it)
                    }
                }
                jsonArray.put(json)
            }
            
            val putDataReq = PutDataMapRequest.create(PATH_PLAYLISTS).apply {
                dataMap.putString("playlists", jsonArray.toString())
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }.asPutDataRequest()
            
            putDataReq.setUrgent() // High priority sync
            
            dataClient.putDataItem(putDataReq).await()
            Log.d(TAG, "Synced ${playlists.size} playlists to watch")
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing playlists", e)
        }
    }
    
    /**
     * Sync favorite songs to watch
     */
    private suspend fun syncFavorites() {
        try {
            val favorites = database.songDao().getFavoriteSongs()
            val jsonArray = JSONArray()
            
            favorites.take(50).forEach { song -> // Limit to 50 for watch storage
                val json = JSONObject().apply {
                    put("id", song.id)
                    put("title", song.title)
                    put("artist", song.artistsText)
                    song.thumbnailUrl?.let {
                        put("thumbnailUrl", it)
                    }
                }
                jsonArray.put(json)
            }
            
            val putDataReq = PutDataMapRequest.create(PATH_FAVORITES).apply {
                dataMap.putString("favorites", jsonArray.toString())
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }.asPutDataRequest()
            
            putDataReq.setUrgent()
            
            dataClient.putDataItem(putDataReq).await()
            Log.d(TAG, "Synced ${favorites.size} favorites to watch")
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing favorites", e)
        }
    }
    
    /**
     * Sync settings to watch
     */
    private suspend fun syncSettings() {
        try {
            // Sync relevant settings to watch
            val putDataReq = PutDataMapRequest.create(PATH_SETTINGS).apply {
                dataMap.putLong("timestamp", System.currentTimeMillis())
                // Add settings here as needed
            }.asPutDataRequest()
            
            dataClient.putDataItem(putDataReq).await()
            Log.d(TAG, "Synced settings to watch")
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing settings", e)
        }
    }
    
    /**
     * Handle playback command from watch
     */
    private fun handlePlaybackCommand(data: ByteArray) {
        try {
            val commandJson = JSONObject(String(data))
            val action = commandJson.getString("action")
            val songId = commandJson.optString("songId")
            
            Log.d(TAG, "Received playback command: $action")
            
            // Handle playback command
            // This would integrate with your existing MusicService
            // For now, just log it
        } catch (e: Exception) {
            Log.e(TAG, "Error handling playback command", e)
        }
    }
}
