import AppIntents
import Foundation

/// Preserve cached intent identity. Compiled into both targets so foreground execution belongs to the app.
struct LogDoseWidgetIntent: AppIntent {
	static let title: LocalizedStringResource = "Log Dose"
	static let description = IntentDescription("Open the dose form to review and save a dose.")
	static let isDiscoverable = false
	static let openAppWhenRun = true

	@Parameter(title: "Medication ID")
	var medicationID: String

	private let navigate: @MainActor @Sendable (UUID) throws -> Void

	init() {
		navigate = { id in
			#if ASNEEDED_WIDGET_EXTENSION
			// Fail closed if a stale archive is dispatched to the extension instead of the foreground app.
			throw WidgetLogError.reviewInApp
			#else
			NavigationManager.shared.pendingWidgetRoute = .logDose(id)
			#endif
		}
	}

	init(navigate: @escaping @MainActor @Sendable (UUID) throws -> Void) {
		self.navigate = navigate
	}

	@MainActor
	func perform() async throws -> some IntentResult & ReturnsValue<URL> {
		guard let id = UUID(uuidString: medicationID), let url = WidgetNavigationRoute.logDose(id).url else {
			throw WidgetLogError.medicationUnavailable
		}
		try navigate(id)
		return .result(value: url)
	}
}
