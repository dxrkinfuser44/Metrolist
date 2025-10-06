package com.metrolist.wear.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.MaterialTheme
import androidx.compose.material.Text

/**
 * Browse screen for standalone Wear OS music playback
 * Optimized for small displays
 */
@Composable
fun BrowseScreen(
    onQuickPicksClick: () -> Unit,
    onSearchClick: () -> Unit,
    onLibraryClick: () -> Unit,
    onDownloadsClick: () -> Unit
) {
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
        
        // Quick Picks
        item {
            BrowseCard(
                title = "Quick Picks",
                description = "Personalized for you",
                onClick = onQuickPicksClick
            )
        }
        
        // Search
        item {
            BrowseCard(
                title = "Search",
                description = "Find songs & artists",
                onClick = onSearchClick
            )
        }
        
        // Library
        item {
            BrowseCard(
                title = "Library",
                description = "Your music",
                onClick = onLibraryClick
            )
        }
        
        // Downloads (offline)
        item {
            BrowseCard(
                title = "Downloads",
                description = "Offline playback",
                onClick = onDownloadsClick
            )
        }
    }
}

@Composable
fun BrowseCard(
    title: String,
    description: String,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.title3,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
            Text(
                text = description,
                style = MaterialTheme.typography.caption1,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}
