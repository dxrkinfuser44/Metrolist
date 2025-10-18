# Wear OS Authentication Setup

This document explains how to set up authentication for the Metrolist Wear OS app using **Passkeys** with Google Password Manager.

## Overview

The Wear OS app uses Android's Credential Manager API with **Passkey** support. This allows users to authenticate securely using biometric authentication (fingerprint, face unlock) stored in Google Password Manager, eliminating the need for passwords.

## Setting Up Passkey Authentication

### 1. What are Passkeys?

Passkeys are a modern, secure alternative to passwords that use:
- **Public-key cryptography** - No passwords to remember or steal
- **Biometric authentication** - Face unlock, fingerprint, or PIN
- **Google Password Manager** - Synced across your devices
- **Phishing-resistant** - Cannot be intercepted or stolen

### 2. Configure Your Backend (Optional)

For production use with a backend server:

1. Set up your Relying Party (RP) identifier (e.g., "metrolist.app")
2. Configure your backend to handle WebAuthn/Passkey registration and authentication
3. Update the `rpId` in `AuthRepository.kt`:

```kotlin
val requestJson = """
    {
        "challenge": "${generateChallenge()}",
        "rpId": "your-domain.com",  // Update this
        "userVerification": "required"
    }
""".trimIndent()
```

### 3. No Special Configuration Required

Unlike OAuth-based authentication, passkeys work **out of the box** with:
- ✅ No API keys needed
- ✅ No OAuth configuration
- ✅ No client IDs
- ✅ Works with Google Password Manager automatically

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

## How Passkeys Work on Wear OS

1. User taps "Sign In with Passkey" on the watch
2. Google Password Manager is invoked
3. User authenticates using biometric (fingerprint/face) or device PIN
4. Passkey credential is returned to the watch
5. User is signed in securely

**Benefits:**
- ✅ **More Secure**: Uses public-key cryptography instead of passwords
- ✅ **Easier**: No typing passwords on small screen
- ✅ **Phishing-resistant**: Cannot be stolen or intercepted
- ✅ **Cross-device**: Passkeys sync via Google Password Manager
- ✅ **Biometric**: Uses fingerprint, face unlock, or PIN

## Testing

### Development Mode

For development and testing without setting up passkeys:

1. The app will show the sign-in screen
2. Use the "Demo Mode" button for immediate access
3. This bypasses the actual passkey authentication

### Production Testing

1. Ensure Google Password Manager is set up on your device
2. Install the app on a Wear OS device or emulator
3. Tap "Sign In with Passkey"
4. Authenticate with biometric or PIN
5. You'll be signed in

### Creating a Passkey for Testing

To create a passkey for testing:
1. Visit your app's website or use a registration flow
2. Google Password Manager will offer to save a passkey
3. The passkey will be available on all your synced devices
4. On the watch, you can use this passkey to sign in

## Troubleshooting

### "Sign-in cancelled or failed" Error

This usually means:
- Google Password Manager is not set up on the device
- No passkey is saved for this app
- The user cancelled the authentication prompt
- Biometric authentication failed

### No Passkey Available

If no passkey is available:
- Create one through your app's registration flow
- Or use the "Demo Mode" for testing
- Ensure Google Password Manager sync is enabled

## Security Considerations

1. **Public-key cryptography** - More secure than passwords
2. **Biometric authentication** - Face unlock, fingerprint, or PIN required
3. **No passwords stored** - Passkeys use cryptographic keys, not passwords
4. **Phishing-resistant** - Cannot be intercepted or stolen like passwords
5. **Backend verification recommended** - In production, verify credentials with your server

## References

- [Android Credential Manager](https://developer.android.com/training/sign-in/credential-manager)
- [Wear OS Sign-In Guide](https://developer.android.com/design/ui/wear/guides/m2-5/behaviors-and-patterns/sign-in)
- [Passkeys Overview](https://developers.google.com/identity/passkeys)
- [WebAuthn/FIDO2](https://webauthn.io/)
