// ReminderConfigurationView.swift
// SwiftUI view for configuring medication reminders

import SwiftUI
import ANModelKit
import SFSafeSymbols
import UserNotifications
import DHLoggingKit

struct ReminderConfigurationView: View {
	let medication: ANMedicationConcept
	@Environment(\.dismiss) private var dismiss
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
		(7, "Saturday", "Sat")
	]
	
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 24) {
					// MARK: - Header Section
					headerSection
					
					// MARK: - Permission Section
					if notificationManager.authorizationStatus != .authorized {
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
			.navigationTitle("Set Reminder")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(action: { dismiss() }) {
						Image(systemSymbol: .xmark)
							.fontWeight(.medium)
					}
				}
			}
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
			.onChange(of: notificationManager.authorizationStatus) { _, newStatus in
				if newStatus == .denied {
					dismiss()
				}
			}
		}
	}
	
	// MARK: - View Components
	private var headerSection: some View {
		VStack(spacing: 8) {
			Image(systemSymbol: .bellBadgeFill)
				.font(.largeTitle)
				.foregroundStyle(
					LinearGradient(
						colors: [.accentColor, .accentColor.opacity(0.7)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
			
			Text("Schedule Reminder")
				.font(.title2)
				.fontWeight(.bold)
			
			Text(medication.displayName)
				.font(.callout)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 8)
	}
	
	@ViewBuilder
	private var notificationPermissionCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Image(systemSymbol: notificationManager.authorizationStatus == .denied ? .bellSlash : .bellBadge)
					.font(.title2)
					.foregroundStyle(notificationManager.authorizationStatus == .denied ? .red : .accentColor)
				
				VStack(alignment: .leading, spacing: 4) {
					Text(notificationManager.authorizationStatus == .denied ? "Notifications Disabled" : "Notifications Required")
						.font(.headline)
					
					Text(notificationManager.authorizationStatus == .denied ? 
						"Enable notifications in Settings to set reminders." : 
						"To set medication reminders, enable notifications.")
						.font(.caption)
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
				.padding(.vertical, 12)
				.background(
					notificationManager.authorizationStatus == .denied ? 
					Color(.systemGray5) : Color.accentColor
				)
				.foregroundColor(
					notificationManager.authorizationStatus == .denied ? 
					.primary : .white
				)
				.cornerRadius(12)
			}
			.buttonStyle(.plain)
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(Color(.secondarySystemGroupedBackground))
		)
	}
	
	private var reminderTypeCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("REMINDER TYPE")
				.font(.caption)
				.fontWeight(.semibold)
				.foregroundStyle(.secondary)
			
			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
				ForEach(ReminderType.allCases, id: \.self) { type in
					Button {
						withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
							reminderType = type
						}
					} label: {
						VStack(spacing: 8) {
							Image(systemSymbol: type.systemImage)
								.font(.title2)
								.foregroundStyle(reminderType == type ? .white : .accentColor)
							
							Text(type.rawValue)
								.font(.subheadline)
								.fontWeight(.medium)
								.foregroundStyle(reminderType == type ? .white : .primary)
							
							Text(type.description)
								.font(.caption2)
								.foregroundStyle(reminderType == type ? .white.opacity(0.8) : .secondary)
								.multilineTextAlignment(.center)
								.lineLimit(2)
						}
						.frame(maxWidth: .infinity)
						.padding(.vertical, 16)
						.padding(.horizontal, 8)
						.background(
							RoundedRectangle(cornerRadius: 12)
								.fill(reminderType == type ? 
									LinearGradient(
										colors: [.accentColor, .accentColor.opacity(0.8)],
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
							RoundedRectangle(cornerRadius: 12)
								.strokeBorder(
									reminderType == type ? Color.clear : Color(.separator).opacity(0.3),
									lineWidth: 1
								)
						)
					}
					.buttonStyle(.plain)
				}
			}
		}
	}
	
	@ViewBuilder
	private var reminderConfigurationCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("SCHEDULE")
				.font(.caption)
				.fontWeight(.semibold)
				.foregroundStyle(.secondary)
			
			VStack(spacing: 16) {
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
					VStack(spacing: 12) {
						dateTimePickerCard(
							title: "Starting Date & Time",
							selection: $reminderDate,
							dateRange: Date()...,
							components: [.date, .hourAndMinute],
							icon: .calendarBadgeClock
						)
						
						HStack {
							Image(systemSymbol: .repeat)
								.font(.caption)
								.foregroundColor(.accentColor)
							Text("Repeats every \(dayOfWeekString(from: reminderDate))")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						.padding(.horizontal, 12)
						.padding(.vertical, 8)
						.background(
							RoundedRectangle(cornerRadius: 8)
								.fill(Color.accentColor.opacity(0.1))
						)
					}
					
				case .custom:
					VStack(spacing: 16) {
						// Days Selection
						VStack(alignment: .leading, spacing: 12) {
							HStack {
								Image(systemSymbol: .calendarBadgePlus)
									.foregroundColor(.accentColor)
								Text("Select Days")
									.font(.subheadline)
									.fontWeight(.semibold)
							}
							
							HStack(spacing: 8) {
								ForEach(weekdays, id: \.0) { day in
									Button {
										withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
											if selectedDays.contains(day.0) {
												selectedDays.remove(day.0)
											} else {
												selectedDays.insert(day.0)
											}
										}
									} label: {
										VStack(spacing: 4) {
											Text(day.2)
												.font(.caption2)
												.fontWeight(.semibold)
											
											Circle()
												.fill(selectedDays.contains(day.0) ? Color.accentColor : Color(.systemGray5))
												.frame(width: 6, height: 6)
										}
										.frame(maxWidth: .infinity)
										.padding(.vertical, 12)
										.background(
											RoundedRectangle(cornerRadius: 10)
												.fill(selectedDays.contains(day.0) ? 
													Color.accentColor.opacity(0.15) : 
													Color(.tertiarySystemGroupedBackground)
												)
										)
										.overlay(
											RoundedRectangle(cornerRadius: 10)
												.strokeBorder(
													selectedDays.contains(day.0) ? 
													Color.accentColor : 
													Color(.separator).opacity(0.2),
													lineWidth: selectedDays.contains(day.0) ? 2 : 1
												)
										)
									}
									.buttonStyle(.plain)
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
									.font(.caption)
									.foregroundColor(.green)
								Text("\(selectedDays.count) day\(selectedDays.count == 1 ? "" : "s") selected")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.padding(.horizontal, 12)
							.padding(.vertical, 8)
							.background(
								RoundedRectangle(cornerRadius: 8)
									.fill(Color.green.opacity(0.1))
							)
						}
					}
				}
			}
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 16)
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
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Image(systemSymbol: icon)
					.foregroundColor(.accentColor)
				Text(title)
					.font(.subheadline)
					.fontWeight(.medium)
			}
			
			if let dateRange = dateRange {
				DatePicker(
					"",
					selection: selection,
					in: dateRange,
					displayedComponents: components
				)
				.labelsHidden()
				.datePickerStyle(.compact)
				.tint(.accentColor)
			} else {
				DatePicker(
					"",
					selection: selection,
					displayedComponents: components
				)
				.labelsHidden()
				.datePickerStyle(.compact)
				.tint(.accentColor)
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
						.font(.headline)
				}
				Text("Schedule Reminder")
					.fontWeight(.semibold)
			}
			.foregroundColor(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
			.background(
				LinearGradient(
					colors: buttonDisabled ? 
					[Color(.systemGray3), Color(.systemGray4)] :
					[.accentColor, .accentColor.opacity(0.8)],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.cornerRadius(14)
			.shadow(
				color: buttonDisabled ? .clear : .accentColor.opacity(0.3),
				radius: 8,
				y: 4
			)
		}
		.buttonStyle(.plain)
		.disabled(buttonDisabled)
		.animation(.easeInOut(duration: 0.2), value: buttonDisabled)
	}
	
	private var buttonDisabled: Bool {
		isScheduling ||
		notificationManager.authorizationStatus != .authorized ||
		(reminderType == .custom && selectedDays.isEmpty)
	}
	
	// MARK: - Helper Functions
	private func scheduleReminder() async {
		isScheduling = true
		defer { isScheduling = false }
		
		logger.info("Scheduling reminder for medication: \(medication.clinicalName)")
		
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
			logger.error("Failed to schedule reminder", error: error)
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