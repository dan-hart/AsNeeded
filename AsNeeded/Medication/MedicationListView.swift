// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import ANModelKit
import SFSafeSymbols
import SwiftUI

struct MedicationListView: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	@State private var showSupportPage = false
	@StateObject private var doseLogSession = LogDoseView.Session()
	@StateObject private var navigationManager = NavigationManager.shared
    @Binding var navigationPath: NavigationPath
    @StateObject private var viewModel = MedicationListViewModel()
	@StateObject private var medicationEditSession = MedicationEditViewModel.Session()
	@Environment(\.scenePhase) private var scenePhase
    @Environment(\.fontFamily) private var fontFamily
	@State private var quickLogError = false
	@State private var showLogDosePicker = false
	@State private var pendingPickerMedication: ANMedicationConcept?
	@State private var logDoseSearchQuery = ""
    private let hapticsManager = HapticsManager.shared

    private let emptyStateSpacing: CGFloat = 32
    private let emptyStateInnerSpacing: CGFloat = 16
    private let emptyStateSubSpacing: CGFloat = 8
    @ScaledMetric private var iconSize: CGFloat = 80
    private let iconCornerRadius: CGFloat = 18
    private let shadowRadius: CGFloat = 8
    private let shadowY: CGFloat = 4
    private let emptyHorizontalPadding: CGFloat = 24
    private let buttonVerticalPadding: CGFloat = 16
    private let buttonHorizontalPadding: CGFloat = 32
    private let buttonCornerRadius: CGFloat = 16
    private let buttonShadowRadius: CGFloat = 8
    private let listRowTopPadding: CGFloat = 5
    private let listRowLeadingPadding: CGFloat = 12
    private let listRowBottomPadding: CGFloat = 5
    private let listRowTrailingPadding: CGFloat = 12
	@ScaledMetric private var floatingButtonClearance: CGFloat = 88
    private let supportViewBottomPadding: CGFloat = 16

    var body: some View {
        mainContent
			.alert("Couldn’t Log Dose", isPresented: $quickLogError) { Button("OK", role: .cancel) {} } message: { Text("We couldn’t save this change. Please try again.") }
			.customNavigationTitle("Medication", displayMode: .large)
			.navigationDestination(isPresented: $showSupportPage) { SupportView() }
			.safeAreaInset(edge: .bottom, spacing: 0) {
				if !loggableMedications.isEmpty && viewModel.editMode == .inactive {
					Color.clear.frame(height: floatingButtonClearance)
				}
			}
			.overlay(alignment: .bottomTrailing) {
				if !loggableMedications.isEmpty && viewModel.editMode == .inactive {
					primaryLogDoseButton
				}
			}
                .toolbar {
                    if viewModel.items.count > 1 || !viewModel.items.archived.isEmpty {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            if viewModel.items.count > 1 {
                                Button(viewModel.editMode == .inactive ? String(localized: "Edit") : String(localized: "Done")) {
                                    viewModel.toggleEditMode()
                                }
                                .font(.customFont(fontFamily, style: .body))
                                .accessibilityLabel(viewModel.editMode == .inactive ? String(localized: "Edit medication list") : String(localized: "Done editing"))
                                .accessibilityHint(viewModel.editMode == .inactive ? String(localized: "Enter edit mode to reorder or delete medications") : String(localized: "Exit edit mode"))
                            }

                            // Show archived toggle if there are any archived medications
                            if !viewModel.items.archived.isEmpty && viewModel.editMode == .inactive {
                                Button(action: {
                                    viewModel.toggleArchivedMedications()
                                }) {
                                    Image(systemSymbol: viewModel.showArchivedMedications ? .archiveboxFill : .archivebox)
                                }
                                .accessibilityLabel(viewModel.showArchivedMedications ? String(localized: "Hide archived medications") : String(localized: "Show archived medications"))
                                .accessibilityHint("Toggle visibility of archived medications in the list")
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            hapticsManager.mediumImpact()
                            viewModel.showAddSheet = true
                        }) {
                            Label("Add Medication", systemSymbol: .plus)
                        }
                        .accessibilityLabel("Add new medication")
                        .accessibilityHint("Opens form to add a new medication to your list")
                    }
                }
                .tint(.accent)
                .sheet(item: $viewModel.editMedication, onDismiss: {
					if viewModel.editMedication == nil { medicationEditSession.reset() }
				}) { med in
                    MedicationEditView(
                        medication: med,
						draft: medicationEditSession.draft(for: med),
                        onSave: { updated in
							let saved = await viewModel.update(updated, original: medicationEditSession.draft(for: med).originalMedication)
							if saved { viewModel.editMedication = nil }
							return saved
                        },
                        onCancel: { viewModel.editMedication = nil }
                    )
                }
                .sheet(isPresented: $viewModel.showAddSheet, onDismiss: {
					if !viewModel.showAddSheet { medicationEditSession.reset() }
				}) {
                    MedicationEditView(
                        medication: nil,
						draft: medicationEditSession.draft(for: nil),
                        onSave: { newMed in
							let saved = await viewModel.add(newMed)
							if saved { viewModel.showAddSheet = false }
							return saved
                        },
                        onCancel: { viewModel.showAddSheet = false }
                    )
                }
				.sheet(isPresented: $showLogDosePicker, onDismiss: {
					guard !showLogDosePicker else { return }
					logDoseSearchQuery = ""
					guard let selected = pendingPickerMedication else { return }
					pendingPickerMedication = nil
					// Revalidate after dismissal so deleted/archived items cannot open a stale dose form.
					viewModel.logMedication = loggableMedications.first { $0.id == selected.id }
				}) {
					LogDosePickerSheet(medications: loggableMedications, query: $logDoseSearchQuery, onSelect: { medication in
						pendingPickerMedication = medication
						showLogDosePicker = false
					}, onQuickLog: { medication in
						await viewModel.quickLog(medication: medication)
					}, onQuickLogSuccess: { _ in
						AppTips.didQuickLog()
						showLogDosePicker = false
					})
				}
                .sheet(item: $viewModel.logMedication, onDismiss: {
					if viewModel.logMedication == nil { doseLogSession.reset() }
				}) { med in
                    LogDoseView(medication: med, source: "list_sheet", draft: doseLogSession.draft(for: med)) { dose, event, operationID in
                        await viewModel.logDose(
                            med: med,
                            dose: dose,
                            event: event,
                            source: "list_sheet",
                            operationID: operationID
                        )
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
                    Text("This deletes the medication, its dose history, and its reminders. This cannot be undone.")
                }
                .sheet(isPresented: $viewModel.showSupportView) {
                    NavigationView {
                        SupportView()
							.toolbar {
								ToolbarItem(placement: .topBarTrailing) {
									Button(role: .close) { viewModel.showSupportView = false }
										.accessibilityLabel("Close support")
								}
							}
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
                            feedback: viewModel.quickLogFeedback,
                            onDismiss: {
                                viewModel.dismissQuickLogToast()
                            },
                            onUndo: { eventID in
                                Task {
                                    if !(await viewModel.undoLastQuickLog(eventID: eventID)) { quickLogError = true }
                                }
                            }
                        )
                    }

                }
				.task(id: "chooser|\(navigationManager.shouldShowLogDoseChooser)|\(viewModel.logMedication?.id.uuidString ?? "")|\(viewModel.editMedication?.id.uuidString ?? "")|\(viewModel.showAddSheet)|\(viewModel.showSupportView)") {
					guard navigationManager.shouldShowLogDoseChooser, viewModel.logMedication == nil,
						viewModel.editMedication == nil, !viewModel.showAddSheet, !viewModel.showSupportView else { return }
					navigationManager.shouldShowLogDoseChooser = false
					pendingPickerMedication = nil
					logDoseSearchQuery = ""
					showLogDosePicker = true
				}
				.task(id: "\(navigationManager.pendingLogMedicationID ?? "")|\(viewModel.logMedication?.id.uuidString ?? "")|\(scenePhase)|\(showLogDosePicker)|\(viewModel.editMedication?.id.uuidString ?? "")|\(viewModel.showAddSheet)|\(viewModel.showSupportView)") {
					guard scenePhase == .active else { return }
					if let id = navigationManager.pendingLogMedicationID, viewModel.logMedication?.id.uuidString == id {
						navigationManager.clearLogDoseNavigation()
						return
					}
					guard let id = navigationManager.pendingLogMedicationID, viewModel.logMedication == nil, !showLogDosePicker, viewModel.editMedication == nil, !viewModel.showAddSheet, !viewModel.showSupportView else { return }
					do {
						let snapshot = try await DataStore.shared.prepareForAccess()
						guard !Task.isCancelled, navigationManager.pendingLogMedicationID == id else { return }
						let medication = LogDosePickerModel.medication(forDeepLink: id, from: snapshot.medications)
						navigationManager.clearLogDoseNavigation()
						guard let medication else {
							navigationManager.showWidgetUnavailable = true
							return
						}
						navigationPath = NavigationPath()
						viewModel.logMedication = medication
					} catch {
						// Retain the pending identity so a later foreground retry can recover.
					}
				}

    }

    // MARK: - Computed Properties

	private var loggableMedications: [ANMedicationConcept] {
		LogDosePickerModel.medications(from: viewModel.sortedMedications)
	}

	private var floatingQuickLogMedication: ANMedicationConcept? {
		LogDosePickerModel.quickLogMedication(selectedID: nil, useLastLogged: true,
			lastLoggedID: DataStore.shared.lastLoggedMedication?.id, from: loggableMedications)
	}

	private var primaryLogDoseButton: some View {
		let medication = floatingQuickLogMedication
		return FloatingLogDoseButton(quickLogMedication: medication, tint: .accent, onChoose: {
			pendingPickerMedication = nil
			logDoseSearchQuery = ""
			showLogDosePicker = true
		}, onQuickLog: medication.map { medication in {
			guard floatingQuickLogMedication?.id == medication.id else { return false }
			return await quickLog(medication)
		} })
	}

	private func quickLog(_ medication: ANMedicationConcept) async -> Bool {
		let saved = await viewModel.quickLog(medication: medication)
		if !saved { quickLogError = true }
		return saved
	}

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
			if demoMode.isEnabled { DemoModeBanner().padding(.horizontal, 16) }
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
                    .filledButtonForeground(against: .accent)
                    .padding(.vertical, buttonVerticalPadding)
                    .padding(.horizontal, buttonHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .fill(Color.accent.dynamicFilledButtonBackground)
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
				if demoMode.isEnabled {
					DemoModeBanner()
						.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
                ForEach(viewModel.sortedMedications, id: \.id) { med in
                    HStack {
                        MedicationRowComponent(
                            medication: med,
                            statusSummary: viewModel.statusSummary(for: med),
                            onLogTapped: {
                                viewModel.logMedication = med
                            },
							onOpen: { navigationPath.append(med) },
                            onQuickLog: {
                                await quickLog(med)
                            },
                            onQuickLogSuccess: { AppTips.didQuickLog() },
                            onAppearanceChanged: { newColorHex, newSymbol in
                                Task {
                                    var updatedMed = med
                                    updatedMed.displayColorHex = newColorHex
                                    updatedMed.symbolInfo = ANMedicationConcept.createSymbolInfo(from: newSymbol)
                                    _ = await viewModel.update(updatedMed, original: med)
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
                            .accessibilityLabel("Edit \(med.demoDisplayName)")
                            .accessibilityHint("Opens edit form for this medication")

                            Button(role: .destructive) {
                                hapticsManager.mediumImpact()
                                viewModel.pendingDelete = med
                            } label: {
                                Label("Delete", systemSymbol: .trash)
                            }
                            .tint(.red)
                            .accessibilityLabel("Delete \(med.demoDisplayName)")
                            .accessibilityHint("Removes this medication permanently")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: listRowTopPadding, leading: listRowLeadingPadding, bottom: listRowBottomPadding, trailing: listRowTrailingPadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: viewModel.moveMedications)
                .onDelete(perform: viewModel.deleteMedications)

				if viewModel.editMode == .inactive {
					SupportSuggestionView(onSupportTapped: { showSupportPage = true })
						.listRowInsets(EdgeInsets())
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
						.environment(\.defaultMinListRowHeight, 0)
				}
            }
            .listStyle(.plain)
            .environment(\.editMode, $viewModel.editMode)
            .scrollContentBackground(.hidden)
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
