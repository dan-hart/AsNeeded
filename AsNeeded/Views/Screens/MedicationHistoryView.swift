import SwiftUI
import ANModelKit
import Foundation
import SFSafeSymbols

struct MedicationHistoryView: View {
    @StateObject private var viewModel = MedicationHistoryViewModel()
    @State private var logMedication: ANMedicationConcept?
    @State private var showSupportToast = false
    @State private var showSupportView = false
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    // MARK: - Private ViewBuilders
    
    @ViewBuilder
    private func emptyHistoryView(for selected: ANMedicationConcept) -> some View {
        Spacer()
        VStack(spacing: 24) {
            Text("No history for \(selected.displayName).")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            SubtleSupportView(message: "If As Needed helps you manage medications, consider supporting its development")
                .padding(.horizontal, 32)
        }
        Spacer()
    }
    
    @ViewBuilder
    private func historyListView() -> some View {
        List {
            ForEach(viewModel.groupedHistory, id: \.day) { group in
                Section(header: sectionHeader(for: group)) {
                    ForEach(group.entries, id: \.id) { event in
                        if let dose = event.dose {
                            let unitName = dose.unit.abbreviation
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(event.date.formatted(date: .omitted, time: .shortened)) – \(dose.amount.formattedAmount) \(unitName)")
                                if let rel = relativeShortIfToday(event.date) {
                                    Text(rel)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.date.formatted(date: .omitted, time: .shortened))
                                if let rel = relativeShortIfToday(event.date) {
                                    Text(rel)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        Task { await viewModel.deleteEvents(at: indexSet, in: group.day) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Section Header Helpers
    @ViewBuilder
    private func sectionHeader(for group: (day: Date, entries: [ANEventConcept])) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(group.day.formatted(date: .abbreviated, time: .omitted))
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
    
    private func dayTotalText(for entries: [ANEventConcept]) -> String? {
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
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Picker("Medication", selection: $viewModel.selectedMedicationID) {
                            ForEach(viewModel.medications, id: \.id) { medication in
                                Text(medication.displayName).tag(Optional(medication.id))
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer(minLength: 8)
                        Button {
                            if let med = viewModel.selectedMedication { logMedication = med }
                        } label: {
                            Label("Log Dose", systemImage: "plus.circle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedMedication == nil)
                        .accessibilityLabel("Log dose for selected medication")
                    }
                    .padding(.horizontal)
                    
                    if let selected = viewModel.selectedMedication {
                        if viewModel.groupedHistory.isEmpty {
                            emptyHistoryView(for: selected)
                        } else {
                            historyListView()
                        }
                    } else {
                        selectionPromptView()
                    }
                }
                .navigationTitle("History")
                .onAppear {
                    // If no medication is selected or the selected medication no longer exists
                    if viewModel.selectedMedicationID == nil || viewModel.selectedMedication == nil {
                        viewModel.selectedMedicationID = viewModel.medications.first?.id
                    }
                }
                .onReceive(timer) { _ in
                    currentTime = Date()
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSupportToast = false
                                    }
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
                
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
            .sheet(isPresented: $showSupportView) {
                NavigationView {
                    SupportView()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
	MedicationHistoryView()
}
#endif
