// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import SwiftUI
import ANModelKit
import SFSafeSymbols

struct MedicationListView: View {
    @StateObject private var viewModel = MedicationListViewModel()
    @State private var showAddSheet = false
    private let hapticsManager = HapticsManager.shared
    @State private var editMedication: ANMedicationConcept?
    @State private var viewMedication: ANMedicationConcept?
    @State private var logMedication: ANMedicationConcept?
    @State private var pendingDelete: ANMedicationConcept?
    @State private var showSupportToast = false
    @State private var showSupportView = false
    @State private var editMode: EditMode = .inactive
    @AppStorage("medicationOrder") private var medicationOrder: [String] = []
    
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
                            .bold()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { 
                            hapticsManager.mediumImpact()
                            showAddSheet = true 
                        }) {
                            Label("Add Medication", systemSymbol: .plus)
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                        }
                    }
                }
                .sheet(item: $editMedication) { med in
                    MedicationEditView(
                        medication: med,
                        onSave: { updated in
                            Task { await viewModel.update(updated); editMedication = nil }
                        },
                        onCancel: { editMedication = nil }
                    )
                }
                .sheet(isPresented: $showAddSheet) {
                    MedicationEditView(
                        medication: nil,
                        onSave: { newMed in
                            Task { await viewModel.add(newMed); showAddSheet = false }
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
                            var updated = med
                            if let quantity = updated.quantity, dose.amount > 0 {
                                updated.quantity = quantity - dose.amount
                            }
                            await viewModel.update(updated)
                            await viewModel.addEvent(event)
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
                    .presentationDetents([.large])
                }
                .alert("Delete Medication?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                    Button("Delete", role: .destructive) {
                        if let med = pendingDelete {
                            hapticsManager.itemDeleted()
                            Task { await viewModel.delete(med); pendingDelete = nil }
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
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image("AppIconDisplay")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 8) {
                    Text("Welcome to As Needed")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Track your medications and view trends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            
            Button(action: { 
                hapticsManager.mediumImpact()
                showAddSheet = true 
            }) {
                Label("Add Your First Medication", systemImage: "plus.circle.fill")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor.gradient)
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: showAddSheet)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var medicationListContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(sortedMedications, id: \.id) { med in
                    HStack {
                        MedicationRow(medication: med) {
                            logMedication = med
                        }
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
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.accentColor)
                            
                            Button(role: .destructive) {
                                hapticsManager.mediumImpact()
                                pendingDelete = med
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
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
                .padding(.bottom, 16)
                .background(Color(.systemGroupedBackground))
        }
    }
    private var sortedMedications: [ANMedicationConcept] {
        let items = viewModel.items
        
        // If we have no saved order, return items as-is
        if medicationOrder.isEmpty {
            return items
        }
        
        // Sort based on saved order
        var sorted: [ANMedicationConcept] = []
        
        // First add items in saved order
        for id in medicationOrder {
            if let med = items.first(where: { $0.id.uuidString == id }) {
                sorted.append(med)
            }
        }
        
        // Then add any new items not in saved order
        for item in items {
            if !medicationOrder.contains(item.id.uuidString) {
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
            Task { await viewModel.delete(med) }
            medicationOrder.removeAll { $0 == med.id.uuidString }
        }
    }
}

// MARK: - Medication Row
struct MedicationRow: View {
    let medication: ANMedicationConcept
    var onLogTapped: () -> Void = {}
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    private let hapticsManager = HapticsManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                // Accessibility Layout
                VStack(alignment: .leading, spacing: 16) {
                    medicationHeader
                    medicationDetails
                    enhancedLogButton
                        .frame(maxWidth: .infinity)
                        .opacity(editMode?.wrappedValue == .active ? 0 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode?.wrappedValue)
                }
                .padding(20)
            } else {
                // Standard Layout
                HStack(alignment: .center, spacing: 16) {
                    // Left Side: Icon and Info
                    HStack(spacing: 14) {
                        medicationIcon
                        
                        VStack(alignment: .leading, spacing: 8) {
                            medicationHeader
                            medicationDetails
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Right Side: Enhanced Log Button
                    enhancedLogButton
                        .opacity(editMode?.wrappedValue == .active ? 0 : 1)
                        .scaleEffect(editMode?.wrappedValue == .active ? 0.8 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode?.wrappedValue)
                }
                .padding(20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? 
                    Color(uiColor: .secondarySystemGroupedBackground) : 
                    Color.white
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.06),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.5),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode?.wrappedValue)
    }
    
    // MARK: - View Components
    private var medicationIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.15),
                            Color.accentColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            
            Image(systemSymbol: iconForMedication)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, options: .speed(0.5), value: isPressed)
        }
    }
    
    private var iconForMedication: SFSymbol {
        // Choose icon based on medication type or unit
        if let unit = medication.prescribedUnit {
            switch unit {
            case .puff:
                return .wind
            case .drop:
                return .drop
            case .spray:
                return .humidity
            default:
                return .pills
            }
        }
        return .pills
    }
    
    private var medicationHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.displayName)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .foregroundStyle(.primary)
            
            if !medication.clinicalName.isEmpty && medication.clinicalName != medication.displayName {
                Text(medication.clinicalName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var medicationDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Quantity Badge
            if let quantity = medication.quantity {
                HStack(spacing: 6) {
                    Image(systemSymbol: .squareStack3dUp)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(quantityColor(for: quantity))
                    
                    Text(quantityText(for: quantity))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(quantityColor(for: quantity))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(quantityColor(for: quantity).opacity(0.12))
                )
            }
        }
    }
    
    private var enhancedLogButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            hapticsManager.mediumImpact()
            onLogTapped()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPressed = false
            }
        }) {
            if dynamicTypeSize.isAccessibilitySize {
                // Full width button for accessibility
                HStack(spacing: 10) {
                    Image(systemSymbol: .plusCircleFill)
                        .font(.title3)
                    Text("Log Dose")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            } else {
                // Compact button with icon and text
                VStack(spacing: 4) {
                    Image(systemSymbol: .plusCircleFill)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Log")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Color.accentColor.opacity(0.4),
                            radius: isPressed ? 2 : 8,
                            x: 0,
                            y: isPressed ? 1 : 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log dose for \(medication.displayName)")
        .accessibilityHint("Opens dose logging for this medication")
    }
    
    // MARK: - Helper Methods
    private func quantityColor(for quantity: Double) -> Color {
        if quantity < 10 {
            return .red
        } else if quantity < 30 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func quantityText(for quantity: Double) -> String {
        let quantityStr = quantity.formattedAmount
        if let unit = medication.prescribedUnit {
            return "\(quantityStr) \(unit.abbreviation) left"
        } else {
            return "\(quantityStr) left"
        }
    }
    
    private func refillColor(isOverdue: Bool, daysUntil: Int) -> Color {
        if isOverdue {
            return .red
        } else if daysUntil <= 7 {
            return .orange
        } else {
            return .secondary
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
            MedicationRow(medication: ANMedicationConcept(
                clinicalName: "Lisinopril",
                nickname: "Blood Pressure",
                quantity: 28.5,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                prescribedUnit: .tablet,
                prescribedDoseAmount: 10.0
            ))
            
            MedicationRow(medication: ANMedicationConcept(
                clinicalName: "Metformin",
                quantity: 90.0,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()), // Yesterday
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), // In 1 month
                prescribedUnit: .tablet
            ))
            
            MedicationRow(medication: ANMedicationConcept(
                clinicalName: "Very Long Medication Name That Could Wrap",
                quantity: 250.0,
                prescribedUnit: .milligram
            ))
            
            MedicationRow(medication: ANMedicationConcept(
                clinicalName: "Albuterol",
                nickname: "Rescue Inhaler",
                quantity: 150.0,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()), // 1 week ago
                nextRefillDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()), // Overdue
                prescribedUnit: .puff
            ))
            
            MedicationRow(medication: ANMedicationConcept(
                clinicalName: "Vitamin D3",
                quantity: 75.0,
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), // Tomorrow
                prescribedUnit: .tablet
            ))
        }
        .listStyle(.insetGrouped)
    }
