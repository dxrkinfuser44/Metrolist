# Wear OS Authentication Setup

This document explains how to set up authentication for the Metrolist Wear OS app using Google Sign-In with Remote Auth.

## Overview

The Wear OS app uses Android's Credential Manager API with Remote Auth support. This allows users to authenticate on their paired phone, making the sign-in process more convenient on the small watch screen.

## Setting Up Google Sign-In

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Sign-In API

### 2. Configure OAuth 2.0 Client IDs

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth 2.0 Client ID**
3. Select **Web application** as the application type
4. Add authorized JavaScript origins and redirect URIs if needed
5. Note the **Client ID** - this will be used in the app

### 3. Update the App Configuration

In `wear/src/main/kotlin/com/metrolist/wear/auth/AuthRepository.kt`, replace the placeholder with your actual Web Client ID:

```kotlin
val googleIdOption = GetGoogleIdOption.Builder()
    .setFilterByAuthorizedAccounts(false)
    .setServerClientId("YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com") // Replace this
    .setAutoSelectEnabled(true)
    .build()
```

### 4. Add Required Dependencies

The following dependencies are already included in `wear/build.gradle.kts`:

```kotlin
implementation("androidx.credentials:credentials:1.5.0")
implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
```

### 5. Configure AndroidManifest.xml

The required permissions are already added:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## How Remote Auth Works

1. User taps "Sign In" on the watch
2. Credential Manager detects the watch is paired to a phone
3. The sign-in request is delegated to the phone via Companion Device Manager
4. User completes authentication on the phone
5. Credentials are returned to the watch securely
6. User is signed in on the watch

## Testing

### Development Mode

For development and testing without setting up Google Sign-In:

1. The app will show the sign-in screen
2. Attempting to sign in will show an error message about the client ID
3. This is expected behavior when the client ID is not configured

### Production Testing

1. Configure a real client ID as described above
2. Install the app on a Wear OS device or emulator
3. Ensure the watch is paired with a phone that has Google Play Services
4. Tap "Sign In" and complete the flow on the phone

## Troubleshooting

### "Sign-in cancelled or failed" Error

This usually means:
- The Web Client ID is not configured correctly
- Google Play Services is not available on the paired phone
- The user cancelled the sign-in flow

### No Phone Available

If the watch is not paired to a phone:
- Remote Auth will not work
- You may need to implement an alternative sign-in method for standalone watches

## Security Considerations

1. **Never commit your Client ID to public repositories** - Use build configuration or environment variables
2. **Use separate Client IDs for debug and release builds**
3. **Implement proper token validation on your backend**
4. **Store tokens securely using DataStore** (already implemented)

## References

- [Android Credential Manager](https://developer.android.com/training/sign-in/credential-manager)
- [Wear OS Sign-In Guide](https://developer.android.com/design/ui/wear/guides/m2-5/behaviors-and-patterns/sign-in)
- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android)
