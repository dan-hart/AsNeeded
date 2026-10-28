import ANModelKit
import SFSafeSymbols
import SwiftUI

/// Medication chooser adapted from 8fab48f, opening the existing dose form.
struct LogDosePickerSheet: View {
	let medications: [ANMedicationConcept]
	@Binding var query: String
	let onSelect: (ANMedicationConcept) -> Void
	var onQuickLog: ((ANMedicationConcept) async -> Bool)? = nil
	var onQuickLogSuccess: ((ANMedicationConcept) -> Void)? = nil

	@State private var quickLogError = false
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily

	private var matches: [ANMedicationConcept] {
		LogDosePickerModel.medications(from: medications, matching: query)
	}

	var body: some View {
		NavigationStack {
			List {
				if matches.isEmpty {
					Text("No medications match your search")
						.font(.customFont(fontFamily, style: .body))
						.foregroundStyle(.secondary)
				} else {
					ForEach(matches) { medication in
						LogDosePickerRow(medication: medication, onSelect: { onSelect(medication) },
							onQuickLog: onQuickLog.map { action in {
							let saved = await action(medication)
							if !saved { quickLogError = true }
							return saved
						} },
							onSuccess: { onQuickLogSuccess?(medication) })
							.listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))

					}
				}
			}
			.alert("Couldn’t Log Dose", isPresented: $quickLogError) {
				Button("OK", role: .cancel) {}
			} message: { Text("Your dose was not saved. Please try again.") }
			.listStyle(.plain)
			.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search medications")
			.customNavigationTitle("Choose Medication", displayMode: .inline)
			.toolbar {
				Button(role: .close) { dismiss() }
					.accessibilityLabel("Close medication picker")
			}
			.tint(.accent)
		}
		.presentationDetents([.medium, .large])
		.presentationDragIndicator(.visible)
	}
}

private struct LogDosePickerRow: View {
	let medication: ANMedicationConcept
	let onSelect: () -> Void
	let onQuickLog: (() async -> Bool)?
	let onSuccess: () -> Void
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.colorSchemeContrast) private var contrast
	@State private var isPressed = false
	@State private var isLongPressing = false
	@State private var holdProgress: Double = 0

	var body: some View {
		let palette = medication.displayColor.filledButtonColors(for: colorScheme, contrast: contrast)
		Button(action: onSelect) {
			HStack(spacing: 12) {
				Image(systemName: medication.effectiveDisplaySymbol)
					.font(.customFont(fontFamily, style: .title3))
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 4) {
					Text(medication.displayName)
						.font(.customFont(fontFamily, style: .headline))
						.noTruncate()
					Text(QuickLogHintPolicy.hintText(for: medication))
						.font(.customFont(fontFamily, style: .caption))
						.noTruncate()
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.foregroundStyle(palette.foreground)
			.padding(8)
			.frame(minHeight: 60)
			.background(palette.background, in: RoundedRectangle(cornerRadius: 12))
			.overlay {
				RoundedRectangle(cornerRadius: 12).trim(from: 0, to: holdProgress)
					.stroke(palette.foreground, lineWidth: 3)
					.padding(2).allowsHitTesting(false).accessibilityHidden(true)
			}
		}
		.buttonStyle(.plain)
		.listRowSeparator(.hidden)
		.doseLogPressGesture(isPressed: $isPressed, isLongPressing: $isLongPressing,
			holdProgress: $holdProgress, onTap: onSelect, onQuickLog: onQuickLog, onQuickLogSuccess: onSuccess)
		.accessibilityLabel("Log dose for \(medication.displayName)")
		.accessibilityHint("Tap to customize dose, hold to log default dose")
		.accessibilityAction(named: "Quick log default dose") {
			guard let onQuickLog else { return }
			Task { if await onQuickLog() { onSuccess() } }
		}
	}
}
