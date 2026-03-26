#if canImport(SwiftUI)
import Foundation
import MetrolistCore
import MetrolistNetworking

// MARK: - Search ViewModel

/// Manages search state: query, filters, results, and search history.
@Observable
@MainActor
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
    private var searchTask: Task<Void, Never>?
    private var suggestionsTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var suggestionsGeneration = 0

    public init(ytMusic: YouTubeMusic? = nil) {
        self.ytMusic = ytMusic ?? YouTubeMusic(auth: InnerTubeAuth())
    }

    isolated deinit {
        searchTask?.cancel()
        suggestionsTask?.cancel()
    }

    public func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            searchResults = []
            isSearching = false
            errorMessage = nil
            return
        }

        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        let filter = activeFilter

        isSearching = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.searchGeneration == generation {
                    self.searchTask = nil
                }
            }
            await self.runSearch(query: trimmed, filter: filter, generation: generation)
        }
    }

    private func runSearch(query: String, filter: SearchFilter, generation: Int) async {
        guard !query.isEmpty else { return }

        do {
            let results = try await ytMusic.search(query: query, filter: filter).get()
            guard !Task.isCancelled, searchGeneration == generation, self.query.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                return
            }
            self.searchResults = [SearchResultSection(title: "Results", items: results.items)]
            self.isSearching = false
        } catch is CancellationError {
            if searchGeneration == generation {
                isSearching = false
            }
        } catch {
            guard searchGeneration == generation else { return }
            isSearching = false
            errorMessage = error.localizedDescription
            MetrolistLogger.network.error("Search failed: \(error)")
        }
    }

    public func fetchSuggestions() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestionsTask?.cancel()
            suggestions = []
            return
        }

        suggestionsTask?.cancel()
        suggestionsGeneration += 1
        let generation = suggestionsGeneration
        suggestionsTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.suggestionsGeneration == generation {
                    self.suggestionsTask = nil
                }
            }
            await self.runSuggestionsFetch(query: trimmed, generation: generation)
        }
    }

    private func runSuggestionsFetch(query: String, generation: Int) async {
        do {
            let result = try await ytMusic.searchSuggestions(query: query).get()
            guard !Task.isCancelled,
                  suggestionsGeneration == generation,
                  self.query.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                return
            }
            self.suggestions = result.queries
        } catch is CancellationError {
            return
        } catch {
            guard suggestionsGeneration == generation else { return }
            suggestions = []
            MetrolistLogger.network.error("Search suggestions failed: \(error)")
        }
    }

    public func clearResults() {
        searchTask?.cancel()
        suggestionsTask?.cancel()
        query = ""
        searchResults = []
        suggestions = []
        isSearching = false
        errorMessage = nil
    }
}

#endif
