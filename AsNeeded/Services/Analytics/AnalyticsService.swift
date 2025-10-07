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
	
	
	private init() {
		trackAppLaunch()
	}
	
	// MARK: - App Lifecycle
	
	/// Track app launch
	private func trackAppLaunch() {
		// Record first launch if needed
		if userDefaults.object(forKey: UserDefaultsKeys.analyticsFirstLaunchDate) == nil {
			userDefaults.set(Date(), forKey: UserDefaultsKeys.analyticsFirstLaunchDate)
			logger.info("First app launch recorded")
		}

		// Increment launch count
		let launchCount = userDefaults.integer(forKey: UserDefaultsKeys.analyticsLaunchCount) + 1
		userDefaults.set(launchCount, forKey: UserDefaultsKeys.analyticsLaunchCount)
		userDefaults.set(Date(), forKey: UserDefaultsKeys.analyticsLastLaunchDate)

		logger.info("App launch #\(launchCount)")

		// Track daily active use
		trackDailyActiveUse()
	}
	
	/// Track daily active use
	private func trackDailyActiveUse() {
		let today = DateUtility.startOfToday
		let lastActiveDate = userDefaults.object(forKey: UserDefaultsKeys.analyticsDailyActiveUse) as? Date

		if let lastActiveDate = lastActiveDate {
			if !Calendar.current.isDate(lastActiveDate, inSameDayAs: today) {
				userDefaults.set(today, forKey: UserDefaultsKeys.analyticsDailyActiveUse)
				logger.info("Daily active use recorded for \(today)")
			}
		} else {
			userDefaults.set(today, forKey: UserDefaultsKeys.analyticsDailyActiveUse)
			logger.info("Daily active use recorded for \(today)")
		}
	}
	
	// MARK: - Feature Usage
	
	/// Track feature usage
	public func trackFeatureUse(_ feature: Feature) {
		var features = userDefaults.dictionary(forKey: UserDefaultsKeys.analyticsMostUsedFeatures) as? [String: Int] ?? [:]
		let count = (features[feature.rawValue] ?? 0) + 1
		features[feature.rawValue] = count
		userDefaults.set(features, forKey: UserDefaultsKeys.analyticsMostUsedFeatures)

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
		let count = userDefaults.integer(forKey: UserDefaultsKeys.analyticsTotalMedicationsAdded) + 1
		userDefaults.set(count, forKey: UserDefaultsKeys.analyticsTotalMedicationsAdded)
		trackFeatureUse(.addMedication)
		logger.info("Medication added (total: \(count))")
	}

	/// Track event logged
	public func trackEventLogged(type: ANEventType) {
		let count = userDefaults.integer(forKey: UserDefaultsKeys.analyticsTotalEventsLogged) + 1
		userDefaults.set(count, forKey: UserDefaultsKeys.analyticsTotalEventsLogged)
		trackFeatureUse(.logDose)
		logger.info("Event logged: \(type) (total: \(count))")
	}

	/// Track data export
	public func trackDataExport(itemCount: Int, redacted: Bool) {
		userDefaults.set(Date(), forKey: UserDefaultsKeys.analyticsLastExportDate)
		trackFeatureUse(.exportData)
		logger.info("Data exported: \(itemCount) items (redacted: \(redacted))")
	}

	/// Track data import
	public func trackDataImport(itemCount: Int, success: Bool) {
		if success {
			userDefaults.set(Date(), forKey: UserDefaultsKeys.analyticsLastImportDate)
		}
		trackFeatureUse(.importData)
		logger.info("Data import \(success ? "successful" : "failed"): \(itemCount) items")
	}
	
	// MARK: - Analytics Summary
	
	/// Get analytics summary
	public func getAnalyticsSummary() -> AnalyticsSummary {
		return AnalyticsSummary(
			firstLaunchDate: userDefaults.object(forKey: UserDefaultsKeys.analyticsFirstLaunchDate) as? Date,
			launchCount: userDefaults.integer(forKey: UserDefaultsKeys.analyticsLaunchCount),
			lastLaunchDate: userDefaults.object(forKey: UserDefaultsKeys.analyticsLastLaunchDate) as? Date,
			totalMedicationsAdded: userDefaults.integer(forKey: UserDefaultsKeys.analyticsTotalMedicationsAdded),
			totalEventsLogged: userDefaults.integer(forKey: UserDefaultsKeys.analyticsTotalEventsLogged),
			lastExportDate: userDefaults.object(forKey: UserDefaultsKeys.analyticsLastExportDate) as? Date,
			lastImportDate: userDefaults.object(forKey: UserDefaultsKeys.analyticsLastImportDate) as? Date,
			mostUsedFeatures: getTopFeatures()
		)
	}

	/// Get top used features
	private func getTopFeatures() -> [(feature: String, count: Int)] {
		let features = userDefaults.dictionary(forKey: UserDefaultsKeys.analyticsMostUsedFeatures) as? [String: Int] ?? [:]
		return features
			.map { ($0.key, $0.value) }
			.sorted { $0.1 > $1.1 }
			.prefix(5)
			.map { (feature: $0.0, count: $0.1) }
	}
	
	/// Clear all analytics data
	public func clearAnalytics() {
		let keys = [
			UserDefaultsKeys.analyticsFirstLaunchDate,
			UserDefaultsKeys.analyticsLaunchCount,
			UserDefaultsKeys.analyticsLastLaunchDate,
			UserDefaultsKeys.analyticsTotalMedicationsAdded,
			UserDefaultsKeys.analyticsTotalEventsLogged,
			UserDefaultsKeys.analyticsLastExportDate,
			UserDefaultsKeys.analyticsLastImportDate,
			UserDefaultsKeys.analyticsMostUsedFeatures,
			UserDefaultsKeys.analyticsDailyActiveUse
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