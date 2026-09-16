// LogDosePickerSheet.swift
// Medication-agnostic Log Dose picker: search plus a grid of medication tiles that tap to log or hold to quick log.

import ANModelKit
import SFSafeSymbols
import SwiftUI

/// Half-height sheet opened by the medication-agnostic Log Dose button on the Medication tab.
///
/// **Features:**
/// - Search field that focuses itself when the list is long (`LogDosePickerModel.searchAutoFocusThreshold`)
/// - Two-column grid of `LogDoseMedicationTile`s in each medication's color, most recently logged first
/// - Every tile behaves like every other Log Dose control: tap opens Log Dose, hold quick logs
/// - Medium and large detents so a short list stays compact and a long one can expand
///
/// **Use Cases:**
/// - Logging any medication from the Medication tab without scrolling a long list
struct LogDosePickerSheet: View {
	let items: [LogDosePickerItem]
	let onSelect: (ANMedicationConcept) -> Void
	let onQuickLog: (ANMedicationConcept) async -> Bool
	let onQuickLogSuccess: (ANMedicationConcept) -> Void

	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@State private var query = ""
	@FocusState private var isSearchFocused: Bool

	@ScaledMetric private var gridSpacing: CGFloat = 12
	@ScaledMetric private var searchFieldPadding: CGFloat = 10
	@ScaledMetric private var searchIconSpacing: CGFloat = 8
	@ScaledMetric private var searchCornerRadius: CGFloat = 12
	@ScaledMetric private var emptyStateSpacing: CGFloat = 8
	@ScaledMetric private var emptyStateTopPadding: CGFloat = 40

	private var filteredItems: [LogDosePickerItem] {
		LogDosePickerModel.filter(items, query: query)
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				searchField
					.padding(.horizontal)
					.padding(.vertical, searchFieldPadding)

				ScrollView {
					if filteredItems.isEmpty {
						emptyState
					} else {
						LazyVGrid(
							columns: [GridItem(.flexible(), spacing: gridSpacing), GridItem(.flexible(), spacing: gridSpacing)],
							spacing: gridSpacing
						) {
							ForEach(filteredItems) { item in
								LogDoseMedicationTile(
									item: item,
									onTap: { onSelect(item.medication) },
									onQuickLog: { await onQuickLog(item.medication) },
									onQuickLogSuccess: { onQuickLogSuccess(item.medication) }
								)
							}
						}
						.padding(.horizontal)
						.padding(.bottom)
					}
				}
				.scrollDismissesKeyboard(.interactively)
			}
			.customNavigationTitle("Log Dose")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
					.accessibilityLabel("Cancel")
				}
			}
			.task {
				// A long list is faster to search than to scroll, so put the cursor in the field straight away.
				guard items.count >= LogDosePickerModel.searchAutoFocusThreshold else { return }
				try? await Task.sleep(for: .milliseconds(300))
				isSearchFocused = true
			}
		}
		.presentationDetents([.medium, .large])
		.presentationDragIndicator(.visible)
	}

	private var searchField: some View {
		HStack(spacing: searchIconSpacing) {
			Image(systemSymbol: .magnifyingglass)
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)

			TextField("Search medications", text: $query)
				.font(.customFont(fontFamily, style: .body))
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($isSearchFocused)
				.submitLabel(.search)

			if !query.isEmpty {
				Button {
					query = ""
				} label: {
					Image(systemSymbol: .xmarkCircleFill)
						.foregroundStyle(.secondary)
				}
				.accessibilityLabel("Clear search")
			}
		}
		.padding(searchFieldPadding)
		.background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: searchCornerRadius, style: .continuous))
	}

	private var emptyState: some View {
		VStack(spacing: emptyStateSpacing) {
			Image(systemSymbol: .pills)
				.font(.customFont(fontFamily, style: .title2))
				.foregroundStyle(.secondary)
			Text("No medications match \u{201C}\(query)\u{201D}")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, emptyStateTopPadding)
		.padding(.horizontal)
	}
}

/// One medication in the Log Dose picker, colored like its row on the Medication tab.
///
/// Uses the shared `doseLogPressGesture`, so it ticks on touch-down, traces a ring during the hold, and
/// pops on a successful quick log exactly like the row button and the History button.
struct LogDoseMedicationTile: View {
	let item: LogDosePickerItem
	let onTap: () -> Void
	let onQuickLog: () async -> Bool
	let onQuickLogSuccess: () -> Void

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isPressed = false
	@State private var isLongPressing = false
	@State private var holdProgress: Double = 0
	@State private var isCelebrating = false

	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var padding: CGFloat = 14
	@ScaledMetric private var contentSpacing: CGFloat = 10
	@ScaledMetric private var symbolCircleSize: CGFloat = 36
	@ScaledMetric private var holdRingLineWidth: CGFloat = 3
	@ScaledMetric private var minHeight: CGFloat = 108

	private var medication: ANMedicationConcept { item.medication }
	private var foreground: Color { medication.displayColor.contrastingForegroundColor() }
	private var lastTakenText: String { LogDosePickerModel.lastTakenText(for: item.lastDoseDate) }

	private var scale: CGFloat {
		if isCelebrating {
			return 1.06
		}
		return isPressed || isLongPressing ? 0.96 : 1.0
	}

	var body: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			HStack {
				ZStack {
					Circle()
						.fill(foreground.opacity(0.2))
						.frame(width: symbolCircleSize, height: symbolCircleSize)
					Image(systemName: medication.effectiveDisplaySymbol)
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.symbolRenderingMode(.hierarchical)
				}

				Spacer(minLength: 0)

				Image(systemSymbol: .plusCircleFill)
					.font(.customFont(fontFamily, style: .title3, weight: .semibold))
					.opacity(0.9)
			}

			Text(medication.displayName)
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.lineLimit(2)
				.multilineTextAlignment(.leading)
				.minimumScaleFactor(0.85)

			Text(lastTakenText)
				.font(.customFont(fontFamily, style: .caption))
				.opacity(0.85)
				.lineLimit(1)
		}
		.foregroundStyle(foreground)
		.frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
		.padding(padding)
		.background(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.fill(
					LinearGradient(
						colors: [medication.displayColor, medication.displayColor.opacity(0.85)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.shadow(color: medication.displayColor.opacity(0.35), radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
		)
		.overlay(
			// Hold progress ring, in the tile's own contrasting color so it reads on every tint.
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.trim(from: 0, to: holdProgress)
				.stroke(foreground.opacity(0.95), style: StrokeStyle(lineWidth: holdRingLineWidth, lineCap: .round))
				.opacity(holdProgress > 0 ? 1 : 0)
		)
		.scaleEffect(scale)
		.doseLogPressGesture(
			isPressed: $isPressed,
			isLongPressing: $isLongPressing,
			holdProgress: $holdProgress,
			onTap: onTap,
			onQuickLog: onQuickLog,
			onQuickLogSuccess: {
				celebrate()
				onQuickLogSuccess()
			}
		)
		.accessibilityElement(children: .ignore)
		.accessibilityAddTraits(.isButton)
		.accessibilityLabel("Log dose for \(medication.displayName). \(lastTakenText)")
		.accessibilityHint("Tap to customize dose, hold to log default dose")
		.accessibilityAction {
			onTap()
		}
		.accessibilityAction(named: "Quick log default dose") {
			Task {
				if await onQuickLog() {
					onQuickLogSuccess()
				}
			}
		}
	}

	private func celebrate() {
		guard !reduceMotion else { return }
		withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
			isCelebrating = true
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
			withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
				isCelebrating = false
			}
		}
	}
}

#if DEBUG
	#Preview {
		let medications = [
			ANMedicationConcept(clinicalName: "Ibuprofen", nickname: "Advil", quantity: 20, displayColorHex: "#E74C3C", prescribedUnit: .tablet, prescribedDoseAmount: 2),
			ANMedicationConcept(clinicalName: "Cetirizine", quantity: 30, displayColorHex: "#27AE60", prescribedUnit: .tablet, prescribedDoseAmount: 1),
			ANMedicationConcept(clinicalName: "Melatonin", quantity: 60, displayColorHex: "#8E44AD", prescribedUnit: .milligram, prescribedDoseAmount: 5),
		]
		let events = [
			ANEventConcept(eventType: .doseTaken, medication: medications[1], dose: ANDoseConcept(amount: 1, unit: .tablet), date: .now),
		]
		return Color.clear
			.sheet(isPresented: .constant(true)) {
				LogDosePickerSheet(
					items: LogDosePickerModel.items(medications: medications, events: events),
					onSelect: { _ in },
					onQuickLog: { _ in true },
					onQuickLogSuccess: { _ in }
				)
			}
	}
#endif
