# MetroSync Development Guide

This guide explains how to develop and extend MetroSync functionality.

## Project Structure

```
Metrolist/
├── app/
│   └── src/main/kotlin/com/metrolist/music/
│       ├── metrosync/
│       │   ├── models/
│       │   │   └── MetroSyncMessage.kt      # Protocol message definitions
│       │   ├── service/
│       │   │   └── MetroSyncService.kt      # Main service
│       │   └── discovery/
│       │       └── DeviceDiscovery.kt       # NSD-based discovery
│       ├── playback/
│       │   └── MusicService.kt              # Integration point
│       └── ui/screens/settings/integrations/
│           └── MetroSyncSettings.kt         # Settings UI
└── wear/
    └── src/main/kotlin/com/metrolist/wear/
        ├── MainActivity.kt                   # Wear OS UI
        ├── WearApp.kt                        # Wear app entry
        └── metrosync/
            └── MetroSyncClient.kt            # Wear client

```

## Adding New Protocol Messages

1. Define the message in `MetroSyncMessage.kt`:

```kotlin
@Serializable
data class VolumeCommand(
    override val deviceId: String,
    override val timestamp: Long = System.currentTimeMillis(),
    val volume: Float,
) : MetroSyncMessage()
```

2. Handle the message in `MetroSyncService.kt`:

```kotlin
private fun handleMessage(message: String, deviceId: String) {
    when {
        message.contains("\"VolumeCommand\"") -> {
            val command = json.decodeFromString<VolumeCommand>(message)
            // Handle volume command
        }
        // ... other message types
    }
}
```

3. Update the Wear OS client if needed:

```kotlin
fun setVolume(volume: Float) {
    val command = """{"VolumeCommand":{"volume":$volume,"timestamp":${System.currentTimeMillis()}}}"""
    sendCommand(command)
}
```

## Testing MetroSync

### Local Testing

1. **Phone-to-Phone Testing**
   - Install app on two Android devices/emulators
   - Enable MetroSync on both
   - Verify they can discover and connect to each other

2. **Phone-to-Watch Testing**
   - Install main app on phone
   - Install Wear app on watch (physical or emulator)
   - Test discovery and playback control

### Unit Tests

Create tests for protocol messages:

```kotlin
@Test
fun testPlaybackStateEncoding() {
    val state = PlaybackState(
        deviceId = "test-device",
        isPlaying = true,
        position = 1000L,
        duration = 5000L,
        currentSong = null,
        repeatMode = 0,
        shuffleEnabled = false,
        volume = 0.5f
    )
    
    val json = Json.encodeToString(state)
    val decoded = Json.decodeFromString<PlaybackState>(json)
    
    assertEquals(state, decoded)
}
```

### Integration Tests

Test device discovery and communication:

```kotlin
@Test
fun testDeviceDiscovery() = runBlocking {
    val service = MetroSyncService(context)
    service.start()
    
    delay(5000) // Wait for discovery
    
    val devices = service.discoveredDevices.value
    assertTrue(devices.isNotEmpty())
    
    service.stop()
}
```

## Debugging

### Enable Verbose Logging

Add to your local.properties:
```
metrosync.debug=true
```

### Log Network Activity

```kotlin
private const val TAG = "MetroSync"

fun sendMessage(socket: Socket, message: MetroSyncMessage) {
    Log.v(TAG, "Sending: ${message::class.simpleName}")
    Log.v(TAG, "Payload: ${json.encodeToString(message)}")
    // ... send logic
}
```

### Monitor Network Traffic

Use Wireshark to inspect MetroSync traffic:
```bash
# Filter for MetroSync port
tcp.port == 45678
```

## Performance Optimization

### Reduce Message Frequency

Debounce playback state updates:

```kotlin
playbackState
    .debounce(500) // Only broadcast every 500ms
    .collect { state ->
        metroSyncService?.broadcastPlaybackState(state)
    }
```

### Optimize JSON Serialization

Use kotlinx.serialization with optimizations:

```kotlin
private val json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = false  // Don't encode default values
    isLenient = true
}
```

### Connection Pooling

Reuse connections for multiple devices:

```kotlin
private val connectionPool = ConcurrentHashMap<String, Socket>()

fun getConnection(deviceId: String): Socket {
    return connectionPool.getOrPut(deviceId) {
        createNewConnection(deviceId)
    }
}
```

## Security Enhancements

### Add Encryption

Use TLS sockets for encrypted communication:

```kotlin
val sslContext = SSLContext.getInstance("TLS")
sslContext.init(keyManagers, trustManagers, SecureRandom())

val sslSocket = sslContext.socketFactory.createSocket(host, port) as SSLSocket
```

### Implement Authentication

Add device pairing with PIN codes:

```kotlin
@Serializable
data class PairingRequest(
    override val deviceId: String,
    override val timestamp: Long,
    val pinCode: String,
) : MetroSyncMessage()
```

## Common Issues

### Issue: Devices Can't Discover Each Other

**Possible Causes:**
- Devices on different networks
- Firewall blocking mDNS
- NSD service not started

**Solution:**
```kotlin
// Add network state checking
fun isOnSameNetwork(): Boolean {
    val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
    val dhcpInfo = wifiManager.dhcpInfo
    return dhcpInfo.gateway != 0
}
```

### Issue: Connection Timeouts

**Possible Causes:**
- Network latency
- Socket timeout too short

**Solution:**
```kotlin
socket.soTimeout = 10000 // 10 seconds
socket.keepAlive = true
```

### Issue: Messages Not Received

**Possible Causes:**
- Buffer overflow
- Incomplete message reads

**Solution:**
```kotlin
// Use proper message framing
fun sendMessage(message: String) {
    val writer = PrintWriter(socket.getOutputStream())
    writer.println(message.length) // Send length first
    writer.println(message)
    writer.flush()
}
```

## Best Practices

1. **Always Close Connections**
   ```kotlin
   try {
       // Use connection
   } finally {
       socket?.close()
   }
   ```

2. **Handle Errors Gracefully**
   ```kotlin
   try {
       sendMessage(socket, message)
   } catch (e: IOException) {
       Log.e(TAG, "Failed to send message", e)
       reconnect()
   }
   ```

3. **Use Coroutines Properly**
   ```kotlin
   scope.launch {
       try {
           withContext(Dispatchers.IO) {
               // Network operation
           }
       } catch (e: CancellationException) {
           throw e // Re-throw cancellation
       } catch (e: Exception) {
           handleError(e)
       }
   }
   ```

4. **Avoid Memory Leaks**
   ```kotlin
   override fun onDestroy() {
       metroSyncService?.stop()
       metroSyncService = null
       super.onDestroy()
   }
   ```

## Extending MetroSync

### Add New Device Types

```kotlin
enum class DeviceType {
    PHONE,
    TABLET,
    WEAR_OS,
    DESKTOP,
    TV,          // New device type
    SPEAKER,     // New device type
    OTHER
}
```

### Add Custom Commands

```kotlin
@Serializable
data class CustomCommand(
    override val deviceId: String,
    override val timestamp: Long,
    val commandType: String,
    val parameters: Map<String, String>,
) : MetroSyncMessage()
```

### Support Multiple Rooms

```kotlin
@Serializable
data class RoomInfo(
    val roomId: String,
    val roomName: String,
    val devices: List<String>,
)
```

## Resources

- [Network Service Discovery (NSD) Guide](https://developer.android.com/training/connect-devices-wirelessly/nsd)
- [Wear OS Development](https://developer.android.com/training/wearables)
- [Kotlin Serialization](https://github.com/Kotlin/kotlinx.serialization)
- [TCP Socket Programming](https://docs.oracle.com/javase/tutorial/networking/sockets/)

## Contributing

When contributing to MetroSync:

1. Follow the existing code style
2. Add tests for new features
3. Update documentation
4. Test on multiple devices
5. Consider backwards compatibility

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation
- Review sample implementations
