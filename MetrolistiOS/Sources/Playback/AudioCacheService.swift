import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MetrolistCore

// MARK: - Audio Cache Service

/// Manages on-disk caching of audio streams for offline playback.
/// Stores downloaded audio files in the app's Caches directory keyed by song ID.
public actor AudioCacheService {
    private let cacheDirectory: URL
    private let maxCacheSizeBytes: Int64

    /// Active downloads to prevent duplicate requests.
    private var activeDownloads: [String: Task<URL, Error>] = [:]

    public init(maxCacheSizeBytes: Int64 = 500 * 1024 * 1024) { // 500MB default
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("AudioCache", isDirectory: true)
        self.maxCacheSizeBytes = maxCacheSizeBytes

        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Returns the cached file URL if the song is already downloaded, nil otherwise.
    public func cachedURL(for songId: String) -> URL? {
        let fileURL = cacheFileURL(for: songId)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    /// Downloads and caches audio from the given stream URL. Returns the local file URL.
    /// Deduplicates concurrent requests for the same song.
    public func cacheAudio(songId: String, from streamURL: URL) async throws -> URL {
        // Return cached version if available
        if let cached = cachedURL(for: songId) {
            return cached
        }

        // Join existing download if in progress
        if let existingTask = activeDownloads[songId] {
            return try await existingTask.value
        }

        let task = Task<URL, Error> {
            defer { activeDownloads[songId] = nil }

            let (tempURL, response) = try await URLSession.shared.download(from: streamURL)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw CacheError.downloadFailed
            }

            let destURL = cacheFileURL(for: songId)
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            // Evict old entries if over size limit
            await evictIfNeeded()

            return destURL
        }

        activeDownloads[songId] = task
        return try await task.value
    }

    /// Remove a specific song from cache.
    public func removeCachedAudio(for songId: String) {
        let url = cacheFileURL(for: songId)
        try? FileManager.default.removeItem(at: url)
    }

    /// Total size of the audio cache in bytes.
    public func totalCacheSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles
        ) else { return 0 }

        return files.reduce(Int64(0)) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    /// Clear entire audio cache.
    public func clearCache() throws {
        try FileManager.default.removeItem(at: cacheDirectory)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func cacheFileURL(for songId: String) -> URL {
        cacheDirectory.appendingPathComponent(songId.sha256Hash + ".audio")
    }

    private func evictIfNeeded() async {
        let currentSize = totalCacheSize()
        guard currentSize > maxCacheSizeBytes else { return }

        // Evict oldest files first until under limit
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        let sorted = files.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return dateA < dateB
        }

        var freed: Int64 = 0
        let targetFree = currentSize - (maxCacheSizeBytes * 80 / 100) // Free to 80% capacity

        for fileURL in sorted {
            guard freed < targetFree else { break }
            let size = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try? FileManager.default.removeItem(at: fileURL)
            freed += size
        }
    }

    // MARK: - Errors

    public enum CacheError: Error, LocalizedError {
        case downloadFailed

        public var errorDescription: String? {
            switch self {
            case .downloadFailed: return "Failed to download audio file"
            }
        }
    }
}

