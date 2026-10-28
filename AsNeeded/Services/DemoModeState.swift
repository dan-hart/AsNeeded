import ANModelKit
import SFSafeSymbols
import SwiftUI

/// Screen presentation only. Never written to defaults, models, backups, or extensions.
@MainActor
final class DemoModeState: ObservableObject {
	static let shared = DemoModeState()
	@Published private(set) var isEnabled = false

	private init() {}

	func enable() { isEnabled = true }
	fileprivate func disableAfterConfirmation() { isEnabled = false }

	func name(_ original: String) -> String {
		isEnabled && !original.isEmpty ? "Hidden medication" : original
	}

	func text(_ original: String) -> String {
		guard isEnabled else { return original }
		let names = DataStore.shared.medications.flatMap { [$0.clinicalName, $0.nickname ?? ""] }
			.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
		return names.reduce(original) { result, name in
			result.replacingOccurrences(of: name, with: "Hidden medication", options: .caseInsensitive)
		}
	}
}

@MainActor
extension ANMedicationConcept {
	var demoDisplayName: String { DemoModeState.shared.name(displayName) }
	var demoClinicalName: String { DemoModeState.shared.name(clinicalName) }
}

private struct DemoNameRedaction: ViewModifier {
	@ObservedObject private var demoMode = DemoModeState.shared

	func body(content: Content) -> some View {
		if demoMode.isEnabled {
			content.redacted(reason: .placeholder)
				.accessibilityLabel("Medication name hidden")
		} else {
			content
		}
	}
}

struct DemoModeBanner: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	@Environment(\.fontFamily) private var fontFamily
	@State private var showDisableConfirmation = false

	var body: some View {
		if demoMode.isEnabled {
			Button { showDisableConfirmation = true } label: {
				Label("Demo Mode is on · Tap to turn off", systemSymbol: .exclamationmarkTriangleFill)
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.fixedSize(horizontal: false, vertical: true)
					.foregroundStyle(.black)
					.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
					.padding(12)
					.background(.yellow, in: RoundedRectangle(cornerRadius: 12))
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Demo Mode is on. Turn off Demo Mode")
			.accessibilityHint("Asks for confirmation before showing medication names")
			.confirmDemoModeDisable(isPresented: $showDisableConfirmation)
			.padding(.vertical, 8)
		}
	}
}

private struct DemoModeDisableConfirmation: ViewModifier {
	@ObservedObject private var demoMode = DemoModeState.shared
	@Binding var isPresented: Bool

	func body(content: Content) -> some View {
		content.alert("Turn Off Demo Mode?", isPresented: $isPresented) {
			Button("Keep Names Hidden", role: .cancel) {}
			Button("Show Medication Names", role: .destructive) {
				demoMode.disableAfterConfirmation()
			}
		} message: {
			Text("Your medication names will become visible. Continue only when you're ready to show them.")
		}
	}
}

private struct DemoMedicationSearch: ViewModifier {
	@ObservedObject private var demoMode = DemoModeState.shared
	@Environment(\.fontFamily) private var fontFamily
	@Binding var query: String

	func body(content: Content) -> some View {
		if demoMode.isEnabled {
			VStack(spacing: 0) {
				SecureField("Search medications", text: $query)
					.font(.customFont(fontFamily, style: .body))
					.textFieldStyle(.roundedBorder)
					.demoNameRedacted()
					.accessibilityLabel("Search medications")
					.padding()
				content
			}
		} else {
			content.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search medications")
		}
	}
}

extension View {
	func confirmDemoModeDisable(isPresented: Binding<Bool>) -> some View {
		modifier(DemoModeDisableConfirmation(isPresented: isPresented))
	}

	func demoNameRedacted() -> some View { modifier(DemoNameRedaction()) }

	func demoMedicationSearch(query: Binding<String>) -> some View {
		modifier(DemoMedicationSearch(query: query))
	}
}
