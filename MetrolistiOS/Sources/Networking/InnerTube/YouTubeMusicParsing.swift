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

        let libraryTokens = PageHelper.extractLibraryTokensFromMenuItems(renderer.menu?.menuRenderer?.items)

        let artists = secondaryLine?.first?.oddElements().map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        } ?? []

        let album = secondaryLine?[safe: 1]?.first(where: { $0.navigationEndpoint?.browseEndpoint != nil }).map {
            Album(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        }

        let duration = secondaryLine?.last?.first?.text.parseTime()
        let thumbnail = renderer.thumbnail?.getThumbnailUrl() ?? ""
        let explicit = renderer.badges?.contains(where: { $0.musicInlineBadgeRenderer?.icon?.iconType == "MUSIC_EXPLICIT_BADGE" }) == true

        return SongItem(
            id: videoId,
            title: title,
            artists: artists,
            album: album,
            duration: duration,
            thumbnail: thumbnail,
            explicit: explicit,
            libraryAddToken: libraryTokens.addToken,
            libraryRemoveToken: libraryTokens.removeToken,
            musicVideoType: renderer.musicVideoType
        )
    }

    private func parseArtistItem(_ renderer: MusicResponsiveListItemRenderer) -> ArtistItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }
        guard let thumbnail = renderer.thumbnail?.getThumbnailUrl() else { return nil }

        let shuffleEndpoint = renderer.menu?.menuRenderer?.items?.first(where: {
            $0.menuNavigationItemRenderer?.icon?.iconType == "MUSIC_SHUFFLE"
        })?.menuNavigationItemRenderer?.navigationEndpoint?.watchPlaylistEndpoint

        let radioEndpoint = renderer.menu?.menuRenderer?.items?.first(where: {
            $0.menuNavigationItemRenderer?.icon?.iconType == "MIX"
        })?.menuNavigationItemRenderer?.navigationEndpoint?.watchPlaylistEndpoint

        return ArtistItem(
            id: browseId,
            title: title,
            thumbnail: thumbnail,
            shuffleEndpoint: shuffleEndpoint,
            radioEndpoint: radioEndpoint
        )
    }

    private func parseAlbumItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> AlbumItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }
        guard let thumbnail = renderer.thumbnail?.getThumbnailUrl() else { return nil }

        let playlistId = renderer.overlay?.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint?.anyWatchEndpoint?.playlistId

        let artists = secondaryLine?[safe: 1]?.oddElements().map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        } ?? []

        let year = secondaryLine?[safe: 2]?.first?.text
        let explicit = renderer.badges?.contains(where: { $0.musicInlineBadgeRenderer?.icon?.iconType == "MUSIC_EXPLICIT_BADGE" }) == true

        return AlbumItem(
            id: browseId,
            playlistId: playlistId,
            title: title,
            artists: artists,
            year: year != nil ? Int(year!) : nil,
            thumbnail: thumbnail,
            explicit: explicit
        )
    }

    private func parsePlaylistItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> PlaylistItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        let playlistId = browseId.replacingOccurrences(of: "VL", with: "")
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }
        guard let thumbnail = renderer.thumbnail?.getThumbnailUrl() else { return nil }

        let author = secondaryLine?.first?.first.map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        }

        let songCountText = renderer.flexColumns[safe: 1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.last?.text ?? ""

        let playEndpoint = renderer.overlay?.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint?.watchPlaylistEndpoint

        let shuffleEndpoint = renderer.menu?.menuRenderer?.items?.first(where: {
            $0.menuNavigationItemRenderer?.icon?.iconType == "MUSIC_SHUFFLE"
        })?.menuNavigationItemRenderer?.navigationEndpoint?.watchPlaylistEndpoint

        let radioEndpoint = renderer.menu?.menuRenderer?.items?.first(where: {
            $0.menuNavigationItemRenderer?.icon?.iconType == "MIX"
        })?.menuNavigationItemRenderer?.navigationEndpoint?.watchPlaylistEndpoint

        return PlaylistItem(
            id: playlistId,
            title: title,
            author: author,
            songCountText: songCountText,
            thumbnail: thumbnail,
            playEndpoint: playEndpoint,
            shuffleEndpoint: shuffleEndpoint,
            radioEndpoint: radioEndpoint
        )
    }

    private func parsePodcastItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> PodcastItem? {
        guard let browseId = renderer.navigationEndpoint?.browseEndpoint?.browseId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }
        guard let thumbnail = renderer.thumbnail?.getThumbnailUrl() else { return nil }

        let author = secondaryLine?.first?.first.map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        }

        return PodcastItem(
            id: browseId,
            title: title,
            author: author,
            thumbnail: thumbnail
        )
    }

    private func parseEpisodeItem(_ renderer: MusicResponsiveListItemRenderer, secondaryLine: [[Run]]?) -> EpisodeItem? {
        guard let videoId = renderer.playlistItemData?.videoId else { return nil }
        guard let title = renderer.flexColumns.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text else { return nil }
        guard let thumbnail = renderer.thumbnail?.getThumbnailUrl() else { return nil }

        let author = secondaryLine?.first?.first.map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        }

        let duration = secondaryLine?.last?.first?.text.parseTime()

        return EpisodeItem(
            id: videoId,
            title: title,
            author: author,
            duration: duration,
            thumbnail: thumbnail
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
        let thumbnail = response.background?.musicThumbnailRenderer?.getThumbnailUrl() ?? response.header?.musicDetailHeaderRenderer?.thumbnail?.getThumbnailUrl() ?? ""

        let artists = responsiveHeader?.straplineTextOne?.runs?.oddElements().map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        } ?? response.header?.musicDetailHeaderRenderer?.subtitle?.runs?.splitBySeparator()[safe: 1]?.oddElements().map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        } ?? []

        let album = AlbumItem(
            id: response.header?.musicDetailHeaderRenderer?.title?.runs?.first?.navigationEndpoint?.browseEndpoint?.browseId ?? "",
            playlistId: playlistId,
            title: title,
            artists: artists,
            year: year != nil ? Int(year!) : nil,
            thumbnail: thumbnail,
            explicit: false
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

        let libraryTokens = PageHelper.extractLibraryTokensFromMenuItems(renderer.menu?.menuRenderer?.items)

        var artists = PageHelper.extractRuns(from: renderer.flexColumns, typeLike: "MUSIC_PAGE_TYPE_ARTIST").map {
            Artist(name: $0.text, id: $0.navigationEndpoint?.browseEndpoint?.browseId)
        }

        if artists.isEmpty {
            artists = album.artists
        }

        let duration = renderer.fixedColumns?.first?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text.parseTime()
        let thumbnail = renderer.thumbnail?.getThumbnailUrl() ?? album.thumbnail
        let explicit = renderer.badges?.contains(where: { $0.musicInlineBadgeRenderer?.icon?.iconType == "MUSIC_EXPLICIT_BADGE" }) == true

        return SongItem(
            id: videoId,
            title: title,
            artists: artists,
            album: Album(name: album.title, id: album.id),
            duration: duration,
            thumbnail: thumbnail,
            explicit: explicit,
            libraryAddToken: libraryTokens.addToken,
            libraryRemoveToken: libraryTokens.removeToken,
            musicVideoType: renderer.musicVideoType
        )
    }

    // MARK: - Playlist Page Parsing

    private func parsePlaylistPage(data: Data) throws -> PlaylistPage {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(BrowseResponse.self, from: data)

        // Get playlist info from header
        let header = response.header?.musicDetailHeaderRenderer ?? response.header?.musicResponsiveHeaderRenderer
        let title = header?.title?.runs?.first?.text ?? ""
        let subtitle = header?.subtitle?.runs?.first

        let playlist = PlaylistItem(
            id: "", // Will be filled from request
            title: title,
            author: subtitle != nil ? Artist(name: subtitle!.text, id: subtitle!.navigationEndpoint?.browseEndpoint?.browseId) : nil,
            songCountText: "",
            thumbnail: header?.thumbnail?.getThumbnailUrl() ?? "",
            playEndpoint: nil,
            shuffleEndpoint: nil,
            radioEndpoint: nil
        )

        // Get songs
        let tabs = response.contents?.singleColumnBrowseResultsRenderer?.tabs ?? response.contents?.twoColumnBrowseResultsRenderer?.tabs
        let shelfRenderer = tabs?.first?.tabRenderer?.content?.sectionListRenderer?.contents?.first?.musicShelfRenderer ??
            tabs?.first?.tabRenderer?.content?.sectionListRenderer?.contents?.first?.musicPlaylistShelfRenderer

        let songs = shelfRenderer?.contents?.compactMap { content -> SongItem? in
            guard let renderer = content.musicResponsiveListItemRenderer else { return nil }
            return parseSongItem(renderer, secondaryLine: renderer.flexColumns[safe: 1]?
                .musicResponsiveListItemFlexColumnRenderer?.text?.runs?.splitBySeparator())
        } ?? []

        let continuation = shelfRenderer?.continuations?.first?.token

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
