import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - String Extensions

public extension String {
    /// SHA-256 hash of the string, returned as a hex string.
    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// SHA-1 hash of the string, returned as a hex string.
    var sha1: String {
        let data = Data(self.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Removes common suffixes from song titles for better lyrics matching.
    var cleanedTitle: String {
        var result = self
        let suffixes = [
            "(Official Video)", "(Official Music Video)", "(Official Audio)",
            "(Lyric Video)", "(Lyrics)", "(Audio)", "(Visualizer)",
            "[Official Video]", "[Official Music Video]", "[Official Audio]",
            "[Lyric Video]", "[Lyrics]", "[Audio]", "[Visualizer]",
            "(MV)", "[MV]", "(Live)", "[Live]",
        ]
        for suffix in suffixes {
            result = result.replacingOccurrences(of: suffix, with: "", options: .caseInsensitive)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
