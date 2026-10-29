import ANModelKit
import SFSafeSymbols
import SwiftUI

/// Screen presentation only. Never written to defaults, models, backups, or extensions.
@MainActor
final class DemoModeState: ObservableObject {
	static let shared = DemoModeState()
	@Published private(set) var isEnabled = false

	private let medicationNames: () -> [String]

	init(medicationNames: @escaping () -> [String] = {
		DataStore.shared.medications.flatMap { [$0.clinicalName, $0.nickname ?? ""] }
	}) {
		self.medicationNames = medicationNames
	}

	func enable() { isEnabled = true }
	func confirmDisable(_ confirmed: Bool) {
		if confirmed { isEnabled = false }
	}

	func name(_ original: String) -> String {
		isEnabled && !original.isEmpty ? "Hidden medication" : original
	}

	func text(_ original: String) -> String {
		guard isEnabled else { return original }
		let names = medicationNames().map(\.precomposedStringWithCanonicalMapping).filter { !$0.isEmpty }.sorted { $0.count > $1.count }
		guard !names.isEmpty,
			let expression = try? NSRegularExpression(
				pattern: names.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|"),
				options: .caseInsensitive
			) else { return original }
		let normalized = original.precomposedStringWithCanonicalMapping
		// Match the original once so a short name cannot redact the replacement itself.
		return expression.stringByReplacingMatches(in: normalized,
			range: NSRange(normalized.startIndex..., in: normalized), withTemplate: "Hidden medication")
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
		content.alert("Are you sure you want to turn off demo mode?", isPresented: $isPresented) {
			Button("No", role: .cancel) {}
				.keyboardShortcut(.defaultAction)
			Button("Yes") {
				demoMode.confirmDisable(true)
			}
		}
		.tint(.accent)
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
