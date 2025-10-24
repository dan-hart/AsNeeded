// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import ANModelKit
import SFSafeSymbols
import SwiftUI
import UIKit

struct MedicationDetailView: View {
    let medicationId: UUID
    @State private var medication: ANMedicationConcept
    @StateObject private var viewModel = MedicationDetailViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var navigationManager = NavigationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fontFamily) private var fontFamily
    @State private var showDeleteConfirm = false
    @State private var showLogDose = false
    @State private var showEditSheet = false
    @State private var showReminderSheet = false
    @State private var showReminderList = false
    @State private var reminderCount = 0
    @ScaledMetric private var contentSpacing: CGFloat = 20
    @ScaledMetric private var cardSpacing: CGFloat = 16
    @ScaledMetric private var heroIconSize: CGFloat = 100
    @ScaledMetric private var heroSpacing: CGFloat = 12
    @ScaledMetric private var heroNameSpacing: CGFloat = 4
    @ScaledMetric private var cardPadding: CGFloat = 20
    @ScaledMetric private var cardCornerRadius: CGFloat = 12
    @ScaledMetric private var detailSpacing: CGFloat = 12
    @ScaledMetric private var buttonVerticalPadding: CGFloat = 16
    @ScaledMetric private var sectionSpacing: CGFloat = 16
    @ScaledMetric private var rowSpacing: CGFloat = 10
    @ScaledMetric private var buttonCornerRadius: CGFloat = 8

    init(medication: ANMedicationConcept) {
        medicationId = medication.id
        _medication = State(initialValue: medication)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: contentSpacing) {
                // MARK: - Hero Section

                heroSection

                // MARK: - Quick Actions

                QuickActionsComponent(
                    onEditTapped: { showEditSheet = true },
                    onHistoryTapped: {
                        navigationManager.navigateToHistory(medicationID: medication.id.uuidString)
                        dismiss()
                    },
                    onDeleteTapped: { showDeleteConfirm = true }
                )

                // MARK: - Details Cards

                VStack(spacing: cardSpacing) {
                    medicationInfoCard

                    if medication.quantity != nil || medication.lastRefillDate != nil || medication.nextRefillDate != nil {
                        refillInfoCard
                    }

                    if medication.prescribedDoseAmount != nil && medication.prescribedUnit != nil {
                        prescribedDoseCard
                    }

                    remindersCard
                }
                .padding(.horizontal)

                // MARK: - Bottom Actions

                bottomActionsSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(medication.displayName)
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
                .font(.customFont(fontFamily, style: .body, weight: .semibold))
            }
        }
        .confirmationDialog("Delete \(medication.displayName)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Medication", role: .destructive) {
                Task { await viewModel.delete(medication); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All history and reminders for this medication will be deleted.")
        }
        .sheet(isPresented: $showLogDose) {
            LogDoseView(medication: medication) { dose, event in
                Task {
                    var medicationToUpdate = medication
                    if let quantity = medication.quantity, dose.amount > 0 {
                        medicationToUpdate.quantity = quantity - dose.amount
                    }
                    await viewModel.save(updated: medicationToUpdate)
                    await viewModel.log(event: event)
                    // Update the local medication state to reflect changes
                    medication = medicationToUpdate
                }
            }
            .dynamicDetent()
        }
        .sheet(isPresented: $showEditSheet) {
            MedicationEditView(
                medication: medication,
                onSave: { updatedMedication in
                    Task {
                        await viewModel.save(updated: updatedMedication)
                        // Update the local medication state to reflect changes
                        medication = updatedMedication
                    }
                    showEditSheet = false
                },
                onCancel: {
                    showEditSheet = false
                }
            )
        }
        .sheet(isPresented: $showReminderSheet) {
            Group {
                if notificationManager.authorizationStatus == .authorized {
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
        .task {
            // Refresh medication data from store
            await refreshMedication()

            if notificationManager.authorizationStatus == .authorized || notificationManager.authorizationStatus == .notDetermined {
                await loadReminderCount()
            }
        }
        .onAppear {
            // Refresh medication data when view appears (e.g., returning from edit)
            Task {
                await refreshMedication()
            }
        }
    }

    // MARK: - View Components

    private var heroSection: some View {
        VStack(spacing: heroSpacing) {
            // Large medication icon
            ZStack {
                Circle()
                    .fill(medication.displayColor.opacity(0.1))
                    .frame(width: heroIconSize, height: heroIconSize)

                Image(systemName: medication.effectiveDisplaySymbol)
                    .font(.largeTitle.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(medication.displayColor)
            }

            // Medication names
            VStack(spacing: heroNameSpacing) {
                Text(medication.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if medication.nickname != nil && medication.nickname != medication.clinicalName {
                    Text(medication.clinicalName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    private var medicationInfoCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Medication Info", systemSymbol: .info)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            VStack(spacing: detailSpacing) {
                detailRow(label: "Clinical Name", value: medication.clinicalName)

                if let nickname = medication.nickname {
                    Divider()
                    detailRow(label: "Nickname", value: nickname)
                }
            }
        }
        .padding(cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var refillInfoCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Supply & Refills", systemSymbol: .pills)
                    .font(.headline)
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
        .padding(cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var prescribedDoseCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Prescribed Dose", systemSymbol: .pill)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            if let amount = medication.prescribedDoseAmount, let unit = medication.prescribedUnit {
                HStack {
                    Text("\(amount.formattedAmount)")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(unit.displayName(for: amount == 1 ? 1 : 2))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Reminders", systemSymbol: .bell)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)
                Spacer()

                if reminderCount > 0 {
                    Text("\(reminderCount) active")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
                }
            }

            if notificationManager.authorizationStatus == .authorized || notificationManager.authorizationStatus == .notDetermined {
                VStack(spacing: rowSpacing) {
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
                            .font(.subheadline)
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
        .padding(cardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var bottomActionsSection: some View {
        VStack(spacing: detailSpacing) {
            // Log dose button (primary action)
            Button {
                showLogDose = true
            } label: {
                Label("Log Dose", systemSymbol: .plusCircle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, buttonVerticalPadding)
                    .background(medication.displayColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .padding(.top, contentSpacing)
    }

    // MARK: - Helper Views

    private func detailRow(label: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }

    private func isRefillSoon(_ date: Date) -> Bool {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return daysUntil <= 7 && daysUntil >= 0
    }

    private func refreshMedication() async {
        if let updatedMedication = DataStore.shared.medications.first(where: { $0.id == medicationId }) {
            await MainActor.run {
                medication = updatedMedication
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
