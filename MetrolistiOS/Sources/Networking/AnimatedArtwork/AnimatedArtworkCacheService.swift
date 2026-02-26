import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import MetrolistCore

// MARK: - Animated Artwork Cache Service

/// Thread-safe cache for downloaded animated artwork video files.
/// Uses SHA-256 hashing for filenames, stores in Application Support,
/// auto-expires after 30 days.
public actor AnimatedArtworkCacheService {
    public static let shared = AnimatedArtworkCacheService()

    private let cacheDirectory: URL
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private let session: URLSession
    private var activeDownloads: [String: Task<URL, Error>] = [:]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("AnimatedArtwork", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Interface

    /// Get the cached video file URL for an album, downloading if necessary.
    /// Returns the local file URL, or nil if the download fails.
    public func getOrDownload(albumId: String, videoURL: URL) async throws -> URL {
        let fileURL = fileURL(for: albumId)

        // Check if already cached and valid
        if isValid(fileURL: fileURL) {
            MetrolistLogger.animatedArtwork.debug("Cache hit for album: \(albumId)")
            return fileURL
        }

        // Check if download is already in progress
        if let existingTask = activeDownloads[albumId] {
            return try await existingTask.value
        }

        // Start new download
        let downloadTask = Task<URL, Error> {
            defer { activeDownloads[albumId] = nil }

            let (tempURL, response) = try await session.download(from: videoURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw AnimatedArtworkError.networkError("Download failed")
            }

            // Move to cache directory
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
            try fm.moveItem(at: tempURL, to: fileURL)

            MetrolistLogger.animatedArtwork.info("Cached animated artwork for album: \(albumId)")
            return fileURL
        }

        activeDownloads[albumId] = downloadTask
        return try await downloadTask.value
    }

    /// Check if a cached file exists and is valid for an album.
    public func hasCachedArtwork(for albumId: String) -> Bool {
        isValid(fileURL: fileURL(for: albumId))
    }

    /// Remove cached artwork for a specific album.
    public func removeCachedArtwork(for albumId: String) {
        let url = fileURL(for: albumId)
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove all expired cache entries.
    public func pruneExpiredEntries() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }

        let cutoff = Date.now.addingTimeInterval(-maxAge)
        var removedCount = 0

        for file in files {
            guard let attributes = try? fm.attributesOfItem(atPath: file.path),
                  let creationDate = attributes[.creationDate] as? Date else { continue }

            if creationDate < cutoff {
                try? fm.removeItem(at: file)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            MetrolistLogger.animatedArtwork.info("Pruned \(removedCount) expired artwork cache entries")
        }
    }

    /// Remove all cached artwork files.
    public func clearCache() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
        MetrolistLogger.animatedArtwork.info("Cleared animated artwork cache")
    }

    /// Total size of the cache in bytes.
    public var cacheSize: Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }

        return files.reduce(Int64(0)) { total, file in
            let size = (try? fm.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }

    // MARK: - Private

    private func fileURL(for albumId: String) -> URL {
        let hash = SHA256.hash(data: Data(albumId.utf8))
        let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(filename).mp4")
    }

    private func isValid(fileURL: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return false }

        // Check age
        guard let attributes = try? fm.attributesOfItem(atPath: fileURL.path),
              let creationDate = attributes[.creationDate] as? Date else { return false }

        let age = Date.now.timeIntervalSince(creationDate)
        guard age < maxAge else {
            // Auto-remove expired file
            try? fm.removeItem(at: fileURL)
            return false
        }

        // Check file is not empty / corrupted
        guard let size = attributes[.size] as? Int64, size > 1024 else {
            try? fm.removeItem(at: fileURL)
            return false
        }

        return true
    }
}
