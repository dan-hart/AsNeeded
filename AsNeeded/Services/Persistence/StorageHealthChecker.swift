// StorageHealthChecker.swift
// Pre-flight health checks for storage system before migration

import DHLoggingKit
import Foundation

/// Performs health checks on storage system before migration or critical operations
/// Helps detect and diagnose issues early to prevent data loss
@MainActor
public final class StorageHealthChecker {
	private let logger = DHLogger.data
	private static let appGroupIdentifier = "group.com.codedbydan.AsNeeded"
	private static let minimumDiskSpaceMB: Double = 50.0

	/// Result of health check
	public struct HealthCheckResult {
		let isHealthy: Bool
		let appGroupAccessible: Bool
		let appGroupWritable: Bool
		let sufficientDiskSpace: Bool
		let diskSpaceMB: Double?
		let issues: [String]

		var detailedReport: String {
			var report = "=== Storage Health Check Report ===\n"
			report += "Overall Status: \(isHealthy ? "✅ HEALTHY" : "❌ UNHEALTHY")\n\n"

			report += "Checks:\n"
			report += "  App Group Accessible: \(appGroupAccessible ? "✅" : "❌")\n"
			report += "  App Group Writable: \(appGroupWritable ? "✅" : "❌")\n"
			report += "  Sufficient Disk Space: \(sufficientDiskSpace ? "✅" : "❌")\n"

			if let diskSpace = diskSpaceMB {
				report += "  Available Disk Space: \(String(format: "%.2f", diskSpace)) MB\n"
			}

			if !issues.isEmpty {
				report += "\nIssues Detected:\n"
				for (index, issue) in issues.enumerated() {
					report += "  \(index + 1). \(issue)\n"
				}
			}

			report += "\n=== End Report ==="
			return report
		}
	}

	/// Performs comprehensive health check on storage system
	public func performHealthCheck() -> HealthCheckResult {
		logger.info("Starting storage health check...")

		var issues: [String] = []
		var appGroupAccessible = false
		var appGroupWritable = false
		var sufficientDiskSpace = false
		var diskSpaceMB: Double?

		// Check 1: App Group Accessibility
		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			let issue = "App Group container is unavailable: \(Self.appGroupIdentifier)"
			issues.append(issue)
			logger.error("❌ \(issue)")

			return HealthCheckResult(
				isHealthy: false,
				appGroupAccessible: false,
				appGroupWritable: false,
				sufficientDiskSpace: false,
				diskSpaceMB: nil,
				issues: issues
			)
		}

		appGroupAccessible = true
		logger.info("✅ App Group accessible: \(appGroupURL.path)")

		// Check 2: App Group Writability
		let testFile = appGroupURL.appendingPathComponent(".health_check_write_test")
		do {
			try "health check test".write(to: testFile, atomically: true, encoding: .utf8)
			try? FileManager.default.removeItem(at: testFile)
			appGroupWritable = true
			logger.info("✅ App Group is writable")
		} catch {
			let issue = "App Group is not writable: \(error.localizedDescription)"
			issues.append(issue)
			logger.error("❌ \(issue)")
		}

		// Check 3: Disk Space
		if let resourceValues = try? appGroupURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
		   let availableCapacity = resourceValues.volumeAvailableCapacity {
			let capacityMB = Double(availableCapacity) / 1_048_576
			diskSpaceMB = capacityMB

			if capacityMB >= Self.minimumDiskSpaceMB {
				sufficientDiskSpace = true
				logger.info("✅ Sufficient disk space: \(String(format: "%.2f", capacityMB)) MB")
			} else {
				let issue = "Low disk space: \(String(format: "%.2f", capacityMB)) MB (minimum \(Self.minimumDiskSpaceMB) MB required)"
				issues.append(issue)
				logger.warning("⚠️ \(issue)")
			}
		} else {
			let issue = "Unable to determine available disk space"
			issues.append(issue)
			logger.warning("⚠️ \(issue)")
		}

		// Check 4: Database File Integrity (if files exist)
		checkDatabaseIntegrity(in: appGroupURL, issues: &issues)

		// Overall health determination
		let isHealthy = appGroupAccessible && appGroupWritable && sufficientDiskSpace && issues.isEmpty

		let result = HealthCheckResult(
			isHealthy: isHealthy,
			appGroupAccessible: appGroupAccessible,
			appGroupWritable: appGroupWritable,
			sufficientDiskSpace: sufficientDiskSpace,
			diskSpaceMB: diskSpaceMB,
			issues: issues
		)

		logger.info(result.detailedReport)

		return result
	}

	/// Checks database file integrity if files exist
	private func checkDatabaseIntegrity(in containerURL: URL, issues: inout [String]) {
		let fileManager = FileManager.default
		let medicationsPath = containerURL.appendingPathComponent("medications.sqlite3")
		let eventsPath = containerURL.appendingPathComponent("events.sqlite3")

		// Check if databases exist
		let medicationsExists = fileManager.fileExists(atPath: medicationsPath.path)
		let eventsExists = fileManager.fileExists(atPath: eventsPath.path)

		if !medicationsExists && !eventsExists {
			logger.info("No existing databases found (likely fresh install)")
			return
		}

		// Check file permissions
		if medicationsExists {
			if fileManager.isReadableFile(atPath: medicationsPath.path) {
				logger.info("✅ Medications database is readable")
			} else {
				let issue = "Medications database exists but is not readable"
				issues.append(issue)
				logger.error("❌ \(issue)")
			}

			if fileManager.isWritableFile(atPath: medicationsPath.path) {
				logger.info("✅ Medications database is writable")
			} else {
				let issue = "Medications database exists but is not writable"
				issues.append(issue)
				logger.error("❌ \(issue)")
			}
		}

		if eventsExists {
			if fileManager.isReadableFile(atPath: eventsPath.path) {
				logger.info("✅ Events database is readable")
			} else {
				let issue = "Events database exists but is not readable"
				issues.append(issue)
				logger.error("❌ \(issue)")
			}

			if fileManager.isWritableFile(atPath: eventsPath.path) {
				logger.info("✅ Events database is writable")
			} else {
				let issue = "Events database exists but is not writable"
				issues.append(issue)
				logger.error("❌ \(issue)")
			}
		}

		// Check for file size anomalies
		if medicationsExists {
			if let attributes = try? fileManager.attributesOfItem(atPath: medicationsPath.path),
			   let size = attributes[.size] as? Int64 {
				if size == 0 {
					let issue = "Medications database exists but has 0 bytes (likely corrupted)"
					issues.append(issue)
					logger.warning("⚠️ \(issue)")
				}
			}
		}

		if eventsExists {
			if let attributes = try? fileManager.attributesOfItem(atPath: eventsPath.path),
			   let size = attributes[.size] as? Int64 {
				if size == 0 {
					let issue = "Events database exists but has 0 bytes (likely corrupted)"
					issues.append(issue)
					logger.warning("⚠️ \(issue)")
				}
			}
		}
	}

	/// Quick health check that returns only a boolean (for simple go/no-go decisions)
	public func isStorageHealthy() -> Bool {
		let result = performHealthCheck()
		return result.isHealthy
	}
}
