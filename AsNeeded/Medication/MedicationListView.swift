// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import ANModelKit
import SFSafeSymbols
import SwiftUI

struct MedicationListView: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var viewModel = MedicationListViewModel()
    @Environment(\.fontFamily) private var fontFamily
    private let hapticsManager = HapticsManager.shared

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
        mainContent
            .navigationTitle("Medication")
                .toolbar {
                    if viewModel.items.count > 1 || !viewModel.items.archived.isEmpty {
                        ToolbarItem(placement: .navigationBarLeading) {
                            HStack(spacing: 12) {
                                if viewModel.items.count > 1 {
                                    Button(viewModel.editMode == .inactive ? "Edit" : "Done") {
                                        viewModel.toggleEditMode()
                                    }
                                    .font(.customFont(fontFamily, style: .body, weight: .bold))
                                    .accessibilityLabel(viewModel.editMode == .inactive ? "Edit medication list" : "Done editing")
                                    .accessibilityHint(viewModel.editMode == .inactive ? "Enter edit mode to reorder or delete medications" : "Exit edit mode")
                                }

                                // Show archived toggle if there are any archived medications
                                if !viewModel.items.archived.isEmpty && viewModel.editMode == .inactive {
                                    Button(action: {
                                        viewModel.toggleArchivedMedications()
                                    }) {
                                        Image(systemSymbol: viewModel.showArchivedMedications ? .archiveboxFill : .archivebox)
                                            .font(.customFont(fontFamily, style: .body, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .accessibilityLabel(viewModel.showArchivedMedications ? "Hide archived medications" : "Show archived medications")
                                    .accessibilityHint("Toggle visibility of archived medications in the list")
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            hapticsManager.mediumImpact()
                            viewModel.showAddSheet = true
                        }) {
                            Label("Add Medication", systemSymbol: .plus)
                                .font(.customFont(fontFamily, style: .body, weight: .medium))
                                .foregroundColor(.accent)
                        }
                        .accessibilityLabel("Add new medication")
                        .accessibilityHint("Opens form to add a new medication to your list")
                    }
                }
                .sheet(item: $viewModel.editMedication) { med in
                    MedicationEditView(
                        medication: med,
                        onSave: { updated in
                            Task {
                                if await viewModel.update(updated) {
                                    viewModel.editMedication = nil
                                }
                            }
                        },
                        onCancel: { viewModel.editMedication = nil }
                    )
                }
                .sheet(isPresented: $viewModel.showAddSheet) {
                    MedicationEditView(
                        medication: nil,
                        onSave: { newMed in
                            Task {
                                if await viewModel.add(newMed) {
                                    viewModel.showAddSheet = false
                                }
                            }
                        },
                        onCancel: { viewModel.showAddSheet = false }
                    )
                }
                .sheet(item: $viewModel.logMedication) { med in
                    LogDoseView(medication: med) { dose, event in
                        Task {
                            await viewModel.logDose(med: med, dose: dose, event: event)
                        }
                    }
                }
                .alert("Delete Medication?", isPresented: Binding(get: { viewModel.pendingDelete != nil }, set: { if !$0 { viewModel.pendingDelete = nil } })) {
                    Button("Delete", role: .destructive) {
                        if let med = viewModel.pendingDelete {
                            hapticsManager.itemDeleted()
                            Task {
                                if await viewModel.delete(med) {
                                    viewModel.pendingDelete = nil
                                }
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { viewModel.pendingDelete = nil }
                } message: {
                    Text("This action cannot be undone.")
                }
                .sheet(isPresented: $viewModel.showSupportView) {
                    NavigationView {
                        SupportView()
                    }
                }
                .overlay(alignment: .top) {
                    // Quick Log Toast
                    if viewModel.showQuickLogToast {
                        QuickLogToastView(
                            medicationName: viewModel.quickLogMedicationName,
                            doseAmount: viewModel.quickLogDoseAmount,
                            doseUnit: viewModel.quickLogDoseUnit,
                            accentColor: viewModel.quickLogAccentColor,
                            isVisible: viewModel.showQuickLogToast,
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.showQuickLogToast = false
                                }
                            }
                        )
                    }

                    // Support Toast
                    SupportToastView(
                        message: "Dose logged successfully",
                        supportMessage: "Support As Needed",
                        isVisible: viewModel.showSupportToast,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.showSupportToast = false
                            }
                        },
                        onSupportTapped: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.showSupportToast = false
                                viewModel.showSupportView = true
                            }
                        }
                    )
                }
                .task {
                    // Initialize medication order if empty to ensure stable sorting
                    // This is now handled in the ViewModel's init
                }
    }

    // MARK: - Computed Properties

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if viewModel.items.isEmpty {
                if viewModel.isLoading {
                    loadingStateView
                } else {
                    emptyStateView
                }
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
                        .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Track your medications and view trends")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, emptyHorizontalPadding)
                }
            }

            Button(action: {
                hapticsManager.mediumImpact()
                viewModel.showAddSheet = true
            }) {
                Label("Add Your First Medication", systemSymbol: .plusCircleFill)
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, buttonVerticalPadding)
                    .padding(.horizontal, buttonHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .fill(.accent.gradient)
                    )
                    .shadow(color: .accent.opacity(0.3), radius: buttonShadowRadius, x: 0, y: shadowY)
            }
            .buttonStyle(.plain)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: viewModel.showAddSheet)
            .accessibilityLabel("Add your first medication")
            .accessibilityHint("Get started by adding your first medication to track")

            Spacer()
        }
    }

    @ViewBuilder
    private var medicationListContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.sortedMedications, id: \.id) { med in
                    HStack {
                        MedicationRowComponent(
                            medication: med,
                            onLogTapped: {
                                viewModel.logMedication = med
                            },
                            onQuickLog: {
                                Task {
                                    // Pass through to view model
                                    _ = await viewModel.quickLog(medication: med)
                                }
                                return true // Assume success for now, actual result handled by VM
                            },
                            onQuickLogSuccess: {
                                // Handled by view model
                            },
                            onAppearanceChanged: { newColorHex, newSymbol in
                                Task {
                                    var updatedMed = med
                                    updatedMed.displayColorHex = newColorHex
                                    updatedMed.symbolInfo = ANMedicationConcept.createSymbolInfo(from: newSymbol)
                                    _ = await viewModel.update(updatedMed)
                                }
                            }
                        )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.editMode == .inactive {
                            navigationPath.append(med)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: viewModel.editMode == .inactive) {
                        if viewModel.editMode == .inactive {
                            Button {
                                hapticsManager.lightImpact()
                                viewModel.editMedication = med
                            } label: {
                                Label("Edit", systemSymbol: .pencil)
                            }
                            .tint(.accent)
                            .accessibilityLabel("Edit \(med.displayName)")
                            .accessibilityHint("Opens edit form for this medication")

                            Button(role: .destructive) {
                                hapticsManager.mediumImpact()
                                viewModel.pendingDelete = med
                            } label: {
                                Label("Delete", systemSymbol: .trash)
                            }
                            .tint(.red)
                            .accessibilityLabel("Delete \(med.displayName)")
                            .accessibilityHint("Removes this medication permanently")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: listRowTopPadding, leading: listRowLeadingPadding, bottom: listRowBottomPadding, trailing: listRowTrailingPadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: viewModel.moveMedications)
                .onDelete(perform: viewModel.deleteMedications)
            }
            .listStyle(.plain)
            .environment(\.editMode, $viewModel.editMode)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))

            SupportSuggestionView()
                .padding(.bottom, supportViewBottomPadding)
                .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.secondary)
            Text("Loading")
                .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Loading"))
    }
}

#Preview {
    NavigationStack {
        MedicationListView(navigationPath: .constant(NavigationPath()))
    }
}

#Preview("Empty List") {
    NavigationStack {
        MedicationListView(navigationPath: .constant(NavigationPath()))
    }
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
