// StorageHealthChecker.swift
// Pre-flight health checks for storage system before migration

import DHLoggingKit
import Foundation
import SQLite3

/// Performs health checks on storage system before migration or critical operations
/// Helps detect and diagnose issues early to prevent data loss
@MainActor
public final class StorageHealthChecker {
	private let logger = DHLogger.data

	/// Severity level for health check issues
	public enum IssueSeverity: String {
		case warning  // Non-blocking, logged but doesn't prevent operation
		case error    // Blocking, prevents operation from proceeding
	}

	/// A health check issue with severity level
	public struct HealthIssue {
		let message: String
		let severity: IssueSeverity
	}

	/// Result of health check
	public struct HealthCheckResult {
		let isHealthy: Bool
		let appGroupAccessible: Bool
		let appGroupWritable: Bool
		let sufficientDiskSpace: Bool
		let diskSpaceMB: Double?
		let issues: [HealthIssue]

		/// Returns only blocking errors (severity = .error)
		var errors: [HealthIssue] {
			issues.filter { $0.severity == .error }
		}

		/// Returns only non-blocking warnings (severity = .warning)
		var warnings: [HealthIssue] {
			issues.filter { $0.severity == .warning }
		}

		/// Legacy compatibility: all issue messages
		var issueMessages: [String] {
			issues.map { $0.message }
		}

		var detailedReport: String {
			var report = "=== Storage Health Check Report ===\n"
			report += "Overall Status: \(isHealthy ? "✅ HEALTHY" : "❌ UNHEALTHY")\n\n"

			report += "Checks:\n"
			report += "  App Group Accessible: \(appGroupAccessible ? "✅" : "❌")\n"
			report += "  App Group Writable: \(appGroupWritable ? "✅" : "❌")\n"
			report += "  Sufficient Disk Space: \(sufficientDiskSpace ? "✅" : "⚠️")\n"

			if let diskSpace = diskSpaceMB {
				report += "  Available Disk Space: \(String(format: "%.2f", diskSpace)) MB\n"
			}

			if !errors.isEmpty {
				report += "\n❌ Errors (blocking):\n"
				for (index, issue) in errors.enumerated() {
					report += "  \(index + 1). \(issue.message)\n"
				}
			}

			if !warnings.isEmpty {
				report += "\n⚠️ Warnings (non-blocking):\n"
				for (index, issue) in warnings.enumerated() {
					report += "  \(index + 1). \(issue.message)\n"
				}
			}

			report += "\n=== End Report ==="
			return report
		}
	}

	/// Performs comprehensive health check on storage system
	public func performHealthCheck() -> HealthCheckResult {
		logger.info("Starting storage health check...")

		var issues: [HealthIssue] = []
		var appGroupAccessible = false
		var appGroupWritable = false
		var sufficientDiskSpace = false
		var diskSpaceMB: Double?

		// Check 1: App Group Accessibility (CRITICAL - blocking)
		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) else {
			let issue = "App Group container is unavailable: \(StorageConstants.appGroupIdentifier)"
			issues.append(HealthIssue(message: issue, severity: .error))
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

		// Check 2: App Group Writability (CRITICAL - blocking)
		let testFile = appGroupURL.appendingPathComponent(".health_check_write_test")
		do {
			try "health check test".write(to: testFile, atomically: true, encoding: .utf8)
			try? FileManager.default.removeItem(at: testFile)
			appGroupWritable = true
			logger.info("✅ App Group is writable")
		} catch {
			let issue = "App Group is not writable: \(error.localizedDescription)"
			issues.append(HealthIssue(message: issue, severity: .error))
			logger.error("❌ \(issue)")
		}

		// Check 3: Disk Space (WARNING - non-blocking, user data should still be accessible)
		if let resourceValues = try? appGroupURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
		   let availableCapacity = resourceValues.volumeAvailableCapacity {
			let capacityMB = Double(availableCapacity) / 1_048_576
			diskSpaceMB = capacityMB

			if capacityMB >= StorageConstants.minimumDiskSpaceMB {
				sufficientDiskSpace = true
				logger.info("✅ Sufficient disk space: \(String(format: "%.2f", capacityMB)) MB")
			} else {
				// Low disk space is a WARNING, not an error - users should still access their data
				let issue = "Low disk space: \(String(format: "%.2f", capacityMB)) MB (minimum \(StorageConstants.minimumDiskSpaceMB) MB recommended)"
				issues.append(HealthIssue(message: issue, severity: .warning))
				logger.warning("⚠️ \(issue)")
				// Still mark as "sufficient" for health determination since it's non-blocking
				sufficientDiskSpace = true
			}
		} else {
			let issue = "Unable to determine available disk space"
			issues.append(HealthIssue(message: issue, severity: .warning))
			logger.warning("⚠️ \(issue)")
			// Unknown disk space is a warning, not blocking
			sufficientDiskSpace = true
		}

		// Check 4: Database File Integrity (if files exist)
		checkDatabaseIntegrity(in: appGroupURL, issues: &issues)

		// Overall health determination - only ERRORS block, warnings don't
		let hasBlockingErrors = issues.contains { $0.severity == .error }
		let isHealthy = appGroupAccessible && appGroupWritable && !hasBlockingErrors

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
	private func checkDatabaseIntegrity(in containerURL: URL, issues: inout [HealthIssue]) {
		let fileManager = FileManager.default
		let medicationsPath = containerURL.appendingPathComponent(StorageConstants.medicationsDBPath)
		let eventsPath = containerURL.appendingPathComponent(StorageConstants.eventsDBPath)

		// Check if databases exist
		let medicationsExists = fileManager.fileExists(atPath: medicationsPath.path)
		let eventsExists = fileManager.fileExists(atPath: eventsPath.path)

		if !medicationsExists && !eventsExists {
			logger.info("No existing databases found (likely fresh install)")
			return
		}

		// Check file permissions (CRITICAL - blocking)
		if medicationsExists {
			if fileManager.isReadableFile(atPath: medicationsPath.path) {
				logger.info("✅ Medications database is readable")
			} else {
				let issue = "Medications database exists but is not readable"
				issues.append(HealthIssue(message: issue, severity: .error))
				logger.error("❌ \(issue)")
			}

			if fileManager.isWritableFile(atPath: medicationsPath.path) {
				logger.info("✅ Medications database is writable")
			} else {
				let issue = "Medications database exists but is not writable"
				issues.append(HealthIssue(message: issue, severity: .error))
				logger.error("❌ \(issue)")
			}

			// Run SQLite integrity check
			validateSQLiteIntegrity(at: medicationsPath, name: "Medications", issues: &issues)
		}

		if eventsExists {
			if fileManager.isReadableFile(atPath: eventsPath.path) {
				logger.info("✅ Events database is readable")
			} else {
				let issue = "Events database exists but is not readable"
				issues.append(HealthIssue(message: issue, severity: .error))
				logger.error("❌ \(issue)")
			}

			if fileManager.isWritableFile(atPath: eventsPath.path) {
				logger.info("✅ Events database is writable")
			} else {
				let issue = "Events database exists but is not writable"
				issues.append(HealthIssue(message: issue, severity: .error))
				logger.error("❌ \(issue)")
			}

			// Run SQLite integrity check
			validateSQLiteIntegrity(at: eventsPath, name: "Events", issues: &issues)
		}

		// Check for file size anomalies (WARNING - may indicate empty database)
		if medicationsExists {
			if let attributes = try? fileManager.attributesOfItem(atPath: medicationsPath.path),
			   let size = attributes[.size] as? Int64 {
				if size == 0 {
					let issue = "Medications database exists but has 0 bytes (likely corrupted)"
					issues.append(HealthIssue(message: issue, severity: .error))
					logger.error("❌ \(issue)")
				}
			}
		}

		if eventsExists {
			if let attributes = try? fileManager.attributesOfItem(atPath: eventsPath.path),
			   let size = attributes[.size] as? Int64 {
				if size == 0 {
					let issue = "Events database exists but has 0 bytes (likely corrupted)"
					issues.append(HealthIssue(message: issue, severity: .error))
					logger.error("❌ \(issue)")
				}
			}
		}
	}

	/// Validates SQLite database integrity using PRAGMA integrity_check
	private func validateSQLiteIntegrity(at path: URL, name: String, issues: inout [HealthIssue]) {
		// Use SQLite3 C API directly for integrity check
		var db: OpaquePointer?
		let openResult = sqlite3_open_v2(path.path, &db, SQLITE_OPEN_READONLY, nil)

		guard openResult == SQLITE_OK, let database = db else {
			let issue = "\(name) database cannot be opened for integrity check"
			issues.append(HealthIssue(message: issue, severity: .warning))
			logger.warning("⚠️ \(issue)")
			if let database = db {
				sqlite3_close(database)
			}
			return
		}

		defer { sqlite3_close(database) }

		// Run quick integrity check (faster than full integrity_check)
		var statement: OpaquePointer?
		let query = "PRAGMA quick_check"

		guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
			let issue = "\(name) database integrity check failed to prepare"
			issues.append(HealthIssue(message: issue, severity: .warning))
			logger.warning("⚠️ \(issue)")
			return
		}

		defer { sqlite3_finalize(statement) }

		var isIntact = true
		while sqlite3_step(statement) == SQLITE_ROW {
			if let resultPointer = sqlite3_column_text(statement, 0) {
				let result = String(cString: resultPointer)
				if result != "ok" {
					isIntact = false
					logger.error("❌ \(name) database integrity issue: \(result)")
				}
			}
		}

		if isIntact {
			logger.info("✅ \(name) database passed integrity check")
		} else {
			let issue = "\(name) database failed integrity check (may be corrupted)"
			issues.append(HealthIssue(message: issue, severity: .error))
		}
	}

	/// Quick health check that returns only a boolean (for simple go/no-go decisions)
	public func isStorageHealthy() -> Bool {
		let result = performHealthCheck()
		return result.isHealthy
	}
}
