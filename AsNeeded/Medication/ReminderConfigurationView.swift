// ReminderConfigurationView.swift
// SwiftUI view for configuring medication reminders

import ANModelKit
import DHLoggingKit
import SFSafeSymbols
import SwiftUI
import UserNotifications

struct ReminderConfigurationView: View {
    let medication: ANMedicationConcept
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var notificationManager = NotificationManager.shared
    private let logger = DHLogger(category: "ReminderConfigurationView")

    @State private var reminderType: ReminderType = .oneTime
    @State private var reminderDate = Date()
    @State private var selectedDays: Set<Int> = []
    @State private var selectedTimes: [Date] = [Date()]
    @State private var showingPermissionAlert = false
    @State private var isScheduling = false
    @State private var showingError = false
    @State private var errorMessage = ""

    @ScaledMetric private var contentSpacing: CGFloat = 24
    @ScaledMetric private var headerVerticalPadding: CGFloat = 8
    @ScaledMetric private var sectionSpacing: CGFloat = 16
    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var cardCornerRadius: CGFloat = 16
    @ScaledMetric private var gridSpacing: CGFloat = 12
    @ScaledMetric private var typeCardSpacing: CGFloat = 8
    @ScaledMetric private var typeCardVerticalPadding: CGFloat = 16
    @ScaledMetric private var typeCardHorizontalPadding: CGFloat = 8
    @ScaledMetric private var typeCardCornerRadius: CGFloat = 12
    @ScaledMetric private var typeBorderWidth: CGFloat = 1
    @ScaledMetric private var dayButtonPadding: CGFloat = 12
    @ScaledMetric private var dayButtonCornerRadius: CGFloat = 10
    @ScaledMetric private var dayCircleSize: CGFloat = 6
    @ScaledMetric private var dayBorderWidth: CGFloat = 2
    @ScaledMetric private var quickButtonSpacing: CGFloat = 4
    @ScaledMetric private var statusHorizontalPadding: CGFloat = 12
    @ScaledMetric private var statusVerticalPadding: CGFloat = 8
    @ScaledMetric private var statusCornerRadius: CGFloat = 8
    @ScaledMetric private var buttonVerticalPadding: CGFloat = 12
    @ScaledMetric private var buttonCornerRadius: CGFloat = 12
    @ScaledMetric private var scheduleButtonPadding: CGFloat = 16
    @ScaledMetric private var scheduleButtonCornerRadius: CGFloat = 14
    @ScaledMetric private var scheduleButtonShadowRadius: CGFloat = 8
    @ScaledMetric private var scheduleButtonShadowY: CGFloat = 4

    enum ReminderType: String, CaseIterable {
        case oneTime = "One Time"
        case daily = "Daily"
        case weekly = "Weekly"
        case custom = "Custom Days"

        var systemImage: SFSymbol {
            switch self {
            case .oneTime: return .clock
            case .daily: return .calendarCircle
            case .weekly: return .calendar
            case .custom: return .calendarBadgePlus
            }
        }

        var description: String {
            switch self {
            case .oneTime: return "Set a single reminder"
            case .daily: return "Remind me every day"
            case .weekly: return "Remind me weekly"
            case .custom: return "Choose specific days"
            }
        }
    }

    private let weekdays = [
        (1, "Sunday", "Sun"),
        (2, "Monday", "Mon"),
        (3, "Tuesday", "Tue"),
        (4, "Wednesday", "Wed"),
        (5, "Thursday", "Thu"),
        (6, "Friday", "Fri"),
        (7, "Saturday", "Sat"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: contentSpacing) {
                    // MARK: - Header Section

                    headerSection

                    // MARK: - Permission Section

                    if !canScheduleReminders {
                        notificationPermissionCard
                    } else {
                        // MARK: - Reminder Type Selection

                        reminderTypeCard

                        // MARK: - Configuration Section

                        reminderConfigurationCard

                        // MARK: - Schedule Button

                        scheduleButton
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .customNavigationTitle("Schedule Reminder")
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
            .tint(.accent)
            .disabled(isScheduling)
            .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to set medication reminders.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .font(.customFont(fontFamily, style: .body))
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: headerVerticalPadding) {
            Image(systemSymbol: .bellBadgeFill)
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accent, .accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(medication.displayName)
                .font(.customFont(fontFamily, style: .callout))
                .foregroundStyle(.secondary)
                .noTruncate()

			Text("Choose a date or repeating schedule. These reminders are separate from optional next-dose alerts.")
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, headerVerticalPadding)
    }

    @ViewBuilder
    private var notificationPermissionCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Image(systemSymbol: notificationManager.authorizationStatus == .denied ? .bellSlash : .bellBadge)
                    .font(.customFont(fontFamily, style: .title2))
                    .foregroundStyle(notificationManager.authorizationStatus == .denied ? .red : .accent)

                VStack(alignment: .leading, spacing: quickButtonSpacing) {
                    Text(notificationManager.authorizationStatus == .denied ? "Notifications Disabled" : "Notifications Required")
                        .font(.customFont(fontFamily, style: .headline))

                    Text(notificationManager.authorizationStatus == .denied ?
                        "Enable notifications in Settings to set reminders." :
                        "To set medication reminders, enable notifications.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                if notificationManager.authorizationStatus == .denied {
                    showingPermissionAlert = true
                } else {
                    Task {
                        _ = await notificationManager.requestAuthorization()
                    }
                }
            } label: {
                HStack {
                    Image(systemSymbol: notificationManager.authorizationStatus == .denied ? .gear : .bellBadgeFill)
                    Text(notificationManager.authorizationStatus == .denied ? "Open Settings" : "Enable Notifications")
                }
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, buttonVerticalPadding)
                .background(
                    notificationManager.authorizationStatus == .denied ?
                        Color(.systemGray5) : .accent
                )
                .foregroundColor(
                    notificationManager.authorizationStatus == .denied ?
                        .primary : .white
                )
                .cornerRadius(buttonCornerRadius)
            }
            .buttonStyle(.plain)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var reminderTypeCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Text("Repeat")
                .font(.customFont(fontFamily, style: .caption))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: reminderTypeColumns, spacing: gridSpacing) {
                ForEach(ReminderType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                            reminderType = type
                        }
                    } label: {
                        VStack(spacing: typeCardSpacing) {
                            Image(systemSymbol: type.systemImage)
                                .font(.customFont(fontFamily, style: .title2))
                                .foregroundStyle(reminderType == type ? .white : .accent)

                            Text(type.rawValue)
                                .font(.customFont(fontFamily, style: .subheadline))
                                .fontWeight(.medium)
                                .foregroundStyle(reminderType == type ? .white : .primary)

                            Text(type.description)
                                .font(.customFont(fontFamily, style: .caption2))
                                .foregroundStyle(reminderType == type ? .white.opacity(0.8) : .secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, typeCardVerticalPadding)
                        .padding(.horizontal, typeCardHorizontalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: typeCardCornerRadius)
                                .fill(reminderType == type ?
                                    LinearGradient(
                                        colors: [.accent, .accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color(.tertiarySystemGroupedBackground), Color(.tertiarySystemGroupedBackground)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: typeCardCornerRadius)
                                .strokeBorder(
                                    reminderType == type ? Color.clear : Color(.separator).opacity(0.3),
                                    lineWidth: typeBorderWidth
                                )
                        )
                    }
                    .buttonStyle(.plain)
					.accessibilityLabel(type.rawValue)
					.accessibilityHint(type.description)
					.accessibilityAddTraits(reminderType == type ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private var reminderConfigurationCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Text("Schedule")
                .font(.customFont(fontFamily, style: .caption))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: sectionSpacing) {
                switch reminderType {
                case .oneTime:
                    dateTimePickerCard(
                        title: "Date & Time",
                        selection: $reminderDate,
                        dateRange: Date()...,
                        components: [.date, .hourAndMinute],
                        icon: .calendarBadgeClock
                    )

                case .daily:
                    dateTimePickerCard(
                        title: "Daily Time",
                        selection: $reminderDate,
                        dateRange: nil,
                        components: .hourAndMinute,
                        icon: .clock
                    )

                case .weekly:
                    VStack(spacing: gridSpacing) {
                        dateTimePickerCard(
                            title: "Starting Date & Time",
                            selection: $reminderDate,
                            dateRange: Date()...,
                            components: [.date, .hourAndMinute],
                            icon: .calendarBadgeClock
                        )

                        HStack {
                            Image(systemSymbol: .repeat)
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundColor(.accent)
                            Text("Repeats every \(dayOfWeekString(from: reminderDate))")
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, statusHorizontalPadding)
                        .padding(.vertical, statusVerticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: statusCornerRadius)
                                .fill(.accent.opacity(0.1))
                        )
                    }

                case .custom:
                    VStack(spacing: sectionSpacing) {
                        // Days Selection
                        VStack(alignment: .leading, spacing: gridSpacing) {
                            HStack {
                                Image(systemSymbol: .calendarBadgePlus)
                                    .foregroundColor(.accent)
                                Text("Select Days")
                                    .font(.customFont(fontFamily, style: .subheadline))
                                    .fontWeight(.semibold)
                            }

                            LazyVGrid(columns: weekdayColumns, spacing: headerVerticalPadding) {
                                ForEach(weekdays, id: \.0) { day in
                                    Button {
                                        withAnimation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8)) {
                                            if selectedDays.contains(day.0) {
                                                selectedDays.remove(day.0)
                                            } else {
                                                selectedDays.insert(day.0)
                                            }
                                        }
                                    } label: {
                                        VStack(spacing: quickButtonSpacing) {
                                            Text(dynamicTypeSize.isAccessibilitySize ? day.1 : day.2)
                                                .font(.customFont(fontFamily, style: .caption2))
                                                .fontWeight(.semibold)

                                            Circle()
                                                .fill(selectedDays.contains(day.0) ? .accent : Color(.systemGray5))
                                                .frame(width: dayCircleSize, height: dayCircleSize)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 44)
                                        .padding(.vertical, dayButtonPadding)
                                        .background(
                                            RoundedRectangle(cornerRadius: dayButtonCornerRadius)
                                                .fill(selectedDays.contains(day.0) ?
                                                    .accent.opacity(0.15) :
                                                    Color(.tertiarySystemGroupedBackground)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: dayButtonCornerRadius)
                                                .strokeBorder(
                                                    selectedDays.contains(day.0) ?
                                                        .accent :
                                                        Color(.separator).opacity(0.2),
                                                    lineWidth: selectedDays.contains(day.0) ? dayBorderWidth : typeBorderWidth
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
									.accessibilityLabel(day.1)
									.accessibilityAddTraits(selectedDays.contains(day.0) ? .isSelected : [])
                                }
                            }
                        }

                        // Time Selection
                        dateTimePickerCard(
                            title: "Time for Selected Days",
                            selection: $reminderDate,
                            dateRange: nil,
                            components: .hourAndMinute,
                            icon: .clock
                        )

                        if !selectedDays.isEmpty {
                            HStack {
                                Image(systemSymbol: .checkmarkCircleFill)
                                    .font(.customFont(fontFamily, style: .caption))
                                    .foregroundColor(.green)
                                Text("\(selectedDays.count) day\(selectedDays.count == 1 ? "" : "s") selected")
                                    .font(.customFont(fontFamily, style: .caption))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, statusHorizontalPadding)
                            .padding(.vertical, statusVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: statusCornerRadius)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                    }
                }
            }
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func dateTimePickerCard(
        title: String,
        selection: Binding<Date>,
        dateRange: PartialRangeFrom<Date>?,
        components: DatePickerComponents,
        icon: SFSymbol
    ) -> some View {
        VStack(alignment: .leading, spacing: headerVerticalPadding) {
            HStack {
                Image(systemSymbol: icon)
                    .foregroundColor(.accent)
                Text(title)
                    .font(.customFont(fontFamily, style: .subheadline))
                    .fontWeight(.medium)
            }

            if let dateRange = dateRange {
                DatePicker(
                    title,
                    selection: selection,
                    in: dateRange,
                    displayedComponents: components
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(minHeight: 44)
                .tint(.accent)
            } else {
                DatePicker(
                    title,
                    selection: selection,
                    displayedComponents: components
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(minHeight: 44)
                .tint(.accent)
            }
        }
    }

    private var scheduleButton: some View {
        Button {
            Task {
                await scheduleReminder()
            }
        } label: {
            HStack {
                if isScheduling {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemSymbol: .bellBadgeFill)
                        .font(.customFont(fontFamily, style: .headline))
                }
                Text("Schedule Reminder")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, scheduleButtonPadding)
            .background(
                LinearGradient(
                    colors: buttonDisabled ?
                        [Color(.systemGray3), Color(.systemGray4)] :
                        [.accent, .accent.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(scheduleButtonCornerRadius)
            .shadow(
                color: buttonDisabled ? .clear : .accent.opacity(0.3),
                radius: scheduleButtonShadowRadius,
                y: scheduleButtonShadowY
            )
        }
        .buttonStyle(.plain)
        .disabled(buttonDisabled)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: buttonDisabled)
    }

    private var buttonDisabled: Bool {
        isScheduling ||
            !canScheduleReminders ||
            (reminderType == .custom && selectedDays.isEmpty)
    }

    // MARK: - Helper Functions
	private var reminderTypeColumns: [GridItem] {
		Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
	}

	private var weekdayColumns: [GridItem] {
		[GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 140 : 64), spacing: headerVerticalPadding)]
	}

	private var canScheduleReminders: Bool {
		switch notificationManager.authorizationStatus {
		case .authorized, .provisional, .ephemeral:
			return true
		default:
			return false
		}
	}

    private func scheduleReminder() async {
        isScheduling = true
        defer { isScheduling = false }

        logger.info("Scheduling medication reminder")

        do {
            switch reminderType {
            case .oneTime:
                try await notificationManager.scheduleReminder(
                    for: medication,
                    date: reminderDate,
                    isRecurring: false
                )

            case .daily:
                let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
                try await notificationManager.scheduleReminder(
                    for: medication,
                    date: reminderDate,
                    isRecurring: true,
                    repeatInterval: dateComponents
                )

            case .weekly:
                let dateComponents = Calendar.current.dateComponents([.weekday, .hour, .minute], from: reminderDate)
                try await notificationManager.scheduleReminder(
                    for: medication,
                    date: reminderDate,
                    isRecurring: true,
                    repeatInterval: dateComponents
                )

            case .custom:
                for weekday in selectedDays {
                    var dateComponents = DateComponents()
                    dateComponents.weekday = weekday
                    dateComponents.hour = Calendar.current.component(.hour, from: reminderDate)
                    dateComponents.minute = Calendar.current.component(.minute, from: reminderDate)

                    // Find next occurrence of this weekday
                    let nextDate = Calendar.current.nextDate(
                        after: Date(),
                        matching: dateComponents,
                        matchingPolicy: .nextTime
                    ) ?? Date()

                    try await notificationManager.scheduleReminder(
                        for: medication,
                        date: nextDate,
                        isRecurring: true,
                        repeatInterval: dateComponents
                    )
                }
            }

            logger.info("Reminder scheduled successfully")
            dismiss()

        } catch {
            logger.logPrivacySafeError("Failed to schedule reminder", error: error)
            errorMessage = "Failed to schedule reminder: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func dayOfWeekString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

#Preview {
    ReminderConfigurationView(
        medication: ANMedicationConcept(
            clinicalName: "Albuterol",
            nickname: "Inhaler"
        )
    )
}
