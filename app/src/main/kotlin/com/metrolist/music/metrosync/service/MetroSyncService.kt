package com.metrolist.music.metrosync.service

import android.content.Context
import android.net.wifi.p2p.WifiP2pDevice
import android.util.Log
import com.metrolist.music.metrosync.MetroSyncConstants
import com.metrolist.music.metrosync.discovery.DeviceDiscovery
import com.metrolist.music.metrosync.discovery.WiFiDirectManager
import com.metrolist.music.metrosync.models.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * MetroSync service that handles device-to-device communication
 * Works both online (via network) and offline (via direct connection)
 */
class MetroSyncService(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val deviceDiscovery = DeviceDiscovery(context)
    private val wifiDirectManager = WiFiDirectManager(context)
    
    // Persist device ID across restarts
    private val deviceId: String by lazy {
        val prefs = context.getSharedPreferences("metrosync_prefs", Context.MODE_PRIVATE)
        prefs.getString("device_id", null) ?: run {
            val newId = UUID.randomUUID().toString()
            prefs.edit().putString("device_id", newId).apply()
            newId
        }
    }
    private val connectedDevices = ConcurrentHashMap<String, Socket>()
    private var useWifiDirect = false // Default to regular WiFi (NSD), WiFi Direct only in offline mode
    
    private val _playbackState = MutableStateFlow<PlaybackState?>(null)
    val playbackState: StateFlow<PlaybackState?> = _playbackState.asStateFlow()
    
    private val _discoveredDevices = MutableStateFlow<List<DeviceAnnouncement>>(emptyList())
    val discoveredDevices: StateFlow<List<DeviceAnnouncement>> = _discoveredDevices.asStateFlow()
    
    private val _playbackCommands = MutableSharedFlow<PlaybackCommand>()
    val playbackCommands: SharedFlow<PlaybackCommand> = _playbackCommands.asSharedFlow()
    
    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    
    companion object {
        private const val TAG = "MetroSyncService"
        
        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }
    }

    /**
     * Enable or disable WiFi Direct mode
     * When enabled, uses WiFi Direct for peer-to-peer (disconnects from WiFi)
     * When disabled, uses NSD over regular WiFi network
     */
    fun setWifiDirectMode(enabled: Boolean) {
        if (useWifiDirect != enabled) {
            useWifiDirect = enabled
            if (isRunning) {
                // Restart discovery with new mode
                stop()
                start()
            }
        }
    }

    /**
     * Start the MetroSync service
     */
    fun start() {
        if (isRunning) return
        
        isRunning = true
        
        // Start server to accept connections
        startServer()
        
        if (useWifiDirect) {
            // Initialize WiFi Direct for peer-to-peer (disconnects from regular WiFi)
            Log.d(TAG, "Starting in WiFi Direct mode (offline P2P, disconnects from WiFi)")
            wifiDirectManager.initialize()
            // Use WiFi Direct for true peer-to-peer discovery
            scope.launch {
                wifiDirectManager.discoverPeers().collect { peers ->
                    Log.d(TAG, "WiFi Direct: Discovered ${peers.size} peers")
                    peers.forEach { peer ->
                        val announcement = DeviceAnnouncement(
                            deviceId = peer.deviceAddress,
                            deviceName = peer.deviceName,
                            deviceType = DeviceType.PHONE,
                            capabilities = listOf(
                                DeviceCapability.PLAYBACK_CONTROL,
                                DeviceCapability.QUEUE_MANAGEMENT,
                                DeviceCapability.OFFLINE_MODE
                            )
                        )
                        val currentList = _discoveredDevices.value.toMutableList()
                        if (currentList.none { it.deviceId == announcement.deviceId }) {
                            currentList.add(announcement)
                            _discoveredDevices.value = currentList
                        }
                    }
                }
            }
        } else {
            // Use NSD for local network discovery (works over regular WiFi)
            Log.d(TAG, "Starting in NSD mode (regular WiFi network)")
            scope.launch {
                deviceDiscovery.registerDevice(
                    deviceId = deviceId,
                    deviceName = android.os.Build.MODEL,
                    port = MetroSyncConstants.DEFAULT_PORT
                ).collect { registered ->
                    Log.d(TAG, "NSD: Device registration: $registered")
                }
            }
            
            scope.launch {
                deviceDiscovery.discoverDevices().collect { announcement ->
                    Log.d(TAG, "NSD: Discovered device: ${announcement.deviceName}")
                    val currentList = _discoveredDevices.value.toMutableList()
                    if (currentList.none { it.deviceId == announcement.deviceId }) {
                        currentList.add(announcement)
                        _discoveredDevices.value = currentList
                    }
                }
            }
        }
    }

    /**
     * Stop the MetroSync service
     */
    fun stop() {
        isRunning = false
        
        // Close all connections
        connectedDevices.values.forEach { socket ->
            try {
                socket.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing socket", e)
            }
        }
        connectedDevices.clear()
        
        // Close server socket
        serverSocket?.close()
        serverSocket = null
        
        // Clean up WiFi Direct
        wifiDirectManager.cleanup()
    }

    /**
     * Connect to a remote device
     * Note: Device is stored with a temporary key initially, then updated when announcement is received
     */
    fun connectToDevice(host: String, port: Int = MetroSyncConstants.DEFAULT_PORT) {
        scope.launch {
            try {
                val socket = Socket(host, port)
                Log.d(TAG, "Connected to device: $host:$port")
                
                // Send device announcement
                val announcement = DeviceAnnouncement(
                    deviceId = deviceId,
                    deviceName = android.os.Build.MODEL,
                    deviceType = DeviceType.PHONE,
                    capabilities = listOf(
                        DeviceCapability.PLAYBACK_CONTROL,
                        DeviceCapability.QUEUE_MANAGEMENT,
                        DeviceCapability.OFFLINE_MODE
                    )
                )
                
                sendMessage(socket, announcement)
                
                // Store connection with temporary key (will be updated when remote announcement received)
                val tempKey = "$host:$port"
                connectedDevices[tempKey] = socket
                
                // Start listening for messages (deviceId will be updated when announcement received)
                listenForMessages(socket, tempKey)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect to device: $host:$port", e)
            }
        }
    }

    /**
     * Send playback state update to all connected devices
     */
    fun broadcastPlaybackState(state: PlaybackState) {
        _playbackState.value = state
        
        connectedDevices.values.forEach { socket ->
            sendMessage(socket, state)
        }
    }

    /**
     * Send playback command to a specific device
     */
    fun sendCommand(deviceId: String, command: PlaybackCommand) {
        connectedDevices[deviceId]?.let { socket ->
            sendMessage(socket, command)
        }
    }

    /**
     * Start server to accept incoming connections
     */
    private fun startServer() {
        scope.launch {
            try {
                serverSocket = ServerSocket(MetroSyncConstants.DEFAULT_PORT)
                Log.d(TAG, "Server started on port ${MetroSyncConstants.DEFAULT_PORT}")
                
                while (isRunning) {
                    try {
                        val socket = serverSocket?.accept()
                        socket?.let {
                            Log.d(TAG, "Client connected: ${it.inetAddress.hostAddress}")
                            val clientId = it.inetAddress.hostAddress ?: "unknown"
                            connectedDevices[clientId] = it
                            listenForMessages(it, clientId)
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error accepting connection", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start server", e)
            }
        }
    }

    /**
     * Listen for messages from a connected socket
     * Uses length-prefix framing to handle message boundaries
     */
    private fun listenForMessages(socket: Socket, deviceId: String) {
        scope.launch {
            try {
                val inputStream = socket.getInputStream()
                val reader = BufferedReader(InputStreamReader(inputStream))
                
                while (isRunning && socket.isConnected) {
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
                        handleMessage(message, deviceId)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading from socket", e)
                connectedDevices.remove(deviceId)
                try {
                    socket.close()
                } catch (ex: Exception) {
                    Log.e(TAG, "Error closing socket", ex)
                }
            }
        }
    }

    /**
     * Handle incoming message
     */
    private fun handleMessage(message: String, deviceId: String) {
        try {
            // Parse and handle different message types
            when {
                message.contains("\"PlaybackState\"") -> {
                    val state = json.decodeFromString<PlaybackState>(message)
                    _playbackState.value = state
                }
                message.contains("\"PlaybackCommand\"") -> {
                    val command = json.decodeFromString<PlaybackCommand>(message)
                    scope.launch {
                        _playbackCommands.emit(command)
                    }
                }
                message.contains("\"DeviceAnnouncement\"") -> {
                    val announcement = json.decodeFromString<DeviceAnnouncement>(message)
                    val currentList = _discoveredDevices.value.toMutableList()
                    if (currentList.none { it.deviceId == announcement.deviceId }) {
                        currentList.add(announcement)
                        _discoveredDevices.value = currentList
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing message: $message", e)
        }
    }

    /**
     * Send a message to a socket with length-prefix framing
     */
    private fun sendMessage(socket: Socket, message: MetroSyncMessage) {
        scope.launch {
            try {
                val writer = PrintWriter(socket.getOutputStream(), true)
                val messageType = message::class.simpleName
                val jsonMessage = json.encodeToString(
                    when (message) {
                        is PlaybackState -> message
                        is PlaybackCommand -> message
                        is DeviceAnnouncement -> message
                        is QueueSync -> message
                        is ConnectionStatus -> message
                    }
                )
                // Send message length first, then the message content
                writer.println(jsonMessage.length)
                writer.println(jsonMessage)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending message", e)
            }
        }
    }

    /**
     * Get the current device ID
     */
    fun getDeviceId(): String = deviceId
}
