#if canImport(SwiftUI)
import Foundation
import MetrolistCore
import MetrolistNetworking

// MARK: - Search ViewModel

/// Manages search state: query, filters, results, and search history.
@Observable
public final class SearchViewModel {
    public var query: String = ""
    public var activeFilter: SearchFilter = .all
    public var isSearching = false
    public var errorMessage: String?

    public var searchResults: [SearchResultSection] = []
    public var suggestions: [String] = []
    public var searchHistory: [String] = []

    public struct SearchResultSection: Identifiable {
        public let id = UUID()
        public let title: String
        public let items: [any YTItem]
    }

    private let ytMusic: YouTubeMusic

    public init(ytMusic: YouTubeMusic? = nil) {
        self.ytMusic = ytMusic ?? YouTubeMusic(auth: InnerTubeAuth())
    }

    @MainActor
    public func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        do {
            let results = try await ytMusic.search(query: trimmed, filter: activeFilter).get()
            self.searchResults = [SearchResultSection(title: "Results", items: results.items)]
        } catch {
            errorMessage = error.localizedDescription
            MetrolistLogger.network.error("Search failed: \(error)")
        }

        isSearching = false
    }

    @MainActor
    public func fetchSuggestions() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }

        do {
            let result = try await ytMusic.searchSuggestions(query: trimmed).get()
            self.suggestions = result.queries
        } catch {
            // Silently fail for suggestions
        }
    }

    public func clearResults() {
        searchResults = []
        suggestions = []
        errorMessage = nil
    }
}

#endif
