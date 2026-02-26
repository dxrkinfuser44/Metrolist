import Foundation
import MetrolistCore

// MARK: - InnerTube Response Models
// These models match the Android implementation for parsing YouTube Music InnerTube API responses

// MARK: - Core Text Models

public struct Runs: Codable, Sendable {
    public let runs: [Run]?
}

public struct Run: Codable, Sendable {
    public let text: String
    public let navigationEndpoint: NavigationEndpoint?
}

// MARK: - Navigation Endpoints

public struct NavigationEndpoint: Codable, Sendable {
    public let watchEndpoint: WatchEndpoint?
    public let watchPlaylistEndpoint: WatchEndpoint?
    public let browseEndpoint: BrowseEndpoint?
    public let searchEndpoint: SearchEndpoint?
    public let queueAddEndpoint: QueueAddEndpoint?
    public let shareEntityEndpoint: ShareEntityEndpoint?
    public let feedbackEndpoint: FeedbackEndpoint?
    public let urlEndpoint: URLEndpoint?

    public var anyWatchEndpoint: WatchEndpoint? {
        watchEndpoint ?? watchPlaylistEndpoint
    }

    public var musicVideoType: String? {
        anyWatchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType
    }
}

public struct WatchEndpoint: Codable, Sendable {
    public let videoId: String?
    public let playlistId: String?
    public let index: Int?
    public let watchEndpointMusicSupportedConfigs: WatchEndpointMusicSupportedConfigs?

    public struct WatchEndpointMusicSupportedConfigs: Codable, Sendable {
        public let watchEndpointMusicConfig: WatchEndpointMusicConfig?

        public struct WatchEndpointMusicConfig: Codable, Sendable {
            public let musicVideoType: String?
        }
    }
}

public struct BrowseEndpoint: Codable, Sendable {
    public let browseId: String?
    public let params: String?
    public let browseEndpointContextSupportedConfigs: BrowseEndpointContextSupportedConfigs?

    public struct BrowseEndpointContextSupportedConfigs: Codable, Sendable {
        public let browseEndpointContextMusicConfig: BrowseEndpointContextMusicConfig?

        public struct BrowseEndpointContextMusicConfig: Codable, Sendable {
            public let pageType: String?

            public static let MUSIC_PAGE_TYPE_ALBUM = "MUSIC_PAGE_TYPE_ALBUM"
            public static let MUSIC_PAGE_TYPE_ARTIST = "MUSIC_PAGE_TYPE_ARTIST"
            public static let MUSIC_PAGE_TYPE_PLAYLIST = "MUSIC_PAGE_TYPE_PLAYLIST"
            public static let MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE = "MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE"
            public static let MUSIC_PAGE_TYPE_NON_MUSIC_AUDIO_TRACK_PAGE = "MUSIC_PAGE_TYPE_NON_MUSIC_AUDIO_TRACK_PAGE"
            public static let MUSIC_PAGE_TYPE_LIBRARY_ARTIST = "MUSIC_PAGE_TYPE_LIBRARY_ARTIST"
            public static let MUSIC_PAGE_TYPE_AUDIOBOOK = "MUSIC_PAGE_TYPE_AUDIOBOOK"
        }
    }
}

public struct SearchEndpoint: Codable, Sendable {
    public let query: String?
}

public struct QueueAddEndpoint: Codable, Sendable {
    public let queueTarget: QueueTarget?

    public struct QueueTarget: Codable, Sendable {
        public let videoId: String?
    }
}

public struct ShareEntityEndpoint: Codable, Sendable {
    public let serializedShareEntity: String?
}

public struct FeedbackEndpoint: Codable, Sendable {
    public let feedbackToken: String?
}

public struct URLEndpoint: Codable, Sendable {
    public let url: String?
}

// MARK: - Thumbnails

public struct ThumbnailRenderer: Codable, Sendable {
    public let musicThumbnailRenderer: MusicThumbnailRenderer?
    public let croppedSquareThumbnailRenderer: CroppedSquareThumbnailRenderer?

    public struct MusicThumbnailRenderer: Codable, Sendable {
        public let thumbnail: Thumbnail?

        public func getThumbnailUrl() -> String? {
            thumbnail?.thumbnails?.last?.url
        }
    }

    public struct CroppedSquareThumbnailRenderer: Codable, Sendable {
        public let thumbnail: Thumbnail?

        public func getThumbnailUrl() -> String? {
            thumbnail?.thumbnails?.last?.url
        }
    }

    public struct Thumbnail: Codable, Sendable {
        public let thumbnails: [ThumbnailItem]?

        public struct ThumbnailItem: Codable, Sendable {
            public let url: String
            public let width: Int?
            public let height: Int?
        }
    }
}

extension ThumbnailRenderer {
    public func getThumbnailUrl() -> String? {
        musicThumbnailRenderer?.getThumbnailUrl() ?? croppedSquareThumbnailRenderer?.getThumbnailUrl()
    }
}

// MARK: - Menu Models

public struct Menu: Codable, Sendable {
    public let menuRenderer: MenuRenderer?

    public struct MenuRenderer: Codable, Sendable {
        public let items: [Item]?
        public let topLevelButtons: [TopLevelButton]?

        public struct Item: Codable, Sendable {
            public let menuNavigationItemRenderer: MenuNavigationItemRenderer?
            public let toggleMenuServiceItemRenderer: ToggleMenuServiceRenderer?
            public let menuServiceItemRenderer: MenuServiceItemRenderer?

            public struct MenuNavigationItemRenderer: Codable, Sendable {
                public let text: Runs?
                public let icon: Icon?
                public let navigationEndpoint: NavigationEndpoint?
            }

            public struct ToggleMenuServiceRenderer: Codable, Sendable {
                public let defaultText: Runs?
                public let defaultIcon: Icon
                public let defaultServiceEndpoint: ServiceEndpoint
                public let toggledText: Runs?
                public let toggledIcon: Icon?
                public let toggledServiceEndpoint: ServiceEndpoint?

                public struct ServiceEndpoint: Codable, Sendable {
                    public let feedbackEndpoint: FeedbackEndpoint?
                }
            }

            public struct MenuServiceItemRenderer: Codable, Sendable {
                public let text: Runs?
                public let icon: Icon?
                public let serviceEndpoint: ServiceEndpoint?

                public struct ServiceEndpoint: Codable, Sendable {
                    public let feedbackEndpoint: FeedbackEndpoint?
                }
            }
        }

        public struct TopLevelButton: Codable, Sendable {
            public let buttonRenderer: ButtonRenderer?

            public struct ButtonRenderer: Codable, Sendable {
                public let navigationEndpoint: NavigationEndpoint?
            }
        }
    }
}

public struct Icon: Codable, Sendable {
    public let iconType: String
}

// MARK: - Badges

public struct Badges: Codable, Sendable {
    public let musicInlineBadgeRenderer: MusicInlineBadgeRenderer?

    public struct MusicInlineBadgeRenderer: Codable, Sendable {
        public let icon: Icon?
    }
}

// MARK: - FlexColumn (for MusicResponsiveListItemRenderer)

public struct FlexColumn: Codable, Sendable {
    public let musicResponsiveListItemFlexColumnRenderer: MusicResponsiveListItemFlexColumnRenderer?

    public struct MusicResponsiveListItemFlexColumnRenderer: Codable, Sendable {
        public let text: Runs?
    }

    enum CodingKeys: String, CodingKey {
        case musicResponsiveListItemFlexColumnRenderer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both musicResponsiveListItemFlexColumnRenderer and musicResponsiveListItemFixedColumnRenderer
        if let flexRenderer = try? container.decode(MusicResponsiveListItemFlexColumnRenderer.self, forKey: .musicResponsiveListItemFlexColumnRenderer) {
            self.musicResponsiveListItemFlexColumnRenderer = flexRenderer
        } else {
            // Try as fixed column renderer (same structure)
            self.musicResponsiveListItemFlexColumnRenderer = try? MusicResponsiveListItemFlexColumnRenderer(from: decoder)
        }
    }
}

// MARK: - MusicResponsiveListItemRenderer

public struct MusicResponsiveListItemRenderer: Codable, Sendable {
    public let badges: [Badges]?
    public let fixedColumns: [FlexColumn]?
    public let flexColumns: [FlexColumn]
    public let thumbnail: ThumbnailRenderer?
    public let menu: Menu?
    public let playlistItemData: PlaylistItemData?
    public let overlay: Overlay?
    public let navigationEndpoint: NavigationEndpoint?

    public var isSong: Bool {
        navigationEndpoint == nil || navigationEndpoint?.watchEndpoint != nil || navigationEndpoint?.watchPlaylistEndpoint != nil
    }

    public var isPlaylist: Bool {
        navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_PLAYLIST
    }

    public var isAlbum: Bool {
        let pageType = navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType
        return pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_ALBUM ||
               pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_AUDIOBOOK
    }

    public var isArtist: Bool {
        let pageType = navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType
        return pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_ARTIST ||
               pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_LIBRARY_ARTIST
    }

    public var isPodcast: Bool {
        navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE
    }

    public var isEpisode: Bool {
        // Method 1: Check browse endpoint
        if navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_NON_MUSIC_AUDIO_TRACK_PAGE {
            return true
        }
        // Method 2: Check if first subtitle text is "Episode"
        let firstSubtitleText = flexColumns[safe: 1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.text
        if firstSubtitleText == "Episode" {
            return true
        }
        // Method 3: Check for podcast link in subtitle
        let hasPodcastLink = flexColumns[safe: 1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.contains { run in
            run.navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType == BrowseEndpoint.BrowseEndpointContextSupportedConfigs.BrowseEndpointContextMusicConfig.MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE
        } == true
        return hasPodcastLink && playlistItemData?.videoId != nil && navigationEndpoint == nil
    }

    public var musicVideoType: String? {
        overlay?.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint?.musicVideoType ?? navigationEndpoint?.musicVideoType
    }

    public struct PlaylistItemData: Codable, Sendable {
        public let playlistSetVideoId: String?
        public let videoId: String
    }

    public struct Overlay: Codable, Sendable {
        public let musicItemThumbnailOverlayRenderer: MusicItemThumbnailOverlayRenderer

        public struct MusicItemThumbnailOverlayRenderer: Codable, Sendable {
            public let content: Content

            public struct Content: Codable, Sendable {
                public let musicPlayButtonRenderer: MusicPlayButtonRenderer

                public struct MusicPlayButtonRenderer: Codable, Sendable {
                    public let playNavigationEndpoint: NavigationEndpoint?
                }
            }
        }
    }
}

// MARK: - Continuation

public struct Continuation: Codable, Sendable {
    public let nextContinuationData: NextContinuationData?
    public let nextRadioContinuationData: NextRadioContinuationData?

    public struct NextContinuationData: Codable, Sendable {
        public let continuation: String
    }

    public struct NextRadioContinuationData: Codable, Sendable {
        public let continuation: String
    }

    public var token: String? {
        nextContinuationData?.continuation ?? nextRadioContinuationData?.continuation
    }
}

// MARK: - Safe Array Access Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
