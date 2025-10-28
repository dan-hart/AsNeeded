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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDeleteConfirm = false
    @State private var showLogDose = false
    @State private var showEditSheet = false
    @State private var showReminderSheet = false
    @State private var showReminderList = false
    @State private var reminderCount = 0
    @State private var showAppearancePicker = false
    @State private var heroIconScale: CGFloat = 1.0
    @State private var selectedColorHex: String?
    @State private var selectedSymbol: String?
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

    // MARK: - Computed Properties

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var adaptiveContentSpacing: CGFloat {
        isRegularWidth ? 32 : contentSpacing
    }

    private var adaptiveCardPadding: CGFloat {
        isRegularWidth ? 32 : cardPadding
    }

    private var adaptiveHeroIconSize: CGFloat {
        isRegularWidth ? 140 : heroIconSize
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
        .navigationTitle(medication.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
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
                    medication = medicationToUpdate
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            MedicationEditView(
                medication: medication,
                onSave: { updatedMedication in
                    Task {
                        await viewModel.save(updated: updatedMedication)
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
                        await viewModel.save(updated: updatedMedication)
                        medication = updatedMedication
                    }
                    showAppearancePicker = false
                },
                onCancel: {
                    showAppearancePicker = false
                }
            )
        }
        .task {
            await refreshMedication()
            if notificationManager.authorizationStatus == .authorized || notificationManager.authorizationStatus == .notDetermined {
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
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: adaptiveContentSpacing) {
            heroSection

            QuickActionsComponent(
                onEditTapped: { showEditSheet = true },
                onHistoryTapped: {
                    navigationManager.navigateToHistory(medicationID: medication.id.uuidString)
                },
                onDeleteTapped: { showDeleteConfirm = true }
            )
            .frame(maxWidth: cardMaxWidth)

            logDoseButton

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

            if medication.prescribedDoseAmount != nil && medication.prescribedUnit != nil {
                prescribedDoseCard
            }

            remindersCard
        }
        .frame(maxWidth: cardMaxWidth)
        .padding(.horizontal, isRegularWidth ? 32 : 20)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showLogDose = true
            } label: {
                Image(systemSymbol: .pillsFill)
                    .font(.customFont(fontFamily, style: .body, weight: .semibold))
                    .foregroundStyle(medication.displayColor)
            }
            .accessibilityLabel("Log dose")
            .accessibilityHint("Open log dose view")
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemSymbol: .pencil)
                }

                Button {
                    navigationManager.navigateToHistory(medicationID: medication.id.uuidString)
                } label: {
                    Label("View History", systemSymbol: .clockArrowCirclepath)
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemSymbol: .trash)
                }
            } label: {
                Image(systemSymbol: .ellipsisCircle)
                    .font(.customFont(fontFamily, style: .body, weight: .medium))
            }
            .accessibilityLabel("More actions")
        }
    }

    // MARK: - View Components

    private var heroSection: some View {
        VStack(spacing: heroSpacing) {
            // Liquid Glass hero icon with interactive tap
            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    heroIconScale = 0.95
                }
                HapticsManager.shared.mediumImpact()

                // Reset scale and show appearance picker
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(duration: 0.4, bounce: 0.6)) {
                        heroIconScale = 1.0
                    }
                }
                showAppearancePicker = true
            } label: {
                ZStack {
                    // Blur halo (more prominent)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    medication.displayColor.opacity(0.4),
                                    medication.displayColor.opacity(0.2),
                                    medication.displayColor.opacity(0.05)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: (adaptiveHeroIconSize + 40) / 2
                            )
                        )
                        .frame(width: adaptiveHeroIconSize + 40, height: adaptiveHeroIconSize + 40)
                        .blur(radius: 30)

                    // Glass circle base with color
                    Circle()
                        .fill(medication.displayColor.opacity(0.15))
                        .frame(width: adaptiveHeroIconSize, height: adaptiveHeroIconSize)

                    // Glass effect overlay
                    Circle()
                        .fill(.clear)
                        .frame(width: adaptiveHeroIconSize, height: adaptiveHeroIconSize)
                        .background {
                            Circle()
                                .fill(medication.displayColor.opacity(0.1))
                                .glassEffect(.regular.tint(medication.displayColor.opacity(0.3)))
                        }

                    // Subtle inner highlight
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .clear,
                                    medication.displayColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: adaptiveHeroIconSize, height: adaptiveHeroIconSize)
                        .blendMode(.overlay)

                    // Icon with stronger presence
                    Image(systemName: medication.effectiveDisplaySymbol)
                        .font(.system(size: adaptiveHeroIconSize * 0.45).weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(medication.displayColor)
                        .shadow(color: medication.displayColor.opacity(0.3), radius: 8, y: 2)
                }
                .scaleEffect(heroIconScale)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Customize appearance")
            .accessibilityHint("Tap to change medication color and symbol")

            // Medication names
            VStack(spacing: heroNameSpacing) {
                Text(medication.displayName)
                    .font(.customFont(fontFamily, style: .title, weight: .bold))
                    .multilineTextAlignment(.center)
                    .noTruncate()

                // Status indicators
                let indicators = statusIndicators()
                if !indicators.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(indicators) { indicator in
                                statusPill(indicator)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .padding(.top, 2)
                }

                // Clinical name (if different from nickname)
                if medication.nickname != nil && medication.nickname != medication.clinicalName {
                    CopyableText(
                        medication.clinicalName,
                        font: .subheadline,
                        color: .secondary
                    )
                    .multilineTextAlignment(.center)
                }

                // Last dose timestamp
                if let lastDose = lastDoseDate() {
                    HStack(spacing: 4) {
                        Image(systemSymbol: .clock)
                            .font(.customFont(fontFamily, style: .caption2))
                        Text("Last taken \(lastDose, style: .relative) ago")
                            .font(.customFont(fontFamily, style: .caption))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func statusPill(_ indicator: StatusIndicator) -> some View {
        HStack(spacing: 4) {
            Image(systemSymbol: indicator.icon)
                .font(.customFont(fontFamily, style: .caption2))
            Text(indicator.text)
                .font(.customFont(fontFamily, style: .caption, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .glassEffect(.regular.tint(indicator.color.opacity(0.3)))
        }
        .foregroundStyle(indicator.color)
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
                // Custom row with copyable clinical name
                HStack {
                    Text("Clinical Name")
                        .font(.subheadline)
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
        .padding(adaptiveCardPadding)
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
        .padding(adaptiveCardPadding)
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
        .padding(adaptiveCardPadding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var logDoseButton: some View {
        Button {
            HapticsManager.shared.mediumImpact()
            showLogDose = true
        } label: {
            HStack(spacing: 8) {
                Image(systemSymbol: .plusCircleFill)
                    .font(.customFont(fontFamily, style: .body, weight: .semibold))
                Text("Log Dose")
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(medication.displayColor.gradient)
                    .glassEffect(.regular.tint(medication.displayColor.opacity(0.2)).interactive(true))
                    .shadow(color: medication.displayColor.opacity(0.3), radius: 12, y: 6)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: cardMaxWidth)
        .padding(.horizontal, isRegularWidth ? 32 : 20)
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

    private func lastDoseDate() -> Date? {
        let events = DataStore.shared.events
            .filter { $0.medication?.id == medication.id }
            .sorted { $0.date > $1.date }
        return events.first?.date
    }

    private func statusIndicators() -> [StatusIndicator] {
        var indicators: [StatusIndicator] = []

        // Low supply warning
        if let quantity = medication.quantity {
            if quantity < 10 {
                indicators.append(StatusIndicator(
                    icon: .exclamationmarkTriangle,
                    text: "Low Supply",
                    color: .red
                ))
            } else if quantity < 30 {
                indicators.append(StatusIndicator(
                    icon: .exclamationmarkTriangle,
                    text: "Supply Low",
                    color: .orange
                ))
            }
        }

        // Refill due soon
        if let nextRefill = medication.nextRefillDate {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextRefill).day ?? 0
            if daysUntil <= 7 && daysUntil >= 0 {
                indicators.append(StatusIndicator(
                    icon: .calendarBadgeClock,
                    text: daysUntil == 0 ? "Refill Due" : "Refill in \(daysUntil)d",
                    color: .orange
                ))
            } else if daysUntil < 0 {
                indicators.append(StatusIndicator(
                    icon: .calendarBadgeExclamationmark,
                    text: "Refill Overdue",
                    color: .red
                ))
            }
        }

        return indicators
    }
}

// MARK: - Supporting Types

struct StatusIndicator: Identifiable {
    let id = UUID()
    let icon: SFSymbol
    let text: String
    let color: Color
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
