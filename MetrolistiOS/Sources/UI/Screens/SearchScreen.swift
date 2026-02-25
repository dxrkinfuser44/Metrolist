import SwiftUI
import MetrolistCore

// MARK: - Search Screen

public struct SearchScreen: View {
    @State private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        List {
            // Search suggestions
            if !viewModel.suggestions.isEmpty && viewModel.searchResults.isEmpty {
                Section("Suggestions") {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button {
                            viewModel.query = suggestion
                            Task { await viewModel.search() }
                        } label: {
                            Label(suggestion, systemImage: "magnifyingglass")
                        }
                    }
                }
            }

            // Search history
            if viewModel.query.isEmpty && !viewModel.searchHistory.isEmpty {
                Section("Recent") {
                    ForEach(viewModel.searchHistory, id: \.self) { item in
                        Button {
                            viewModel.query = item
                            Task { await viewModel.search() }
                        } label: {
                            Label(item, systemImage: "clock")
                        }
                    }
                }
            }

            // Search results
            ForEach(viewModel.searchResults) { section in
                Section(section.title) {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        SongRowView(song: item, onTap: {
                            // Navigate or play
                        })
                    }
                }
            }

            // Loading
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.query, prompt: "Search songs, artists, albums...")
        .onSubmit(of: .search) {
            Task { await viewModel.search() }
        }
        .onChange(of: viewModel.query) {
            Task { await viewModel.fetchSuggestions() }
        }
        .navigationTitle("Search")
    }
}

// MARK: - Filter Chips

public struct SearchFilterChips: View {
    @Binding var activeFilter: SearchFilter

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    Button {
                        activeFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                activeFilter == filter
                                    ? Color.accentColor.opacity(0.2)
                                    : Color(.systemGray5)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

private extension SearchFilter {
    var displayName: String {
        switch self {
        case .all: return "All"
        case .songs: return "Songs"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .playlists: return "Playlists"
        case .videos: return "Videos"
        case .communityPlaylists: return "Community"
        case .featuredPlaylists: return "Featured"
        }
    }
}
