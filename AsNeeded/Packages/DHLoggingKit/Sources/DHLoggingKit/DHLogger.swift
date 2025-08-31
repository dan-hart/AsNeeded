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
	/// Logs a debug message with full OSLog privacy control support.
	///
	/// Debug messages are disabled in release builds for performance reasons.
	/// Use for detailed tracing information that's only useful during development.
	///
	/// Example usage:
	/// ```
	/// logger.debug("User login attempt: \(username, privacy: .private)")
	/// ```
	///
	/// - Parameters:
	///   - message: The message to log with OSLog string interpolation support
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func debug(
		_ message: @autoclosure () -> OSLogMessage,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		logger.debug("\(message())")
	}
	
	/// Logs an info message with full OSLog privacy control support.
	///
	/// Info messages are visible in debug builds and can be enabled in release builds.
	/// Use for general events that might be useful for understanding app behavior.
	///
	/// Example usage:
	/// ```
	/// logger.info("API request completed: \(endpoint, privacy: .public) in \(duration)ms")
	/// ```
	///
	/// - Parameters:
	///   - message: The message to log with OSLog string interpolation support
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func info(
		_ message: @autoclosure () -> OSLogMessage,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		logger.info("\(message())")
	}
	
	/// Logs a notice message with full OSLog privacy control support.
	///
	/// Notice is the default log level and these messages are always captured.
	/// Use for important events that should be logged in production.
	///
	/// Example usage:
	/// ```
	/// logger.notice("User action: \(action, privacy: .public) by \(userId, privacy: .private(mask: .hash))")
	/// ```
	///
	/// - Parameters:
	///   - message: The message to log with OSLog string interpolation support
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func notice(
		_ message: @autoclosure () -> OSLogMessage,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		logger.notice("\(message())")
	}
	
	/// Logs a warning message with full OSLog privacy control support.
	///
	/// Warning messages indicate something unexpected but recoverable happened.
	/// These are always captured and should be used sparingly.
	///
	/// Example usage:
	/// ```
	/// logger.warning("Rate limit approaching: \(currentCount)/\(maxCount, privacy: .public)")
	/// ```
	///
	/// - Parameters:
	///   - message: The message to log with OSLog string interpolation support
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func warning(
		_ message: @autoclosure () -> OSLogMessage,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		logger.warning("\(message())")
	}
	
	/// Logs an error message with full OSLog privacy control support.
	///
	/// Error messages indicate that something went wrong but the app can continue.
	/// These are always captured and persisted.
	///
	/// Example usage:
	/// ```
	/// logger.error("Failed to save data", error: saveError)
	/// logger.error("Network error: \(errorCode, privacy: .public) - \(errorMessage, privacy: .private)")
	/// ```
	///
	/// - Parameters:
	///   - message: The message to log with OSLog string interpolation support
	///   - error: An optional Error to include in the log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func error(
		_ message: @autoclosure () -> OSLogMessage,
		error: Error? = nil,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		if let error = error {
			logger.error("\(message()) - Error: \(String(describing: error), privacy: .public)")
		} else {
			logger.error("\(message())")
		}
	}
	
	/// Logs a fault message with full OSLog privacy control support.
	///
	/// Fault messages indicate serious problems that require immediate attention.
	/// These are always captured and persisted with high priority.
	///
	/// Example usage:
	/// ```
	/// logger.fault("Critical system failure", error: criticalError)
	/// logger.fault("Memory corruption detected at \(address, privacy: .private(mask: .hash))")
	/// ```
	///
	/// - Parameters:
	///   - message: The message to log with OSLog string interpolation support
	///   - error: An optional Error to include in the log
	///   - file: The file name (automatically provided)
	///   - function: The function name (automatically provided)
	///   - line: The line number (automatically provided)
	public func fault(
		_ message: @autoclosure () -> OSLogMessage,
		error: Error? = nil,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		if let error = error {
			logger.fault("\(message()) - Error: \(String(describing: error), privacy: .public)")
		} else {
			logger.fault("\(message())")
		}
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