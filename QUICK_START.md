# MetroSync Quick Start Guide

## What is MetroSync?

MetroSync is a **Spotify Connect-style protocol** that lets you control Metrolist playback across multiple devices using **WiFi Direct** for true peer-to-peer connections. Plus, the Wear OS app now functions as a **standalone YouTube Music player**!

Features:
- 🎵 **Standalone Playback**: Browse and play YouTube Music directly on your watch
- ⌚ **Remote Control**: Control your phone's playback from your watch
- 🔗 **WiFi Direct**: True peer-to-peer, works without a router
- ✈️ **Works Offline**: No internet needed for device connections

## 5-Minute Setup

### Step 1: Enable on Phone

1. Open **Metrolist** app
2. Go to **Settings** → **Integrations** → **MetroSync**
3. Toggle **Enable MetroSync** to ON
4. Done! Your phone is now discoverable

### Step 2: Use on Watch

**Option A: Standalone Player** (No phone needed!)
1. Install **Metrolist Wear** on your smartwatch
2. Open the app - defaults to Browse mode
3. Navigate to Quick Picks, Search, or Library
4. Play music directly on your watch! 🎉

**Option B: Remote Control** (Control your phone)
1. Open the app on your watch
2. Swipe or navigate to Remote Control mode
3. Tap **Discover Devices**
4. Select your phone from the list
5. Control phone playback from your wrist! ⌚

## What Can You Do?

Once connected, you can:

- ▶️ **Play/Pause** from any device
- ⏭️ **Skip tracks** remotely  
- 🔀 **Toggle shuffle** from watch
- 🔁 **Change repeat mode** easily
- 📱 **See what's playing** in real-time

## How Does It Work?

```
Your Phone                      Your Watch
    │                               │
    │  1. Discovers devices ─────→  │
    │                               │
    │  ←──── 2. Connects ───────────│
    │                               │
    │  3. Syncs playback ───────→   │
    │                               │
    │  ←── 4. Sends commands ───────│
```

**Online Mode** (Default)
- Uses your Wi-Fi network
- Automatic device discovery
- Best for home use

**Offline Mode** (Optional)
- Direct device connection
- No internet needed
- Perfect for outdoor activities

## Common Scenarios

### 🏃 Workout Control
"I'm running and want to change songs without pulling out my phone"

**Solution**: Enable MetroSync, connect watch, control from wrist

### 🏠 Multi-Room
"I want to see what's playing while my phone is in another room"

**Solution**: Enable MetroSync on tablet and phone, they sync automatically

### ✈️ Airplane Mode
"I'm flying but want to use my watch to control music"

**Solution**: Enable Offline Mode in settings, devices connect directly

## Settings Explained

| Setting | What It Does | When to Use |
|---------|-------------|-------------|
| **Enable MetroSync** | Master on/off switch | Always enable first |
| **Auto Connect** | Automatically connects to known devices | For convenience |
| **Offline Mode** | Enables direct device connection | When no Wi-Fi available |

## Tips & Tricks

💡 **Tip 1**: Leave MetroSync enabled - it uses minimal battery when idle

💡 **Tip 2**: Enable Auto Connect to skip manual connection each time

💡 **Tip 3**: Use Offline Mode when traveling or hiking

💡 **Tip 4**: Multiple devices can connect simultaneously

💡 **Tip 5**: Changes sync instantly - no delay!

## Troubleshooting

### "Can't find devices"
- ✅ Both devices on same Wi-Fi?
- ✅ MetroSync enabled on both?
- ✅ Try toggling MetroSync off/on

### "Connection keeps dropping"
- ✅ Stay within Wi-Fi range
- ✅ Disable battery optimization for app
- ✅ Check for network congestion

### "Commands not working"
- ✅ Verify connection status
- ✅ Restart MetroSync service
- ✅ Check app logs for errors

### "Offline mode not working"
- ✅ Enable Offline Mode in settings
- ✅ Devices need to be paired once online first
- ✅ Keep devices close together

## More Information

📖 **Full Documentation**: See [METROSYNC.md](METROSYNC.md)  
👨‍💻 **Developer Guide**: See [METROSYNC_DEVELOPMENT.md](METROSYNC_DEVELOPMENT.md)  
🔧 **Technical Details**: See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

## FAQ

**Q: Does this work with other music apps?**  
A: No, MetroSync is designed specifically for Metrolist.

**Q: Can I control someone else's phone?**  
A: Only if you're on the same network and they have MetroSync enabled.

**Q: Does it work over the internet?**  
A: Currently only on local network. Cloud support is a future enhancement.

**Q: Will this drain my battery?**  
A: Very minimal - less than 1% per hour with active connection.

**Q: Do I need both devices running Metrolist?**  
A: Yes, both need the app. Wear OS device needs the Wear version.

**Q: Can I use this with multiple watches?**  
A: Yes! Multiple devices can connect simultaneously.

**Q: Is it secure?**  
A: Currently unencrypted on local network. Use on trusted networks only.

**Q: Does it work with Bluetooth?**  
A: Not yet. It uses Wi-Fi/Wi-Fi Direct. Bluetooth is a future enhancement.

## Support

Need help? 
- Check the full documentation
- Look for errors: `adb logcat | grep MetroSync`
- Open an issue on GitHub

## Enjoy MetroSync! 🎵⌚

Now you can control your music from anywhere, on any device. Happy listening! 🎉
