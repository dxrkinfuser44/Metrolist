package com.metrolist.music.metrosync.discovery

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pDeviceList
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/**
 * Manages WiFi Direct (P2P) connections for true peer-to-peer communication
 * Works without requiring a router or internet connection
 */
class WiFiDirectManager(private val context: Context) {
    private val manager: WifiP2pManager? by lazy {
        context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    }
    
    private var channel: WifiP2pManager.Channel? = null
    
    companion object {
        private const val TAG = "WiFiDirectManager"
        const val SERVICE_INSTANCE = "Metrolist"
        const val SERVICE_TYPE = "_metrosync._tcp"
    }

    /**
     * Initialize WiFi Direct channel
     */
    fun initialize() {
        channel = manager?.initialize(context, context.mainLooper, null)
    }

    /**
     * Discover nearby peers using WiFi Direct
     */
    fun discoverPeers(): Flow<List<WifiP2pDevice>> = callbackFlow {
        if (!hasLocationPermission()) {
            Log.w(TAG, "Missing location permission for WiFi Direct")
            close()
            return@callbackFlow
        }

        val peerListListener = WifiP2pManager.PeerListListener { peerList ->
            trySend(peerList.deviceList.toList())
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                        manager?.requestPeers(channel, peerListListener)
                    }
                    WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                        val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                        Log.d(TAG, "WiFi P2P state changed: $state")
                    }
                }
            }
        }

        val intentFilter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        }

        context.registerReceiver(receiver, intentFilter)

        // Start peer discovery
        manager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Peer discovery started")
            }

            override fun onFailure(reason: Int) {
                Log.e(TAG, "Failed to start peer discovery: $reason")
            }
        })

        awaitClose {
            context.unregisterReceiver(receiver)
            manager?.stopPeerDiscovery(channel, null)
        }
    }

    /**
     * Connect to a specific peer
     */
    fun connectToPeer(device: WifiP2pDevice, onSuccess: (WifiP2pInfo) -> Unit, onFailure: (Int) -> Unit) {
        val config = WifiP2pConfig().apply {
            deviceAddress = device.deviceAddress
        }

        manager?.connect(channel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Connection initiated to ${device.deviceName}")
                requestConnectionInfo(onSuccess)
            }

            override fun onFailure(reason: Int) {
                Log.e(TAG, "Failed to connect to peer: $reason")
                onFailure(reason)
            }
        })
    }

    /**
     * Request connection info after successful connection
     */
    private fun requestConnectionInfo(onSuccess: (WifiP2pInfo) -> Unit) {
        manager?.requestConnectionInfo(channel) { info ->
            if (info != null) {
                Log.d(TAG, "Connection info received - Group formed: ${info.groupFormed}, Is owner: ${info.isGroupOwner}")
                onSuccess(info)
            }
        }
    }

    /**
     * Create a group (become group owner)
     */
    fun createGroup(onSuccess: () -> Unit, onFailure: (Int) -> Unit) {
        manager?.createGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Group created successfully")
                onSuccess()
            }

            override fun onFailure(reason: Int) {
                Log.e(TAG, "Failed to create group: $reason")
                onFailure(reason)
            }
        })
    }

    /**
     * Remove the current group
     */
    fun removeGroup() {
        manager?.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(TAG, "Group removed")
            }

            override fun onFailure(reason: Int) {
                Log.e(TAG, "Failed to remove group: $reason")
            }
        })
    }

    /**
     * Check if we have required location permissions for WiFi Direct
     */
    private fun hasLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        removeGroup()
        channel = null
    }
}
