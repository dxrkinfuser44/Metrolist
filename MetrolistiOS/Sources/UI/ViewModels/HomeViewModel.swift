import Foundation
import MetrolistCore
import MetrolistNetworking

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

    public init(ytMusic: YouTubeMusic? = nil) {
        self.ytMusic = ytMusic ?? YouTubeMusic(auth: InnerTubeAuth())
    }

    @MainActor
    public func loadHome() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let homePage = try await ytMusic.home().get()
            // Derive quick picks from the first section's song items
            if let firstSection = homePage.sections.first {
                self.quickPicks = firstSection.items.compactMap { $0 as? SongItem }
            }
            self.continuationToken = homePage.continuation
            self.homeSections = homePage.sections.map { section in
                HomeSection(title: section.title ?? "Recommended", items: section.items, continuationToken: nil)
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
            let more = try await ytMusic.home(continuation: token).get()
            self.continuationToken = more.continuation
            let newSections = more.sections.map { section in
                HomeSection(title: section.title ?? "More", items: section.items, continuationToken: nil)
            }
            self.homeSections.append(contentsOf: newSections)
        } catch {
            MetrolistLogger.network.error("Home continuation failed: \(error)")
        }

        isLoading = false
    }
}
