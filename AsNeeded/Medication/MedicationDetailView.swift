// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import ANModelKit
import SFSafeSymbols
import SwiftUI
import UIKit

struct MedicationDetailView: View {
	@StateObject private var doseLogSession = LogDoseView.Session()
	@StateObject private var doseConfirmation = MedicationListViewModel()
	@State private var showSupportPage = false
	@State private var undoDoseError = false
    let medicationId: UUID
    @State private var medication: ANMedicationConcept
    @StateObject private var viewModel = MedicationDetailViewModel()
	@StateObject private var medicationEditSession = MedicationEditViewModel.Session()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var navigationManager = NavigationManager.shared
    private let statusSummaryService = MedicationStatusSummaryService()
    private let safetyProfileStore = MedicationSafetyProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fontFamily) private var fontFamily
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showDeleteConfirm = false
    @State private var showLogDose = false
    @State private var showEditSheet = false
    @State private var showReminderSheet = false
    @State private var showReminderList = false
	@Environment(\.scenePhase) private var scenePhase
	@State private var isUpdatingNotificationUrgency = false
	@State private var notificationUrgencyError: String?
    @State private var reminderCount = 0
    @State private var showAppearancePicker = false
    @State private var selectedColorHex: String?
    @State private var selectedSymbol: String?
    private let contentSpacing: CGFloat = 20
    private let cardSpacing: CGFloat = 16
    private let cardPadding: CGFloat = 20
    private let cardCornerRadius: CGFloat = 12
    private let detailSpacing: CGFloat = 12
    private let buttonVerticalPadding: CGFloat = 16
    private let sectionSpacing: CGFloat = 16
    private let rowSpacing: CGFloat = 10
    private let buttonCornerRadius: CGFloat = 8

    // MARK: - Computed Properties

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

	private var notificationsAllowed: Bool {
		switch notificationManager.authorizationStatus {
		case .authorized, .provisional, .ephemeral: return true
		default: return false
		}
	}

    private var adaptiveContentSpacing: CGFloat {
        isRegularWidth ? 32 : contentSpacing
    }

    private var adaptiveCardPadding: CGFloat {
        isRegularWidth ? 32 : cardPadding
    }

    private var cardMaxWidth: CGFloat? {
        isRegularWidth ? 600 : nil
    }

    init(medication: ANMedicationConcept) {
        medicationId = medication.id
        _medication = State(initialValue: medication)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            mainContent
        }
        .background(Color(.systemGroupedBackground))
        .customNavigationTitle(medication.displayName, displayMode: .inline)
		.navigationDestination(isPresented: $showSupportPage) { SupportView() }
		.overlay(alignment: .top) {
			if doseConfirmation.showQuickLogToast {
				QuickLogToastView(
					medicationName: doseConfirmation.quickLogMedicationName,
					doseAmount: doseConfirmation.quickLogDoseAmount,
					doseUnit: doseConfirmation.quickLogDoseUnit,
					accentColor: doseConfirmation.quickLogAccentColor,
					isVisible: doseConfirmation.showQuickLogToast,
					feedback: doseConfirmation.quickLogFeedback,
					onDismiss: { doseConfirmation.dismissQuickLogToast() },
					onUndo: { eventID in
						Task {
							if await doseConfirmation.undoLastQuickLog(eventID: eventID) { await refreshMedication() }
							else { undoDoseError = true }
						}
					},
					includesSupportSuggestion: doseConfirmation.confirmationIncludesSupport,
					onSupportTapped: { doseConfirmation.dismissQuickLogToast(); showSupportPage = true }
				)
			}
		}
		.alert("Couldn’t Undo Dose", isPresented: $undoDoseError) {
			Button("OK", role: .cancel) {}
		} message: { Text("Your dose could not be removed. Check History before trying again.") }
        .toolbar {
            toolbarContent
        }
        .tint(.accent)
        .confirmationDialog("Delete \(medication.displayName)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Medication", role: .destructive) {
                Task {
					await viewModel.delete(medication)
					if viewModel.errorMessage == nil { dismiss() }
				}
            }
			.tint(.red)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All history and reminders for this medication will be deleted.")
        }
        .sheet(isPresented: $showLogDose, onDismiss: {
			if !showLogDose { doseLogSession.reset() }
		}) {
            LogDoseView(medication: medication, source: "detail_sheet", draft: doseLogSession.draft(for: medication)) { dose, event, operationID in
                let success = await viewModel.logDose(
                    medication: medication,
                    dose: dose,
                    event: event,
                    source: "detail_sheet",
                    operationID: operationID
                )

                if success {
                    await refreshMedication()
					doseConfirmation.presentDoseConfirmation(med: medication, dose: dose, event: event)
                }

                return success
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
			if !showEditSheet { medicationEditSession.reset() }
		}) {
            MedicationEditView(
                medication: medication,
				draft: medicationEditSession.draft(for: medication),
                onSave: { updatedMedication in
					let saved = await viewModel.save(updated: updatedMedication, original: medicationEditSession.draft(for: medication).originalMedication)
					if saved {
						medication = viewModel.currentMedication(id: medicationId) ?? updatedMedication
						showEditSheet = false
					}
					return saved
                },
                onCancel: {
                    showEditSheet = false
                }
            )
        }
        .sheet(isPresented: $showReminderSheet) {
            Group {
                if notificationsAllowed {
                    ReminderConfigurationView(medication: medication)
                        .onDisappear {
                            Task {
                                await loadReminderCount()
                            }
                        }
                } else if notificationManager.authorizationStatus == .notDetermined {
                    NotificationPermissionRequestView(
                        onPermissionGranted: {
                            // Permission granted, view will automatically update
                        },
                        onPermissionDenied: {
                            showReminderSheet = false
                        }
                    )
                } else {
					ReminderConfigurationView(medication: medication)
                }
            }
        }
        .sheet(isPresented: $showReminderList) {
            ReminderListView(medication: medication)
                .onDisappear {
                    Task {
                        await loadReminderCount()
                    }
                }
        }
        .sheet(isPresented: $showAppearancePicker) {
            MedicationAppearancePickerComponent(
                medication: medication,
                selectedColorHex: $selectedColorHex,
                selectedSymbol: $selectedSymbol,
                onSave: {
                    Task {
                        var updatedMedication = medication
                        updatedMedication.displayColorHex = selectedColorHex
                        if let symbol = selectedSymbol {
                            updatedMedication.symbolInfo = ANSymbolInfo(name: symbol)
                        }
						if await viewModel.save(updated: updatedMedication, original: medication) {
							medication = viewModel.currentMedication(id: medicationId) ?? updatedMedication
							showAppearancePicker = false
						}
                    }
                },
                onCancel: {
                    showAppearancePicker = false
                }
            )
			.alert("Appearance not saved", isPresented: Binding(
				get: { viewModel.errorMessage != nil },
				set: { if !$0 { viewModel.errorMessage = nil } }
			)) {
				Button("Keep Editing", role: .cancel) { viewModel.errorMessage = nil }
			} message: {
				Text("Your choices are still here. Please try saving again.")
			}
        }
		.alert("Changes not saved", isPresented: Binding(
			get: { viewModel.errorMessage != nil && !showLogDose && !showEditSheet && !showAppearancePicker },
			set: { if !$0 { viewModel.errorMessage = nil } }
		)) {
			Button("OK", role: .cancel) { viewModel.errorMessage = nil }
		} message: {
			Text("Some changes may already be saved. Review this medication before trying again.")
		}
        .task {
            await refreshMedication()
			await notificationManager.checkAuthorizationStatus()
            if notificationsAllowed || notificationManager.authorizationStatus == .notDetermined {
                await loadReminderCount()
            }
            // Initialize selected color and symbol
            selectedColorHex = medication.displayColorHex
            selectedSymbol = medication.symbolInfo?.name
        }
        .onAppear {
            Task {
                await refreshMedication()
            }
        }
		.onChange(of: scenePhase) { _, phase in
			if phase == .active { Task { await notificationManager.checkAuthorizationStatus() } }
		}
		.alert("Reminder settings not saved", isPresented: Binding(
			get: { notificationUrgencyError != nil },
			set: { if !$0 { notificationUrgencyError = nil } }
		)) {
			Button("OK", role: .cancel) { notificationUrgencyError = nil }
		} message: {
			Text(notificationUrgencyError ?? "Please try again.")
		}
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: adaptiveContentSpacing) {
            heroSection

            detailsCardsSection
        }
        .padding(.vertical)
    }

    private var detailsCardsSection: some View {
        VStack(spacing: cardSpacing) {
            medicationInfoCard

            if medication.quantity != nil || medication.lastRefillDate != nil || medication.nextRefillDate != nil {
                refillInfoCard
            }

			VStack(spacing: 12) {
				logDoseButton
				editMedicationButton
			}

			if doseInterval != nil || dailyDoseLimit != nil {
				TimelineView(.periodic(from: .now, by: 1)) { context in
					confidenceCard(at: context.date)
				}
			}

            if medication.prescribedDoseAmount != nil && medication.prescribedUnit != nil {
                prescribedDoseCard
            }

            remindersCard
        }
        .frame(maxWidth: cardMaxWidth)
        .padding(.horizontal, isRegularWidth ? 32 : 20)
    }

	private var doseInterval: Double? {
		medication.minimumHoursBetweenDoses ?? safetyProfileStore.profile(for: medicationId).minimumHoursBetweenDoses
	}

	private var dailyDoseLimit: Double? {
		medication.maximumDailyDoseAmount ?? safetyProfileStore.profile(for: medicationId).maxDailyAmount
	}

    private func confidenceSummary(at date: Date) -> MedicationStatusSummaryService.Summary {
        statusSummaryService.summary(
            for: DataStore.shared.medications.first(where: { $0.id == medicationId }) ?? medication,
			at: date,
            events: DataStore.shared.events,
            profile: safetyProfileStore.profile(for: medication.id)
        )
    }

    private func confidenceCard(at date: Date) -> some View {
        let summary = confidenceSummary(at: date)

        return VStack(alignment: .leading, spacing: sectionSpacing) {
			let headerLayout = dynamicTypeSize.isAccessibilitySize
				? AnyLayout(VStackLayout(alignment: .leading, spacing: rowSpacing))
				: AnyLayout(HStackLayout(alignment: .top, spacing: rowSpacing))
			headerLayout {
                Image(systemSymbol: summaryIcon(for: summary.severity))
                    .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                    .foregroundStyle(summaryColor(for: summary.severity))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dose Timing")
                        .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)

                    Text(summary.headline)
                        .font(.customFont(fontFamily, style: .subheadline, weight: .medium))
                        .foregroundStyle(summaryColor(for: summary.severity))
                        .fixedSize(horizontal: false, vertical: true)
                }

				if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                Text(summary.badgeText)
                    .font(.customFont(fontFamily, style: .caption, weight: .bold))
                    .foregroundStyle(summaryColor(for: summary.severity))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(summaryColor(for: summary.severity).opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: detailSpacing) {
                confidenceRow(icon: .clock, text: summary.timingText, color: .secondary)

				if let hours = doseInterval {
					confidenceRow(icon: .clock, text: "At least \(hours.formattedAmount) hours between doses", color: .secondary)
				}
				if let maximum = dailyDoseLimit {
					confidenceRow(icon: .chartLineUptrendXyaxis, text: "Maximum in any 24 hours: \(maximum.formattedAmount) \(medication.prescribedUnit?.abbreviation ?? "(unit not set)")", color: .secondary)
				}

                if let dailyText = summary.dailyText {
                    confidenceRow(icon: .chartLineUptrendXyaxis, text: dailyText, color: .secondary)
                }

                confidenceRow(icon: .shippingboxFill, text: summary.refillText, color: .secondary)
				Text("Based only on your saved limits and logged doses. Follow your prescription and care instructions.")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(adaptiveCardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel([summary.accessibilityLabel, doseInterval.map { "Minimum interval: \($0.formattedAmount) hours" }, dailyDoseLimit.map { "Maximum in rolling 24 hours: \($0.formattedAmount) \(medication.prescribedUnit?.abbreviation ?? "unit missing")" }, "Follow your prescription and care instructions."].compactMap { $0 }.joined(separator: ". "))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showLogDose = true
            } label: {
                Label("Log Dose", systemSymbol: .pillsFill)
            }
			.tint(.accent)
            .accessibilityLabel("Log dose")
            .accessibilityHint("Open log dose view")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemSymbol: .pencil)
                }

                Button {
                    navigationManager.navigateToHistory(medicationID: medication.id.uuidString)
                } label: {
                    Label("View History", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
					Label("Delete Medication", systemSymbol: .trash)
						.symbolRenderingMode(.monochrome)
						.foregroundStyle(.red)
                }
				.tint(.red)
            } label: {
                Label("More Actions", systemSymbol: .ellipsis)
            }
			.tint(.accent)
            .accessibilityLabel("More actions")
        }
    }

    // MARK: - View Components

	private var heroSection: some View {
		HStack(alignment: .top, spacing: 12) {
			Button {
				selectedColorHex = medication.displayColorHex
				selectedSymbol = medication.symbolInfo?.name
				showAppearancePicker = true
			} label: {
				Image(systemName: medication.effectiveDisplaySymbol)
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))
					.foregroundStyle(medication.displayColor)
					.padding(16)
					.frame(minWidth: 64, minHeight: 64)
					.background(medication.displayColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Change appearance for \(medication.displayName)")

			VStack(alignment: .leading, spacing: 4) {
				Text(medication.displayName)
					.font(.customFont(fontFamily, style: .title2, weight: .bold))
					.noTruncate()
					.accessibilityAddTraits(.isHeader)
				if medication.clinicalName != medication.displayName {
					CopyableText(medication.clinicalName, font: .customFont(fontFamily, style: .subheadline), color: .secondary)
				}
			}
			Spacer(minLength: 0)
		}
		.frame(maxWidth: cardMaxWidth, alignment: .leading)
		.padding(.horizontal, isRegularWidth ? 32 : 20)
	}

    private var medicationInfoCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Medication Info", systemSymbol: .info)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)
                Spacer()
            }

            VStack(spacing: detailSpacing) {
                // Custom row with copyable clinical name
                HStack {
                    Text("Clinical Name")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
                    Spacer()
                    CopyableText(
                        medication.clinicalName,
                        font: .subheadline,
                        weight: .medium,
                        color: .secondary
                    )
                }

                if let nickname = medication.nickname {
                    Divider()
                    detailRow(label: "Nickname", value: nickname)
                }
            }
        }
        .padding(adaptiveCardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var refillInfoCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Supply & Refills", systemSymbol: .pills)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)
                Spacer()
            }

            VStack(spacing: detailSpacing) {
                if let quantity = medication.quantity {
                    let supplyValue: String = {
                        if let unit = medication.prescribedUnit {
                            return "\(quantity.formattedAmount) \(unit.abbreviation)"
                        } else {
                            return quantity.formattedAmount
                        }
                    }()
                    detailRow(
                        label: "Current Supply",
                        value: supplyValue
                    )
                }

                if medication.lastRefillDate != nil || medication.nextRefillDate != nil {
                    if medication.quantity != nil { Divider() }

                    if let lastRefill = medication.lastRefillDate {
                        detailRow(
                            label: "Last Refill",
                            value: lastRefill.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    if let nextRefill = medication.nextRefillDate {
                        if medication.lastRefillDate != nil { Divider() }
                        detailRow(
                            label: "Next Refill",
                            value: nextRefill.formatted(date: .abbreviated, time: .omitted),
                            valueColor: isRefillSoon(nextRefill) ? .orange : .secondary
                        )
                    }
                }
            }
        }
        .padding(adaptiveCardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var prescribedDoseCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Prescribed Dose", systemSymbol: .pill)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)
                Spacer()
            }

            if let amount = medication.prescribedDoseAmount, let unit = medication.prescribedUnit {
                HStack {
                    Text("\(amount.formattedAmount)")
                        .font(.customFont(fontFamily, style: .title))
                        .fontWeight(.semibold)
                    Text(unit.displayName(for: amount == 1 ? 1 : 2))
                        .font(.customFont(fontFamily, style: .title3))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(adaptiveCardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Scheduled Reminders", systemSymbol: .bell)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)
                Spacer()

                if reminderCount > 0 {
                    Text("\(reminderCount) active")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
                }
            }

			Text("Reminders for times you choose. Next-dose alerts are separate, in Edit Medication.")
				.font(.customFont(fontFamily, style: .caption))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

            if notificationsAllowed || notificationManager.authorizationStatus == .notDetermined {
                VStack(spacing: rowSpacing) {
					if notificationsAllowed { urgencyControl }
                    if reminderCount > 0 {
                        Button {
                            showReminderList = true
                        } label: {
                            HStack {
                                Text("Manage Reminders")
                                    .font(.customFont(fontFamily, style: .body, weight: .medium))
                                Spacer()
                                Image(systemSymbol: .chevronRight)
                                    .font(.customFont(fontFamily, style: .caption))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, rowSpacing)
                            .padding(.horizontal, detailSpacing)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showReminderSheet = true
                    } label: {
                        HStack {
                            Image(systemSymbol: .plus)
                                .font(.customFont(fontFamily, style: .subheadline))
                            Text("Add Reminder")
                                .font(.customFont(fontFamily, style: .body, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, rowSpacing)
                        .background(medication.displayColor.opacity(0.1))
                        .foregroundStyle(medication.displayColor)
                        .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            } else if notificationManager.authorizationStatus == .denied {
                VStack(spacing: rowSpacing) {
                    HStack(spacing: contentSpacing) {
                        Image(systemSymbol: .bellSlash)
                            .foregroundColor(.orange)
                        Text("Notifications Disabled")
                            .font(.customFont(fontFamily, style: .subheadline))
                            .foregroundColor(.secondary)
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemSymbol: .gearshape)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, rowSpacing)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(adaptiveCardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

	private var urgencyControl: some View {
		VStack(alignment: .leading, spacing: 8) {
			Toggle(isOn: Binding(
				get: { notificationManager.isUrgent(for: medicationId) },
				set: { requested in
					guard !isUpdatingNotificationUrgency else { return }
					isUpdatingNotificationUrgency = true
					Task {
						defer { isUpdatingNotificationUrgency = false }
						do { try await notificationManager.setUrgent(requested, for: medicationId) }
						catch { notificationUrgencyError = "Your reminder settings could not be updated. Please try again." }
					}
				}
			)) {
				VStack(alignment: .leading, spacing: 4) {
					Text("Urgent Reminders")
						.font(.customFont(fontFamily, style: .body, weight: .medium))
					Text("Use Time Sensitive delivery for scheduled reminders. Can notify you through Focus and Scheduled Summary when allowed in iOS Settings.")
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
			.tint(.accent)
			.disabled(isUpdatingNotificationUrgency)
			if isUpdatingNotificationUrgency {
				ProgressView("Updating reminders…")
					.font(.customFont(fontFamily, style: .caption))
			}
			if notificationManager.isUrgent(for: medicationId), notificationManager.timeSensitiveSetting != .enabled {
				Text(notificationManager.timeSensitiveSetting == .disabled ? "Time Sensitive alerts are off in iOS Settings." : "Time Sensitive delivery is unavailable for this build or device.")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				Button("Open Settings") {
					if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
				}
				.font(.customFont(fontFamily, style: .caption))
				.tint(.accent)
			}
		}
		.padding(.vertical, rowSpacing)
		.padding(.horizontal, detailSpacing)
		.background(Color(.tertiarySystemGroupedBackground))
		.clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
	}

	private var logDoseButton: some View {
		detailActionButton("Log Dose", icon: .plusCircleFill) {
			HapticsManager.shared.mediumImpact()
			showLogDose = true
		}
	}

	private var editMedicationButton: some View {
		detailActionButton("Edit Medication", icon: .pencil, isSecondary: true) {
			HapticsManager.shared.mediumImpact()
			showEditSheet = true
		}
	}

	private func detailActionButton(_ title: String, icon: SFSymbol, isSecondary: Bool = false, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack(spacing: 12) {
				Image(systemSymbol: icon)
					.font(.customFont(fontFamily, style: .body, weight: .semibold))
					.padding(4)
					.accessibilityHidden(true)
				Text(title)
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity)
			.padding(.horizontal, 16)
			.padding(.vertical, 16)
			.foregroundStyle(isSecondary ? Color.primary : medication.displayColor.dynamicFilledButtonForeground)
		}
		.buttonStyle(.borderedProminent)
		.tint(isSecondary ? Color(.secondarySystemFill) : medication.displayColor.dynamicFilledButtonBackground)
	}

    // MARK: - Helper Views

    private func detailRow(label: String, value: String, valueColor: Color = .secondary) -> some View {
		let layout = dynamicTypeSize.isAccessibilitySize
			? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
			: AnyLayout(HStackLayout(alignment: .top))
		return layout {
			Text(label)
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
			if !dynamicTypeSize.isAccessibilitySize { Spacer() }
			Text(value)
				.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
				.foregroundStyle(valueColor)
				.fixedSize(horizontal: false, vertical: true)
		}
		.accessibilityElement(children: .combine)
    }

    private func confidenceRow(icon: SFSymbol, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: rowSpacing) {
            Image(systemSymbol: icon)
                .font(.customFont(fontFamily, style: .caption, weight: .medium))
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(text)
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryColor(for severity: MedicationDoseGuidanceService.Severity) -> Color {
        switch severity {
        case .clear:
            return .guidanceGreen(for: colorScheme)
        case .caution:
            return .orange
        case .warning:
            return .red
        }
    }

    private func summaryIcon(for severity: MedicationDoseGuidanceService.Severity) -> SFSymbol {
        switch severity {
        case .clear:
            return .checkmarkCircleFill
        case .caution:
            return .exclamationmarkTriangleFill
        case .warning:
            return .exclamationmarkTriangleFill
        }
    }

    private func isRefillSoon(_ date: Date) -> Bool {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return daysUntil <= 7 && daysUntil >= 0
    }

    private func refreshMedication() async {
        if let updatedMedication = DataStore.shared.medications.first(where: { $0.id == medicationId }) {
            await MainActor.run {
                medication = viewModel.currentMedication(id: medicationId) ?? updatedMedication
            }
        }
    }

    private func loadReminderCount() async {
        let reminders = await notificationManager.getReminderDetails(for: medication)
        await MainActor.run {
            reminderCount = reminders.count
        }
    }


}

#Preview {
    MedicationDetailView(medication: ANMedicationConcept(
        clinicalName: "Albuterol Inhaler",
        nickname: "Rescue Inhaler"
    ))
}

#Preview("Medication with Long History") {
    MedicationDetailView(medication: ANMedicationConcept(
        clinicalName: "Metformin",
        nickname: "Diabetes Med"
    ))
}

#Preview("Medication with Refill Info") {
    MedicationDetailView(medication: ANMedicationConcept(
        clinicalName: "Lisinopril",
        nickname: "Blood Pressure",
        quantity: 30,
        lastRefillDate: Date(timeIntervalSinceNow: -86400 * 10),
        nextRefillDate: Date(timeIntervalSinceNow: 86400 * 20)
    ))
}
