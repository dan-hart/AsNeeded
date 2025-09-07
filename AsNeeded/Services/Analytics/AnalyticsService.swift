// AnalyticsService.swift
// Centralized analytics and usage tracking service

import Foundation
import ANModelKit
import DHLoggingKit

@MainActor
public final class AnalyticsService {
	public static let shared = AnalyticsService()
	private let logger = DHLogger(category: "Analytics")
	private let userDefaults = UserDefaults.standard
	
	// Analytics keys
	private enum Keys {
		static let firstLaunchDate = "analytics.firstLaunchDate"
		static let launchCount = "analytics.launchCount"
		static let lastLaunchDate = "analytics.lastLaunchDate"
		static let totalMedicationsAdded = "analytics.totalMedicationsAdded"
		static let totalEventsLogged = "analytics.totalEventsLogged"
		static let lastExportDate = "analytics.lastExportDate"
		static let lastImportDate = "analytics.lastImportDate"
		static let mostUsedFeatures = "analytics.mostUsedFeatures"
		static let dailyActiveUse = "analytics.dailyActiveUse"
	}
	
	private init() {
		trackAppLaunch()
	}
	
	// MARK: - App Lifecycle
	
	/// Track app launch
	private func trackAppLaunch() {
		// Record first launch if needed
		if userDefaults.object(forKey: Keys.firstLaunchDate) == nil {
			userDefaults.set(Date(), forKey: Keys.firstLaunchDate)
			logger.info("First app launch recorded")
		}
		
		// Increment launch count
		let launchCount = userDefaults.integer(forKey: Keys.launchCount) + 1
		userDefaults.set(launchCount, forKey: Keys.launchCount)
		userDefaults.set(Date(), forKey: Keys.lastLaunchDate)
		
		logger.info("App launch #\(launchCount)")
		
		// Track daily active use
		trackDailyActiveUse()
	}
	
	/// Track daily active use
	private func trackDailyActiveUse() {
		let today = DateUtility.startOfToday
		let lastActiveDate = userDefaults.object(forKey: Keys.dailyActiveUse) as? Date
		
		if let lastActiveDate = lastActiveDate {
			if !Calendar.current.isDate(lastActiveDate, inSameDayAs: today) {
				userDefaults.set(today, forKey: Keys.dailyActiveUse)
				logger.info("Daily active use recorded for \(today)")
			}
		} else {
			userDefaults.set(today, forKey: Keys.dailyActiveUse)
			logger.info("Daily active use recorded for \(today)")
		}
	}
	
	// MARK: - Feature Usage
	
	/// Track feature usage
	public func trackFeatureUse(_ feature: Feature) {
		var features = userDefaults.dictionary(forKey: Keys.mostUsedFeatures) as? [String: Int] ?? [:]
		let count = (features[feature.rawValue] ?? 0) + 1
		features[feature.rawValue] = count
		userDefaults.set(features, forKey: Keys.mostUsedFeatures)
		
		logger.debug("Feature '\(feature.rawValue)' used \(count) times")
	}
	
	public enum Feature: String {
		case addMedication = "add_medication"
		case editMedication = "edit_medication"
		case deleteMedication = "delete_medication"
		case logDose = "log_dose"
		case viewHistory = "view_history"
		case viewTrends = "view_trends"
		case exportData = "export_data"
		case importData = "import_data"
		case searchMedication = "search_medication"
		case setReminder = "set_reminder"
		case siriShortcut = "siri_shortcut"
	}
	
	// MARK: - Data Operations
	
	/// Track medication added
	public func trackMedicationAdded() {
		let count = userDefaults.integer(forKey: Keys.totalMedicationsAdded) + 1
		userDefaults.set(count, forKey: Keys.totalMedicationsAdded)
		trackFeatureUse(.addMedication)
		logger.info("Medication added (total: \(count))")
	}
	
	/// Track event logged
	public func trackEventLogged(type: ANEventType) {
		let count = userDefaults.integer(forKey: Keys.totalEventsLogged) + 1
		userDefaults.set(count, forKey: Keys.totalEventsLogged)
		trackFeatureUse(.logDose)
		logger.info("Event logged: \(type) (total: \(count))")
	}
	
	/// Track data export
	public func trackDataExport(itemCount: Int, redacted: Bool) {
		userDefaults.set(Date(), forKey: Keys.lastExportDate)
		trackFeatureUse(.exportData)
		logger.info("Data exported: \(itemCount) items (redacted: \(redacted))")
	}
	
	/// Track data import
	public func trackDataImport(itemCount: Int, success: Bool) {
		if success {
			userDefaults.set(Date(), forKey: Keys.lastImportDate)
		}
		trackFeatureUse(.importData)
		logger.info("Data import \(success ? "successful" : "failed"): \(itemCount) items")
	}
	
	// MARK: - Analytics Summary
	
	/// Get analytics summary
	public func getAnalyticsSummary() -> AnalyticsSummary {
		return AnalyticsSummary(
			firstLaunchDate: userDefaults.object(forKey: Keys.firstLaunchDate) as? Date,
			launchCount: userDefaults.integer(forKey: Keys.launchCount),
			lastLaunchDate: userDefaults.object(forKey: Keys.lastLaunchDate) as? Date,
			totalMedicationsAdded: userDefaults.integer(forKey: Keys.totalMedicationsAdded),
			totalEventsLogged: userDefaults.integer(forKey: Keys.totalEventsLogged),
			lastExportDate: userDefaults.object(forKey: Keys.lastExportDate) as? Date,
			lastImportDate: userDefaults.object(forKey: Keys.lastImportDate) as? Date,
			mostUsedFeatures: getTopFeatures()
		)
	}
	
	/// Get top used features
	private func getTopFeatures() -> [(feature: String, count: Int)] {
		let features = userDefaults.dictionary(forKey: Keys.mostUsedFeatures) as? [String: Int] ?? [:]
		return features
			.map { ($0.key, $0.value) }
			.sorted { $0.1 > $1.1 }
			.prefix(5)
			.map { (feature: $0.0, count: $0.1) }
	}
	
	/// Clear all analytics data
	public func clearAnalytics() {
		let keys = [
			Keys.firstLaunchDate,
			Keys.launchCount,
			Keys.lastLaunchDate,
			Keys.totalMedicationsAdded,
			Keys.totalEventsLogged,
			Keys.lastExportDate,
			Keys.lastImportDate,
			Keys.mostUsedFeatures,
			Keys.dailyActiveUse
		]
		
		for key in keys {
			userDefaults.removeObject(forKey: key)
		}
		
		logger.warning("All analytics data cleared")
	}
}

/// Analytics summary structure
public struct AnalyticsSummary {
	public let firstLaunchDate: Date?
	public let launchCount: Int
	public let lastLaunchDate: Date?
	public let totalMedicationsAdded: Int
	public let totalEventsLogged: Int
	public let lastExportDate: Date?
	public let lastImportDate: Date?
	public let mostUsedFeatures: [(feature: String, count: Int)]
	
	/// Days since first launch
	public var daysSinceFirstLaunch: Int? {
		guard let firstLaunch = firstLaunchDate else { return nil }
		return Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day
	}
	
	/// Average daily launches
	public var averageDailyLaunches: Double? {
		guard let days = daysSinceFirstLaunch, days > 0 else { return nil }
		return Double(launchCount) / Double(days)
	}
}