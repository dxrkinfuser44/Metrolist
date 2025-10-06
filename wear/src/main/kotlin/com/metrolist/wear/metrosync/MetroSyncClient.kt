package com.metrolist.wear.metrosync

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.Socket
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Simplified data models for Wear OS client
 */
data class WearPlaybackState(
    val isPlaying: Boolean = false,
    val currentSong: WearSongInfo? = null,
)

data class WearSongInfo(
    val id: String,
    val title: String,
    val artist: String,
)

data class WearDeviceInfo(
    val deviceId: String,
    val deviceName: String,
)

/**
 * MetroSync client for Wear OS
 */
@Singleton
class MetroSyncClient @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val nsdManager: NsdManager by lazy {
        context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }
    
    private var socket: Socket? = null
    private var connectedDeviceId: String? = null
    
    private val _playbackState = MutableStateFlow(WearPlaybackState())
    val playbackState: StateFlow<WearPlaybackState> = _playbackState.asStateFlow()
    
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()
    
    private val _discoveredDevices = MutableStateFlow<List<WearDeviceInfo>>(emptyList())
    val discoveredDevices: StateFlow<List<WearDeviceInfo>> = _discoveredDevices.asStateFlow()
    
    companion object {
        private const val TAG = "MetroSyncClient"
        private const val SERVICE_TYPE = "_metrosync._tcp."
        private const val BUFFER_SIZE = 8192
    }

    /**
     * Start discovering MetroSync devices
     */
    fun startDiscovery() {
        val discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "Discovery started")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service found: ${serviceInfo.serviceName}")
                
                nsdManager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                        Log.e(TAG, "Resolve failed: $errorCode")
                    }

                    override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                        Log.d(TAG, "Service resolved: ${serviceInfo.serviceName}")
                        
                        val device = WearDeviceInfo(
                            deviceId = "${serviceInfo.host.hostAddress}:${serviceInfo.port}",
                            deviceName = serviceInfo.serviceName
                        )
                        
                        val currentList = _discoveredDevices.value.toMutableList()
                        if (currentList.none { it.deviceId == device.deviceId }) {
                            currentList.add(device)
                            _discoveredDevices.value = currentList
                        }
                    }
                })
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service lost: ${serviceInfo.serviceName}")
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "Discovery stopped")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery stop failed: $errorCode")
            }
        }

        try {
            nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start discovery", e)
        }
    }

    /**
     * Connect to a device
     */
    fun connectToDevice(deviceId: String) {
        scope.launch {
            try {
                val parts = deviceId.split(":")
                if (parts.size != 2) return@launch
                
                val host = parts[0]
                val port = parts[1].toInt()
                
                socket = Socket(host, port)
                connectedDeviceId = deviceId
                _isConnected.value = true
                
                Log.d(TAG, "Connected to device: $deviceId")
                
                // Start listening for messages
                listenForMessages()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect to device", e)
                _isConnected.value = false
            }
        }
    }

    /**
     * Disconnect from device
     */
    fun disconnect() {
        socket?.close()
        socket = null
        connectedDeviceId = null
        _isConnected.value = false
        _playbackState.value = WearPlaybackState()
    }

    /**
     * Send play command
     */
    fun play() {
        sendCommand("PLAY")
    }

    /**
     * Send pause command
     */
    fun pause() {
        sendCommand("PAUSE")
    }

    /**
     * Send next command
     */
    fun next() {
        sendCommand("NEXT")
    }

    /**
     * Send previous command
     */
    fun previous() {
        sendCommand("PREVIOUS")
    }

    /**
     * Listen for messages from connected device
     */
    private fun listenForMessages() {
        scope.launch {
            try {
                val reader = BufferedReader(InputStreamReader(socket?.getInputStream()))
                val buffer = CharArray(BUFFER_SIZE)
                
                while (_isConnected.value && socket?.isConnected == true) {
                    val length = reader.read(buffer)
                    if (length > 0) {
                        val message = String(buffer, 0, length)
                        handleMessage(message)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading from socket", e)
                _isConnected.value = false
            }
        }
    }

    /**
     * Handle incoming message
     */
    private fun handleMessage(message: String) {
        try {
            // Simple message parsing for demo
            if (message.contains("\"PlaybackState\"")) {
                // Parse playback state
                val isPlaying = message.contains("\"isPlaying\":true")
                val titleMatch = Regex("\"title\":\"([^\"]+)\"").find(message)
                val artistMatch = Regex("\"artist\":\"([^\"]+)\"").find(message)
                
                _playbackState.value = WearPlaybackState(
                    isPlaying = isPlaying,
                    currentSong = if (titleMatch != null) {
                        WearSongInfo(
                            id = "",
                            title = titleMatch.groupValues[1],
                            artist = artistMatch?.groupValues?.getOrNull(1) ?: ""
                        )
                    } else null
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing message", e)
        }
    }

    /**
     * Send a command to the connected device
     */
    private fun sendCommand(action: String) {
        scope.launch {
            try {
                val writer = PrintWriter(socket?.getOutputStream(), true)
                val command = """{"PlaybackCommand":{"action":"$action","timestamp":${System.currentTimeMillis()}}}"""
                writer.println(command)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending command", e)
            }
        }
    }
}
