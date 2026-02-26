import Foundation
#if canImport(os)
import os
#endif

/// Centralized logging for Metrolist iOS.
/// Provides category-specific loggers matching the Android timber-based approach.
public enum MetrolistLogger {
    #if canImport(os)
    public static let playback = Logger(subsystem: "com.metrolist.music", category: "playback")
    public static let network = Logger(subsystem: "com.metrolist.music", category: "network")
    public static let lyrics = Logger(subsystem: "com.metrolist.music", category: "lyrics")
    public static let animatedArtwork = Logger(subsystem: "com.metrolist.music", category: "animatedArtwork")
    public static let database = Logger(subsystem: "com.metrolist.music", category: "database")
    public static let general = Logger(subsystem: "com.metrolist.music", category: "general")
    #else
    public static let playback = PrintLogger(category: "playback")
    public static let network = PrintLogger(category: "network")
    public static let lyrics = PrintLogger(category: "lyrics")
    public static let animatedArtwork = PrintLogger(category: "animatedArtwork")
    public static let database = PrintLogger(category: "database")
    public static let general = PrintLogger(category: "general")
    #endif
}

#if !canImport(os)
/// Fallback logger for non-Apple platforms.
public struct PrintLogger: Sendable {
    public let category: String

    public func debug(_ message: @autoclosure () -> String) {
        print("[DEBUG][\(category)] \(message())")
    }

    public func info(_ message: @autoclosure () -> String) {
        print("[INFO][\(category)] \(message())")
    }

    public func error(_ message: @autoclosure () -> String) {
        print("[ERROR][\(category)] \(message())")
    }

    public func warning(_ message: @autoclosure () -> String) {
        print("[WARN][\(category)] \(message())")
    }
}
#endif
