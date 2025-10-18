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
    val host: String,
    val port: Int
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
                        
                        val host = serviceInfo.host.hostAddress ?: return
                        val port = serviceInfo.port
                        
                        val device = WearDeviceInfo(
                            deviceId = "${serviceInfo.serviceName}_${host}_$port",
                            deviceName = serviceInfo.serviceName,
                            host = host,
                            port = port
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
            nsdManager.discoverServices(MetroSyncConstants.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start discovery", e)
        }
    }

    /**
     * Connect to a device using deviceId from discovered devices
     */
    fun connectToDevice(deviceId: String) {
        val device = _discoveredDevices.value.find { it.deviceId == deviceId }
        if (device != null) {
            connectToDevice(device.host, device.port, deviceId)
        } else {
            Log.e(TAG, "Device not found: $deviceId")
        }
    }
    
    /**
     * Connect to a device with host and port
     */
    private fun connectToDevice(host: String, port: Int, deviceId: String) {
        scope.launch {
            try {
                socket = Socket(host, port)
                connectedDeviceId = deviceId
                _isConnected.value = true
                
                Log.d(TAG, "Connected to device: $deviceId at $host:$port")
                
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
     * Listen for messages from connected device using length-prefix framing
     */
    private fun listenForMessages() {
        scope.launch {
            try {
                val reader = BufferedReader(InputStreamReader(socket?.getInputStream()))
                
                while (_isConnected.value && socket?.isConnected == true) {
                    // Read message length (first line)
                    val lengthStr = reader.readLine() ?: break
                    val messageLength = lengthStr.toIntOrNull() ?: continue
                    
                    // Read exact message content
                    val buffer = CharArray(messageLength)
                    var totalRead = 0
                    while (totalRead < messageLength) {
                        val read = reader.read(buffer, totalRead, messageLength - totalRead)
                        if (read == -1) break
                        totalRead += read
                    }
                    
                    if (totalRead == messageLength) {
                        val message = String(buffer)
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
     * Handle incoming message using proper JSON parsing
     */
    private fun handleMessage(message: String) {
        try {
            if (message.contains("\"PlaybackState\"")) {
                // Use org.json for parsing (available on Android)
                val json = org.json.JSONObject(message)
                val playbackStateJson = json.optJSONObject("PlaybackState")
                if (playbackStateJson != null) {
                    val isPlaying = playbackStateJson.optBoolean("isPlaying", false)
                    val currentSongJson = playbackStateJson.optJSONObject("currentSong")
                    
                    _playbackState.value = WearPlaybackState(
                        isPlaying = isPlaying,
                        currentSong = if (currentSongJson != null) {
                            WearSongInfo(
                                id = currentSongJson.optString("id", ""),
                                title = currentSongJson.optString("title", ""),
                                artist = currentSongJson.optString("artist", "")
                            )
                        } else null
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing message", e)
        }
    }

    /**
     * Send a command to the connected device with deviceId and length-prefix framing
     */
    private fun sendCommand(action: String) {
        scope.launch {
            try {
                val writer = PrintWriter(socket?.getOutputStream(), true)
                // Include deviceId in the command for proper routing
                val deviceIdValue = connectedDeviceId ?: "unknown"
                val command = """{"PlaybackCommand":{"deviceId":"$deviceIdValue","action":"$action","timestamp":${System.currentTimeMillis()}}}"""
                // Send message length first, then the message content
                writer.println(command.length)
                writer.println(command)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending command", e)
            }
        }
    }
}
