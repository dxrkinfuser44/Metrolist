package com.metrolist.wear.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.metrolist.wear.data.SyncedSong
import com.metrolist.wear.data.WearableDataService

/**
 * Screen showing synced favorite songs from phone
 */
@Composable
fun SyncedFavoritesScreen(
    wearableDataService: WearableDataService,
    onSongClick: (SyncedSong) -> Unit,
    onBackClick: () -> Unit = {}
) {
    val favorites by wearableDataService.syncedFavorites.collectAsState()
    val isPhoneConnected by wearableDataService.isPhoneConnected.collectAsState()
    
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
                text = "Favorites",
                style = MaterialTheme.typography.title2,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }
        
        if (!isPhoneConnected) {
            item {
                Card(
                    onClick = {},
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "📱",
                            style = MaterialTheme.typography.title1
                        )
                        Text(
                            text = "No phone connected",
                            style = MaterialTheme.typography.body2,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                        Text(
                            text = "Connect your phone to sync favorites",
                            style = MaterialTheme.typography.caption1,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
            }
        } else if (favorites.isEmpty()) {
            item {
                Card(
                    onClick = {},
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "No favorites synced yet",
                            style = MaterialTheme.typography.body2,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        } else {
            items(favorites.size) { index ->
                val song = favorites[index]
                SongCard(
                    song = song,
                    onClick = { onSongClick(song) }
                )
            }
        }
    }
}

@Composable
fun SongCard(
    song: SyncedSong,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Song icon
            Text(
                text = "♫",
                style = MaterialTheme.typography.title2,
                modifier = Modifier.size(32.dp)
            )
            
            Spacer(modifier = Modifier.width(12.dp))
            
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = song.title,
                    style = MaterialTheme.typography.title3,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                song.artist?.let { artist ->
                    Text(
                        text = artist,
                        style = MaterialTheme.typography.caption1,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}
