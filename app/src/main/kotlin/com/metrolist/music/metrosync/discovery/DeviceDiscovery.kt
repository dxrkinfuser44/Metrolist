package com.metrolist.music.metrosync.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import com.metrolist.music.metrosync.models.DeviceAnnouncement
import com.metrolist.music.metrosync.models.DeviceCapability
import com.metrolist.music.metrosync.models.DeviceType
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import java.net.InetAddress

/**
 * Handles device discovery using Network Service Discovery (NSD) for local network
 * and custom discovery for offline peer-to-peer connections
 */
class DeviceDiscovery(private val context: Context) {
    private val nsdManager: NsdManager by lazy {
        context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }

    companion object {
        private const val TAG = "MetroSync.Discovery"
        private const val SERVICE_TYPE = "_metrosync._tcp."
        private const val SERVICE_NAME = "MetroSync"
    }

    /**
     * Start discovering devices on the network
     */
    fun discoverDevices(): Flow<DeviceAnnouncement> = callbackFlow {
        val discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "Service discovery started: $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service found: ${serviceInfo.serviceName}")
                
                nsdManager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                        Log.e(TAG, "Resolve failed: $errorCode")
                    }

                    override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                        Log.d(TAG, "Service resolved: ${serviceInfo.serviceName}")
                        
                        // Create device announcement from resolved service
                        val announcement = DeviceAnnouncement(
                            deviceId = serviceInfo.serviceName,
                            deviceName = serviceInfo.serviceName,
                            deviceType = DeviceType.PHONE, // Could be parsed from service attributes
                            capabilities = listOf(
                                DeviceCapability.PLAYBACK_CONTROL,
                                DeviceCapability.QUEUE_MANAGEMENT,
                                DeviceCapability.OFFLINE_MODE
                            )
                        )
                        
                        trySend(announcement)
                    }
                })
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service lost: ${serviceInfo.serviceName}")
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "Discovery stopped: $serviceType")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
                close()
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery stop failed: $errorCode")
            }
        }

        try {
            nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start discovery", e)
            close(e)
        }

        awaitClose {
            try {
                nsdManager.stopServiceDiscovery(discoveryListener)
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping discovery", e)
            }
        }
    }

    /**
     * Register this device for discovery by other devices
     */
    fun registerDevice(
        deviceId: String,
        deviceName: String,
        port: Int
    ): Flow<Boolean> = callbackFlow {
        val serviceInfo = NsdServiceInfo().apply {
            serviceName = deviceName
            serviceType = SERVICE_TYPE
            setPort(port)
        }

        val registrationListener = object : NsdManager.RegistrationListener {
            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                Log.e(TAG, "Registration failed: $errorCode")
                trySend(false)
            }

            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                Log.e(TAG, "Unregistration failed: $errorCode")
            }

            override fun onServiceRegistered(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service registered: ${serviceInfo.serviceName}")
                trySend(true)
            }

            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service unregistered: ${serviceInfo.serviceName}")
                trySend(false)
            }
        }

        try {
            nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register service", e)
            trySend(false)
            close(e)
        }

        awaitClose {
            try {
                nsdManager.unregisterService(registrationListener)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering service", e)
            }
        }
    }
}
