package com.metrolist.music.metrosync

/**
 * Shared constants for MetroSync protocol used by both app and wear modules.
 * These constants define the communication protocol parameters.
 */
object MetroSyncConstants {
    /**
     * Network Service Discovery (NSD) service type for MetroSync protocol
     */
    const val SERVICE_TYPE = "_metrosync._tcp."
    
    /**
     * Default service name for device registration
     */
    const val SERVICE_NAME = "MetroSync"
    
    /**
     * Default port for MetroSync server
     */
    const val DEFAULT_PORT = 45678
    
    /**
     * Buffer size for socket communication
     */
    const val BUFFER_SIZE = 8192
}
