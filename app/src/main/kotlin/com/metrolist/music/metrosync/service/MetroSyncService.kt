package com.metrolist.music.metrosync.service

import android.content.Context
import android.util.Log
import com.metrolist.music.metrosync.discovery.DeviceDiscovery
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
    
    private val deviceId = UUID.randomUUID().toString()
    private val connectedDevices = ConcurrentHashMap<String, Socket>()
    
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
        private const val DEFAULT_PORT = 45678
        private const val BUFFER_SIZE = 8192
        
        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
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
        
        // Register this device for discovery
        scope.launch {
            deviceDiscovery.registerDevice(
                deviceId = deviceId,
                deviceName = android.os.Build.MODEL,
                port = DEFAULT_PORT
            ).collect { registered ->
                Log.d(TAG, "Device registration: $registered")
            }
        }
        
        // Start discovering other devices
        scope.launch {
            deviceDiscovery.discoverDevices().collect { announcement ->
                Log.d(TAG, "Discovered device: ${announcement.deviceName}")
                val currentList = _discoveredDevices.value.toMutableList()
                if (currentList.none { it.deviceId == announcement.deviceId }) {
                    currentList.add(announcement)
                    _discoveredDevices.value = currentList
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
    }

    /**
     * Connect to a remote device
     */
    fun connectToDevice(host: String, port: Int = DEFAULT_PORT) {
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
                
                // Store connection
                connectedDevices[host] = socket
                
                // Start listening for messages
                listenForMessages(socket, host)
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
                serverSocket = ServerSocket(DEFAULT_PORT)
                Log.d(TAG, "Server started on port $DEFAULT_PORT")
                
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
     */
    private fun listenForMessages(socket: Socket, deviceId: String) {
        scope.launch {
            try {
                val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                val buffer = CharArray(BUFFER_SIZE)
                
                while (isRunning && socket.isConnected) {
                    val length = reader.read(buffer)
                    if (length > 0) {
                        val message = String(buffer, 0, length)
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
     * Send a message to a socket
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
