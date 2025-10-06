package com.metrolist.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import com.metrolist.wear.metrosync.MetroSyncClient
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    
    @Inject
    lateinit var metroSyncClient: MetroSyncClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            MaterialTheme {
                WearApp(metroSyncClient)
            }
        }
    }
}

@Composable
fun WearApp(metroSyncClient: MetroSyncClient) {
    val playbackState by metroSyncClient.playbackState.collectAsState()
    val isConnected by metroSyncClient.isConnected.collectAsState()
    val discoveredDevices by metroSyncClient.discoveredDevices.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colors.background)
    ) {
        TimeText()
        
        ScalingLazyColumn(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(32.dp))
            }
            
            item {
                Text(
                    text = "Metrolist",
                    style = MaterialTheme.typography.title2,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
            
            if (isConnected) {
                item {
                    NowPlayingCard(
                        title = playbackState?.currentSong?.title ?: "No song playing",
                        artist = playbackState?.currentSong?.artist ?: "",
                        isPlaying = playbackState?.isPlaying ?: false,
                        onPlayPause = {
                            if (playbackState?.isPlaying == true) {
                                metroSyncClient.pause()
                            } else {
                                metroSyncClient.play()
                            }
                        },
                        onNext = { metroSyncClient.next() },
                        onPrevious = { metroSyncClient.previous() }
                    )
                }
            } else {
                item {
                    Card(
                        onClick = { metroSyncClient.startDiscovery() },
                        modifier = Modifier.padding(8.dp)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Not Connected",
                                style = MaterialTheme.typography.title3
                            )
                            Text(
                                text = "Tap to discover devices",
                                style = MaterialTheme.typography.caption1
                            )
                        }
                    }
                }
                
                if (discoveredDevices.isNotEmpty()) {
                    item {
                        Text(
                            text = "Available Devices",
                            style = MaterialTheme.typography.caption1,
                            modifier = Modifier.padding(8.dp)
                        )
                    }
                    
                    items(discoveredDevices.size) { index ->
                        val device = discoveredDevices[index]
                        Chip(
                            label = { Text(device.deviceName) },
                            onClick = { metroSyncClient.connectToDevice(device.deviceId) },
                            colors = ChipDefaults.primaryChipColors()
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun NowPlayingCard(
    title: String,
    artist: String,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit
) {
    Card(
        onClick = {},
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.title3,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
            
            if (artist.isNotEmpty()) {
                Text(
                    text = artist,
                    style = MaterialTheme.typography.caption1,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center
                )
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                Button(
                    onClick = onPrevious,
                    modifier = Modifier.size(40.dp),
                    colors = ButtonDefaults.secondaryButtonColors()
                ) {
                    Text("⏮")
                }
                
                Button(
                    onClick = onPlayPause,
                    modifier = Modifier.size(48.dp),
                    colors = ButtonDefaults.primaryButtonColors()
                ) {
                    Text(if (isPlaying) "⏸" else "▶")
                }
                
                Button(
                    onClick = onNext,
                    modifier = Modifier.size(40.dp),
                    colors = ButtonDefaults.secondaryButtonColors()
                ) {
                    Text("⏭")
                }
            }
        }
    }
}
