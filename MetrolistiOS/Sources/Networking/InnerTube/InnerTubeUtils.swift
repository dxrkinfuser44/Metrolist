import Foundation
import MetrolistCore

// MARK: - String Parsing Extensions

extension String {
    /// Parse time string in format "MM:SS" or "HH:MM:SS" to seconds
    func parseTime() -> Int? {
        let parts = split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }
}

// MARK: - Run Array Extensions

extension Array where Element == Run {
    /// Split runs by bullet separator " • "
    func splitBySeparator() -> [[Run]] {
        var result: [[Run]] = []
        var temp: [Run] = []

        for run in self {
            if run.text == " • " {
                result.append(temp)
                temp = []
            } else {
                temp.append(run)
            }
        }
        result.append(temp)
        return result
    }

    /// Get odd-indexed elements (used for extracting artists from runs)
    func oddElements() -> [Run] {
        enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
    }

    /// Clean runs by removing first group if it doesn't have navigation or contains & or comma
    func cleaned() -> [[Run]] {
        let split = splitBySeparator()
        if let first = split.first?.first {
            if first.navigationEndpoint != nil || first.text.range(of: "[&,]", options: .regularExpression) != nil {
                return split
            }
        }
        if split.count > 1 {
            var result = split
            result.removeFirst()
            return result
        }
        return []
    }
}

// MARK: - PageHelper for Token Extraction

public struct PageHelper {
    // Icon types for library management (YouTube changed these in Feb 2026)
    private static let LIBRARY_ADD_ICONS: Set<String> = ["LIBRARY_ADD", "BOOKMARK_BORDER"]
    private static let LIBRARY_SAVED_ICONS: Set<String> = ["LIBRARY_SAVED", "BOOKMARK", "LIBRARY_REMOVE"]
    private static let ALL_LIBRARY_ICONS = LIBRARY_ADD_ICONS.union(LIBRARY_SAVED_ICONS)

    public struct LibraryFeedbackTokens {
        public let addToken: String?
        public let removeToken: String?

        public init(addToken: String?, removeToken: String?) {
            self.addToken = addToken
            self.removeToken = removeToken
        }
    }

    /// Check if an icon type is a library-related icon
    public static func isLibraryIcon(_ iconType: String?) -> Bool {
        guard let iconType = iconType else { return false }
        // Exclude KEEP/KEEP_OFF (Listen Again pins)
        if iconType == "KEEP" || iconType == "KEEP_OFF" { return false }
        return ALL_LIBRARY_ICONS.contains(iconType) || iconType.hasPrefix("LIBRARY_")
    }

    /// Check if an icon type indicates the song is NOT in library
    public static func isAddLibraryIcon(_ iconType: String?) -> Bool {
        guard let iconType = iconType else { return false }
        return LIBRARY_ADD_ICONS.contains(iconType)
    }

    /// Check if an icon type indicates the song IS in library
    public static func isSavedLibraryIcon(_ iconType: String?) -> Bool {
        guard let iconType = iconType else { return false }
        return LIBRARY_SAVED_ICONS.contains(iconType)
    }

    /// Extract runs from flex columns that match a specific type (e.g., "MUSIC_PAGE_TYPE_ARTIST")
    public static func extractRuns(from columns: [FlexColumn], typeLike: String) -> [Run] {
        var filteredRuns: [Run] = []

        for column in columns {
            guard let runs = column.musicResponsiveListItemFlexColumnRenderer?.text?.runs else { continue }

            for run in runs {
                let typeStr = run.navigationEndpoint?.watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType
                    ?? run.navigationEndpoint?.browseEndpoint?.browseEndpointContextSupportedConfigs?.browseEndpointContextMusicConfig?.pageType
                    ?? ""

                if typeStr.contains(typeLike) {
                    filteredRuns.append(run)
                }
            }
        }
        return filteredRuns
    }

    /// Extract library feedback tokens from menu items
    public static func extractLibraryTokensFromMenuItems(_ menuItems: [Menu.MenuRenderer.Item]?) -> LibraryFeedbackTokens {
        guard let menuItems = menuItems else {
            return LibraryFeedbackTokens(addToken: nil, removeToken: nil)
        }

        var addToken: String?
        var removeToken: String?

        for item in menuItems {
            guard let toggleRenderer = item.toggleMenuServiceItemRenderer else { continue }
            let iconType = toggleRenderer.defaultIcon.iconType

            // Skip KEEP/KEEP_OFF icons
            if iconType == "KEEP" || iconType == "KEEP_OFF" { continue }

            // Only process library-related icons
            guard isLibraryIcon(iconType) else { continue }

            let defaultToken = toggleRenderer.defaultServiceEndpoint.feedbackEndpoint?.feedbackToken
            let toggledToken = toggleRenderer.toggledServiceEndpoint?.feedbackEndpoint?.feedbackToken

            // Determine which token is which based on icon type
            if isAddLibraryIcon(iconType) {
                // BOOKMARK_BORDER or LIBRARY_ADD: default=add, toggled=remove
                if addToken == nil { addToken = defaultToken }
                if removeToken == nil { removeToken = toggledToken }
            } else if isSavedLibraryIcon(iconType) {
                // BOOKMARK or LIBRARY_SAVED/REMOVE: default=remove, toggled=add
                if removeToken == nil { removeToken = defaultToken }
                if addToken == nil { addToken = toggledToken }
            }
        }

        return LibraryFeedbackTokens(addToken: addToken, removeToken: removeToken)
    }
}
