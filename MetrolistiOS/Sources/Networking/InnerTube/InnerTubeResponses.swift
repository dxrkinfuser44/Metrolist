import Foundation

// MARK: - Response Structures

/// Response from the search endpoint
public struct SearchResponse: Codable, Sendable {
    public let contents: Contents?
    public let continuationContents: ContinuationContents?

    public struct Contents: Codable, Sendable {
        public let tabbedSearchResultsRenderer: TabbedSearchResultsRenderer?

        public struct TabbedSearchResultsRenderer: Codable, Sendable {
            public let tabs: [Tab]?

            public struct Tab: Codable, Sendable {
                public let tabRenderer: TabRenderer?

                public struct TabRenderer: Codable, Sendable {
                    public let content: Content?

                    public struct Content: Codable, Sendable {
                        public let sectionListRenderer: SectionListRenderer?
                    }
                }
            }
        }
    }

    public struct ContinuationContents: Codable, Sendable {
        public let musicShelfContinuation: MusicShelfContinuation

        public struct MusicShelfContinuation: Codable, Sendable {
            public let contents: [Content]
            public let continuations: [Continuation]?

            public struct Content: Codable, Sendable {
                public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer
            }
        }
    }
}

/// Response from browse endpoint (albums, artists, playlists, home, etc.)
public struct BrowseResponse: Codable, Sendable {
    public let contents: Contents?
    public let header: Header?
    public let background: Background?
    public let continuationContents: ContinuationContents?
    public let microformat: Microformat?

    public struct Contents: Codable, Sendable {
        public let singleColumnBrowseResultsRenderer: SingleColumnBrowseResultsRenderer?
        public let twoColumnBrowseResultsRenderer: TwoColumnBrowseResultsRenderer?

        public struct SingleColumnBrowseResultsRenderer: Codable, Sendable {
            public let tabs: [Tab]?
        }

        public struct TwoColumnBrowseResultsRenderer: Codable, Sendable {
            public let tabs: [Tab]?
            public let secondaryContents: SecondaryContents?

            public struct SecondaryContents: Codable, Sendable {
                public let sectionListRenderer: SectionListRenderer?
            }
        }

        public struct Tab: Codable, Sendable {
            public let tabRenderer: TabRenderer?

            public struct TabRenderer: Codable, Sendable {
                public let content: Content?

                public struct Content: Codable, Sendable {
                    public let sectionListRenderer: SectionListRenderer?
                }
            }
        }
    }

    public struct Header: Codable, Sendable {
        public let musicDetailHeaderRenderer: MusicDetailHeaderRenderer?
        public let musicResponsiveHeaderRenderer: MusicResponsiveHeaderRenderer?
        public let musicImmersiveHeaderRenderer: MusicImmersiveHeaderRenderer?

        public struct MusicDetailHeaderRenderer: Codable, Sendable {
            public let title: Runs?
            public let subtitle: Runs?
            public let thumbnail: ThumbnailRenderer?
            public let menu: Menu?
        }

        public struct MusicImmersiveHeaderRenderer: Codable, Sendable {
            public let title: Runs?
            public let subscriptionButton: SubscriptionButton?
            public let thumbnail: ThumbnailRenderer?

            public struct SubscriptionButton: Codable, Sendable {
                public let subscribeButtonRenderer: SubscribeButtonRenderer?

                public struct SubscribeButtonRenderer: Codable, Sendable {
                    public let subscriberCountText: Runs?
                }
            }
        }
    }

    public struct Background: Codable, Sendable {
        public let musicThumbnailRenderer: ThumbnailRenderer.MusicThumbnailRenderer?
    }

    public struct ContinuationContents: Codable, Sendable {
        public let musicShelfContinuation: MusicShelfContinuation?
        public let musicPlaylistShelfContinuation: MusicPlaylistShelfContinuation?
        public let gridContinuation: GridContinuation?
        public let sectionListContinuation: SectionListContinuation?

        public struct MusicShelfContinuation: Codable, Sendable {
            public let contents: [Content]
            public let continuations: [Continuation]?

            public struct Content: Codable, Sendable {
                public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
            }
        }

        public struct MusicPlaylistShelfContinuation: Codable, Sendable {
            public let contents: [Content]
            public let continuations: [Continuation]?

            public struct Content: Codable, Sendable {
                public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
            }
        }

        public struct GridContinuation: Codable, Sendable {
            public let items: [Item]
            public let continuations: [Continuation]?

            public struct Item: Codable, Sendable {
                public let musicTwoRowItemRenderer: MusicTwoRowItemRenderer?
            }
        }

        public struct SectionListContinuation: Codable, Sendable {
            public let contents: [Content]
            public let continuations: [Continuation]?

            public struct Content: Codable, Sendable {
                public let musicCarouselShelfRenderer: MusicCarouselShelfRenderer?
                public let musicShelfRenderer: MusicShelfRenderer?
            }
        }
    }

    public struct Microformat: Codable, Sendable {
        public let microformatDataRenderer: MicroformatDataRenderer?

        public struct MicroformatDataRenderer: Codable, Sendable {
            public let urlCanonical: String?
        }
    }
}

// MARK: - Common Renderer Structures

/// Responsive header used in album/playlist pages
public struct MusicResponsiveHeaderRenderer: Codable, Sendable {
    public let title: Runs?
    public let subtitle: Runs?
    public let straplineTextOne: Runs?
    public let thumbnail: ThumbnailRenderer?
}

/// Section list renderer containing multiple content sections
public struct SectionListRenderer: Codable, Sendable {
    public let contents: [Content]?
    public let continuations: [Continuation]?

    public struct Content: Codable, Sendable {
        public let musicResponsiveHeaderRenderer: MusicResponsiveHeaderRenderer?
        public let musicShelfRenderer: MusicShelfRenderer?
        public let musicCarouselShelfRenderer: MusicCarouselShelfRenderer?
        public let musicPlaylistShelfRenderer: MusicPlaylistShelfRenderer?
        public let gridRenderer: GridRenderer?
        public let musicCardShelfRenderer: MusicCardShelfRenderer?
        public let musicDescriptionShelfRenderer: MusicDescriptionShelfRenderer?
    }
}

/// Music shelf renderer for vertical lists
public struct MusicShelfRenderer: Codable, Sendable {
    public let title: Runs?
    public let contents: [Content]?
    public let continuations: [Continuation]?
    public let bottomText: Runs?

    public struct Content: Codable, Sendable {
        public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    }
}

/// Music carousel shelf renderer for horizontal scrolling sections
public struct MusicCarouselShelfRenderer: Codable, Sendable {
    public let header: Header?
    public let contents: [Content]?

    public struct Header: Codable, Sendable {
        public let musicCarouselShelfBasicHeaderRenderer: MusicCarouselShelfBasicHeaderRenderer?

        public struct MusicCarouselShelfBasicHeaderRenderer: Codable, Sendable {
            public let title: Runs?
            public let accessibilityData: AccessibilityData?
            public let moreContentButton: MoreContentButton?

            public struct AccessibilityData: Codable, Sendable {
                public let accessibilityData: Label?

                public struct Label: Codable, Sendable {
                    public let label: String?
                }
            }

            public struct MoreContentButton: Codable, Sendable {
                public let buttonRenderer: ButtonRenderer?

                public struct ButtonRenderer: Codable, Sendable {
                    public let navigationEndpoint: NavigationEndpoint?
                }
            }
        }
    }

    public struct Content: Codable, Sendable {
        public let musicTwoRowItemRenderer: MusicTwoRowItemRenderer?
        public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    }
}

/// Music two-row item renderer for grid/carousel items
public struct MusicTwoRowItemRenderer: Codable, Sendable {
    public let title: Runs?
    public let subtitle: Runs?
    public let thumbnailRenderer: ThumbnailRenderer?
    public let navigationEndpoint: NavigationEndpoint?
    public let menu: Menu?
    public let thumbnailOverlay: ThumbnailOverlay?

    public struct ThumbnailOverlay: Codable, Sendable {
        public let musicItemThumbnailOverlayRenderer: MusicItemThumbnailOverlayRenderer?

        public struct MusicItemThumbnailOverlayRenderer: Codable, Sendable {
            public let content: Content?

            public struct Content: Codable, Sendable {
                public let musicPlayButtonRenderer: MusicPlayButtonRenderer?

                public struct MusicPlayButtonRenderer: Codable, Sendable {
                    public let playNavigationEndpoint: NavigationEndpoint?
                }
            }
        }
    }
}

/// Grid renderer for grid layouts
public struct GridRenderer: Codable, Sendable {
    public let items: [Item]?
    public let header: Header?
    public let continuations: [Continuation]?

    public struct Item: Codable, Sendable {
        public let musicTwoRowItemRenderer: MusicTwoRowItemRenderer?
        public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    }

    public struct Header: Codable, Sendable {
        public let gridHeaderRenderer: GridHeaderRenderer?

        public struct GridHeaderRenderer: Codable, Sendable {
            public let title: Runs?
        }
    }
}

/// Music card shelf renderer for top results in search
public struct MusicCardShelfRenderer: Codable, Sendable {
    public let title: Runs?
    public let contents: [Content]?
    public let header: Header?

    public struct Content: Codable, Sendable {
        public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    }

    public struct Header: Codable, Sendable {
        public let musicCardShelfHeaderBasicRenderer: MusicCardShelfHeaderBasicRenderer?

        public struct MusicCardShelfHeaderBasicRenderer: Codable, Sendable {
            public let title: Runs?
        }
    }
}

/// Music description shelf renderer for descriptions
public struct MusicDescriptionShelfRenderer: Codable, Sendable {
    public let description: Runs?
}

/// Music playlist shelf renderer for playlist contents
public struct MusicPlaylistShelfRenderer: Codable, Sendable {
    public let contents: [Content]?
    public let continuations: [Continuation]?

    public struct Content: Codable, Sendable {
        public let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    }
}
