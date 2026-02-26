import Foundation
import MetrolistCore

// MARK: - YouTube Music Parsing Extensions

extension YouTubeMusic {

    // MARK: - Search Response Parsing

    private func parseSearchResponse(data: Data) throws -> SearchResult {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SearchResponse.self, from: data)

        var items: [any YTItem] = []
        var continuation: String?

        // Parse main search results
        if let tabs = response.contents?.tabbedSearchResultsRenderer?.tabs {
            for tab in tabs {
                guard let sectionList = tab.tabRenderer?.content?.sectionListRenderer else { continue }

                for section in sectionList.contents ?? [] {
                    // Music shelf (regular results)
                    if let shelf = section.musicShelfRenderer {
                        for content in shelf.contents ?? [] {
                            if let renderer = content.musicResponsiveListItemRenderer {
                                if let item = toYTItem(renderer) {
                                    items.append(item)
                                }
                            }
                        }
                    }

                    // Music card shelf (top results)
                    if let cardShelf = section.musicCardShelfRenderer {
                        for content in cardShelf.contents ?? [] {
                            if let renderer = content.musicResponsiveListItemRenderer {
                                if let item = toYTItem(renderer) {
                                    items.append(item)
                                }
                            }
                        }
                    }
                }

                continuation = sectionList.continuations?.first?.token
            }
        }

        // Parse continuation results
        if let continuationContents = response.continuationContents {
            let contents = continuationContents.musicShelfContinuation.contents
            for content in contents {
                if let item = toYTItem(content.musicResponsiveListItemRenderer) {
                    items.append(item)
                }
            }
            continuation = continuationContents.musicShelfContinuation.continuations?.first?.token
        }

        return SearchResult(items: items, continuation: continuation)
    }

    // MARK: - MusicResponsiveListItemRenderer to YTItem Conversion

    private func toYTItem(_ renderer: MusicResponsiveListItemRenderer) -> (any YTItem)? {
        let secondaryLine = renderer.flexColumns[safe: 1]?
            .musicResponsiveListItemFlexColumnRenderer?
            .text?.runs?
            .splitBySeparator()

        if renderer.isSong {
            return parseSongItem(renderer, secondaryLine: secondaryLine)
        } else if renderer.isArtist {
            return parseArtistItem(renderer)
        } else if renderer.isAlbum {
            return parseAlbumItem(renderer, secondaryLine: secondaryLine)
        } else if renderer.isPlaylist {
            return parsePlaylistItem(renderer, secondaryLine: secondaryLine)
        } else if renderer.isPodcast {
            return parsePodcastItem(renderer, secondaryLine: secondaryLine)
        } else if renderer.isEpisode {
            return parseEpisodeItem(renderer, secondaryLine: secondaryLine)
        }

        return nil
    }

    private func parseSongItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> SongItem? {
        guard let videoId = renderer.playlistItemData?.videoId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }

        let artists = secondaryLine?.first?.oddElements().compactMap { run -> ArtistItem? in
            guard let browseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: browseId, title: run.text)
        } ?? []

        let album = secondaryLine?[safe: 1]?.first(where: { $0.navigationEndpoint?.browseEndpoint != nil }).flatMap { run -> AlbumItem? in
            guard let browseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return AlbumItem(id: browseId, title: run.text)
        }

        let duration = secondaryLine?.last?.first?.text.parseTime()
        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]
        let explicit = renderer.badges?.contains(where: { $0.musicInlineBadgeRenderer?.icon?.iconType == "MUSIC_EXPLICIT_BADGE" }) == true

        return SongItem(
            id: videoId,
            title: title,
            thumbnails: thumbnails,
            artists: artists,
            album: album,
            duration: duration,
            isExplicit: explicit
        )
    }

    private func parseArtistItem(_ renderer: MusicResponsiveListItemRenderer) -> ArtistItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }

        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        return ArtistItem(
            id: browseId,
            title: title,
            thumbnails: thumbnails
        )
    }

    private func parseAlbumItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> AlbumItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }

        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        let artists = secondaryLine?[safe: 1]?.oddElements().compactMap { run -> ArtistItem? in
            guard let artistBrowseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: artistBrowseId, title: run.text)
        } ?? []

        let year = secondaryLine?[safe: 2]?.first?.text
        let explicit = renderer.badges?.contains(where: { $0.musicInlineBadgeRenderer?.icon?.iconType == "MUSIC_EXPLICIT_BADGE" }) == true

        return AlbumItem(
            id: browseId,
            title: title,
            thumbnails: thumbnails,
            browseId: browseId,
            artists: artists,
            year: year != nil ? Int(year!) : nil,
            isExplicit: explicit
        )
    }

    private func parsePlaylistItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> PlaylistItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        let playlistId = browseId.replacingOccurrences(of: "VL", with: "")
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }

        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        let author = secondaryLine?.first?.first.flatMap { run -> ArtistItem? in
            guard let authorBrowseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: authorBrowseId, title: run.text)
        }

        let songCountText = renderer.flexColumns[safe: 1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.last?.text ?? ""
        let songCount = Int(songCountText.components(separatedBy: " ").first ?? "")

        return PlaylistItem(
            id: playlistId,
            title: title,
            thumbnails: thumbnails,
            songCount: songCount,
            author: author
        )
    }

    private func parsePodcastItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> PodcastItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }

        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        let author = secondaryLine?.first?.first.flatMap { run -> ArtistItem? in
            guard let authorBrowseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: authorBrowseId, title: run.text)
        }

        return PodcastItem(
            id: browseId,
            title: title,
            thumbnails: thumbnails,
            author: author
        )
    }

    private func parseEpisodeItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> EpisodeItem? {
        guard let videoId = renderer.playlistItemData?.videoId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }

        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        let podcastInfo = secondaryLine?.first?.first.flatMap { run -> PodcastItem? in
            guard let podcastBrowseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return PodcastItem(id: podcastBrowseId, title: run.text)
        }

        let duration = secondaryLine?.last?.first?.text.parseTime()

        return EpisodeItem(
            id: videoId,
            title: title,
            thumbnails: thumbnails,
            podcast: podcastInfo,
            duration: duration
        )
    }

    // MARK: - Album Page Parsing

    private func parseAlbumPage(data: Data) throws -> AlbumPage {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(BrowseResponse.self, from: data)

        // Get playlist ID
        var playlistId = response.microformat?.microformatDataRenderer?.urlCanonical?.components(separatedBy: "=").last
        if playlistId == nil {
            playlistId = response.header?.musicDetailHeaderRenderer?.menu?.menuRenderer?.topLevelButtons?.first?
                .buttonRenderer?.navigationEndpoint?.watchPlaylistEndpoint?.playlistId
        }

        // Get header
        let tabs = response.contents?.singleColumnBrowseResultsRenderer?.tabs ?? response.contents?.twoColumnBrowseResultsRenderer?.tabs
        let section = tabs?.first?.tabRenderer?.content?.sectionListRenderer?.contents?.first
        let responsiveHeader = section?.musicResponsiveHeaderRenderer

        // Get album info
        let title = (responsiveHeader?.title ?? response.header?.musicDetailHeaderRenderer?.title)?.runs?.first?.text ?? ""
        let year = (responsiveHeader?.subtitle ?? response.header?.musicDetailHeaderRenderer?.subtitle)?.runs?.last?.text
        let thumbnailUrl = response.background?.musicThumbnailRenderer?.getThumbnailUrl() ?? response.header?.musicDetailHeaderRenderer?.thumbnail?.getThumbnailUrl() ?? ""
        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        let artists = responsiveHeader?.straplineTextOne?.runs?.oddElements().compactMap { run -> ArtistItem? in
            guard let browseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: browseId, title: run.text)
        } ?? response.header?.musicDetailHeaderRenderer?.subtitle?.runs?.splitBySeparator()[safe: 1]?.oddElements().compactMap { run -> ArtistItem? in
            guard let browseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: browseId, title: run.text)
        } ?? []

        let album = AlbumItem(
            id: response.header?.musicDetailHeaderRenderer?.title?.runs?.first?.navigationEndpoint?.browseEndpoint?.browseId ?? "",
            title: title,
            thumbnails: thumbnails,
            browseId: response.header?.musicDetailHeaderRenderer?.title?.runs?.first?.navigationEndpoint?.browseEndpoint?.browseId ?? "",
            artists: artists,
            year: year != nil ? Int(year!) : nil,
            isExplicit: false
        )

        // Get songs
        let shelfRenderer = tabs?.first?.tabRenderer?.content?.sectionListRenderer?.contents?.first?.musicShelfRenderer ??
            response.contents?.twoColumnBrowseResultsRenderer?.secondaryContents?.sectionListRenderer?.contents?.first?.musicShelfRenderer

        let songs = shelfRenderer?.contents?.compactMap { content -> SongItem? in
            guard let renderer = content.musicResponsiveListItemRenderer else { return nil }
            return parseSongFromAlbum(renderer, album: album)
        } ?? []

        return AlbumPage(album: album, songs: songs, otherVersions: [])
    }

    private func parseSongFromAlbum(_ renderer: MusicResponsiveListItemRenderer, album: AlbumItem) -> SongItem? {
        guard let videoId = renderer.playlistItemData?.videoId else { return nil }
        guard let title = PageHelper.extractRuns(from: renderer.flexColumns, typeLike: "MUSIC_VIDEO").first?.text else { return nil }

        var artists = PageHelper.extractRuns(from: renderer.flexColumns, typeLike: "MUSIC_PAGE_TYPE_ARTIST").compactMap { run -> ArtistItem? in
            guard let browseId = run.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
            return ArtistItem(id: browseId, title: run.text)
        }

        if artists.isEmpty {
            artists = album.artists
        }

        let duration = renderer.fixedColumns?.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text.parseTime()
        let thumbnailUrl = renderer.thumbnail?.getThumbnailUrl()
        let thumbnails: [Thumbnail]
        if let url = thumbnailUrl, !url.isEmpty {
            thumbnails = [Thumbnail(url: url)]
        } else if !album.thumbnails.isEmpty {
            thumbnails = album.thumbnails
        } else {
            thumbnails = []
        }
        let explicit = renderer.badges?.contains(where: { $0.musicInlineBadgeRenderer?.icon?.iconType == "MUSIC_EXPLICIT_BADGE" }) == true

        return SongItem(
            id: videoId,
            title: title,
            thumbnails: thumbnails,
            artists: artists,
            album: album,
            duration: duration,
            isExplicit: explicit
        )
    }

    // MARK: - Playlist Page Parsing

    private func parsePlaylistPage(data: Data) throws -> PlaylistPage {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(BrowseResponse.self, from: data)

        // Get playlist info from header
        let title: String
        let subtitle: Run?
        let thumbnailUrl: String

        if let detailHeader = response.header?.musicDetailHeaderRenderer {
            title = detailHeader.title?.runs?.first?.text ?? ""
            subtitle = detailHeader.subtitle?.runs?.first
            thumbnailUrl = detailHeader.thumbnail?.getThumbnailUrl() ?? ""
        } else if let responsiveHeader = response.header?.musicResponsiveHeaderRenderer {
            title = responsiveHeader.title?.runs?.first?.text ?? ""
            subtitle = responsiveHeader.subtitle?.runs?.first
            thumbnailUrl = responsiveHeader.thumbnail?.getThumbnailUrl() ?? ""
        } else {
            title = ""
            subtitle = nil
            thumbnailUrl = ""
        }

        let thumbnails = thumbnailUrl.isEmpty ? [] : [Thumbnail(url: thumbnailUrl)]

        let author: ArtistItem?
        if let sub = subtitle, let browseId = sub.navigationEndpoint?.browseEndpoint?.browseId {
            author = ArtistItem(id: browseId, title: sub.text)
        } else {
            author = nil
        }

        let playlist = PlaylistItem(
            id: "", // Will be filled from request
            title: title,
            thumbnails: thumbnails,
            author: author
        )

        // Get songs
        let tabs = response.contents?.singleColumnBrowseResultsRenderer?.tabs ?? response.contents?.twoColumnBrowseResultsRenderer?.tabs

        let musicShelfRenderer = tabs?.first?.tabRenderer?.content?.sectionListRenderer?.contents?.first?.musicShelfRenderer
        let playlistShelfRenderer = tabs?.first?.tabRenderer?.content?.sectionListRenderer?.contents?.first?.musicPlaylistShelfRenderer

        var songs: [SongItem] = []
        var continuation: String?

        if let musicShelf = musicShelfRenderer {
            songs = musicShelf.contents?.compactMap { content -> SongItem? in
                guard let renderer = content.musicResponsiveListItemRenderer else { return nil }
                return parseSongItem(renderer, secondaryLine: renderer.flexColumns[safe: 1]?
                    .musicResponsiveListItemFlexColumnRenderer?.text?.runs?.splitBySeparator())
            } ?? []
            continuation = musicShelf.continuations?.first?.token
        } else if let playlistShelf = playlistShelfRenderer {
            songs = playlistShelf.contents?.compactMap { content -> SongItem? in
                guard let renderer = content.musicResponsiveListItemRenderer else { return nil }
                return parseSongItem(renderer, secondaryLine: renderer.flexColumns[safe: 1]?
                    .musicResponsiveListItemFlexColumnRenderer?.text?.runs?.splitBySeparator())
            } ?? []
            continuation = playlistShelf.continuations?.first?.token
        }

        return PlaylistPage(playlist: playlist, songs: songs, continuation: continuation)
    }

    // MARK: - Account Info Parsing

    private func parseAccountInfo(data: Data) throws -> AccountInfo {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(AccountMenuResponse.self, from: data)

        let header = response.actions?.first?.openPopupAction?.popup?.multiPageMenuRenderer?.header?.activeAccountHeaderRenderer

        let name = header?.accountName?.runs?.first?.text ?? "Unknown"
        let email = header?.email?.runs?.first?.text
        let channelHandle = header?.channelHandle?.runs?.first?.text
        let thumbnailUrl = header?.accountPhoto?.thumbnails?.last?.url

        return AccountInfo(name: name, email: email, channelHandle: channelHandle, thumbnailUrl: thumbnailUrl)
    }

    // MARK: - Other Stub Parsers (to be implemented)

    private func parseArtistPage(data: Data) throws -> ArtistPage {
        let placeholder = ArtistItem(id: "", title: "")
        return ArtistPage(artist: placeholder, sections: [])
    }

    private func parseHomePage(data: Data) throws -> HomePage {
        HomePage()
    }

    private func parseExplorePage(data: Data) throws -> ExplorePage {
        ExplorePage()
    }

    private func parseNextResult(data: Data) throws -> NextResult {
        NextResult()
    }

    private func parseQueueResponse(data: Data) throws -> [SongItem] {
        []
    }

    private func parseBrowseContinuationItems(data: Data) throws -> BrowseContinuationResult {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(BrowseResponse.self, from: data)

        var items: [any YTItem] = []
        var continuation: String?

        if let continuationContents = response.continuationContents {
            if let musicShelfContinuation = continuationContents.musicShelfContinuation {
                items = musicShelfContinuation.contents.compactMap { content -> (any YTItem)? in
                    guard let renderer = content.musicResponsiveListItemRenderer else { return nil }
                    return toYTItem(renderer)
                }
                continuation = musicShelfContinuation.continuations?.first?.token
            } else if let playlistContinuation = continuationContents.musicPlaylistShelfContinuation {
                items = playlistContinuation.contents.compactMap { content -> (any YTItem)? in
                    guard let renderer = content.musicResponsiveListItemRenderer else { return nil }
                    return toYTItem(renderer)
                }
                continuation = playlistContinuation.continuations?.first?.token
            }
        }

        return BrowseContinuationResult(items: items, continuation: continuation)
    }
}
