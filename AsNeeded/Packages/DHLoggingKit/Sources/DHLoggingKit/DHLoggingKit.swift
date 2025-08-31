//
//  DHLoggingKit.swift
//  DHLoggingKit
//
//  Main entry point and public API for DHLoggingKit
//

import Foundation
@preconcurrency import OSLog

/// DHLoggingKit provides a unified, easy-to-use logging solution that wraps Apple's OSLog
/// with enhanced features for better developer experience across all Apple platforms.
///
/// ## Features
/// - Thread-safe logging with minimal performance overhead
/// - Privacy-conscious logging with OSLog's built-in privacy controls
/// - Automatic context information (file, function, line)
/// - Convenient timing utilities
/// - Pre-configured loggers for common use cases
/// - Support for all Apple platforms (iOS, macOS, watchOS, tvOS, visionOS)
///
/// ## Basic Usage
/// ```swift
/// import DHLoggingKit
///
/// let logger = DHLogger.network
/// logger.info("Starting network request to \(url, privacy: .public)")
/// logger.error("Network request failed", error: networkError)
/// ```
///
/// ## Custom Loggers
/// ```swift
/// let customLogger = DHLogger(category: "custom-feature")
/// customLogger.debug("Debug information: \(data, privacy: .private)")
/// ```
@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
public enum DHLoggingKit {
	/// Current version of DHLoggingKit
	public static let version = "1.0.0"
	
	/// Shared logger for general app events
	public static let shared = DHLogger.general
}