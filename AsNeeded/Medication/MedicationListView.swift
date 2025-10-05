// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import SwiftUI
import ANModelKit
import SFSafeSymbols

struct MedicationListView: View {
    @StateObject private var viewModel = MedicationListViewModel()
    @Environment(\.fontFamily) private var fontFamily
    @State private var showAddSheet = false
    private let hapticsManager = HapticsManager.shared
    @State private var editMedication: ANMedicationConcept?
    @State private var viewMedication: ANMedicationConcept?
    @State private var logMedication: ANMedicationConcept?
    @State private var pendingDelete: ANMedicationConcept?
    @State private var showSupportToast = false
    @State private var showSupportView = false
    @State private var editMode: EditMode = .inactive
    @AppStorage(UserDefaultsKeys.medicationOrder) private var medicationOrder: [String] = []

    // Quick log toast state
    @State private var showQuickLogToast = false
    @State private var quickLogMedicationName = ""
    @State private var quickLogDoseAmount: Double = 0
    @State private var quickLogDoseUnit = ""
    @State private var quickLogAccentColor: Color = .blue

    @ScaledMetric private var emptyStateSpacing: CGFloat = 32
    @ScaledMetric private var emptyStateInnerSpacing: CGFloat = 16
    @ScaledMetric private var emptyStateSubSpacing: CGFloat = 8
    @ScaledMetric private var iconSize: CGFloat = 80
    @ScaledMetric private var iconCornerRadius: CGFloat = 18
    @ScaledMetric private var shadowRadius: CGFloat = 8
    @ScaledMetric private var shadowY: CGFloat = 4
    @ScaledMetric private var emptyHorizontalPadding: CGFloat = 24
    @ScaledMetric private var buttonVerticalPadding: CGFloat = 16
    @ScaledMetric private var buttonHorizontalPadding: CGFloat = 32
    @ScaledMetric private var buttonCornerRadius: CGFloat = 16
    @ScaledMetric private var buttonShadowRadius: CGFloat = 8
    @ScaledMetric private var listRowTopPadding: CGFloat = 8
    @ScaledMetric private var listRowLeadingPadding: CGFloat = 12
    @ScaledMetric private var listRowBottomPadding: CGFloat = 8
    @ScaledMetric private var listRowTrailingPadding: CGFloat = 12
    @ScaledMetric private var supportViewBottomPadding: CGFloat = 16
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Medication")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if viewModel.items.count > 1 {
                            Button(editMode == .inactive ? "Edit" : "Done") {
                                withAnimation {
                                    editMode = editMode == .inactive ? .active : .inactive
                                    hapticsManager.selectionChanged()
                                }
                            }
                            .font(.customFont(fontFamily, style: .body, weight: .bold))
                            .accessibilityLabel(editMode == .inactive ? "Edit medication list" : "Done editing")
                            .accessibilityHint(editMode == .inactive ? "Enter edit mode to reorder or delete medications" : "Exit edit mode")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            hapticsManager.mediumImpact()
                            showAddSheet = true
                        }) {
                            Label("Add Medication", systemSymbol: .plus)
                                .font(.customFont(fontFamily, style: .body, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .accessibilityLabel("Add new medication")
                        .accessibilityHint("Opens form to add a new medication to your list")
                    }
                }
                .sheet(item: $editMedication) { med in
                    MedicationEditView(
                        medication: med,
                        onSave: { updated in
                            Task {
                                if await viewModel.update(updated) {
                                    editMedication = nil
                                }
                            }
                        },
                        onCancel: { editMedication = nil }
                    )
                }
                .sheet(isPresented: $showAddSheet) {
                    MedicationEditView(
                        medication: nil,
                        onSave: { newMed in
                            Task {
                                if await viewModel.add(newMed) {
                                    showAddSheet = false
                                }
                            }
                        },
                        onCancel: { showAddSheet = false }
                    )
                }
                .sheet(item: $viewMedication) { med in
                    NavigationView {
                        MedicationDetailView(medication: med)
                    }
                }
                .sheet(item: $logMedication) { med in
                    LogDoseView(medication: med) { dose, event in
                        Task {
                            // Batch operations for better performance
                            var updated = med
                            if let quantity = updated.quantity, dose.amount > 0 {
                                updated.quantity = quantity - dose.amount
                            }

                            // Perform operations concurrently where possible
                            async let updateResult = viewModel.update(updated)
                            async let eventResult = viewModel.addEvent(event)

                            // Wait for both operations to complete
                            let (updateSuccess, eventSuccess) = await (updateResult, eventResult)

                            // Only proceed if operations succeeded
                            if updateSuccess && eventSuccess {
                                logMedication = nil

                                // Show success toast with optimized timing
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSupportToast = true
                                    }

                                    try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSupportToast = false
                                    }
                                }
                            }
                        }
                    }
                }
                .alert("Delete Medication?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                    Button("Delete", role: .destructive) {
                        if let med = pendingDelete {
                            hapticsManager.itemDeleted()
                            Task {
                                if await viewModel.delete(med) {
                                    pendingDelete = nil
                                }
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { pendingDelete = nil }
                } message: {
                    Text("This action cannot be undone.")
                }
                .sheet(isPresented: $showSupportView) {
                    NavigationView {
                        SupportView()
                    }
                }
                .overlay(alignment: .center) {
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
        }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if viewModel.items.isEmpty {
                emptyStateView
            } else {
                medicationListContent
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: emptyStateSpacing) {
            Spacer()

            VStack(spacing: emptyStateInnerSpacing) {
                Image("AppIconDisplay")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: shadowY)

                VStack(spacing: emptyStateSubSpacing) {
                    Text("Welcome to As Needed")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Track your medications and view trends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, emptyHorizontalPadding)
                }
            }

            Button(action: {
                hapticsManager.mediumImpact()
                showAddSheet = true
            }) {
                Label("Add Your First Medication", systemSymbol: .plusCircleFill)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, buttonVerticalPadding)
                    .padding(.horizontal, buttonHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .fill(Color.accentColor.gradient)
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: buttonShadowRadius, x: 0, y: shadowY)
            }
            .buttonStyle(.plain)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: showAddSheet)
            .accessibilityLabel("Add your first medication")
            .accessibilityHint("Get started by adding your first medication to track")

            Spacer()
        }
    }
    
    @ViewBuilder
    private var medicationListContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(sortedMedications, id: \.id) { med in
                    HStack {
                        MedicationRowComponent(
                            medication: med,
                            onLogTapped: {
                                logMedication = med
                            },
                            onQuickLog: {
                                // Quick log with default dose on long press
                                // Create default dose from prescribed values
                                let dose = ANDoseConcept(
                                    amount: med.prescribedDoseAmount ?? 1,
                                    unit: med.prescribedUnit ?? .unit
                                )

                                // Update medication quantity
                                var updatedMed = med
                                if let quantity = updatedMed.quantity, dose.amount > 0 {
                                    updatedMed.quantity = quantity - dose.amount
                                }

                                // Create event with current time, no note
                                let event = ANEventConcept(
                                    eventType: .doseTaken,
                                    medication: updatedMed,
                                    dose: dose,
                                    date: Date(),
                                    note: nil
                                )

                                // Perform operations concurrently
                                async let updateResult = viewModel.update(updatedMed)
                                async let eventResult = viewModel.addEvent(event, shouldRecordForReview: false)

                                // Wait for both operations to complete
                                let (updateSuccess, eventSuccess) = await (updateResult, eventResult)

                                // Only proceed if operations succeeded
                                if updateSuccess && eventSuccess {
                                    await MainActor.run {
                                        hapticsManager.doseLogged()
                                    }
                                }

                                // Return success status
                                return updateSuccess && eventSuccess
                            },
                            onQuickLogSuccess: {
                                // Set toast data and show it
                                quickLogMedicationName = med.displayName
                                quickLogDoseAmount = med.prescribedDoseAmount ?? 1
                                quickLogDoseUnit = (med.prescribedUnit ?? .unit).abbreviation
                                quickLogAccentColor = med.displayColor

                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showQuickLogToast = true
                                }

                                // Auto-dismiss after 3 seconds
                                Task {
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    await MainActor.run {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showQuickLogToast = false
                                        }
                                    }
                                }
                            },
                            onAppearanceChanged: { newColorHex, newSymbol in
                                Task {
                                    var updatedMed = med
                                    updatedMed.displayColorHex = newColorHex
                                    updatedMed.symbolInfo = ANMedicationConcept.createSymbolInfo(from: newSymbol)
                                    let _ = await viewModel.update(updatedMed)
                                }
                            }
                        )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { 
                        if editMode == .inactive {
                            viewMedication = med
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: editMode == .inactive) {
                        if editMode == .inactive {
                            Button {
                                hapticsManager.lightImpact()
                                editMedication = med
                            } label: {
                                Label("Edit", systemSymbol: .pencil)
                            }
                            .tint(.accentColor)
                            .accessibilityLabel("Edit \(med.displayName)")
                            .accessibilityHint("Opens edit form for this medication")

                            Button(role: .destructive) {
                                hapticsManager.mediumImpact()
                                pendingDelete = med
                            } label: {
                                Label("Delete", systemSymbol: .trash)
                            }
                            .accessibilityLabel("Delete \(med.displayName)")
                            .accessibilityHint("Removes this medication permanently")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: listRowTopPadding, leading: listRowLeadingPadding, bottom: listRowBottomPadding, trailing: listRowTrailingPadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveMedications)
                .onDelete(perform: deleteMedications)
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))

            SupportSuggestionView()
                .padding(.bottom, supportViewBottomPadding)
                .background(Color(.systemGroupedBackground))
        }
        .overlay(alignment: .top) {
            if showQuickLogToast {
                QuickLogToastView(
                    medicationName: quickLogMedicationName,
                    doseAmount: quickLogDoseAmount,
                    doseUnit: quickLogDoseUnit,
                    accentColor: quickLogAccentColor,
                    isVisible: showQuickLogToast,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showQuickLogToast = false
                        }
                    }
                )
            }
        }
    }
    private var sortedMedications: [ANMedicationConcept] {
        let items = viewModel.items

        // If we have no saved order, return items as-is
        if medicationOrder.isEmpty {
            return items
        }

        // Create efficient lookup structures - O(n) setup
        let itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0) })
        let orderSet = Set(medicationOrder)

        // Build sorted array more efficiently
        var sorted: [ANMedicationConcept] = []
        sorted.reserveCapacity(items.count)

        // First add items in saved order - O(n) lookup
        for id in medicationOrder {
            if let med = itemsById[id] {
                sorted.append(med)
            }
        }

        // Then add any new items not in saved order - O(n) lookup
        for item in items {
            if !orderSet.contains(item.id.uuidString) {
                sorted.append(item)
            }
        }

        return sorted
    }
    
    // MARK: - Private Methods
    private func moveMedications(from source: IndexSet, to destination: Int) {
        var items = sortedMedications
        items.move(fromOffsets: source, toOffset: destination)
        medicationOrder = items.map { $0.id.uuidString }
    }
    
    private func deleteMedications(at offsets: IndexSet) {
        for index in offsets {
            guard let med = sortedMedications[doesExistAt: index] else { continue }
            Task { _ = await viewModel.delete(med) }
            medicationOrder.removeAll { $0 == med.id.uuidString }
        }
    }
}

    
    #Preview {
        MedicationListView()
    }
    
    #Preview("Empty List") {
        MedicationListView()
    }
    
    #Preview("Medication Row Samples") {
        List {
            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Lisinopril",
                nickname: "Blood Pressure",
                quantity: 28.5,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                prescribedUnit: .tablet,
                prescribedDoseAmount: 10.0
            ))

            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Metformin",
                quantity: 90.0,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()), // Yesterday
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), // In 1 month
                prescribedUnit: .tablet
            ))

            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Very Long Medication Name That Could Wrap",
                quantity: 250.0,
                prescribedUnit: .milligram
            ))

            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Albuterol",
                nickname: "Rescue Inhaler",
                quantity: 150.0,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()), // 1 week ago
                nextRefillDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()), // Overdue
                prescribedUnit: .puff
            ))

            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Vitamin D3",
                quantity: 75.0,
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), // Tomorrow
                prescribedUnit: .tablet
            ))
        }
        .listStyle(.insetGrouped)
    }
