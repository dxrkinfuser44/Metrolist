package com.metrolist.wear.data

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Wearable Data Layer service for syncing data between phone and watch
 * Implements standalone operation while enabling seamless data sync
 */
@Singleton
class WearableDataService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val dataClient: DataClient = Wearable.getDataClient(context)
    private val messageClient: MessageClient = Wearable.getMessageClient(context)
    private val capabilityClient: CapabilityClient = Wearable.getCapabilityClient(context)
    
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    
    private val _syncedPlaylists = MutableStateFlow<List<SyncedPlaylist>>(emptyList())
    val syncedPlaylists: StateFlow<List<SyncedPlaylist>> = _syncedPlaylists.asStateFlow()
    
    private val _syncedFavorites = MutableStateFlow<List<SyncedSong>>(emptyList())
    val syncedFavorites: StateFlow<List<SyncedSong>> = _syncedFavorites.asStateFlow()
    
    private val _isPhoneConnected = MutableStateFlow(false)
    val isPhoneConnected: StateFlow<Boolean> = _isPhoneConnected.asStateFlow()
    
    companion object {
        private const val TAG = "WearableDataService"
        
        // Data paths
        private const val PATH_PLAYLISTS = "/metrolist/playlists"
        private const val PATH_FAVORITES = "/metrolist/favorites"
        private const val PATH_SETTINGS = "/metrolist/settings"
        
        // Message paths
        private const val PATH_REQUEST_SYNC = "/metrolist/request_sync"
        private const val PATH_PLAYBACK_COMMAND = "/metrolist/playback_command"
        
        // Capability for phone app
        private const val CAPABILITY_PHONE_APP = "metrolist_phone_app"
    }
    
    init {
        setupDataListeners()
        setupCapabilityListener() // Add dynamic connectivity monitoring
        checkPhoneConnectivity()
    }
    
    /**
     * Setup dynamic capability listener for real-time connectivity updates
     */
    private fun setupCapabilityListener() {
        capabilityClient.addListener(
            { capabilityInfo ->
                val isConnected = capabilityInfo.nodes.isNotEmpty()
                _isPhoneConnected.value = isConnected
                
                if (isConnected) {
                    Log.d(TAG, "Phone connected: ${capabilityInfo.nodes.size} node(s)")
                    requestInitialSync()
                } else {
                    Log.d(TAG, "Phone disconnected")
                }
            },
            CAPABILITY_PHONE_APP
        )
    }
    
    /**
     * Setup listeners for data changes from phone
     */
    private fun setupDataListeners() {
        dataClient.addListener { dataEventBuffer ->
            dataEventBuffer.forEach { event ->
                when (event.type) {
                    DataEvent.TYPE_CHANGED -> {
                        event.dataItem.also { item ->
                            when (item.uri.path) {
                                PATH_PLAYLISTS -> handlePlaylistsUpdate(item)
                                PATH_FAVORITES -> handleFavoritesUpdate(item)
                                PATH_SETTINGS -> handleSettingsUpdate(item)
                            }
                        }
                    }
                    DataEvent.TYPE_DELETED -> {
                        Log.d(TAG, "Data deleted: ${event.dataItem.uri.path}")
                    }
                }
            }
            dataEventBuffer.release()
        }
    }
    
    /**
     * Check if phone app is connected
     */
    private fun checkPhoneConnectivity() {
        scope.launch {
            try {
                val nodes = capabilityClient.getCapability(
                    CAPABILITY_PHONE_APP,
                    CapabilityClient.FILTER_REACHABLE
                ).await()
                
                _isPhoneConnected.value = nodes.nodes.isNotEmpty()
                
                if (nodes.nodes.isNotEmpty()) {
                    Log.d(TAG, "Phone connected: ${nodes.nodes.size} node(s)")
                    requestInitialSync()
                } else {
                    Log.d(TAG, "No phone connected")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking phone connectivity", e)
                _isPhoneConnected.value = false
            }
        }
    }
    
    /**
     * Request initial data sync from phone
     */
    private fun requestInitialSync() {
        scope.launch {
            try {
                val nodes = capabilityClient.getCapability(
                    CAPABILITY_PHONE_APP,
                    CapabilityClient.FILTER_REACHABLE
                ).await()
                
                nodes.nodes.firstOrNull()?.let { node ->
                    messageClient.sendMessage(
                        node.id,
                        PATH_REQUEST_SYNC,
                        ByteArray(0)
                    ).await()
                    Log.d(TAG, "Requested initial sync from phone")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting sync", e)
            }
        }
    }
    
    /**
     * Handle playlists update from phone
     */
    private fun handlePlaylistsUpdate(dataItem: DataItem) {
        try {
            val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
            val playlistsJson = dataMap.getString("playlists") ?: return
            
            val playlists = mutableListOf<SyncedPlaylist>()
            val jsonArray = JSONArray(playlistsJson)
            
            for (i in 0 until jsonArray.length()) {
                val json = jsonArray.getJSONObject(i)
                playlists.add(
                    SyncedPlaylist(
                        id = json.getString("id"),
                        name = json.getString("name"),
                        songCount = json.optInt("songCount", 0),
                        thumbnailUrl = json.optString("thumbnailUrl")
                    )
                )
            }
            
            _syncedPlaylists.value = playlists
            Log.d(TAG, "Updated playlists: ${playlists.size} playlists")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing playlists", e)
        }
    }
    
    /**
     * Handle favorites update from phone
     */
    private fun handleFavoritesUpdate(dataItem: DataItem) {
        try {
            val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
            val favoritesJson = dataMap.getString("favorites") ?: return
            
            val favorites = mutableListOf<SyncedSong>()
            val jsonArray = JSONArray(favoritesJson)
            
            for (i in 0 until jsonArray.length()) {
                val json = jsonArray.getJSONObject(i)
                favorites.add(
                    SyncedSong(
                        id = json.getString("id"),
                        title = json.getString("title"),
                        artist = json.optString("artist"),
                        thumbnailUrl = json.optString("thumbnailUrl")
                    )
                )
            }
            
            _syncedFavorites.value = favorites
            Log.d(TAG, "Updated favorites: ${favorites.size} songs")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing favorites", e)
        }
    }
    
    /**
     * Handle settings update from phone
     */
    private fun handleSettingsUpdate(dataItem: DataItem) {
        try {
            val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
            // Handle settings sync if needed
            Log.d(TAG, "Settings updated from phone")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing settings", e)
        }
    }
    
    /**
     * Send playback command to phone
     */
    fun sendPlaybackCommand(command: PlaybackCommand) {
        scope.launch {
            try {
                val nodes = capabilityClient.getCapability(
                    CAPABILITY_PHONE_APP,
                    CapabilityClient.FILTER_REACHABLE
                ).await()
                
                nodes.nodes.firstOrNull()?.let { node ->
                    val commandJson = JSONObject().apply {
                        put("action", command.action)
                        command.songId?.let { put("songId", it) }
                    }.toString()
                    
                    messageClient.sendMessage(
                        node.id,
                        PATH_PLAYBACK_COMMAND,
                        commandJson.toByteArray()
                    ).await()
                    
                    Log.d(TAG, "Sent playback command: ${command.action}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending playback command", e)
            }
        }
    }
}

/**
 * Synced playlist data from phone
 */
data class SyncedPlaylist(
    val id: String,
    val name: String,
    val songCount: Int,
    val thumbnailUrl: String?
)

/**
 * Synced song data from phone
 */
data class SyncedSong(
    val id: String,
    val title: String,
    val artist: String?,
    val thumbnailUrl: String?
)

/**
 * Playback command to send to phone
 */
data class PlaybackCommand(
    val action: String,
    val songId: String? = null
) {
    companion object {
        const val ACTION_PLAY = "play"
        const val ACTION_PAUSE = "pause"
        const val ACTION_NEXT = "next"
        const val ACTION_PREVIOUS = "previous"
        const val ACTION_PLAY_SONG = "play_song"
    }
}
