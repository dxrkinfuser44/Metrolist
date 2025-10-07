package com.metrolist.music.ui.screens.settings.integrations

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarScrollBehavior
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavController
import com.metrolist.music.LocalPlayerAwareWindowInsets
import com.metrolist.music.R
import com.metrolist.music.constants.MetroSyncAutoConnectKey
import com.metrolist.music.constants.MetroSyncDeviceNameKey
import com.metrolist.music.constants.MetroSyncEnabledKey
import com.metrolist.music.constants.MetroSyncOfflineModeKey
import com.metrolist.music.ui.component.IconButton
import com.metrolist.music.ui.component.PreferenceEntry
import com.metrolist.music.ui.component.PreferenceGroupTitle
import com.metrolist.music.ui.component.SwitchPreference
import com.metrolist.music.ui.utils.backToMain
import com.metrolist.music.utils.rememberPreference

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MetroSyncSettings(
    navController: NavController,
    scrollBehavior: TopAppBarScrollBehavior,
) {
    val context = LocalContext.current
    val (metroSyncEnabled, onMetroSyncEnabledChange) = rememberPreference(MetroSyncEnabledKey, defaultValue = false)
    val (autoConnect, onAutoConnectChange) = rememberPreference(MetroSyncAutoConnectKey, defaultValue = false)
    val (offlineMode, onOfflineModeChange) = rememberPreference(MetroSyncOfflineModeKey, defaultValue = true)

    Column(
        Modifier
            .windowInsetsPadding(LocalPlayerAwareWindowInsets.current)
            .verticalScroll(rememberScrollState()),
    ) {
        PreferenceGroupTitle(title = stringResource(R.string.metrosync))

        SwitchPreference(
            title = { Text(stringResource(R.string.enable_metrosync)) },
            description = stringResource(R.string.enable_metrosync_description),
            icon = { Icon(painterResource(R.drawable.devices), null) },
            checked = metroSyncEnabled,
            onCheckedChange = onMetroSyncEnabledChange,
        )

        if (metroSyncEnabled) {
            PreferenceGroupTitle(title = stringResource(R.string.metrosync_settings))

            SwitchPreference(
                title = { Text(stringResource(R.string.auto_connect)) },
                description = stringResource(R.string.auto_connect_description),
                icon = { Icon(painterResource(R.drawable.link), null) },
                checked = autoConnect,
                onCheckedChange = onAutoConnectChange,
            )

            SwitchPreference(
                title = { Text(stringResource(R.string.offline_mode)) },
                description = stringResource(R.string.offline_mode_description),
                icon = { Icon(painterResource(R.drawable.cloud_off), null) },
                checked = offlineMode,
                onCheckedChange = onOfflineModeChange,
            )

            PreferenceGroupTitle(title = stringResource(R.string.about_metrosync))

            PreferenceEntry(
                title = { Text(stringResource(R.string.metrosync_info_title)) },
                description = stringResource(R.string.metrosync_info_description),
                icon = { Icon(painterResource(R.drawable.info), null) },
            )
        }
    }

    TopAppBar(
        title = { Text(stringResource(R.string.metrosync_integration)) },
        navigationIcon = {
            IconButton(
                onClick = navController::navigateUp,
                onLongClick = navController::backToMain,
            ) {
                Icon(
                    painterResource(R.drawable.arrow_back),
                    contentDescription = null,
                )
            }
        },
        scrollBehavior = scrollBehavior,
    )
}
