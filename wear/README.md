# Metrolist Wear OS App

A standalone Wear OS application for Metrolist with full authentication support and music playback capabilities.

## Features

- 🔐 **Authentication**: Sign in using Credential Manager with Remote Auth (phone delegation)
- 🎵 **Music Playback**: Standalone music streaming on your watch
- 📱 **Remote Control**: Control music playback on your paired phone via MetroSync
- 💾 **Offline Mode**: Download and play music without internet
- 🎨 **Wear OS Optimized**: Designed for circular displays and watch interactions

## Quick Start

### Development Mode (Demo)

The easiest way to test the app without authentication setup:

1. Build and install the app on a Wear OS device or emulator
2. Launch the app
3. Tap **"Demo Mode"** button on the sign-in screen
4. You'll be signed in as a demo user and can explore the UI

### Production Mode (Real Authentication)

For full authentication with Google Sign-In:

1. **Set up Google Cloud credentials** - See [AUTHENTICATION.md](./AUTHENTICATION.md)
2. **Update the client ID** in `AuthRepository.kt`
3. **Test on a paired device** with Google Play Services

## Project Structure

```
wear/
├── src/main/kotlin/com/metrolist/wear/
│   ├── MainActivity.kt              # Main entry point
│   ├── WearApp.kt                   # App configuration
│   ├── auth/
│   │   └── AuthRepository.kt        # Authentication logic
│   ├── navigation/
│   │   └── WearNavigation.kt        # Screen navigation
│   ├── ui/screens/
│   │   ├── SignInScreen.kt          # Sign-in UI
│   │   ├── BrowseScreen.kt          # Browse music UI
│   │   └── AccountScreen.kt         # Account management
│   ├── metrosync/
│   │   └── MetroSyncClient.kt       # Phone remote control
│   └── playback/
│       └── WearMusicService.kt      # Media playback service
├── AUTHENTICATION.md                # Auth setup guide
└── build.gradle.kts                 # Dependencies
```

## Authentication Flow

```
Watch: User taps "Sign In"
    ↓
Watch: Opens Credential Manager
    ↓
Phone: Receives auth request via Remote Auth
    ↓
Phone: User completes Google Sign-In
    ↓
Phone: Returns credentials to watch
    ↓
Watch: Saves credentials and navigates to app
```

## Key Dependencies

- **Wear OS Compose**: Material components for Wear OS
- **Credential Manager**: Android authentication API
- **Media3**: Audio playback
- **Hilt**: Dependency injection
- **DataStore**: Persistent storage
- **Coil**: Image loading

## Building

```bash
# Build debug APK
./gradlew :wear:assembleDebug

# Install on connected device
./gradlew :wear:installDebug

# Build release APK
./gradlew :wear:assembleRelease
```

## Testing

### On Emulator
1. Create a Wear OS emulator (API 30+)
2. Pair with a phone emulator or physical device
3. Install and run the app

### On Physical Device
1. Enable Developer Options on your watch
2. Connect via ADB over Bluetooth or Wi-Fi
3. Install and run the app

## Documentation

- [Authentication Setup Guide](./AUTHENTICATION.md) - How to configure Google Sign-In
- [Main Implementation Summary](../WEAR_OS_IMPLEMENTATION.md) - Technical details

## Architecture

### State Management
- **Flow-based**: Reactive state with Kotlin Flows
- **DataStore**: Persistent user data
- **Compose State**: UI state management

### Design Patterns
- **Repository Pattern**: Centralized data access
- **Dependency Injection**: Hilt for component lifecycle
- **Navigation**: Wear-optimized screen transitions

## Troubleshooting

### "Sign-in cancelled or failed"
- Ensure watch is paired with a phone
- Check that Google Play Services is updated on the phone
- Verify the Web Client ID is configured correctly

### App won't install
- Check minimum SDK version (API 30)
- Ensure watch has sufficient storage
- Verify ADB connection

### Demo mode not working
- This is a development feature only
- Should work without any configuration
- Check logs for errors

## Contributing

When working on the Wear OS module:

1. **Keep it minimal** - Watch screens should be simple and focused
2. **Test on device** - Emulators may not match real device behavior
3. **Consider battery** - Minimize background activity
4. **Follow Material Design** - Use Wear OS components

## License

Same as the main Metrolist project - See [LICENSE](../LICENSE)
