import SwiftUI
import ANModelKit
import Foundation
import SFSafeSymbols

struct MedicationHistoryView: View {
    @StateObject private var viewModel = MedicationHistoryViewModel()
    @EnvironmentObject private var navigationManager: NavigationManager
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
    @State private var editingEntryEvent: ANEventConcept?
    @State private var editingEntryDate: Date = Date()

    @ScaledMetric private var spacing24: CGFloat = 24
    @ScaledMetric private var spacing32: CGFloat = 32
    @ScaledMetric private var spacing12: CGFloat = 12
    @ScaledMetric private var spacing8: CGFloat = 8
    @ScaledMetric private var spacing4: CGFloat = 4
    @ScaledMetric private var spacing2: CGFloat = 2
    @ScaledMetric private var circleSize: CGFloat = 16
    @ScaledMetric private var shadowRadius: CGFloat = 3
    @ScaledMetric private var strokeWidth: CGFloat = 0.5
    @ScaledMetric private var paddingVertical8: CGFloat = 8
    @ScaledMetric private var paddingHorizontal12: CGFloat = 12
    @ScaledMetric private var cornerRadius8: CGFloat = 8
    @ScaledMetric private var paddingVertical12: CGFloat = 12
    @ScaledMetric private var paddingHorizontal24: CGFloat = 24
    @ScaledMetric private var paddingVertical16: CGFloat = 16
    @ScaledMetric private var paddingTrailing20: CGFloat = 20
    @ScaledMetric private var paddingBottom20: CGFloat = 20
    @ScaledMetric private var shadowRadius4: CGFloat = 4
    @ScaledMetric private var spacing20: CGFloat = 20

    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    // MARK: - Private ViewBuilders
    
    @ViewBuilder
    private func emptyHistoryView(for selected: ANMedicationConcept) -> some View {
        Spacer()
        VStack(spacing: spacing24) {
            Text("No history for \(selected.displayName).")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            SubtleSupportView(message: "If As Needed helps you manage medications, consider supporting its development")
                .padding(.horizontal, spacing32)
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
                            VStack(alignment: .leading, spacing: spacing8) {
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

                                        Circle()
                                            .fill(medicationColor)
                                            .frame(width: circleSize, height: circleSize)
                                            .shadow(color: medicationColor.opacity(0.4), radius: shadowRadius, x: 0, y: 1)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white.opacity(0.3), lineWidth: strokeWidth)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: spacing2) {
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
                                        } else {
                                            Text(event.date.formatted(date: .omitted, time: .shortened))
                                        }
                                        if let rel = relativeShortIfToday(event.date) {
                                            Text(rel)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()

                                    // Show add note button if no note exists
                                    if event.note?.isEmpty != false {
                                        Button {
                                            editingEvent = event
                                            editingNoteText = ""
                                        } label: {
                                            HStack(spacing: spacing4) {
                                                Text("Add Note")
                                                Image(systemSymbol: .squareAndPencil)
                                                    .font(.caption)
                                            }
                                            .font(.subheadline)
                                            .foregroundStyle(viewModel.isShowingAllMedications ? .secondary : (viewModel.selectedMedication?.displayColor ?? .accent))
                                            .padding(.vertical, paddingVertical8)
                                            .padding(.horizontal, paddingHorizontal12)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                    }
                                }

                                // Show note below if it exists
                                if let note = event.note, !note.isEmpty {
                                    Text(note)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, paddingHorizontal12)
                                        .padding(.vertical, paddingVertical8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: cornerRadius8)
                                                .fill(Color(.tertiarySystemGroupedBackground))
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingEvent = event
                                            editingNoteText = event.note ?? ""
                                        }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingEntryEvent = event
                                editingEntryDate = event.date
                            }
                        }
                        .onDelete { indexSet in
                            Task { await viewModel.deleteEvents(at: indexSet, in: group.day) }
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
        VStack(alignment: .leading, spacing: spacing2) {
            HStack {
                Text(formatDateWithDayOfWeek(group.day))
                Spacer()
                if let totalText = dayTotalText(for: group.entries) {
                    Text(totalText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let rel = dayRelativeLabel(for: group.day) {
                Text(rel)
                    .font(.footnote)
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
                    HStack(alignment: .center, spacing: spacing12) {
                        Picker("Medication", selection: $viewModel.selectedMedicationID) {
                            Text("All", comment: "Option to view all medications in history").tag(Optional("all"))
                            ForEach(viewModel.medications, id: \.id) { medication in
                                Text(medication.displayName).tag(Optional(medication.id.uuidString))
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(viewModel.selectedMedication?.displayColor ?? .accent)

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
                    .padding(.vertical, paddingVertical12)
                    
                    Divider()
                    
                    if viewModel.isShowingAllMedications {
                        if viewModel.groupedHistory.isEmpty {
                            Spacer()
                            VStack(spacing: spacing24) {
                                Text("No dose history found.")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)

                                SubtleSupportView(message: "If As Needed helps you manage medications, consider supporting its development")
                                    .padding(.horizontal, spacing32)
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
                            .padding(.horizontal, paddingHorizontal24)
                            .padding(.vertical, paddingVertical16)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedMedication?.displayColor ?? .accent)
                                    .shadow(color: .black.opacity(0.3), radius: shadowRadius4, x: 0, y: 2)
                            )
                    }
                    .padding(.trailing, paddingTrailing20)
                    .padding(.bottom, paddingBottom20)
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
                   let uuid = UUID(uuidString: medicationID) {
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
                    VStack(spacing: spacing20) {
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
                            Button("Cancel") {
                                showDatePicker = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Jump") {
                                scrollTarget = Calendar.current.startOfDay(for: selectedDate)
                                showDatePicker = false
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
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
                        Form {
                            Section(header: Text("Event Details")) {
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
                            
                            Section(header: Text("Note")) {
                                TextField("Add a note about this dose", text: $editingNoteText, axis: .vertical)
                                    .lineLimit(4...8)
                            }
                        }
                        .navigationTitle("Edit Note")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    editingEvent = nil
                                    editingNoteText = ""
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    if let event = editingEvent {
                                        Task {
                                            let trimmedNote = editingNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            var updatedEvent = event
                                            updatedEvent.note = trimmedNote.isEmpty ? nil : trimmedNote
                                            await viewModel.updateEvent(updatedEvent)
                                            editingEvent = nil
                                            editingNoteText = ""
                                        }
                                    }
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
                            }
                        }
                    }
                    .dynamicDetent()
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
                    Section(header: Text("Dose Entry Details")) {
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

                        if let dose = event.dose {
                            HStack {
                                Text("Dose")
                                Spacer()
                                Text("\(dose.amount.formattedAmount) \(dose.unit.abbreviation)")
                                    .foregroundStyle(.secondary)
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
                        Button("Cancel") {
                            editingEntryEvent = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let event = editingEntryEvent {
                                Task {
                                    // Update the event with new date/time
                                    var updatedEvent = event
                                    updatedEvent.date = editingEntryDate
                                    await viewModel.updateEvent(updatedEvent)
                                    editingEntryEvent = nil
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
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

#if DEBUG
#Preview {
	MedicationHistoryView()
}
#endif
