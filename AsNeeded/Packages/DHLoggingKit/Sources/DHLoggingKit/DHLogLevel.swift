//
//  DHLogLevel.swift
//  DHLoggingKit
//
//  Log level definitions and utilities
//

import Foundation
@preconcurrency import OSLog

/// Represents the different log levels available in DHLoggingKit.
/// These correspond to OSLog levels but provide a more convenient API.
@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
public enum DHLogLevel: Int, CaseIterable, Comparable {
	/// Debug messages - only visible during development
	case debug = 0
	
	/// Info messages - general informational events
	case info = 1
	
	/// Notice messages - significant events (default level)
	case notice = 2
	
	/// Warning messages - potentially problematic situations
	case warning = 3
	
	/// Error messages - error conditions
	case error = 4
	
	/// Fault messages - critical errors
	case fault = 5
	
	/// Human-readable description of the log level
	public var description: String {
		switch self {
		case .debug:
			return "DEBUG"
		case .info:
			return "INFO"
		case .notice:
			return "NOTICE"
		case .warning:
			return "WARNING"
		case .error:
			return "ERROR"
		case .fault:
			return "FAULT"
		}
	}
	
	/// Emoji representation for console output
	public var emoji: String {
		switch self {
		case .debug:
			return "🔍"
		case .info:
			return "ℹ️"
		case .notice:
			return "📝"
		case .warning:
			return "⚠️"
		case .error:
			return "❌"
		case .fault:
			return "💥"
		}
	}
	
	/// Converts to OSLog level
	internal var osLogType: OSLogType {
		switch self {
		case .debug:
			return .debug
		case .info:
			return .info
		case .notice:
			return .default
		case .warning:
			return .info // OSLog doesn't have warning, use info
		case .error:
			return .error
		case .fault:
			return .fault
		}
	}
	
	public static func < (lhs: DHLogLevel, rhs: DHLogLevel) -> Bool {
		return lhs.rawValue < rhs.rawValue
	}
}