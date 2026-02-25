import SwiftUI
import MetrolistCore

// MARK: - Home Screen

/// Main home screen with personalized content sections.
/// iOS 26: TabView and NavigationStack automatically adopt Liquid Glass.
public struct HomeScreen: View {
    @State private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Quick Picks
                if !viewModel.quickPicks.isEmpty {
                    HorizontalSection("Quick Picks") {
                        ForEach(viewModel.quickPicks, id: \.id) { song in
                            ItemCardView(
                                title: song.title,
                                subtitle: song.subtitle,
                                thumbnailURL: song.thumbnails.last?.url
                            ) {
                                // Play song
                            }
                        }
                    }
                }

                // Dynamic sections from YouTube Music
                ForEach(viewModel.homeSections) { section in
                    HorizontalSection(section.title) {
                        ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                            ItemCardView(
                                title: item.title,
                                subtitle: item.subtitle,
                                thumbnailURL: item.thumbnails.last?.url,
                                isRound: item is ArtistItem
                            ) {
                                // Navigate to detail
                            }
                        }
                    }
                }

                // Loading indicator
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // Error state
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadHome() }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.loadHome()
        }
        .navigationTitle("Home")
        .task {
            if viewModel.homeSections.isEmpty {
                await viewModel.loadHome()
            }
        }
    }
}
