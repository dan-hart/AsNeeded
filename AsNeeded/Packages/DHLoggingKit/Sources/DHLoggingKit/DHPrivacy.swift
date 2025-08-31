//
//  DHPrivacy.swift
//  DHLoggingKit
//
//  Privacy utilities and extensions for easier privacy handling
//

import Foundation
@preconcurrency import OSLog

/// Convenience extensions and utilities for handling privacy in logging.
/// These make it easier to work with OSLog's privacy features.
@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
public enum DHPrivacy {
	/// Common privacy patterns for easy use
	
	/// Mark data as always private (redacted in logs)
	@MainActor public static let `private` = OSLogPrivacy.private
	
	/// Mark data as public (visible in logs)
	@MainActor public static let `public` = OSLogPrivacy.public
	
	/// Private data with hash representation
	@MainActor public static let privateHash = OSLogPrivacy.private(mask: .hash)
	
	/// Auto privacy (respects system settings)
	@MainActor public static let auto = OSLogPrivacy.auto
}

// MARK: - Convenience Extensions
@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
extension String {
	/// Convenience property to mark string as private
	public var `private`: (String, OSLogPrivacy) {
		return (self, .private)
	}
	
	/// Convenience property to mark string as public
	public var `public`: (String, OSLogPrivacy) {
		return (self, .public)
	}
	
	/// Convenience property to mark string as private with hash
	public var privateHash: (String, OSLogPrivacy) {
		return (self, .private(mask: .hash))
	}
}

@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
extension CustomStringConvertible {
	/// Convenience property to mark any CustomStringConvertible as private
	public var `private`: (String, OSLogPrivacy) {
		return (self.description, .private)
	}
	
	/// Convenience property to mark any CustomStringConvertible as public
	public var `public`: (String, OSLogPrivacy) {
		return (self.description, .public)
	}
	
	/// Convenience property to mark any CustomStringConvertible as private with hash
	public var privateHash: (String, OSLogPrivacy) {
		return (self.description, .private(mask: .hash))
	}
}