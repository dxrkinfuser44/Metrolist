package com.metrolist.wear.tiles

import android.content.Context
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.DeviceParametersBuilders.DeviceParameters
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.Button
import androidx.wear.protolayout.material.ButtonColors
import androidx.wear.protolayout.material.Colors
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.SettableFuture

/**
 * Wear OS Tile for quick playback control
 * Provides play/pause, next, previous controls on watch face
 */
class PlaybackTileService : TileService() {
    
    companion object {
        private const val TILE_ID = "playback_tile"
        private const val ACTION_PLAY_PAUSE = "action_play_pause"
        private const val ACTION_NEXT = "action_next"
        private const val ACTION_PREVIOUS = "action_previous"
        private const val ACTION_OPEN_APP = "action_open_app"
    }
    
    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val future = SettableFuture.create<TileBuilders.Tile>()
        
        val deviceParams = requestParams.deviceConfiguration
        
        // Build tile layout
        val layout = createTileLayout(this, deviceParams)
        
        // Build tile
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion("1")
            .setTileTimeline(
                TimelineBuilders.Timeline.Builder()
                    .addTimelineEntry(
                        TimelineBuilders.TimelineEntry.Builder()
                            .setLayout(
                                LayoutElementBuilders.Layout.Builder()
                                    .setRoot(layout)
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .setFreshnessIntervalMillis(60000) // Update every minute
            .build()
        
        future.set(tile)
        return future
    }
    
    override fun onTileResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> {
        val future = SettableFuture.create<ResourceBuilders.Resources>()
        
        val resources = ResourceBuilders.Resources.Builder()
            .setVersion("1")
            .build()
        
        future.set(resources)
        return future
    }
    
    private fun createTileLayout(
        context: Context,
        deviceParams: DeviceParameters
    ): LayoutElementBuilders.LayoutElement {
        
        val colors = Colors.DEFAULT
        
        // Create play/pause button
        val playPauseButton = Button.Builder(context, createPlayPauseAction())
            .setTextContent("▶") // Or ⏸ when playing
            .setButtonColors(ButtonColors.primaryButtonColors(colors))
            .setSize(DimensionBuilders.DpProp.Builder(48f).build())
            .build()
        
        // Create previous button
        val previousButton = Button.Builder(context, createPreviousAction())
            .setTextContent("⏮")
            .setButtonColors(ButtonColors.secondaryButtonColors(colors))
            .setSize(DimensionBuilders.DpProp.Builder(40f).build())
            .build()
        
        // Create next button
        val nextButton = Button.Builder(context, createNextAction())
            .setTextContent("⏭")
            .setButtonColors(ButtonColors.secondaryButtonColors(colors))
            .setSize(DimensionBuilders.DpProp.Builder(40f).build())
            .build()
        
        // Create row with buttons
        val buttonRow = LayoutElementBuilders.Row.Builder()
            .setWidth(DimensionBuilders.ExpandedDimensionProp.Builder().build())
            .setHeight(DimensionBuilders.WrapDimensionProp.Builder().build())
            .addContent(previousButton)
            .addContent(
                LayoutElementBuilders.Spacer.Builder()
                    .setWidth(DimensionBuilders.DpProp.Builder(4f).build())
                    .build()
            )
            .addContent(playPauseButton)
            .addContent(
                LayoutElementBuilders.Spacer.Builder()
                    .setWidth(DimensionBuilders.DpProp.Builder(4f).build())
                    .build()
            )
            .addContent(nextButton)
            .build()
        
        // Create title text
        val titleText = Text.Builder(context, "Metrolist")
            .setTypography(Typography.TYPOGRAPHY_CAPTION1)
            .setColor(ColorBuilders.argb(0xFFFFFFFF.toInt()))
            .build()
        
        // Build primary layout
        return PrimaryLayout.Builder(deviceParams)
            .setContent(buttonRow)
            .setPrimaryChipContent(titleText)
            .build()
    }
    
    private fun createPlayPauseAction(): ModifiersBuilders.Clickable {
        return ModifiersBuilders.Clickable.Builder()
            .setId(ACTION_PLAY_PAUSE)
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName("${packageName}.MainActivity")
                            .build()
                    )
                    .build()
            )
            .build()
    }
    
    private fun createPreviousAction(): ModifiersBuilders.Clickable {
        return ModifiersBuilders.Clickable.Builder()
            .setId(ACTION_PREVIOUS)
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName("${packageName}.MainActivity")
                            .build()
                    )
                    .build()
            )
            .build()
    }
    
    private fun createNextAction(): ModifiersBuilders.Clickable {
        return ModifiersBuilders.Clickable.Builder()
            .setId(ACTION_NEXT)
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName("${packageName}.MainActivity")
                            .build()
                    )
                    .build()
            )
            .build()
    }
}
