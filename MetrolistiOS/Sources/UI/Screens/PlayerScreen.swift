#if canImport(SwiftUI)
import SwiftUI
import AVKit
import NukeUI
import MetrolistCore

// MARK: - Player Screen (Full-Screen Now Playing)

/// Full-screen player with album art (or animated artwork video), playback controls,
/// lyrics overlay, and queue management. Designed for iOS 26 Liquid Glass.
public struct PlayerScreen: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    public init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — blurred album art
                artworkBackground

                VStack(spacing: 0) {
                    // Drag indicator / dismiss handle
                    Capsule()
                        .fill(.white.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    Spacer()

                    // Artwork
                    artworkView(size: min(geo.size.width - 48, 340))

                    Spacer().frame(height: 32)

                    // Track info
                    trackInfoSection

                    Spacer().frame(height: 24)

                    // Progress slider
                    progressSection

                    Spacer().frame(height: 20)

                    // Main controls
                    controlsSection

                    Spacer().frame(height: 20)

                    // Bottom actions
                    bottomActionsSection

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .onChange(of: viewModel.currentTime) {
            if !isDraggingSlider {
                sliderValue = viewModel.currentTime
            }
            viewModel.updateLyricPosition(at: viewModel.currentTime)
        }
        .task(id: viewModel.currentItem?.id) {
            await viewModel.onTrackChanged()
        }
        .sheet(isPresented: $viewModel.showQueue) {
            QueueSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLyrics) {
            LyricsSheet(viewModel: viewModel)
        }
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkBackground: some View {
        if let urlStr = viewModel.currentItem?.thumbnailUrl, let url = URL(string: urlStr) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.5))
                }
            }
            .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func artworkView(size: CGFloat) -> some View {
        ZStack {
            // Animated artwork (video) if available
            if let videoURL = viewModel.animatedArtworkURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .allowsHitTesting(false)
            } else if let urlStr = viewModel.currentItem?.thumbnailUrl, let url = URL(string: urlStr) {
                // Static artwork fallback
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .shadow(radius: 20, y: 8)
    }

    // MARK: - Track Info

    private var trackInfoSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.currentItem?.title ?? "Not Playing")
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .foregroundStyle(.white)

            Text(viewModel.currentItem?.artists.map(\.name).joined(separator: ", ") ?? "")
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 4) {
            ProgressSlider(
                value: $sliderValue,
                in: 0...max(viewModel.duration, 1)
            ) { editing in
                isDraggingSlider = editing
                if !editing {
                    viewModel.seekTo(sliderValue)
                }
            }

            HStack {
                Text(viewModel.formattedCurrentTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(viewModel.formattedDuration)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 32) {
            // Shuffle
            Button {
                viewModel.shuffleEnabled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(viewModel.shuffleEnabled ? .accent : .white.opacity(0.6))
            }

            // Previous
            Button(action: viewModel.skipToPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            // Play/Pause
            Button(action: viewModel.togglePlayPause) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }

            // Next
            Button(action: viewModel.skipToNext) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            // Repeat
            Button(action: viewModel.cycleRepeatMode) {
                Image(systemName: repeatIcon)
                    .font(.title3)
                    .foregroundStyle(viewModel.repeatMode == .off ? .white.opacity(0.6) : .accent)
            }
        }
    }

    private var repeatIcon: String {
        switch viewModel.repeatMode {
        case .off: return "repeat"
        case .queue: return "repeat"
        case .one: return "repeat.1"
        }
    }

    // MARK: - Bottom Actions

    private var bottomActionsSection: some View {
        HStack(spacing: 40) {
            Button {
                viewModel.showLyrics = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button {
                // Like action
            } label: {
                Image(systemName: "heart")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button {
                viewModel.showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button {
                viewModel.showSleepTimerSheet = true
            } label: {
                Image(systemName: "moon.zzz")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Queue Sheet

struct QueueSheet: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.queue.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        if index == viewModel.currentIndex {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.accent)
                                .frame(width: 20)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.body)
                                .lineLimit(1)
                                .foregroundStyle(index == viewModel.currentIndex ? .accent : .primary)

                            Text(item.artists.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.playerService.skipToIndex(index)
                    }
                }
                .onMove { source, destination in
                    viewModel.playerService.moveInQueue(from: source, to: destination)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.playerService.removeFromQueue(at: index)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Lyrics Sheet

struct LyricsSheet: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.isLoadingLyrics {
                            ProgressView("Loading lyrics...")
                                .padding(.top, 40)
                        } else if viewModel.syncedLyrics.isEmpty {
                            if let lyrics = viewModel.currentLyrics {
                                // Plain lyrics (not synced)
                                Text(lyrics)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            } else {
                                ContentUnavailableView(
                                    "No Lyrics",
                                    systemImage: "text.quote",
                                    description: Text("Lyrics not available for this track")
                                )
                            }
                        } else {
                            // Synced lyrics
                            ForEach(Array(viewModel.syncedLyrics.enumerated()), id: \.offset) { index, line in
                                Text(line.text)
                                    .font(.title3.weight(index == viewModel.currentLyricIndex ? .bold : .regular))
                                    .foregroundStyle(index == viewModel.currentLyricIndex ? .primary : .secondary)
                                    .multilineTextAlignment(.center)
                                    .id(index)
                                    .onTapGesture {
                                        viewModel.seekTo(line.time)
                                    }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentLyricIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let provider = viewModel.lyricsProvider {
                    Text("Provided by \(provider)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#endif
