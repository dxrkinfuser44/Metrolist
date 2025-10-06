# MetroSync - Device Control Protocol

## Overview

MetroSync is a Spotify Connect-style device control protocol that enables seamless playback control across multiple devices. It works both **online** (via local network) and **offline** (via peer-to-peer connection), making it perfect for controlling playback from your Wear OS smartwatch or other devices.

## Features

- **Device Discovery**: Automatic discovery of nearby devices using Network Service Discovery (NSD)
- **Offline & Online Support**: Works on local network and via direct device connection
- **Real-time Sync**: Playback state is synchronized in real-time across all connected devices
- **Wear OS Support**: Full companion app for Wear OS smartwatches
- **Playback Control**: Play, pause, next, previous, shuffle, repeat, and volume control
- **Queue Management**: Share and synchronize playback queues across devices

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MetroSync System                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐          ┌──────────────────┐
│   Phone/Tablet   │          │    Wear OS       │
│                  │          │                  │
│ ┌──────────────┐ │          │ ┌──────────────┐ │
│ │ MusicService │ │          │ │ MainActivity │ │
│ └──────┬───────┘ │          │ └──────┬───────┘ │
│        │         │          │        │         │
│ ┌──────▼───────┐ │          │ ┌──────▼───────┐ │
│ │ MetroSync    │◄├──────────┤►│ MetroSync    │ │
│ │ Service      │ │  Network  │ │ Client       │ │
│ └──────┬───────┘ │    or     │ └──────────────┘ │
│        │         │  Direct   │                  │
│ ┌──────▼───────┐ │  Socket   │                  │
│ │   Device     │ │           │                  │
│ │  Discovery   │ │           │                  │
│ └──────────────┘ │           │                  │
└──────────────────┘           └──────────────────┘

         │                              │
         └──────────────┬───────────────┘
                        │
              ┌─────────▼─────────┐
              │  Protocol Messages │
              │  - Announcements   │
              │  - Playback State  │
              │  - Commands        │
              └────────────────────┘
```

### Core Components

1. **MetroSync Protocol** (`app/src/main/kotlin/com/metrolist/music/metrosync/`)
   - `models/MetroSyncMessage.kt`: Protocol message definitions
   - `service/MetroSyncService.kt`: Main service handling device communication
   - `discovery/DeviceDiscovery.kt`: NSD-based device discovery

2. **MusicService Integration** (`app/src/main/kotlin/com/metrolist/music/playback/MusicService.kt`)
   - Integrated MetroSync into the main music service
   - Automatic playback state broadcasting
   - Command handling for remote control

3. **Wear OS App** (`wear/`)
   - **Standalone YouTube Music player** with full playback capabilities
   - **Dual-mode operation**: Browse & play music OR remote control phone
   - MetroSync client for connecting to phone/tablet
   - Compose-based UI optimized for small displays
   - Independent music playback service (`WearMusicService`)
   - Browse, search, and library screens for standalone use

4. **Settings UI** (`app/src/main/kotlin/com/metrolist/music/ui/screens/settings/integrations/MetroSyncSettings.kt`)
   - Enable/disable MetroSync
   - Auto-connect configuration
   - Offline mode toggle

## Protocol Messages

### DeviceAnnouncement
Broadcast when a device becomes available:
```kotlin
{
  "deviceId": "unique-device-id",
  "deviceName": "Samsung Galaxy",
  "deviceType": "PHONE",
  "capabilities": ["PLAYBACK_CONTROL", "QUEUE_MANAGEMENT", "OFFLINE_MODE"]
}
```

### PlaybackState
Synchronized playback state:
```kotlin
{
  "deviceId": "unique-device-id",
  "isPlaying": true,
  "position": 45000,
  "duration": 180000,
  "currentSong": {
    "id": "song-id",
    "title": "Song Title",
    "artist": "Artist Name",
    "album": "Album Name",
    "thumbnailUrl": "https://...",
    "duration": 180000
  },
  "repeatMode": 0,
  "shuffleEnabled": false,
  "volume": 0.8
}
```

### PlaybackCommand
Control commands sent between devices:
```kotlin
{
  "deviceId": "unique-device-id",
  "action": "PLAY", // PAUSE, NEXT, PREVIOUS, SEEK, etc.
  "value": null // optional parameter
}
```

## Usage

### Enabling MetroSync

1. Open the app and navigate to **Settings → Integrations → MetroSync**
2. Toggle **Enable MetroSync** to ON
3. Configure settings:
   - **Auto Connect**: Automatically connect to nearby devices
   - **Offline Mode**: Enable peer-to-peer connection without internet

### Connecting from Wear OS

1. Install the Metrolist Wear OS app on your smartwatch
2. Open the app and tap **Discover Devices**
3. Select your phone/tablet from the list
4. Once connected, you can control playback directly from your watch

### Using MetroSync

Once connected:
- **Playback State**: Real-time sync of current song, position, and playing state
- **Control Playback**: Play, pause, skip tracks from any connected device
- **Queue Management**: Changes to the queue are reflected on all devices
- **Volume Control**: Adjust volume from any device

## Technical Details

### Network Communication

MetroSync uses three communication methods:

1. **WiFi Direct (Primary for P2P)**
   - True peer-to-peer connections without requiring a router
   - Works completely offline
   - Automatic peer discovery
   - Best for watch-to-phone connections

2. **Network Service Discovery (NSD - Fallback)**
   - Uses multicast DNS (mDNS) for device discovery
   - Service type: `_metrosync._tcp.`
   - Default port: 45678
   - Works on local networks

3. **TCP Socket Communication**
   - Direct socket connections for message passing
   - JSON-serialized messages
   - Persistent connections with automatic reconnection

### Device Discovery Flow

```
Phone A                          Phone B / Watch
   |                                  |
   |-- Register Service ------------> |
   |                                  |
   |<---------- Discover Service -----|
   |                                  |
   |<---------- TCP Connect ----------|
   |                                  |
   |-- DeviceAnnouncement ----------->|
   |<-- DeviceAnnouncement -----------|
   |                                  |
   |-- PlaybackState --------------->|
   |<-- PlaybackCommand --------------|
```

### Offline Mode

In offline mode, MetroSync can work without an active internet connection or Wi-Fi router:
- Uses Wi-Fi Direct or Bluetooth for initial pairing (future enhancement)
- Direct TCP connection between devices
- No cloud services required

## Configuration

### Preference Keys

```kotlin
MetroSyncEnabledKey          // Enable/disable MetroSync
MetroSyncDeviceNameKey       // Custom device name
MetroSyncAutoConnectKey      // Auto-connect to known devices
MetroSyncOfflineModeKey      // Enable offline peer-to-peer mode
```

## Security Considerations

- MetroSync operates on the local network only
- No data is sent to external servers
- Device connections are authenticated via discovery protocol
- Consider implementing encryption for production use

## Future Enhancements

1. **Encryption**: Add TLS/SSL for secure communication
2. **Authentication**: Device pairing with PIN codes
3. **Wi-Fi Direct**: Better offline connectivity
4. **Cloud Relay**: Optional cloud relay for remote connections
5. **Multi-room Audio**: Synchronized playback across multiple devices
6. **Handoff**: Seamless transfer of playback between devices

## Troubleshooting

### Devices Not Discovering Each Other
- Ensure both devices are on the same Wi-Fi network
- Check that MetroSync is enabled in settings
- Verify firewall settings aren't blocking port 45678

### Connection Drops
- Check network stability
- Ensure devices stay within Wi-Fi range
- Try disabling and re-enabling MetroSync

### Playback Commands Not Working
- Verify both devices are connected
- Check that the sending device has PLAYBACK_CONTROL capability
- Review logs for error messages

## Development

### Building the Wear Module

```bash
./gradlew :wear:assembleDebug
```

### Testing

```bash
# Install on phone
./gradlew :app:installDebug

# Install on watch
./gradlew :wear:installDebug
```

### Debugging

Enable debug logs to see MetroSync activity:
```
adb logcat | grep "MetroSync"
```

## Contributing

Contributions are welcome! Please ensure:
- Code follows the existing style
- All new features have appropriate documentation
- Test your changes on both phone and Wear OS devices

## License

This project is licensed under the same license as Metrolist.
