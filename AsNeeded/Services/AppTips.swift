import DHLoggingKit
import SFSafeSymbols
import SwiftUI
import TipKit

/// Native, dismissible onboarding. No medication names or dose history enter the tip store.
struct LogDoseTip: Tip {
	@Parameter static var hasLearnedQuickLog: Bool = false
	@Parameter static var hasOpenedDosePicker: Bool = false

	var title: Text { Text("Two ways to log a dose") }
	var message: Text? {
		Text("Tap to choose a medication. After recording a dose, hold this button to quickly log that medication again.")
	}
	var image: Image? { Image(systemSymbol: .handTapFill) }
	var rules: [Rule] {
		#Rule(Self.$hasLearnedQuickLog) { $0 == false }
	}
	var options: [any TipOption] { MaxDisplayCount(3) }
}

struct HistoryFilterTip: Tip {
	var title: Text { Text("Find a medication's history") }
	var message: Text? { Text("Choose a medication here, or use All to see every recorded dose.") }
	var rules: [Rule] {
		#Rule(LogDoseTip.$hasOpenedDosePicker) { $0 == true }
	}
	var options: [any TipOption] { MaxDisplayCount(1) }
}

struct MedicationAppearanceTip: Tip {
	var title: Text { Text("Make it yours") }
	var message: Text? { Text("Tap here to choose a color and icon for this medication. Customizing is optional.") }
	var image: Image? { Image(systemSymbol: .paintbrushPointedFill) }
	var options: [any TipOption] { MaxDisplayCount(1) }
}

struct TrendsRangeTip: Tip {
	var title: Text { Text("Choose the bigger picture") }
	var message: Text? { Text("Switch between 14, 30, and 90 complete days to explore your recorded doses.") }
	var rules: [Rule] {
		#Rule(LogDoseTip.$hasOpenedDosePicker) { $0 == true }
	}
	var options: [any TipOption] { MaxDisplayCount(1) }
}

@MainActor
enum AppTips {
	private(set) static var isConfigured = false

	static func configure(defaults: UserDefaults = .standard) {
		guard !isConfigured else { return }
		do {
			try Tips.configure([.displayFrequency(.hourly)])
			isConfigured = true
			// Existing users who learned or dismissed the former hint are not taught it again.
			LogDoseTip.hasLearnedQuickLog = defaults.bool(forKey: UserDefaultsKeys.hasDiscoveredQuickLog)
		} catch {
			DHLogger.ui.logPrivacySafeError("Unable to configure onboarding tips", error: error)
		}
	}

	static func didOpenDosePicker() {
		guard isConfigured else { return }
		LogDoseTip.hasOpenedDosePicker = true
	}

	static func didQuickLog() {
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasDiscoveredQuickLog)
		guard isConfigured else { return }
		LogDoseTip.hasLearnedQuickLog = true
		LogDoseTip().invalidate(reason: .actionPerformed)
	}
}
