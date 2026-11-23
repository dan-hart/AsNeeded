import Accessibility
import ANModelKit
import Combine
import Foundation
import SFSafeSymbols
import SwiftUI
import TipKit

private enum HistoryEntryMutation {
	case edit
	case delete
}

struct MedicationHistoryView: View {
	private enum Anchor: Hashable {
		case day(Date)
		case entry(UUID)
	}

	private struct ScrollRequest: Equatable {
		let id = UUID()
		let target: Anchor
	}

	private struct Feedback {
		let id = UUID()
		var target: Anchor?
		var message: String?
		var changedSubtotals: Set<MedicationHistoryViewModel.SubtotalID> = []
	}

	@AppStorage(UserDefaultsKeys.historyShowsDailyTotals) private var showDailyTotals = UserDefaultsKeys.defaultHistoryShowsDailyTotals
	@ObservedObject private var demoMode = DemoModeState.shared
	@State private var showSupportPage = false
	@StateObject private var doseLogSession = LogDoseView.Session()
	@StateObject private var viewModel = MedicationHistoryViewModel()
	// Reuse the existing atomic dose/Undo coordinator on both tabs.
	@StateObject private var quickLogCoordinator = MedicationListViewModel()
	@State private var quickLogError = false
	@State private var floatingLogDoseScroll = FloatingLogDoseScrollState()
	@State private var showLogDosePicker = false
	@State private var pickerQuery = ""
	@State private var pendingPickerMedication: ANMedicationConcept?

	@EnvironmentObject private var navigationManager: NavigationManager
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var logMedication: ANMedicationConcept?
	@State private var scrollRequest: ScrollRequest?
	@State private var feedback: Feedback?
	@State private var pendingJumpDate: Date?
	@State private var pendingEditorFeedback: Feedback?
	@AccessibilityFocusState(for: .voiceOver) private var focusedEntry: UUID?
	@State private var showDatePicker = false
	@State private var showCustomRange = false
	@State private var lastHistoryRequestID: UUID?
	@State private var selectedDate = Date()
	@State private var editingEvent: ANEventConcept?
	@State private var editingNoteText: String = ""
	@FocusState private var isNoteFieldFocused: Bool
	@State private var editingEntryEvent: ANEventConcept?
	@State private var reviewingDose: ANEventConcept?
	@State private var reviewEditID: UUID?
	@State private var showDiscardNoteChanges = false

	@ScaledMetric private var emptySectionSpacing: CGFloat = 24
	@ScaledMetric private var entrySpacing: CGFloat = 8
	@ScaledMetric private var noteTopSpacing: CGFloat = 4
	@ScaledMetric private var sectionHeaderSpacing: CGFloat = 2
	@ScaledMetric private var medicationColorCircleSize: CGFloat = 26
	@ScaledMetric private var colorCircleShadowRadius: CGFloat = 3
	@ScaledMetric private var colorCircleStrokeWidth: CGFloat = 0.5
	@ScaledMetric private var pickerContainerPaddingV: CGFloat = 12
	@ScaledMetric private var fabPaddingH: CGFloat = 24
	@ScaledMetric private var floatingButtonClearance: CGFloat = 88
	@ScaledMetric private var reflectionBadgePaddingH: CGFloat = 8
	@ScaledMetric private var reflectionBadgePaddingV: CGFloat = 5

	private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

	// MARK: - Private ViewBuilders

	@ViewBuilder
	private func emptyHistoryView(for selected: ANMedicationConcept) -> some View {
		Spacer()
		VStack(spacing: emptySectionSpacing) {
			Text("No history for \(selected.demoDisplayName).")
				.demoNameRedacted()
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .center)
				.noTruncate()
			Text("Use Log Dose to record a dose you have taken.")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		Spacer()
	}

	private func historyDoseDetails(for date: Date, doseText: String?) -> some View {
		let time = date.formatted(date: .omitted, time: .shortened)
		let details = doseText.map { "\(time) – \($0)" } ?? time
		let relative = relativeShortIfToday(date)
		return ViewThatFits(in: .horizontal) {
			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Text(details)
					.font(.customFont(fontFamily, style: .subheadline))
				if let relative {
					Text(relative)
						.font(.customFont(fontFamily, style: .footnote))
						.foregroundStyle(.secondary)
				}
			}
			.fixedSize(horizontal: true, vertical: true)

			VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
				Text(details)
					.font(.customFont(fontFamily, style: .subheadline))
					.noTruncate()
				if let relative {
					Text(relative)
						.font(.customFont(fontFamily, style: .footnote))
						.foregroundStyle(.secondary)
						.noTruncate()
				}
			}
		}
	}

	@ViewBuilder
	private func historyListView(_ groups: [MedicationHistoryViewModel.Day]) -> some View {
		let showButtonDay: Date? = if !showDailyTotals, viewModel.isShowingAllMedications,
			groups.contains(where: { !$0.medicationTotals.isEmpty })
		{
			groups.first?.day
		} else {
			nil
		}

		ScrollViewReader { proxy in
			List {
				if demoMode.isEnabled {
					DemoModeBanner()
						.listRowInsets(EdgeInsets())
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
				ForEach(groups, id: \.day) { group in
					Section(header: sectionHeader(for: group, offersDailyTotals: group.day == showButtonDay)) {
						ForEach(group.entries, id: \.id) { event in
							historyRow(for: event)
								.id(Anchor.entry(event.id))
						}
						if showDailyTotals, viewModel.isShowingAllMedications, !group.medicationTotals.isEmpty {
							dailyTotalsRow(for: group)
								.swipeActions(edge: .trailing, allowsFullSwipe: false) {
									Button {
										showDailyTotals = false
									} label: {
										Label("Hide daily totals", systemSymbol: .eyeSlash)
									}
									.tint(.accent)
								}
						}
					}
					.id(Anchor.day(group.day))
				}
				SupportSuggestionView(onSupportTapped: { showSupportPage = true })
					.listRowInsets(EdgeInsets())
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
					.environment(\.defaultMinListRowHeight, 0)
			}
			.collapsesFloatingLogDose(floatingLogDoseScroll)
			.listStyle(.insetGrouped)
			.onChange(of: scrollRequest, initial: true) { _, request in
				guard let request else { return }
				let anchor: UnitPoint = if case .entry = request.target { .center } else { .top }
				withAnimation(reduceMotion ? nil : .default) {
					proxy.scrollTo(request.target, anchor: anchor)
				}
				scrollRequest = nil
			}
		}
	}

	private var showDailyTotalsButton: some View {
		Button {
			showDailyTotals = true
		} label: {
			Text("Show daily totals")
				.font(.customFont(fontFamily, style: .footnote, weight: .semibold))
				.frame(minHeight: 44)
				.contentShape(Rectangle())
		}
		.buttonStyle(.borderless)
		.tint(.accent)
	}

	private func historyRow(for event: ANEventConcept) -> some View {
		let medication = event.medication.map { viewModel.currentMedication(for: $0) }
		let reflection = DoseReflectionCodec.reflection(from: event.note)
		let note = reflection?.note
		let doseText = event.dose.map { $0.unit.localizedCompactAmount(for: $0.amount) }
		let highlights = reflectionHighlights(for: reflection, historicalMedication: event.medication)
		let tint = viewModel.isShowingAllMedications ? Color.accent : (medication?.displayColor ?? .accent)
		let isSavedEntry = feedback?.target == .entry(event.id)

		return VStack(alignment: .leading, spacing: entrySpacing) {
			HStack(alignment: .center, spacing: 8) {
				Button {
					editingEntryEvent = event
				} label: {
					HStack(alignment: .center) {
						if !dynamicTypeSize.isAccessibilitySize, viewModel.isShowingAllMedications, let medication {
							medicationIcon(for: medication)
						}

						VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
							if viewModel.isShowingAllMedications, let medication {
								Text(medication.demoDisplayName)
									.demoNameRedacted()
									.font(.customFont(fontFamily, style: .headline))
									.noTruncate()
							}

							historyDoseDetails(for: event.date, doseText: doseText)
							if isSavedEntry {
								feedbackLabel(String(localized: "Entry saved"))
							}
						}
						.fixedSize(horizontal: false, vertical: true)
						Spacer()
					}
					.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel(historyAccessibilityLabel(for: event, medication: medication, doseText: doseText, hasNote: note != nil))
				.accessibilityHint("Edit this dose entry")
				.accessibilityValue(isSavedEntry ? Text("Entry saved") : Text(verbatim: ""))
				.accessibilityFocused($focusedEntry, equals: event.id)
				.background {
					if isSavedEntry {
						Color.clear
							.task(id: feedback?.id) {
								await Task.yield()
								if !Task.isCancelled { focusedEntry = event.id }
							}
					}
				}

				// Show add note button on trailing side if no note exists
				if note == nil {
					AddNoteButtonComponent(
						medicationColor: viewModel.isShowingAllMedications ? .secondary : tint,
						onTap: {
							editingEvent = event
							editingNoteText = ""
						}
					)
				}
			}

			if let warning = viewModel.doseWarnings[event.id] {
				let status = HistoryDoseWarningView.status(for: warning)
				Button {
					reviewingDose = event
				} label: {
					Label(status.title, systemSymbol: status.symbol)
						.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
						.fixedSize(horizontal: false, vertical: true)
						.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
						.contentShape(Rectangle())
				}
				.buttonStyle(.borderless)
				.tint(.accent)
				.accessibilityHint("Review dose details")
			}

			if !highlights.isEmpty {
				let reflectionLayout = dynamicTypeSize.isAccessibilitySize
					? AnyLayout(VStackLayout(alignment: .leading, spacing: entrySpacing))
					: AnyLayout(HStackLayout(spacing: sectionHeaderSpacing))
				reflectionLayout {
					ForEach(highlights.indices, id: \.self) { index in
						reflectionBadge(highlights[index], tint: tint)
					}
				}
			}

			// Show enhanced note display below if it exists
			if let note {
				NoteDisplayCardComponent(
					noteText: demoMode.text(note, historicalMedication: event.medication),
					medicationColor: tint,
					onEdit: {
						editingEvent = event
						editingNoteText = note
					}
				)
				.padding(.top, noteTopSpacing)
			}
		}
		.listRowBackground(isSavedEntry ? Color.accent.opacity(0.12) : nil)
		.contentShape(Rectangle())
		.accessibilityElement(children: .contain)
		.accessibilityAction(named: "Edit entry") {
			editingEntryEvent = event
		}
		.accessibilityAction(named: "Edit note") {
			editingEvent = event
			editingNoteText = note ?? ""
		}
		.swipeActions(edge: .trailing) {
			Button {
				editingEntryEvent = event
			} label: {
				Label("Edit", systemSymbol: .pencil)
			}
			.tint(.accent)

			Button(role: .destructive) {
				Task {
					let previousGroups = viewModel.groupedHistory
					if await viewModel.deleteEvent(event) {
						presentFeedback(mutationFeedback(for: .delete, eventID: event.id, previousGroups: previousGroups))
					}
				}
			} label: {
				Label("Delete", systemSymbol: .trash)
			}
			.tint(.red)
			.disabled(viewModel.isMutating)
		}
	}

	private func reflectionBadge(_ highlight: String, tint: Color) -> some View {
		Text(highlight)
			.font(.customFont(fontFamily, style: .caption, weight: .medium))
			.noTruncate()
			.foregroundStyle(tint)
			.padding(.horizontal, reflectionBadgePaddingH)
			.padding(.vertical, reflectionBadgePaddingV)
			.background(tint.opacity(0.12), in: Capsule())
	}

	private func medicationIcon(for medication: ANMedicationConcept) -> some View {
		let color = medication.displayColor
		return Image(systemName: medication.effectiveDisplaySymbol)
			.font(.customFont(fontFamily, style: .caption, weight: .medium))
			.symbolRenderingMode(.hierarchical)
			.foregroundStyle(color)
			.frame(width: medicationColorCircleSize, height: medicationColorCircleSize)
			.background {
				Circle()
					.fill(color.opacity(0.15))
					.shadow(color: color.opacity(0.4), radius: colorCircleShadowRadius, x: 0, y: 1)
					.overlay(Circle().stroke(.white.opacity(0.3), lineWidth: colorCircleStrokeWidth))
			}
			.accessibilityHidden(true)
	}

	private func dailyTotalsRow(for group: MedicationHistoryViewModel.Day) -> some View {
		let rows = group.medicationTotals.map { total in
			(medication: viewModel.currentMedication(for: total.medication), amounts: total.amounts)
		}.sorted { lhs, rhs in
			switch lhs.medication.demoDisplayName.localizedStandardCompare(rhs.medication.demoDisplayName) {
			case .orderedSame: lhs.medication.id.uuidString < rhs.medication.id.uuidString
			case .orderedAscending: true
			case .orderedDescending: false
			}
		}

		return VStack(alignment: .leading, spacing: sectionHeaderSpacing * 3) {
			Text("Daily totals", comment: "Heading for the per-medication dose totals below each day in History.")
				.font(.customFont(fontFamily, style: .caption, weight: .semibold))
				.foregroundStyle(.secondary)
				.accessibilityAddTraits(.isHeader)

			ForEach(rows, id: \.medication.id) { row in
				let subtotal = MedicationHistoryViewModel.SubtotalID(day: group.day, medicationID: row.medication.id)
				let changed = feedback?.changedSubtotals.contains(subtotal) == true
				dailyTotal(for: row.medication, amounts: row.amounts, changed: changed)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func dailyTotal(for medication: ANMedicationConcept, amounts: [ANUnitConcept: Double], changed: Bool) -> some View {
		let total = amounts.sorted { $0.key.rawValue < $1.key.rawValue }
			.map { unit, amount in
				if amount < 0.005 {
					return String(localized: "<\(unit.localizedCompactAmount(for: 0.01))",
						comment: "A positive dose below the smallest amount shown in the compact unit format.")
				}
				return unit.localizedCompactAmount(for: amount)
			}
			.formatted(.list(type: .and))
		let layout = dynamicTypeSize.isAccessibilitySize
			? AnyLayout(VStackLayout(alignment: .leading, spacing: sectionHeaderSpacing))
			: AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: entrySpacing))

		return layout {
			HStack(spacing: entrySpacing) {
				Circle()
					.fill(medication.displayColor)
					.frame(width: 7, height: 7)
					.accessibilityHidden(true)
				Text(medication.demoDisplayName)
					.demoNameRedacted()
					.font(.customFont(fontFamily, style: .subheadline))
					.noTruncate()
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: sectionHeaderSpacing * 2) {
				if changed {
					Image(systemSymbol: .checkmarkCircleFill)
						.foregroundStyle(Color.accent)
						.accessibilityHidden(true)
				}
				Text(total)
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.monospacedDigit()
					.multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
					.noTruncate()
			}
		}
		.background(changed ? Color.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 4))
		.accessibilityElement(children: .combine)
		.accessibilityValue(changed ? Text("Updated subtotal") : Text(verbatim: ""))
	}

	// MARK: - Section Header Helpers

	@ViewBuilder
	private func sectionHeader(for group: MedicationHistoryViewModel.Day, offersDailyTotals: Bool) -> some View {
		VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
			if offersDailyTotals { showDailyTotalsButton }

			let headerLayout = dynamicTypeSize.isAccessibilitySize
				? AnyLayout(VStackLayout(alignment: .leading, spacing: sectionHeaderSpacing))
				: AnyLayout(HStackLayout())
			headerLayout {
				Text(formatDateWithDayOfWeek(group.day))
					.font(.customFont(fontFamily, style: .headline))
					.accessibilityAddTraits(.isHeader)
				Spacer()
				if let totalText = selectedMedicationTotal(for: group) {
					Text(totalText)
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(.secondary)
						.noTruncate()
				}
			}
			if feedback?.target == .day(group.day), let message = feedback?.message {
				feedbackLabel(message, icon: .arrowDownCircle)
			}
			if let rel = dayRelativeLabel(for: group.day) {
				Text(rel)
					.font(.customFont(fontFamily, style: .footnote))
					.foregroundStyle(.secondary)
			}
		}
	}

	private func formatDateWithDayOfWeek(_ date: Date) -> String {
		let dayFormatter = DateFormatter()
		dayFormatter.dateFormat = "EEE" // Mon, Tue, Wed, etc.
		let dayOfWeek = dayFormatter.string(from: date)

		let dateString = date.formatted(date: .abbreviated, time: .omitted)
		return String(localized: "\(dayOfWeek), \(dateString)")
	}

	private func selectedMedicationTotal(for group: MedicationHistoryViewModel.Day) -> String? {
		guard let selected = viewModel.selectedMedication,
			let unit = selected.prescribedUnit ?? group.entries.lazy.compactMap({ $0.dose?.unit }).first,
			let amount = group.medicationTotals.first?.amounts[unit] else { return nil }
		return unit.localizedCompactAmount(for: amount)
	}

	private func dayRelativeLabel(for date: Date) -> String? {
		let cal = Calendar.current
		let currentTime = Date.now
		if cal.isDate(date, inSameDayAs: currentTime) { return String(localized: "Today") }
		if let yesterday = cal.date(byAdding: .day, value: -1, to: currentTime), cal.isDate(date, inSameDayAs: yesterday) { return String(localized: "Yesterday") }

		// Use our centralized relative formatting for other dates
		let daysDiff = cal.dateComponents([.day], from: date, to: currentTime).day ?? 0
		if daysDiff > 1 && daysDiff <= 7 {
			return date.relativeFormattedAsPast.capitalized
		}
		return nil
	}

	private func relativeShortIfToday(_ date: Date) -> String? {
		let cal = Calendar.current
		let currentTime = Date.now
		let elapsed = currentTime.timeIntervalSince(date)
		guard cal.isDate(date, inSameDayAs: currentTime), elapsed >= 0 else { return nil }
		let diff = Int(elapsed)
		if diff <= 60 { return String(localized: "Logged just now") }
		let mins = diff / 60
		if mins < 60 { return String(localized: "\(mins)m ago") }
		let hrs = mins / 60
		return String(localized: "\(hrs)h ago")
	}

	private func displayNote(for event: ANEventConcept) -> String? {
		DoseReflectionCodec.displayNote(from: event.note)
	}

	private func reflectionHighlights(for reflection: DoseReflection?, historicalMedication: ANMedicationConcept?) -> [String] {
		guard let reflection else {
			return []
		}

		var highlights: [String] = []

		if let reason = reflection.reason {
			highlights.append(demoMode.text(reason, historicalMedication: historicalMedication))
		}

		if let effectiveness = reflection.effectiveness {
			highlights.append(String(localized: "Effect \(effectiveness)/5"))
		}

		if let before = reflection.symptomSeverityBefore, let after = reflection.symptomSeverityAfter {
			highlights.append(String(localized: "Before \(before)/5 to \(after)/5"))
		}

		if let sideEffect = reflection.sideEffects.first {
			highlights.append(demoMode.text(sideEffect, historicalMedication: historicalMedication))
		}

		return Array(highlights.prefix(3))
	}

	private func historyAccessibilityLabel(for event: ANEventConcept, medication: ANMedicationConcept?, doseText: String?, hasNote: Bool) -> String {
		let medicationText = medication?.demoDisplayName ?? String(localized: "Medication")
		let amountText = doseText ?? String(localized: "dose amount not recorded")
		let timeText = event.date.formatted(date: .abbreviated, time: .shortened)
		let noteText = hasNote ? String(localized: "Has note") : String(localized: "No note")
		return String(localized: "\(medicationText), \(amountText), logged \(timeText). \(noteText).")
	}

	private var mutationErrorPresented: Binding<Bool> {
		Binding(
			get: { viewModel.mutationError != nil },
			set: { if !$0 { viewModel.mutationError = nil } }
		)
	}

	@ViewBuilder
	private func selectionPromptView() -> some View {
		Spacer()
		Text("Select a medication to see history.")
			.font(.customFont(fontFamily, style: .body))
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, alignment: .center)
		Spacer()
	}

	// MARK: - Private Methods

	private func applyHistoryNavigation() {
		guard lastHistoryRequestID != navigationManager.historyRequestID else { return }
		lastHistoryRequestID = navigationManager.historyRequestID
		let targetDate = navigationManager.historyTargetDate
		let targetRange = navigationManager.historyTargetRange
		if let id = navigationManager.historyTargetMedicationID, let uuid = UUID(uuidString: id) {
			guard DataStore.shared.medications.contains(where: { $0.id == uuid }) else {
				navigationManager.clearHistoryNavigation()
				navigationManager.showWidgetUnavailable = true
				return
			}
			viewModel.selectedMedicationID = uuid.uuidString
		} else { viewModel.ensureValidSelection() }
		viewModel.dateFilter = targetRange.map(HistoryDateFilter.custom) ?? .allTime
		feedback = nil
		scrollRequest = nil
		if let date = targetDate ?? targetRange?.end, let day = viewModel.jumpTarget(for: date).landedDay {
			scrollRequest = ScrollRequest(target: .day(day))
		}
		navigationManager.clearHistoryNavigation()
	}

	private func feedbackLabel(_ message: String, icon: SFSymbol = .checkmarkCircle) -> some View {
		Label {
			Text(verbatim: message)
				.noTruncate()
		} icon: {
			Image(systemSymbol: icon)
				.accessibilityHidden(true)
		}
		.font(.customFont(fontFamily, style: .footnote, weight: .semibold))
		.foregroundStyle(.primary)
	}

	private func presentFeedback(_ newFeedback: Feedback) {
		feedback = newFeedback
		scrollRequest = newFeedback.target.map { ScrollRequest(target: $0) }
	}

	private func completeHistoryJump() {
		guard let date = pendingJumpDate else { return }
		pendingJumpDate = nil
		let jump = viewModel.jumpTarget(for: date)
		let requested = jump.requestedDay.formatted(date: .abbreviated, time: .omitted)
		guard let day = jump.landedDay else {
			presentFeedback(Feedback(message: String(localized: "No entries on \(requested) in this view.")))
			return
		}
		let landed = day.formatted(date: .abbreviated, time: .omitted)
		let message = day == jump.requestedDay
			? String(localized: "Showing \(landed).")
			: String(localized: "No entries on \(requested) in this view. Showing \(landed).")
		presentFeedback(Feedback(target: .day(day), message: message))
	}

	private func mutationFeedback(for mutation: HistoryEntryMutation, eventID: UUID, previousGroups: [MedicationHistoryViewModel.Day]) -> Feedback {
		var result = Feedback()
		if showDailyTotals, viewModel.isShowingAllMedications {
			result.changedSubtotals = viewModel.changedSubtotals(since: previousGroups, for: eventID)
		}
		switch mutation {
		case .edit:
			switch viewModel.savedEntryLocation(id: eventID) {
			case let .visible(id):
				result.target = .entry(id)
			case let .outsideFilters(date):
				let savedDate = date.formatted(date: .abbreviated, time: .omitted)
				result.message = String(localized: "Entry saved for \(savedDate), outside the current filters.")
			case .unavailable:
				result.message = String(localized: "Entry saved. It’s no longer available in History.")
			}
		case .delete:
			break
		}
		return result
	}

	private func presentEditorFeedback() {
		guard let pendingEditorFeedback else { return }
		self.pendingEditorFeedback = nil
		presentFeedback(pendingEditorFeedback)
	}

	private var floatingQuickLogMedication: ANMedicationConcept? {
		let useLastLogged = viewModel.isShowingAllMedications
		return LogDosePickerModel.quickLogMedication(selectedID: viewModel.selectedMedication?.id,
			useLastLogged: useLastLogged,
			lastLoggedID: useLastLogged ? DataStore.shared.lastLoggedMedication?.id : nil,
			from: viewModel.logDosePickerMedications)
	}

	private var primaryLogDoseButton: some View {
		let medication = floatingQuickLogMedication
		return FloatingLogDoseButton(quickLogMedication: medication, tint: viewModel.selectedMedication?.displayColor ?? .accent, scrollState: floatingLogDoseScroll, onChoose: {
			pendingPickerMedication = nil
			pickerQuery = ""
			showLogDosePicker = true
		}, onQuickLog: medication.map { medication in { await quickLog(medication) } })
	}

	private func quickLog(_ medication: ANMedicationConcept) async -> Bool {
		guard floatingQuickLogMedication?.id == medication.id else { return false }
		let saved = await quickLogCoordinator.quickLog(medication: medication)
		if !saved { quickLogError = true }
		return saved
	}

	private var historyMedicationMenu: some View {
		Menu {
			Picker("Medication", selection: $viewModel.selectedMedicationID) {
				Text("All medications")
					.font(.customFont(fontFamily, style: .body))
					.tag(Optional("all"))
				ForEach(viewModel.medications, id: \.id) { medication in
					Text(medication.demoDisplayName)
						.demoNameRedacted()
						.font(.customFont(fontFamily, style: .body))
						.tag(Optional(medication.id.uuidString))
				}
			}
		} label: {
			Label("Filter Medications", systemSymbol: .line3HorizontalDecrease)
		}
		.popoverTip(AppTips.isConfigured ? HistoryFilterTip() : nil)
		.accessibilityLabel("History medication filter")
		.accessibilityValue(historyScopeTitle)
	}

	private var historyScopeTitle: String {
		viewModel.isShowingAllMedications ? String(localized: "All medications") : (viewModel.selectedMedication?.demoDisplayName ?? String(localized: "All medications"))
	}

	private var historyRangeSelection: Binding<Int> {
		Binding(get: {
			switch viewModel.dateFilter {
			case .allTime: 0
			case let .period(period): period.rawValue
			case .custom: Int.min
			}
		}, set: { value in
			feedback = nil
			if value == 0 { viewModel.clearDateFilter() }
			else if let period = TrendsPeriod(rawValue: value) { viewModel.dateFilter = .period(period) }
		})
	}

	private var historyRangeMenu: some View {
		Menu {
			Picker("Time Range", selection: historyRangeSelection) {
				Text("All Time").tag(0)
				if viewModel.dateFilter == .period(.sevenDays) { Text(TrendsPeriod.sevenDays.displayName).tag(7) }
				ForEach(TrendsPeriod.menuPeriods, id: \.rawValue) { period in
					Text(period.displayName).tag(period.rawValue)
				}
				if case .custom = viewModel.dateFilter { Text("Custom Range").tag(Int.min) }
			}
			Button("Custom Range") { showCustomRange = true }
			Divider()
			Button("Jump to Date") { showDatePicker = true }
				.disabled(!viewModel.events.contains { $0.eventType == .doseTaken })
			Divider()
			Toggle("Show daily totals", isOn: $showDailyTotals)
		} label: {
			Label(viewModel.dateFilterTitle, systemSymbol: .calendar)
		}
		.font(.customFont(fontFamily, style: .body))
		.accessibilityLabel("Time Range")
		.accessibilityValue(viewModel.dateFilterTitle)
	}

	private var filteredHistoryEmptyView: some View {
		VStack(spacing: emptySectionSpacing) {
			Text("No dose history in this date range.")
				.font(.customFont(fontFamily, style: .body))
			Text("Date filter: \(viewModel.dateFilterTitle)")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
			Button {
				feedback = nil
				viewModel.clearDateFilter()
			} label: {
				Text("Clear date filter")
					.font(.customFont(fontFamily, style: .body))
					.frame(minHeight: 44)
			}
			.accessibilityHint("Show all dates for the current medication selection")
		}
		.multilineTextAlignment(.center)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding()
	}

	@ViewBuilder
	private var historyContent: some View {
		let groups = viewModel.groupedHistory
		if !groups.isEmpty {
			historyListView(groups)
		} else {
			VStack(alignment: .leading, spacing: 0) {
				if demoMode.isEnabled { DemoModeBanner().padding(.horizontal) }
				if viewModel.dateFilter != .allTime {
					filteredHistoryEmptyView
				} else if viewModel.isShowingAllMedications {
					Spacer()
					VStack(spacing: emptySectionSpacing) {
						Text("No dose history found.")
							.font(.customFont(fontFamily, style: .body))
						Text(viewModel.medications.isEmpty ? String(localized: "Add a medication in the Medication tab to start recording doses.") : String(localized: "Use Log Dose to choose a medication and record a dose you have taken."))
							.font(.customFont(fontFamily, style: .subheadline))
							.multilineTextAlignment(.center)
					}
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity)
					Spacer()
				} else if let selected = viewModel.selectedMedication {
					emptyHistoryView(for: selected)
				} else {
					selectionPromptView()
				}
			}
		}
	}

	// MARK: - Body

	var body: some View {
		ZStack {
			NavigationStack {
				ZStack(alignment: .bottomTrailing) {
					historyContent
					.safeAreaInset(edge: .top, spacing: 0) {
						if let feedback, feedback.target == nil, let message = feedback.message {
							feedbackLabel(message, icon: .infoCircle)
								.padding(.horizontal)
								.padding(.vertical, entrySpacing)
								.frame(maxWidth: .infinity, alignment: .leading)
								.background(.regularMaterial)
						}
					}
					.safeAreaInset(edge: .bottom, spacing: 0) {
						if !viewModel.logDosePickerMedications.isEmpty {
							Color.clear.frame(height: floatingButtonClearance)
						}
					}

					if !viewModel.logDosePickerMedications.isEmpty {
						primaryLogDoseButton
					}

				}
				.customNavigationTitle("History", displayMode: .large)
			.navigationDestination(isPresented: $showSupportPage) { SupportView() }
				.navigationSubtitle(Text(verbatim: "\(historyScopeTitle) · \(viewModel.dateFilterTitle)").font(.customFont(fontFamily, style: .subheadline)))
				.toolbar {
					ToolbarItemGroup(placement: .topBarTrailing) {
						historyMedicationMenu
						historyRangeMenu
					}
				}
				.tint(.accent)
				.alert("Couldn’t Log Dose", isPresented: $quickLogError) { Button("OK", role: .cancel) {} } message: { Text("We couldn’t save this change. Please try again.") }
				.overlay(alignment: .top) {
					if quickLogCoordinator.showQuickLogToast {
						QuickLogToastView(
							medicationName: quickLogCoordinator.quickLogMedicationName,
							doseAmount: quickLogCoordinator.quickLogDoseAmount,
							doseUnit: quickLogCoordinator.quickLogDoseUnit,
							accentColor: quickLogCoordinator.quickLogAccentColor,
							isVisible: quickLogCoordinator.showQuickLogToast,
							feedback: quickLogCoordinator.quickLogFeedback,
							isUndoing: quickLogCoordinator.isUndoingQuickLog,
							onDismiss: { quickLogCoordinator.dismissQuickLogToast() },
							onUndo: { eventID in Task { if !(await quickLogCoordinator.undoLastQuickLog(eventID: eventID)) { quickLogError = true } } })
					}
				}

				.onAppear { applyHistoryNavigation() }
				.onChange(of: navigationManager.historyRequestID) { _, _ in applyHistoryNavigation() }
				.onChange(of: viewModel.selectedMedicationID) { _, _ in feedback = nil }
				.onReceive(timer) { _ in viewModel.refreshForClockChange() }
				.task(id: feedback?.id) {
					guard let feedback else { return }
					if let message = feedback.message {
						AccessibilityNotification.Announcement(message).post()
					}
					try? await Task.sleep(for: .seconds(5))
					if !Task.isCancelled, self.feedback?.id == feedback.id { self.feedback = nil }
				}
				.sheet(isPresented: $showCustomRange) {
					MedicationDateRangeSheet(
						initialRange: viewModel.activeDateRange ?? TrendsPeriod.fourteenDays.range(calendar: .current, now: .now, includingToday: true),
						earliestEvent: viewModel.events.filter { $0.eventType == .doseTaken }.map(\.date).min(),
						includingToday: true
					) { range in
						feedback = nil
						viewModel.dateFilter = .custom(range)
					}
				}

				.sheet(isPresented: $showDatePicker, onDismiss: completeHistoryJump) {
					NavigationStack {
						ScrollView {
							DatePicker(
								"Select Date",
								selection: $selectedDate,
								displayedComponents: [.date]
							)
							.datePickerStyle(.graphical)
							.padding(.horizontal)

						}
						.customNavigationTitle("Jump to Date")
						.toolbar {
							ToolbarItem(placement: .cancellationAction) {
								Button {
									showDatePicker = false
								} label: {
									Image(systemSymbol: .xmark)
								}
								.accessibilityLabel("Cancel date selection")
							}

							ToolbarItem(placement: .confirmationAction) {
								Button {
									pendingJumpDate = selectedDate
									showDatePicker = false
								} label: {
									Image(systemSymbol: .checkmark)
								}
								.accessibilityLabel("Jump to selected date")
							}
						}
						.tint(.accent)
					}
					.dynamicDetent()
				}
				.sheet(isPresented: $showLogDosePicker, onDismiss: {
					pickerQuery = ""
					if let medication = pendingPickerMedication {
						pendingPickerMedication = nil
						logMedication = viewModel.logDosePickerMedications.first { $0.id == medication.id }
					}
				}) {
					LogDosePickerSheet(medications: viewModel.logDosePickerMedications, query: $pickerQuery,
						onSelect: { medication in
							pendingPickerMedication = medication
							showLogDosePicker = false
						}, onQuickLog: { medication in
							await quickLogCoordinator.quickLog(medication: medication)
						}, onQuickLogSuccess: { _ in
							AppTips.didQuickLog()
							showLogDosePicker = false
						})
				}
				.sheet(item: $logMedication, onDismiss: {
					if logMedication == nil { doseLogSession.reset() }
				}) { med in
					LogDoseView(medication: med, source: "history_sheet", draft: doseLogSession.draft(for: med)) { dose, event, operationID, isBackdated in
						let saved = await quickLogCoordinator.logDose(med: med, dose: dose, event: event, source: "history_sheet", operationID: operationID, isBackdated: isBackdated)
						if saved { logMedication = nil }
						return saved
					}
				}
				.sheet(item: $editingEvent, onDismiss: presentEditorFeedback) { event in
					NavigationStack {
						VStack(spacing: 0) {
							Form {
								if let message = viewModel.mutationError {
									Section("Update Incomplete") {
										Text(message).font(.customFont(fontFamily, style: .body))
									}
								}
								Section(header: Text("Event Details").font(.customFont(fontFamily, style: .subheadline))) {
									HStack {
										Text("Date")
										Spacer()
										Text(event.date.formatted(date: .abbreviated, time: .shortened))
											.foregroundStyle(.secondary)
											.noTruncate()
									}
									if let dose = event.dose {
										HStack {
											Text("Dose")
											Spacer()
											Text(dose.unit.localizedCompactAmount(for: dose.amount))
												.foregroundStyle(.secondary)
												.noTruncate()
										}
									}
								}

								Section(header: Text("Note").font(.customFont(fontFamily, style: .subheadline))) {
									let highlights = reflectionHighlights(
										for: DoseReflectionCodec.reflection(from: event.note),
										historicalMedication: event.medication
									)
									if !highlights.isEmpty {
										VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
											Text("Saved context from this dose stays attached when you update the note.")
												.font(.customFont(fontFamily, style: .caption))
												.foregroundStyle(.secondary)

											VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
												ForEach(highlights.indices, id: \.self) { index in
													reflectionBadge(highlights[index], tint: viewModel.selectedMedication?.displayColor ?? .accent)
												}
											}
										}
										.padding(.bottom, sectionHeaderSpacing)
									}

									Group {
										if demoMode.isEnabled {
											SecureField("Add a note about this dose", text: $editingNoteText)
										} else {
											TextField("Add a note about this dose", text: $editingNoteText, axis: .vertical)
												.lineLimit(4 ... 8)
										}
									}
									.font(.customFont(fontFamily, style: .body))
									.focused($isNoteFieldFocused)
								}
							}
							.scrollDismissesKeyboard(.interactively)
							.disabled(viewModel.isMutating)
							.font(.customFont(fontFamily, style: .body))

							// Sticky save button container
							VStack(spacing: 0) {
								Divider()
									.background(.separator.opacity(0.5))

								Button {
									guard editingNoteText != (displayNote(for: event) ?? "") else {
										editingEvent = nil
										return
									}
									Task {
										let previousGroups = viewModel.groupedHistory
										if await viewModel.updateEventNote(event, text: editingNoteText) {
											pendingEditorFeedback = mutationFeedback(for: .edit, eventID: event.id, previousGroups: previousGroups)
											editingEvent = nil
											editingNoteText = ""
										}
									}
								} label: {
									HStack(spacing: entrySpacing) {
										Image(systemSymbol: .checkmarkCircle)
											.font(.customFont(fontFamily, style: .body))
										Text("Save Note")
											.font(.customFont(fontFamily, style: .headline))
									}
									.foregroundStyle(Color.accent.dynamicFilledButtonForeground)
									.frame(maxWidth: .infinity)
									.padding(.vertical, 14)
									.background(
										RoundedRectangle(cornerRadius: 12, style: .continuous)
											.fill(LinearGradient(
												colors: [
													Color.accent.dynamicFilledButtonBackground,
													Color.accent.dynamicFilledButtonBackground,
												],
												startPoint: .topLeading,
												endPoint: .bottomTrailing
											))
											.shadow(color: (viewModel.selectedMedication?.displayColor ?? .accent).opacity(0.3), radius: 4, x: 0, y: 2)
									)
								}
								.padding(.horizontal, fabPaddingH)
								.disabled(viewModel.isMutating)
								.padding(.vertical, pickerContainerPaddingV)
							}
							.background(.regularMaterial)
						}
						.customNavigationTitle("Edit Note")
						.toolbar {
							ToolbarItem(placement: .topBarTrailing) {
								Button {
									if editingNoteText != (displayNote(for: event) ?? "") {
										showDiscardNoteChanges = true
									} else {
										editingEvent = nil
										editingNoteText = ""
									}
								} label: {
									Image(systemSymbol: .xmark)
								}
								.accessibilityLabel("Close note editor")
								.disabled(viewModel.isMutating)
							}
						}
						.tint(.accent)
						.confirmationDialog("Discard note changes?", isPresented: $showDiscardNoteChanges, titleVisibility: .visible) {
							Button("Discard Changes", role: .destructive) {
								editingEvent = nil
								editingNoteText = ""
							}
							Button("Keep Editing", role: .cancel) {}
						}
					}
					.presentationDetents([.large])
					.alert("Couldn’t Update History", isPresented: mutationErrorPresented) {
						Button("OK", role: .cancel) { viewModel.mutationError = nil }
					} message: {
						Text(viewModel.mutationError ?? String(localized: "Review History before trying again."))
					}
					.interactiveDismissDisabled(viewModel.isMutating || editingNoteText != (displayNote(for: event) ?? ""))
					.task {
						try? await Task.sleep(for: .milliseconds(750))
						if !Task.isCancelled { isNoteFieldFocused = true }
					}
				}
			}
			.onAppear {
				// Ensure we have a valid medication selected
				viewModel.ensureValidSelection()
			}


		}
		.sheet(item: $reviewingDose, onDismiss: {
			if let reviewEditID {
				editingEntryEvent = viewModel.events.first { $0.id == reviewEditID }
				self.reviewEditID = nil
			}
		}) { event in
			let review: HistoryDoseWarningView.Review? = if let warning = viewModel.doseWarnings[event.id],
				let current = viewModel.events.first(where: { $0.id == event.id }) {
				.init(
					warning: warning,
					dose: .init(current),
					medicationName: current.medication.map { viewModel.currentMedication(for: $0).demoDisplayName },
					rollingEntries: warning.rolling == nil ? [] : viewModel.rollingWarningEntries(for: current)
				)
			} else {
				nil
			}
			HistoryDoseWarningView(review: review) { id in
				reviewEditID = id
				reviewingDose = nil
			}
		}
		.sheet(item: $editingEntryEvent, onDismiss: presentEditorFeedback) { event in
			HistoryEntryEditor(event: event, viewModel: viewModel, onDismiss: {
				editingEntryEvent = nil
			}, onMutation: { mutation, previousGroups in
				pendingEditorFeedback = mutationFeedback(for: mutation, eventID: event.id, previousGroups: previousGroups)
				editingEntryEvent = nil
			})
		}
		.alert("Couldn’t Update History", isPresented: Binding(
			get: { viewModel.mutationError != nil && editingEvent == nil && editingEntryEvent == nil },
			set: { if !$0 { viewModel.mutationError = nil } }
		)) {
			Button("OK", role: .cancel) { viewModel.mutationError = nil }
		} message: {
			Text(viewModel.mutationError ?? String(localized: "Review History before trying again."))
		}
	}
}


/// Edit state belongs to this presentation and starts from its exact saved event.
/// Separate parent state can otherwise be captured before the first sheet renders.
private struct HistoryEntryEditor: View {
	let event: ANEventConcept
	@ObservedObject var viewModel: MedicationHistoryViewModel
	let onDismiss: () -> Void
	let onMutation: (HistoryEntryMutation, [MedicationHistoryViewModel.Day]) -> Void

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var editingEntryDate: Date
	@State private var editingEntryAmount: String
	@State private var editingEntryUnit: ANUnitConcept
	@State private var showDiscardEntryChanges = false

	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var entrySpacing: CGFloat = 8
	@ScaledMetric private var sectionHeaderSpacing: CGFloat = 2

	init(event: ANEventConcept, viewModel: MedicationHistoryViewModel, onDismiss: @escaping () -> Void,
		onMutation: @escaping (HistoryEntryMutation, [MedicationHistoryViewModel.Day]) -> Void) {
		self.event = event
		self.viewModel = viewModel
		self.onDismiss = onDismiss
		self.onMutation = onMutation
		_editingEntryDate = State(initialValue: event.date)
		_editingEntryAmount = State(initialValue: Self.amountText(for: event))
		_editingEntryUnit = State(initialValue: event.dose?.unit ?? .unit)
	}

	private static func amountText(for event: ANEventConcept) -> String {
		event.dose.map { DoseAmountInput.text(for: $0.amount) } ?? ""
	}

	private var enteredAmount: Double? { DoseAmountInput.value(from: editingEntryAmount) }
	private var amountHasChanged: Bool {
		editingEntryAmount != Self.amountText(for: event) &&
			(enteredAmount == nil || enteredAmount != event.dose?.amount)
	}
	private var unitHasChanged: Bool { editingEntryUnit != (event.dose?.unit ?? .unit) }
	private var dateHasChanged: Bool { editingEntryDate != event.date }
	private var entryHasChanges: Bool { amountHasChanged || unitHasChanged || dateHasChanged }
	private var canSave: Bool { !(amountHasChanged || unitHasChanged) || (enteredAmount ?? 0) > 0 }

	private var mutationErrorPresented: Binding<Bool> {
		Binding(
			get: { viewModel.mutationError != nil },
			set: { if !$0 { viewModel.mutationError = nil } }
		)
	}

	var body: some View {
		NavigationStack {
			Form {
				if let message = viewModel.mutationError {
					Section("Update Incomplete") {
						Text(message).font(.customFont(fontFamily, style: .body))
					}
				}
				Section(header: Text("Dose Entry Details").font(.customFont(fontFamily, style: .subheadline))) {
					HStack {
						Text("Medication")
						Spacer()
						if let eventMedication = event.medication {
							let medication = viewModel.currentMedication(for: eventMedication)
							Text(medication.demoDisplayName)
								.demoNameRedacted()
								.foregroundStyle(.secondary)
								.noTruncate()
						}
					}

					VStack(alignment: .leading, spacing: rowSpacing) {
						Text("Dose Amount")
							.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))

						HStack(spacing: rowSpacing) {
							Button(action: {
								if let amount = enteredAmount, amount > 0.5 {
									editingEntryAmount = DoseAmountInput.text(for: amount - 0.5)
								}
							}) {
								Image(systemSymbol: .minusCircleFill)
									.font(.customFont(fontFamily, style: .title2))
									.foregroundStyle((enteredAmount ?? 0) > 0.5 ? (viewModel.selectedMedication?.displayColor ?? .accent) : Color.secondary.opacity(0.5))
									.frame(minWidth: 44, minHeight: 44)
							}
							.buttonStyle(.borderless)
							.accessibilityLabel("Decrease dose amount")
							.accessibilityHint("Decrease by \(editingEntryUnit.localizedCompactAmount(for: 0.5))")
							.disabled((enteredAmount ?? 0) <= 0.5)

							VStack(spacing: sectionHeaderSpacing) {
								TextField("Dose Amount", text: $editingEntryAmount, prompt: Text("Not recorded"))
									.font(.customFont(fontFamily, style: .title2, weight: .semibold))
									.keyboardType(.decimalPad)
									.multilineTextAlignment(.center)

								Text(editingEntryUnit.localizedDisplayName)
									.font(.customFont(fontFamily, style: .caption))
									.foregroundStyle(.secondary)
									.textCase(.uppercase)
									.noTruncate()
							}
							.frame(minWidth: 80)

							Button(action: {
								editingEntryAmount = DoseAmountInput.text(for: max(0, enteredAmount ?? 0) + 0.5)
							}) {
								Image(systemSymbol: .plusCircleFill)
									.font(.customFont(fontFamily, style: .title2))
									.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
									.frame(minWidth: 44, minHeight: 44)
							}
							.buttonStyle(.borderless)
							.accessibilityLabel("Increase dose amount")
							.accessibilityHint("Increase by \(editingEntryUnit.localizedCompactAmount(for: 0.5))")
						}
						.frame(maxWidth: .infinity)

						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: entrySpacing) {
								ForEach(ANUnitConcept.allCases, id: \.self) { unit in
									Button(action: {
										withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
											editingEntryUnit = unit
										}
									}) {
										Text(unit.localizedDisplayName)
											.font(.customFont(fontFamily, style: .caption, weight: editingEntryUnit == unit ? .semibold : .regular))
											.padding(.horizontal, rowSpacing)
											.padding(.vertical, entrySpacing)
											.frame(minHeight: 44)
											.background(
												Capsule()
													.fill(editingEntryUnit == unit ? Color.accent.dynamicFilledButtonBackground : Color.secondary.opacity(0.1))
											)
											.foregroundStyle(editingEntryUnit == unit ? Color.accent.dynamicFilledButtonForeground : .primary)
									}
									.buttonStyle(.borderless)
									.accessibilityAddTraits(editingEntryUnit == unit ? [.isSelected] : [])
								}
							}
						}
					}

					DatePicker(
						"Time",
						selection: $editingEntryDate,
						displayedComponents: [.date, .hourAndMinute]
					)
				}

				Section {
					Button(role: .destructive) {
						Task {
							let previousGroups = viewModel.groupedHistory
							if await viewModel.deleteEvent(event) {
								onMutation(.delete, previousGroups)
							}
						}
					} label: {
						Label("Delete Entry", systemSymbol: .trash)
							.frame(maxWidth: .infinity)
							.foregroundStyle(.red)
					}
					.disabled(viewModel.isMutating)
				}
			}
			.font(.customFont(fontFamily, style: .body))
			.disabled(viewModel.isMutating)
			.customNavigationTitle("Edit Entry")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						if entryHasChanges {
							showDiscardEntryChanges = true
						} else {
							onDismiss()
						}
					} label: {
						Image(systemSymbol: .xmark)
					}
					.accessibilityLabel("Close entry editor")
					.disabled(viewModel.isMutating)
				}
				ToolbarItem(placement: .confirmationAction) {
					Button {
						guard entryHasChanges else {
							onDismiss()
							return
						}
						Task {
							let previousGroups = viewModel.groupedHistory
							let saved = await viewModel.updateEvent(
								event,
								newDate: dateHasChanged ? editingEntryDate : nil,
								newAmount: amountHasChanged ? enteredAmount : nil,
								newUnit: unitHasChanged ? editingEntryUnit : nil
							)
							if saved {
								onMutation(.edit, previousGroups)
							}
						}
					} label: {
						Image(systemSymbol: .checkmark)
					}
					.accessibilityLabel("Save entry changes")
					.disabled(viewModel.isMutating || !canSave)
				}
			}
			.tint(.accent)
			.confirmationDialog("Discard entry changes?", isPresented: $showDiscardEntryChanges, titleVisibility: .visible) {
				Button("Discard Changes", role: .destructive) { onDismiss() }
				Button("Keep Editing", role: .cancel) {}
			}
		}
		.dynamicDetent()
		.alert("Couldn’t Update History", isPresented: mutationErrorPresented) {
			Button("OK", role: .cancel) { viewModel.mutationError = nil }
		} message: {
			Text(viewModel.mutationError ?? String(localized: "Review History before trying again."))
		}
		.interactiveDismissDisabled(viewModel.isMutating || entryHasChanges)
	}
}
