//
//  DHLogger.swift
//  DHLoggingKit
//
//  A unified logging solution that wraps Apple's OSLog with enhanced features
//  for easy, performant, and privacy-conscious logging across all Apple platforms.
//

import Foundation
@preconcurrency import OSLog

/// A comprehensive logging solution that provides a unified interface to Apple's OSLog
/// with enhanced features for better developer experience and production use.
@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
public struct DHLogger: Sendable {
	// MARK: - Properties
	private let logger: Logger
	private let subsystem: String
	private let category: String
	
	// MARK: - Initialization
	/// Creates a new DHLogger instance with the specified subsystem and category.
	///
	/// - Parameters:
	///   - subsystem: The subsystem identifier (typically your app's bundle ID)
	///   - category: The category for organizing logs within the subsystem
	public init(subsystem: String, category: String) {
		self.subsystem = subsystem
		self.category = category
		self.logger = Logger(subsystem: subsystem, category: category)
	}
	
	/// Convenience initializer that uses the main bundle identifier as subsystem.
	///
	/// - Parameter category: The category for organizing logs within the subsystem
	public init(category: String) {
		let bundleId = Bundle.main.bundleIdentifier ?? "com.unknown.app"
		self.init(subsystem: bundleId, category: category)
	}
	
	// MARK: - Logging Methods
	/// Logs a debug message.
	///
	/// Debug messages are disabled in release builds for performance reasons.
	/// Use for detailed tracing information that's only useful during development.
	///
	/// - Parameters:
	///   - message: The message to log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func debug(
		_ message: String,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		let context = formatContext(file: file, function: function, line: line)
		logger.debug("\(context) \(message)")
	}
	
	/// Logs an info message for general informational events.
	///
	/// Info messages are visible in debug builds and can be enabled in release builds.
	/// Use for general events that might be useful for understanding app behavior.
	///
	/// - Parameters:
	///   - message: The message to log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func info(
		_ message: String,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		let context = formatContext(file: file, function: function, line: line)
		logger.info("\(context) \(message)")
	}
	
	/// Logs a notice message for significant events that are part of normal operation.
	///
	/// Notice is the default log level and these messages are always captured.
	/// Use for important events that should be logged in production.
	///
	/// - Parameters:
	///   - message: The message to log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func notice(
		_ message: String,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		let context = formatContext(file: file, function: function, line: line)
		logger.notice("\(context) \(message)")
	}
	
	/// Logs a warning message for potentially problematic situations.
	///
	/// Warning messages indicate something unexpected but recoverable happened.
	/// These are always captured and should be used sparingly.
	///
	/// - Parameters:
	///   - message: The message to log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func warning(
		_ message: String,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		let context = formatContext(file: file, function: function, line: line)
		logger.warning("\(context) \(message)")
	}
	
	/// Logs an error message for error conditions.
	///
	/// Error messages indicate that something went wrong but the app can continue.
	/// These are always captured and persisted.
	///
	/// - Parameters:
	///   - message: The message to log
	///   - error: An optional Error to include in the log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func error(
		_ message: String,
		error: Error? = nil,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		let context = formatContext(file: file, function: function, line: line)
		if let error = error {
			logger.error("\(context) \(message) - Error: \(String(describing: error))")
		} else {
			logger.error("\(context) \(message)")
		}
	}
	
	/// Logs a fault message for critical errors that may cause the app to crash.
	///
	/// Fault messages indicate serious problems that require immediate attention.
	/// These are always captured and persisted with high priority.
	///
	/// - Parameters:
	///   - message: The message to log
	///   - error: An optional Error to include in the log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func fault(
		_ message: String,
		error: Error? = nil,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		let context = formatContext(file: file, function: function, line: line)
		if let error = error {
			logger.fault("\(context) \(message) - Error: \(String(describing: error))")
		} else {
			logger.fault("\(context) \(message)")
		}
	}
	
	// MARK: - Direct OSLog Access
	/// Provides direct access to the underlying OSLog Logger for advanced use cases.
	///
	/// Use this when you need full OSLog features including privacy annotations.
	/// The context information (file, function, line) is not automatically added.
	///
	/// Example usage:
	/// ```swift
	/// logger.oslog.info("User \(username, privacy: .private) logged in from \(ip, privacy: .public)")
	/// ```
	///
	/// - Returns: The underlying OSLog Logger instance
	public var oslog: Logger {
		return logger
	}

	// MARK: - Convenience Methods
	/// Logs entry into a function or method (debug level).
	public func enter(
		function: String = #function,
		file: String = #file,
		line: Int = #line
	) {
		debug("→ Entering \(function)", file: file, function: function, line: line)
	}
	
	/// Logs exit from a function or method (debug level).
	public func exit(
		function: String = #function,
		file: String = #file,
		line: Int = #line
	) {
		debug("← Exiting \(function)", file: file, function: function, line: line)
	}
	
	/// Logs execution timing for a closure.
	///
	/// Example usage:
	/// ```
	/// let result = logger.timed("Database query") {
	///     return database.fetchUsers()
	/// }
	/// ```
	///
	/// - Parameters:
	///   - operation: Description of the operation being timed
	///   - closure: The operation to time
	/// - Returns: The result of the closure
	public func timed<T>(
		_ operation: String,
		file: String = #file,
		function: String = #function,
		line: Int = #line,
		_ closure: () throws -> T
	) rethrows -> T {
		let startTime = CFAbsoluteTimeGetCurrent()
		defer {
			let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
			debug("⏱ \(operation) took \(String(format: "%.3f", timeElapsed))s", file: file, function: function, line: line)
		}
		return try closure()
	}
	
	/// Logs execution timing for an async closure.
	///
	/// Example usage:
	/// ```
	/// let result = await logger.timedAsync("API call") {
	///     return await apiService.fetchData()
	/// }
	/// ```
	///
	/// - Parameters:
	///   - operation: Description of the operation being timed
	///   - closure: The async operation to time
	/// - Returns: The result of the closure
	public func timedAsync<T>(
		_ operation: String,
		file: String = #file,
		function: String = #function,
		line: Int = #line,
		_ closure: () async throws -> T
	) async rethrows -> T {
		let startTime = CFAbsoluteTimeGetCurrent()
		defer {
			let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
			debug("⏱ \(operation) took \(String(format: "%.3f", timeElapsed))s", file: file, function: function, line: line)
		}
		return try await closure()
	}
	
	// MARK: - Privacy Helper Methods
	/// Redacts sensitive data for logging purposes.
	/// 
	/// This method provides a consistent way to redact sensitive information
	/// when logging with string interpolation instead of OSLog privacy controls.
	///
	/// - Parameter sensitiveValue: The sensitive value to redact
	/// - Returns: A redacted string safe for logging
	/// - Note: For better privacy control, use OSLog's built-in privacy annotations
	public static func redact(_ sensitiveValue: Any) -> String {
		return "<private>"
	}
	
	/// Creates a hash representation of sensitive data for logging.
	/// 
	/// This creates a consistent hash that allows tracking the same value 
	/// across logs without exposing the actual content.
	///
	/// - Parameter sensitiveValue: The sensitive value to hash
	/// - Returns: A hashed representation safe for logging
	/// - Note: For better privacy control, use OSLog's built-in privacy annotations with mask: .hash
	public static func hash(_ sensitiveValue: Any) -> String {
		let stringValue = String(describing: sensitiveValue)
		let hasher = stringValue.hash
		return "<hash:\(String(hasher.magnitude, radix: 16))>"
	}
	
	
	// MARK: - Private Helpers
	private func formatContext(file: String, function: String, line: Int) -> String {
		let filename = URL(fileURLWithPath: file).lastPathComponent
		return "[\(filename):\(line) \(function)]"
	}
}

// MARK: - Static Factory Methods
@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
extension DHLogger {
	/// Creates a logger for general app events.
	public static var general: DHLogger {
		DHLogger(category: "general")
	}
	
	/// Creates a logger for UI-related events.
	public static var ui: DHLogger {
		DHLogger(category: "ui")
	}
	
	/// Creates a logger for network-related events.
	public static var network: DHLogger {
		DHLogger(category: "network")
	}
	
	/// Creates a logger for data/persistence-related events.
	public static var data: DHLogger {
		DHLogger(category: "data")
	}
	
	/// Creates a logger for authentication-related events.
	public static var auth: DHLogger {
		DHLogger(category: "auth")
	}
	
	/// Creates a logger for performance-related events.
	public static var performance: DHLogger {
		DHLogger(category: "performance")
	}
}