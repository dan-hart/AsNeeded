// LogDoseWidgetIntent.swift
// App Intent for logging medication doses directly from widgets (iOS 17+)

import ANModelKit
import AppIntents
import Foundation
import WidgetKit

@available(iOS 17.0, *)
struct LogDoseWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Dose"
    static let description = IntentDescription("Log a dose directly from widget")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Medication ID")
    var medicationID: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Parse medication ID
        guard let id = UUID(uuidString: medicationID) else {
			throw WidgetLogError.medicationUnavailable
        }

		try await WidgetDataProvider.shared.recordDose(medicationID: id)
		WidgetCenter.shared.reloadAllTimelines()
		return .result()

    }
}
