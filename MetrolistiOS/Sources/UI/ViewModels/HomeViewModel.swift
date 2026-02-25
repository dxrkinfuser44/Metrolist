import Foundation
import MetrolistCore

// MARK: - Home ViewModel

/// Manages the home screen state including quick picks, trending, and personalized content.
/// Equivalent to Android's HomeViewModel.
@Observable
public final class HomeViewModel {
    public var isLoading = false
    public var errorMessage: String?
    public var quickPicks: [SongItem] = []
    public var trendingItems: [SongItem] = []
    public var homeSections: [HomeSection] = []
    public var continuationToken: String?

    public struct HomeSection: Identifiable {
        public let id = UUID()
        public let title: String
        public let items: [any YTItem]
        public let continuationToken: String?
    }

    private let ytMusic: YouTubeMusic

    public init(ytMusic: YouTubeMusic = YouTubeMusic()) {
        self.ytMusic = ytMusic
    }

    @MainActor
    public func loadHome() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let homePage = try await ytMusic.home()
            self.quickPicks = homePage.quickPicks
            self.continuationToken = homePage.continuationToken
            self.homeSections = homePage.sections.map { section in
                HomeSection(title: section.title, items: section.items, continuationToken: section.continuationToken)
            }
        } catch {
            errorMessage = error.localizedDescription
            MetrolistLogger.network.error("Home fetch failed: \(error)")
        }

        isLoading = false
    }

    @MainActor
    public func loadMore() async {
        guard let token = continuationToken, !isLoading else { return }
        isLoading = true

        do {
            let more = try await ytMusic.homeContinuation(token: token)
            self.continuationToken = more.continuationToken
            let newSections = more.sections.map { section in
                HomeSection(title: section.title, items: section.items, continuationToken: section.continuationToken)
            }
            self.homeSections.append(contentsOf: newSections)
        } catch {
            MetrolistLogger.network.error("Home continuation failed: \(error)")
        }

        isLoading = false
    }
}
