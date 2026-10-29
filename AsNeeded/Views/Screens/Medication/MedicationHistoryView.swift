import ANModelKit
import Foundation
import SFSafeSymbols
import SwiftUI
import TipKit

struct MedicationHistoryView: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	@State private var showSupportPage = false
	@StateObject private var doseLogSession = LogDoseView.Session()
	@StateObject private var viewModel = MedicationHistoryViewModel()
	// Reuse the existing atomic dose/Undo coordinator on both tabs.
	@StateObject private var quickLogCoordinator = MedicationListViewModel()
	@State private var quickLogError = false
	@State private var showLogDosePicker = false
	@State private var pickerQuery = ""
	@State private var pendingPickerMedication: ANMedicationConcept?

	@EnvironmentObject private var navigationManager: NavigationManager
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var logMedication: ANMedicationConcept?
	@State private var currentTime = Date()
	@State private var scrollTarget: Date?
	@State private var showDatePicker = false
	@State private var selectedDate = Date()
	@State private var selectedEventNote: String?
	@State private var editingEvent: ANEventConcept?
	@State private var editingNoteText: String = ""
	@FocusState private var isNoteFieldFocused: Bool
	@State private var editingEntryEvent: ANEventConcept?
	@State private var editingEntryDate: Date = .init()
	@State private var editingEntryAmount: Double = 1.0
	@State private var editingEntryUnit: ANUnitConcept = .unit
	@State private var showDiscardNoteChanges = false
	@State private var showDiscardEntryChanges = false

	@ScaledMetric private var emptySectionSpacing: CGFloat = 24
	@ScaledMetric private var supportViewPaddingH: CGFloat = 32
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var entrySpacing: CGFloat = 8
	@ScaledMetric private var noteTopSpacing: CGFloat = 4
	@ScaledMetric private var sectionHeaderSpacing: CGFloat = 2
	@ScaledMetric private var medicationColorCircleSize: CGFloat = 26
	@ScaledMetric private var colorCircleShadowRadius: CGFloat = 3
	@ScaledMetric private var colorCircleStrokeWidth: CGFloat = 0.5
	@ScaledMetric private var unitPickerItemPaddingH: CGFloat = 12
	@ScaledMetric private var unitPickerItemCornerRadius: CGFloat = 8
	@ScaledMetric private var pickerContainerPaddingV: CGFloat = 12
	@ScaledMetric private var fabPaddingH: CGFloat = 24
	@ScaledMetric private var floatingButtonClearance: CGFloat = 88
	@ScaledMetric private var datePickerSpacing: CGFloat = 20
	@ScaledMetric private var reflectionBadgePaddingH: CGFloat = 8
	@ScaledMetric private var reflectionBadgePaddingV: CGFloat = 5

	let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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

	private func historyDoseDetails(for event: ANEventConcept) -> some View {
		let time = event.date.formatted(date: .omitted, time: .shortened)
		let details = event.dose.map { "\(time) – \($0.amount.formattedAmount) \($0.unit.abbreviation)" } ?? time
		return ViewThatFits(in: .horizontal) {
			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Text(details)
					.font(.customFont(fontFamily, style: .subheadline))
				if let relative = relativeShortIfToday(event.date) {
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
				if let relative = relativeShortIfToday(event.date) {
					Text(relative)
						.font(.customFont(fontFamily, style: .footnote))
						.foregroundStyle(.secondary)
						.noTruncate()
				}
			}
		}
	}

	@ViewBuilder
	private func historyListView() -> some View {
		ScrollViewReader { proxy in
			List {
				if demoMode.isEnabled {
					DemoModeBanner()
						.listRowInsets(EdgeInsets())
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
				ForEach(viewModel.groupedHistory, id: \.day) { group in
					Section(header: sectionHeader(for: group)) {
						ForEach(group.entries, id: \.id) { event in
							VStack(alignment: .leading, spacing: entrySpacing) {
								HStack(alignment: .center, spacing: 8) {
									Button {
										editingEntryEvent = event
										editingEntryDate = event.date
										editingEntryAmount = event.dose?.amount ?? 1.0
										editingEntryUnit = event.dose?.unit ?? .unit
									} label: {
										HStack(alignment: .center) {
											// Medication color indicator on the left side
											if !dynamicTypeSize.isAccessibilitySize, viewModel.isShowingAllMedications, let eventMedication = event.medication {
												// Look up current medication from viewModel to ensure we have the latest data
												let currentMedication = viewModel.medications.first { $0.id == eventMedication.id }
												let rowMedication = currentMedication ?? eventMedication

												let medicationColor: Color = {
													// First try the medication's custom color
													if let hexColor = rowMedication.displayColorHex, !hexColor.isEmpty {
														return Color(hex: hexColor) ?? .accent
													}
													// Use app accent color as default
													return .accent
												}()

												ZStack {
													Circle()
														.fill(medicationColor.opacity(0.15))
														.frame(width: medicationColorCircleSize, height: medicationColorCircleSize)
														.shadow(color: medicationColor.opacity(0.4), radius: colorCircleShadowRadius, x: 0, y: 1)
														.overlay(
															Circle()
																.stroke(.white.opacity(0.3), lineWidth: colorCircleStrokeWidth)
														)

													// Add medication symbol
													if viewModel.isShowingAllMedications {
														Image(systemName: rowMedication.effectiveDisplaySymbol)
															.font(.customFont(fontFamily, style: .caption, weight: .medium))
															.symbolRenderingMode(.hierarchical)
															.foregroundStyle(medicationColor)
													} else if !viewModel.isShowingAllMedications,
													          let medication = viewModel.selectedMedication
													{
														Image(systemName: medication.effectiveDisplaySymbol)
															.font(.customFont(fontFamily, style: .caption, weight: .medium))
															.symbolRenderingMode(.hierarchical)
															.foregroundStyle(medicationColor)
													}
												}
											}

											VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
												// Show medication name when viewing all medications
												if viewModel.isShowingAllMedications, let eventMedication = event.medication {
													let currentMedication = viewModel.medications.first { $0.id == eventMedication.id }
													let rowMedication = currentMedication ?? eventMedication
													Text(rowMedication.demoDisplayName)
														.demoNameRedacted()
														.font(.customFont(fontFamily, style: .headline))
														.foregroundStyle(.primary)
														.noTruncate()
												}

												historyDoseDetails(for: event)
											}
											.fixedSize(horizontal: false, vertical: true)
											Spacer()
										}
										.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
										.contentShape(Rectangle())
									}
									.buttonStyle(.plain)
									.accessibilityLabel(historyAccessibilityLabel(for: event))
									.accessibilityHint("Edit this dose entry")

									// Show add note button on trailing side if no note exists
									if displayNote(for: event)?.isEmpty != false {
										AddNoteButtonComponent(
											medicationColor: viewModel.isShowingAllMedications ? .secondary : (viewModel.selectedMedication?.displayColor ?? .accent),
											onTap: {
												editingEvent = event
												editingNoteText = ""
											}
										)
									}
								}

								if !reflectionHighlights(for: event).isEmpty {
									let reflectionLayout = dynamicTypeSize.isAccessibilitySize
										? AnyLayout(VStackLayout(alignment: .leading, spacing: entrySpacing))
										: AnyLayout(HStackLayout(spacing: sectionHeaderSpacing))
									reflectionLayout {
										ForEach(reflectionHighlights(for: event), id: \.self) { highlight in
											Text(highlight)
												.font(.customFont(fontFamily, style: .caption, weight: .medium))
												.noTruncate()
												.foregroundStyle(viewModel.isShowingAllMedications ? .accent : (viewModel.selectedMedication?.displayColor ?? .accent))
												.padding(.horizontal, reflectionBadgePaddingH)
												.padding(.vertical, reflectionBadgePaddingV)
												.background(
													Capsule()
														.fill((viewModel.isShowingAllMedications ? Color.accent : (viewModel.selectedMedication?.displayColor ?? .accent)).opacity(0.12))
												)
										}
									}
								}

								// Show enhanced note display below if it exists
								if let note = displayNote(for: event), !note.isEmpty {
									NoteDisplayCardComponent(
										noteText: note,
										medicationColor: viewModel.isShowingAllMedications ? .accent : (viewModel.selectedMedication?.displayColor ?? .accent),
										onEdit: {
											editingEvent = event
											editingNoteText = displayNote(for: event) ?? ""
										}
									)
									.padding(.top, noteTopSpacing)
								}
							}
							.contentShape(Rectangle())
							.accessibilityElement(children: .contain)
							.accessibilityAction(named: "Edit entry") {
								editingEntryEvent = event
								editingEntryDate = event.date
								editingEntryAmount = event.dose?.amount ?? 1.0
								editingEntryUnit = event.dose?.unit ?? .unit
							}
							.accessibilityAction(named: "Edit note") {
								editingEvent = event
								editingNoteText = displayNote(for: event) ?? ""
							}
							.swipeActions(edge: .trailing) {
								Button {
									editingEntryEvent = event
									editingEntryDate = event.date
									editingEntryAmount = event.dose?.amount ?? 1.0
									editingEntryUnit = event.dose?.unit ?? .unit
								} label: {
									Label("Edit", systemSymbol: .pencil)
								}
								.tint(.accent)

								Button(role: .destructive) {
									Task { await viewModel.deleteEvent(event) }
								} label: {
									Label("Delete", systemSymbol: .trash)
								}
								.tint(.red)
								.disabled(viewModel.isMutating)
							}
						}
					}
					.id(group.day)
				}
				SupportSuggestionView(onSupportTapped: { showSupportPage = true })
					.listRowInsets(EdgeInsets())
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
					.environment(\.defaultMinListRowHeight, 0)
			}
			.listStyle(.insetGrouped)
			.onChange(of: scrollTarget) { _, newTarget in
				if let target = newTarget {
					withAnimation(reduceMotion ? nil : .default) {
						proxy.scrollTo(target, anchor: .top)
					}
				}
			}
		}
	}

	// MARK: - Section Header Helpers

	@ViewBuilder
	private func sectionHeader(for group: (day: Date, entries: [ANEventConcept])) -> some View {
		VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
			let headerLayout = dynamicTypeSize.isAccessibilitySize
				? AnyLayout(VStackLayout(alignment: .leading, spacing: sectionHeaderSpacing))
				: AnyLayout(HStackLayout())
			headerLayout {
				Text(formatDateWithDayOfWeek(group.day))
					.font(.customFont(fontFamily, style: .headline))
				Spacer()
				if let totalText = dayTotalText(for: group.entries) {
					Text(totalText)
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(.secondary)
						.noTruncate()
				}
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
		return "\(dayOfWeek), \(dateString)"
	}

	private func dayTotalText(for entries: [ANEventConcept]) -> String? {
		// Don't show totals when showing all medications
		guard !viewModel.isShowingAllMedications else { return nil }

		let preferredUnit = viewModel.selectedMedication?.prescribedUnit ?? entries.compactMap { $0.dose?.unit }.first
		if let unit = preferredUnit {
			let total = entries.compactMap { ev -> Double? in
				guard let dose = ev.dose, dose.unit == unit else { return nil }
				return dose.amount
			}.reduce(0, +)
			return total > 0 ? "\(total.formattedAmount) \(unit.abbreviation)" : nil
		} else {
			let total = entries.compactMap { $0.dose?.amount }.reduce(0, +)
			return total > 0 ? "\(total.formattedAmount)" : nil
		}
	}

	private func dayRelativeLabel(for date: Date) -> String? {
		let cal = Calendar.current
		if cal.isDateInToday(date) { return "Today" }
		if cal.isDateInYesterday(date) { return "Yesterday" }

		// Use our centralized relative formatting for other dates
		let daysDiff = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
		if daysDiff > 1 && daysDiff <= 7 {
			return date.relativeFormattedAsPast.capitalized
		}
		return nil
	}

	private func relativeShortIfToday(_ date: Date) -> String? {
		let cal = Calendar.current
		guard cal.isDateInToday(date) else { return nil }
		let diff = Int(Date().timeIntervalSince(date))
		if diff <= 60 { return "Logged just now" }
		let mins = diff / 60
		if mins < 60 { return "\(mins)m ago" }
		let hrs = mins / 60
		return "\(hrs)h ago"
	}

	private func displayNote(for event: ANEventConcept) -> String? {
		DoseReflectionCodec.displayNote(from: event.note)
	}

	private func reflectionHighlights(for event: ANEventConcept) -> [String] {
		guard let reflection = DoseReflectionCodec.reflection(from: event.note) else {
			return []
		}

		var highlights: [String] = []

		if let reason = reflection.reason {
			highlights.append(reason)
		}

		if let effectiveness = reflection.effectiveness {
			highlights.append("Effect \(effectiveness)/5")
		}

		if let before = reflection.symptomSeverityBefore, let after = reflection.symptomSeverityAfter {
			highlights.append("Before \(before)/5 to \(after)/5")
		}

		if let sideEffect = reflection.sideEffects.first {
			highlights.append(sideEffect)
		}

		return Array(highlights.prefix(3))
	}

	private func historyAccessibilityLabel(for event: ANEventConcept) -> String {
		let medicationText = eventMedicationName(for: event)
		let doseText: String = {
			guard let dose = event.dose else {
				return "dose amount not recorded"
			}

			return "\(dose.amount.formattedAmount) \(dose.unit.abbreviation)"
		}()
		let timeText = event.date.formatted(date: .abbreviated, time: .shortened)
		let noteText: String = {
			guard let note = displayNote(for: event), !note.isEmpty else {
				return "No note"
			}

			return "Has note"
		}()

		return "\(medicationText), \(doseText), logged \(timeText). \(noteText)."
	}

	private func eventMedicationName(for event: ANEventConcept) -> String {
		guard let medicationID = event.medication?.id else {
			return "Medication"
		}

		if let currentMedication = viewModel.medications.first(where: { $0.id == medicationID }) {
			return currentMedication.demoDisplayName
		}

		return event.medication?.demoDisplayName ?? "Medication"
	}

	private func entryHasChanges(for event: ANEventConcept) -> Bool {
		editingEntryDate != event.date ||
			editingEntryAmount != (event.dose?.amount ?? 1.0) ||
			editingEntryUnit != (event.dose?.unit ?? .unit)
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

	private var floatingQuickLogMedication: ANMedicationConcept? {
		LogDosePickerModel.quickLogMedication(selectedID: viewModel.selectedMedication?.id,
			useLastLogged: viewModel.isShowingAllMedications,
			lastLoggedID: DataStore.shared.lastLoggedMedication?.id, from: viewModel.logDosePickerMedications)
	}

	private var primaryLogDoseButton: some View {
		let medication = floatingQuickLogMedication
		return FloatingLogDoseButton(quickLogMedication: medication, tint: viewModel.selectedMedication?.displayColor ?? .accent, onChoose: {
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
		viewModel.isShowingAllMedications ? "All medications" : (viewModel.selectedMedication?.demoDisplayName ?? "All medications")
	}

	// MARK: - Body

	var body: some View {
		ZStack {
			NavigationStack {
				ZStack(alignment: .bottomTrailing) {
					VStack(alignment: .leading, spacing: 0) {
						if demoMode.isEnabled && viewModel.groupedHistory.isEmpty { DemoModeBanner().padding(.horizontal) }
						if viewModel.isShowingAllMedications {
							if viewModel.groupedHistory.isEmpty {
								Spacer()
								VStack(spacing: emptySectionSpacing) {
									Text("No dose history found.")
										.font(.customFont(fontFamily, style: .body))
										.foregroundStyle(.secondary)
										.frame(maxWidth: .infinity, alignment: .center)

									Text(viewModel.medications.isEmpty ? "Add a medication in the Medication tab to start recording doses." : "Use Log Dose to choose a medication and record a dose you have taken.")
										.font(.customFont(fontFamily, style: .subheadline))
										.foregroundStyle(.secondary)
										.multilineTextAlignment(.center)
										.padding(.horizontal)
								}
								Spacer()
							} else {
								historyListView()
							}
						} else if let selected = viewModel.selectedMedication {
							if viewModel.groupedHistory.isEmpty {
								emptyHistoryView(for: selected)
							} else {
								historyListView()
							}
						} else {
							selectionPromptView()
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
				.navigationSubtitle(Text(historyScopeTitle).font(.customFont(fontFamily, style: .subheadline)))
				.toolbar {
					ToolbarItemGroup(placement: .topBarTrailing) {
						historyMedicationMenu
						Button {
							showDatePicker = true
						} label: {
							Label("Jump to Date", systemSymbol: .calendar)
						}
						.disabled(viewModel.groupedHistory.isEmpty)
						.accessibilityLabel("Jump to date")
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
							onDismiss: { quickLogCoordinator.dismissQuickLogToast() },
							onUndo: { eventID in Task { if !(await quickLogCoordinator.undoLastQuickLog(eventID: eventID)) { quickLogError = true } } })
					}
				}

				.onAppear {
					// Handle navigation from trends or medication detail
					if let targetDate = navigationManager.historyTargetDate {
						scrollTarget = Calendar.current.startOfDay(for: targetDate)
					}

					if let medicationID = navigationManager.historyTargetMedicationID,
					   let uuid = UUID(uuidString: medicationID)
					{
						// Set the selected medication from navigation
						viewModel.selectedMedicationID = uuid.uuidString
						// Clear navigation state after use
						navigationManager.clearHistoryNavigation()
					} else {
						// Ensure we have a valid selection (will default to "all" if needed)
						viewModel.ensureValidSelection()
					}
				}
				.onReceive(timer) { _ in
					currentTime = Date()
				}
				.sheet(isPresented: $showDatePicker) {
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
									scrollTarget = Calendar.current.startOfDay(for: selectedDate)
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
					LogDoseView(medication: med, source: "history_sheet", draft: doseLogSession.draft(for: med)) { dose, event, operationID in
						let saved = await quickLogCoordinator.logDose(med: med, dose: dose, event: event, source: "history_sheet", operationID: operationID)
						if saved { logMedication = nil }
						return saved
					}
				}
				.sheet(item: $editingEvent) { event in
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
											Text("\(dose.amount.formattedAmount) \(dose.unit.abbreviation)")
												.foregroundStyle(.secondary)
												.noTruncate()
										}
									}
								}

								Section(header: Text("Note").font(.customFont(fontFamily, style: .subheadline))) {
									if !reflectionHighlights(for: event).isEmpty {
										VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
											Text("Saved context from this dose stays attached when you update the note.")
												.font(.customFont(fontFamily, style: .caption))
												.foregroundStyle(.secondary)

											VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
												ForEach(reflectionHighlights(for: event), id: \.self) { highlight in
													Text(highlight)
														.font(.customFont(fontFamily, style: .caption, weight: .medium))
														.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
														.padding(.horizontal, reflectionBadgePaddingH)
														.padding(.vertical, reflectionBadgePaddingV)
														.background(
															Capsule()
																.fill((viewModel.selectedMedication?.displayColor ?? .accent).opacity(0.12))
														)
												}
											}
										}
										.padding(.bottom, sectionHeaderSpacing)
									}

									TextField("Add a note about this dose", text: $editingNoteText, axis: .vertical)
										.lineLimit(4 ... 8)
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

								Button(action: {
									if let event = editingEvent {
										Task {
											var updatedEvent = event
											updatedEvent.note = (try? DoseReflectionCodec.updatingNote(in: event.note, with: editingNoteText)) ??
												editingNoteText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
											if await viewModel.updateEventNote(updatedEvent) {
												editingEvent = nil
												editingNoteText = ""
											}
										}
									}
								}) {
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
						Text(viewModel.mutationError ?? "Review History before trying again.")
					}
					.interactiveDismissDisabled(viewModel.isMutating || editingNoteText != (displayNote(for: event) ?? ""))
					.onAppear {
						editingNoteText = displayNote(for: event) ?? ""
						// Auto-focus the note field when sheet opens - increased delay for reliability
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
							isNoteFieldFocused = true
						}
					}
				}
			}
			.onAppear {
				// Ensure we have a valid medication selected
				viewModel.ensureValidSelection()
			}


		}
		.sheet(item: $editingEntryEvent) { event in
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
								let currentMedication = viewModel.medications.first { $0.id == eventMedication.id }
								let medication = currentMedication ?? eventMedication
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
									if editingEntryAmount > 0.5 {
										editingEntryAmount -= 0.5
									}
								}) {
									Image(systemSymbol: .minusCircleFill)
										.font(.customFont(fontFamily, style: .title2))
										.foregroundStyle(editingEntryAmount > 0.5 ? (viewModel.selectedMedication?.displayColor ?? .accent) : Color.secondary.opacity(0.5))
										.frame(minWidth: 44, minHeight: 44)
								}
								.buttonStyle(.borderless)
								.accessibilityLabel("Decrease dose amount")
								.accessibilityHint("Decrease by 0.5 \(editingEntryUnit.displayName)")
								.disabled(editingEntryAmount <= 0.5)

								VStack(spacing: sectionHeaderSpacing) {
									Text("\(editingEntryAmount, specifier: "%.1f")")
										.font(.customFont(fontFamily, style: .title2, weight: .semibold))
										.noTruncate()
										.contentTransition(.numericText())

									Text(editingEntryUnit.displayName)
										.font(.customFont(fontFamily, style: .caption))
										.foregroundStyle(.secondary)
										.textCase(.uppercase)
										.noTruncate()
								}
								.frame(minWidth: 80)

								Button(action: {
									if editingEntryAmount < 100 {
										editingEntryAmount += 0.5
									}
								}) {
									Image(systemSymbol: .plusCircleFill)
										.font(.customFont(fontFamily, style: .title2))
										.foregroundStyle(editingEntryAmount < 100 ? (viewModel.selectedMedication?.displayColor ?? .accent) : Color.secondary.opacity(0.5))
										.frame(minWidth: 44, minHeight: 44)
								}
								.buttonStyle(.borderless)
								.accessibilityLabel("Increase dose amount")
								.accessibilityHint("Increase by 0.5 \(editingEntryUnit.displayName)")
								.disabled(editingEntryAmount >= 100)
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
											Text(unit.displayName)
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
							if let event = editingEntryEvent {
								Task {
									if await viewModel.deleteEvent(event) {
										editingEntryEvent = nil
									}
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
							if entryHasChanges(for: event) {
								showDiscardEntryChanges = true
							} else {
								editingEntryEvent = nil
							}
						} label: {
							Image(systemSymbol: .xmark)
						}
						.accessibilityLabel("Close entry editor")
						.disabled(viewModel.isMutating)
					}
					ToolbarItem(placement: .confirmationAction) {
						Button {
							if let event = editingEntryEvent {
								Task {
									// Update the event with new date, dose amount, and unit
									let saved = await viewModel.updateEvent(
										event,
										newDate: editingEntryDate,
										newAmount: editingEntryAmount,
										newUnit: editingEntryUnit
									)
									if saved {
										editingEntryEvent = nil
									}
								}
							}
						} label: {
							Image(systemSymbol: .checkmark)
						}
						.accessibilityLabel("Save entry changes")
						.disabled(viewModel.isMutating)
					}
				}
				.tint(.accent)
				.confirmationDialog("Discard entry changes?", isPresented: $showDiscardEntryChanges, titleVisibility: .visible) {
					Button("Discard Changes", role: .destructive) { editingEntryEvent = nil }
					Button("Keep Editing", role: .cancel) {}
				}
			}
			.dynamicDetent()
			.alert("Couldn’t Update History", isPresented: mutationErrorPresented) {
				Button("OK", role: .cancel) { viewModel.mutationError = nil }
			} message: {
				Text(viewModel.mutationError ?? "Review History before trying again.")
			}
			.interactiveDismissDisabled(viewModel.isMutating || entryHasChanges(for: event))
		}
		.alert("Couldn’t Update History", isPresented: Binding(
			get: { viewModel.mutationError != nil && editingEvent == nil && editingEntryEvent == nil },
			set: { if !$0 { viewModel.mutationError = nil } }
		)) {
			Button("OK", role: .cancel) { viewModel.mutationError = nil }
		} message: {
			Text(viewModel.mutationError ?? "Review History before trying again.")
		}
	}
}

private extension String {
	var nilIfEmpty: String? {
		let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

#if DEBUG
	#Preview {
		MedicationHistoryView()
	}
#endif
