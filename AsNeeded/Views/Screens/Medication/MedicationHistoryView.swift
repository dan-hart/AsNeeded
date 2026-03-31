import ANModelKit
import Foundation
import SFSafeSymbols
import SwiftUI

struct MedicationHistoryView: View {
    @StateObject private var viewModel = MedicationHistoryViewModel()
    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(\.fontFamily) private var fontFamily
    @State private var logMedication: ANMedicationConcept?
    @State private var showSupportToast = false
    @State private var showSupportView = false
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
    @ScaledMetric private var fabPaddingV: CGFloat = 16
    @ScaledMetric private var fabTrailingPadding: CGFloat = 20
    @ScaledMetric private var fabBottomPadding: CGFloat = 20
    @ScaledMetric private var fabShadowRadius: CGFloat = 4
    @ScaledMetric private var datePickerSpacing: CGFloat = 20
    @ScaledMetric private var reflectionBadgePaddingH: CGFloat = 8
    @ScaledMetric private var reflectionBadgePaddingV: CGFloat = 5

    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - Private ViewBuilders

    @ViewBuilder
    private func emptyHistoryView(for selected: ANMedicationConcept) -> some View {
        Spacer()
        VStack(spacing: emptySectionSpacing) {
            Text("No history for \(selected.displayName).")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            SubtleSupportView(message: "If As Needed helps you manage medications, consider supporting its development")
                .padding(.horizontal, supportViewPaddingH)
        }
        Spacer()
    }

    @ViewBuilder
    private func historyListView() -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.groupedHistory, id: \.day) { group in
                    Section(header: sectionHeader(for: group)) {
                        ForEach(group.entries, id: \.id) { event in
                            VStack(alignment: .leading, spacing: entrySpacing) {
                                HStack(alignment: .center) {
                                    // Medication color indicator on the left side
                                    if viewModel.isShowingAllMedications, let eventMedicationID = event.medication?.id {
                                        // Look up current medication from viewModel to ensure we have the latest data
                                        let currentMedication = viewModel.medications.first { $0.id == eventMedicationID }
                                        let rowMedication = currentMedication ?? event.medication!

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
                                            if viewModel.isShowingAllMedications,
                                               let eventMedicationID = event.medication?.id,
                                               let currentMedication = viewModel.medications.first(where: { $0.id == eventMedicationID })
                                            {
                                                Image(systemName: currentMedication.effectiveDisplaySymbol)
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
                                        if viewModel.isShowingAllMedications, let eventMedicationID = event.medication?.id {
                                            let currentMedication = viewModel.medications.first { $0.id == eventMedicationID }
                                            let rowMedication = currentMedication ?? event.medication!
                                            Text(rowMedication.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                        }

                                        if let dose = event.dose {
                                            let unitName = dose.unit.abbreviation
                                            Text("\(event.date.formatted(date: .omitted, time: .shortened)) – \(dose.amount.formattedAmount) \(unitName)")
                                                .font(.customFont(fontFamily, style: .subheadline))
                                        } else {
                                            Text(event.date.formatted(date: .omitted, time: .shortened))
                                                .font(.customFont(fontFamily, style: .subheadline))
                                        }
                                        if let rel = relativeShortIfToday(event.date) {
                                            Text(rel)
                                                .font(.customFont(fontFamily, style: .footnote))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()

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
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: sectionHeaderSpacing) {
                                            ForEach(reflectionHighlights(for: event), id: \.self) { highlight in
                                                Text(highlight)
                                                    .font(.customFont(fontFamily, style: .caption, weight: .medium))
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
                            .onTapGesture {
                                editingEntryEvent = event
                                editingEntryDate = event.date
                                editingEntryAmount = event.dose?.amount ?? 1.0
                                editingEntryUnit = event.dose?.unit ?? .unit
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
                                .tint(viewModel.selectedMedication?.displayColor ?? .accent)

                                Button(role: .destructive) {
                                    Task { await viewModel.deleteEvent(event) }
                                } label: {
                                    Label("Delete", systemSymbol: .trash)
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .id(group.day)
                }
            }
            .listStyle(.insetGrouped)
            .onChange(of: scrollTarget) { _, newTarget in
                if let target = newTarget {
                    withAnimation {
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
            HStack {
                Text(formatDateWithDayOfWeek(group.day))
                    .font(.customFont(fontFamily, style: .headline))
                Spacer()
                if let totalText = dayTotalText(for: group.entries) {
                    Text(totalText)
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func selectionPromptView() -> some View {
        Spacer()
        Text("Select a medication to see history.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
        Spacer()
    }

    // MARK: - Private Methods

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Medication picker and date button
                        HStack(alignment: .center, spacing: rowSpacing) {
                            Menu {
                                Button {
                                    viewModel.selectedMedicationID = "all"
                                } label: {
                                    Text("All", comment: "Option to view all medications in history")
                                }
                                ForEach(viewModel.medications, id: \.id) { medication in
                                    Button {
                                        viewModel.selectedMedicationID = medication.id.uuidString
                                    } label: {
                                        Text(medication.displayName)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.isShowingAllMedications ? "All" : (viewModel.selectedMedication?.displayName ?? "All"))
                                        .font(.customFont(fontFamily, style: .body))
                                        .foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
                                    Image(systemSymbol: .chevronUpChevronDown)
                                        .font(.customFont(fontFamily, style: .caption2))
                                        .foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
                                }
                            }

                            Spacer()

                            Button {
                                showDatePicker = true
                            } label: {
                                Label("Jump to Date", systemSymbol: .calendar)
                                    .labelStyle(.titleAndIcon)
                                    .font(.callout)
                                    .foregroundStyle(viewModel.groupedHistory.isEmpty ? Color.secondary : (viewModel.selectedMedication?.displayColor ?? .accent))
                            }
                            .disabled(viewModel.groupedHistory.isEmpty)
                            .accessibilityLabel("Jump to date")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, pickerContainerPaddingV)

                        Divider()

                        if viewModel.isShowingAllMedications {
                            if viewModel.groupedHistory.isEmpty {
                                Spacer()
                                VStack(spacing: emptySectionSpacing) {
                                    Text("No dose history found.")
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    SubtleSupportView(message: "If As Needed helps you manage medications, consider supporting its development")
                                        .padding(.horizontal, supportViewPaddingH)
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

                    // Floating Action Button for Log Dose
                    if viewModel.selectedMedication != nil && !viewModel.isShowingAllMedications {
                        Button {
                            if let med = viewModel.selectedMedication {
                                logMedication = med
                            }
                        } label: {
                            Label("Log Dose", systemSymbol: .plus)
                                .labelStyle(.titleAndIcon)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, fabPaddingH)
                                .padding(.vertical, fabPaddingV)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedMedication?.displayColor ?? .accent)
                                        .shadow(color: .black.opacity(0.3), radius: fabShadowRadius, x: 0, y: 2)
                                )
                        }
                        .padding(.trailing, fabTrailingPadding)
                        .padding(.bottom, fabBottomPadding)
                        .accessibilityLabel("Log dose for selected medication")
                    }
                }
                .navigationTitle("History")
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
                        VStack(spacing: sectionHeaderSpacing) {
                            DatePicker(
                                "Select Date",
                                selection: $selectedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)

                            Spacer()
                        }
                        .navigationTitle("Jump to Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    showDatePicker = false
                                } label: {
                                    Image(systemSymbol: .xmark)
                                        .font(.customFont(fontFamily, style: .body, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ToolbarItem(placement: .confirmationAction) {
                                Button {
                                    scrollTarget = Calendar.current.startOfDay(for: selectedDate)
                                    showDatePicker = false
                                } label: {
                                    Image(systemSymbol: .checkmarkCircleFill)
                                        .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                    }
                    .dynamicDetent()
                }
                .sheet(item: $logMedication) { med in
                    LogDoseView(medication: med) { dose, event in
                        Task {
                            var updated = med
                            if let quantity = updated.quantity, dose.amount > 0 {
                                updated.quantity = quantity - dose.amount
                            }
                            try? await DataStore.shared.updateMedication(updated)
                            try? await DataStore.shared.addEvent(event)
                            logMedication = nil

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSupportToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSupportToast = false
                                    }
                                }
                            }
                        }
                    }
                }
                .sheet(item: $editingEvent) { event in
                    NavigationStack {
                        VStack(spacing: 0) {
                            Form {
                                Section(header: Text("Event Details").font(.customFont(fontFamily, style: .subheadline))) {
                                    HStack {
                                        Text("Date")
                                        Spacer()
                                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundStyle(.secondary)
                                    }
                                    if let dose = event.dose {
                                        HStack {
                                            Text("Dose")
                                            Spacer()
                                            Text("\(dose.amount.formattedAmount) \(dose.unit.abbreviation)")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Section(header: Text("Note").font(.customFont(fontFamily, style: .subheadline))) {
                                    if !reflectionHighlights(for: event).isEmpty {
                                        VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
                                            Text("Saved context from this dose stays attached when you update the note.")
                                                .font(.customFont(fontFamily, style: .caption))
                                                .foregroundStyle(.secondary)

                                            HStack(spacing: sectionHeaderSpacing) {
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
                                            await viewModel.updateEventNote(updatedEvent)
                                            editingEvent = nil
                                            editingNoteText = ""
                                        }
                                    }
                                }) {
                                    HStack(spacing: entrySpacing) {
                                        Image(systemSymbol: .checkmarkCircle)
                                            .font(.customFont(fontFamily, style: .body))
                                        Text("Save Note")
                                            .font(.customFont(fontFamily, style: .headline))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(LinearGradient(
                                                colors: [
                                                    viewModel.selectedMedication?.displayColor ?? .accent,
                                                    (viewModel.selectedMedication?.displayColor ?? .accent).opacity(0.9),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .shadow(color: (viewModel.selectedMedication?.displayColor ?? .accent).opacity(0.3), radius: 4, x: 0, y: 2)
                                    )
                                }
                                .padding(.horizontal, fabPaddingH)
                                .padding(.vertical, pickerContainerPaddingV)
                            }
                            .background(.regularMaterial)
                        }
                        .navigationTitle("Edit Note")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    editingEvent = nil
                                    editingNoteText = ""
                                } label: {
                                    Image(systemSymbol: .xmark)
                                        .font(.customFont(fontFamily, style: .body, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .presentationDetents([.large])
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

            // Support toast positioned outside NavigationStack to avoid layout interference
            SupportToastView(
                message: "Dose logged successfully",
                supportMessage: "Support As Needed",
                isVisible: showSupportToast,
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSupportToast = false
                    }
                },
                onSupportTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSupportToast = false
                        showSupportView = true
                    }
                }
            )
        }
        .sheet(item: $editingEntryEvent) { event in
            NavigationStack {
                Form {
                    Section(header: Text("Dose Entry Details").font(.customFont(fontFamily, style: .subheadline))) {
                        HStack {
                            Text("Medication")
                            Spacer()
                            if let eventMedicationID = event.medication?.id {
                                let currentMedication = viewModel.medications.first { $0.id == eventMedicationID }
                                let medication = currentMedication ?? event.medication!
                                Text(medication.displayName)
                                    .foregroundStyle(.secondary)
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
                                }
                                .buttonStyle(.borderless)
                                .disabled(editingEntryAmount <= 0.5)

                                VStack(spacing: sectionHeaderSpacing) {
                                    Text("\(editingEntryAmount, specifier: "%.1f")")
                                        .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                                        .contentTransition(.numericText())

                                    Text(editingEntryUnit.displayName)
                                        .font(.customFont(fontFamily, style: .caption))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
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
                                }
                                .buttonStyle(.borderless)
                                .disabled(editingEntryAmount >= 100)
                            }
                            .frame(maxWidth: .infinity)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: entrySpacing) {
                                    ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                editingEntryUnit = unit
                                            }
                                        }) {
                                            Text(unit.displayName)
                                                .font(.customFont(fontFamily, style: .caption, weight: editingEntryUnit == unit ? .semibold : .regular))
                                                .padding(.horizontal, rowSpacing)
                                                .padding(.vertical, entrySpacing)
                                                .background(
                                                    Capsule()
                                                        .fill(editingEntryUnit == unit ? (viewModel.selectedMedication?.displayColor ?? .accent) : Color.secondary.opacity(0.1))
                                                )
                                                .foregroundStyle(editingEntryUnit == unit ? .white : .primary)
                                        }
                                        .buttonStyle(.borderless)
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
                                    await viewModel.deleteEvent(event)
                                    editingEntryEvent = nil
                                }
                            }
                        } label: {
                            Label("Delete Entry", systemSymbol: .trash)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Edit Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            editingEntryEvent = nil
                        } label: {
                            Image(systemSymbol: .xmark)
                                .font(.customFont(fontFamily, style: .body, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            if let event = editingEntryEvent {
                                Task {
                                    // Update the event with new date, dose amount, and unit
                                    await viewModel.updateEvent(
                                        event,
                                        newDate: editingEntryDate,
                                        newAmount: editingEntryAmount,
                                        newUnit: editingEntryUnit
                                    )
                                    editingEntryEvent = nil
                                }
                            }
                        } label: {
                            Image(systemSymbol: .checkmarkCircleFill)
                                .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                                .foregroundStyle(.accent)
                        }
                    }
                }
            }
            .dynamicDetent()
        }
        .sheet(isPresented: $showSupportView) {
            NavigationView {
                SupportView()
            }
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
