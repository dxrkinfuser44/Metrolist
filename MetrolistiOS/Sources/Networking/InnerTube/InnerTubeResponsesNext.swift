import Foundation

// MARK: - Next Response (Watch/Queue)

public struct NextResponse: Codable, Sendable {
    public let contents: Contents?
    public let continuationContents: ContinuationContents?

    public struct Contents: Codable, Sendable {
        public let singleColumnMusicWatchNextResultsRenderer: SingleColumnMusicWatchNextResultsRenderer?

        public struct SingleColumnMusicWatchNextResultsRenderer: Codable, Sendable {
            public let tabbedRenderer: TabbedRenderer?

            public struct TabbedRenderer: Codable, Sendable {
                public let watchNextTabbedResultsRenderer: WatchNextTabbedResultsRenderer?

                public struct WatchNextTabbedResultsRenderer: Codable, Sendable {
                    public let tabs: [Tab]?

                    public struct Tab: Codable, Sendable {
                        public let tabRenderer: TabRenderer?

                        public struct TabRenderer: Codable, Sendable {
                            public let content: Content?

                            public struct Content: Codable, Sendable {
                                public let musicQueueRenderer: MusicQueueRenderer?

                                public struct MusicQueueRenderer: Codable, Sendable {
                                    public let content: Content?

                                    public struct Content: Codable, Sendable {
                                        public let playlistPanelRenderer: PlaylistPanelRenderer?
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public struct ContinuationContents: Codable, Sendable {
        public let playlistPanelContinuation: PlaylistPanelContinuation?

        public struct PlaylistPanelContinuation: Codable, Sendable {
            public let contents: [Content]
            public let continuations: [Continuation]?

            public struct Content: Codable, Sendable {
                public let playlistPanelVideoRenderer: PlaylistPanelVideoRenderer?
            }
        }
    }
}

/// Playlist panel renderer for queue items
public struct PlaylistPanelRenderer: Codable, Sendable {
    public let contents: [Content]?
    public let continuations: [Continuation]?
    public let playlistId: String?
    public let isInfinite: Bool?

    public struct Content: Codable, Sendable {
        public let playlistPanelVideoRenderer: PlaylistPanelVideoRenderer?
        public let automixPreviewVideoRenderer: AutomixPreviewVideoRenderer?
    }

    public struct AutomixPreviewVideoRenderer: Codable, Sendable {
        public let content: Content?

        public struct Content: Codable, Sendable {
            public let automixPlaylistVideoRenderer: AutomixPlaylistVideoRenderer?

            public struct AutomixPlaylistVideoRenderer: Codable, Sendable {
                public let navigationEndpoint: NavigationEndpoint?
            }
        }
    }
}

/// Playlist panel video renderer for individual queue items
public struct PlaylistPanelVideoRenderer: Codable, Sendable {
    public let title: Runs?
    public let longBylineText: Runs?
    public let shortBylineText: Runs?
    public let lengthText: Runs?
    public let thumbnail: ThumbnailRenderer?
    public let videoId: String?
    public let navigationEndpoint: NavigationEndpoint?
    public let menu: Menu?
    public let badges: [Badges]?
}

// MARK: - Get Queue Response

public struct GetQueueResponse: Codable, Sendable {
    public let queueDatas: [QueueData]?

    public struct QueueData: Codable, Sendable {
        public let content: Content?

        public struct Content: Codable, Sendable {
            public let playlistPanelRenderer: PlaylistPanelRenderer?
        }
    }
}

// MARK: - Account Menu Response

public struct AccountMenuResponse: Codable, Sendable {
    public let actions: [Action]?

    public struct Action: Codable, Sendable {
        public let openPopupAction: OpenPopupAction?

        public struct OpenPopupAction: Codable, Sendable {
            public let popup: Popup?

            public struct Popup: Codable, Sendable {
                public let multiPageMenuRenderer: MultiPageMenuRenderer?

                public struct MultiPageMenuRenderer: Codable, Sendable {
                    public let header: Header?

                    public struct Header: Codable, Sendable {
                        public let activeAccountHeaderRenderer: ActiveAccountHeaderRenderer?

                        public struct ActiveAccountHeaderRenderer: Codable, Sendable {
                            public let accountName: Runs?
                            public let email: Runs?
                            public let channelHandle: Runs?
                            public let accountPhoto: ThumbnailRenderer.Thumbnail?
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Get Search Suggestions Response

public struct GetSearchSuggestionsResponse: Codable, Sendable {
    public let contents: [[String: String]]?
}
