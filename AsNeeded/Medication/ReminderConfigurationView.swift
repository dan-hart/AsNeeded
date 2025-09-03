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
  }
  
  private let weekdays = [
    (1, "Sunday"),
    (2, "Monday"),
    (3, "Tuesday"),
    (4, "Wednesday"),
    (5, "Thursday"),
    (6, "Friday"),
    (7, "Saturday")
  ]
  
  var body: some View {
    NavigationView {
      Form {
        notificationPermissionSection
        
        if notificationManager.authorizationStatus == .authorized {
          reminderTypeSection
          
          reminderConfigurationSection
          
          scheduleButtonSection
        }
      }
      .navigationTitle("Set Reminder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
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
  
  @ViewBuilder
  private var notificationPermissionSection: some View {
    if notificationManager.authorizationStatus == .notDetermined {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Label("Notifications Required", systemSymbol: .bellBadge)
            .font(.headline)
          
          Text("To set medication reminders, you need to enable notifications.")
            .font(.caption)
            .foregroundStyle(.secondary)
          
          Button {
            Task {
              _ = await notificationManager.requestAuthorization()
            }
          } label: {
            Text("Enable Notifications")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
      }
    } else if notificationManager.authorizationStatus == .denied {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Label("Notifications Disabled", systemSymbol: .bellSlash)
            .font(.headline)
            .foregroundStyle(.red)
          
          Text("Notifications are disabled. Enable them in Settings to set reminders.")
            .font(.caption)
            .foregroundStyle(.secondary)
          
          Button {
            showingPermissionAlert = true
          } label: {
            Text("Open Settings")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
      }
    }
  }
  
  private var reminderTypeSection: some View {
    Section("Reminder Type") {
      Picker("Type", selection: $reminderType) {
        ForEach(ReminderType.allCases, id: \.self) { type in
          Label(type.rawValue, systemSymbol: type.systemImage)
            .tag(type)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
    }
  }
  
  @ViewBuilder
  private var reminderConfigurationSection: some View {
    Section("Schedule") {
      switch reminderType {
      case .oneTime:
        DatePicker(
          "Date & Time",
          selection: $reminderDate,
          in: Date()...,
          displayedComponents: [.date, .hourAndMinute]
        )
        
      case .daily:
        DatePicker(
          "Time",
          selection: $reminderDate,
          displayedComponents: .hourAndMinute
        )
        
      case .weekly:
        DatePicker(
          "Day & Time",
          selection: $reminderDate,
          in: Date()...,
          displayedComponents: [.date, .hourAndMinute]
        )
        Text("Repeats every week on \(dayOfWeekString(from: reminderDate))")
          .font(.caption)
          .foregroundStyle(.secondary)
        
      case .custom:
        VStack(alignment: .leading, spacing: 12) {
          Text("Select Days")
            .font(.subheadline)
            .fontWeight(.medium)
          
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            ForEach(weekdays, id: \.0) { day in
              Button {
                if selectedDays.contains(day.0) {
                  selectedDays.remove(day.0)
                } else {
                  selectedDays.insert(day.0)
                }
              } label: {
                Text(String(day.1.prefix(3)))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 8)
                  .background(selectedDays.contains(day.0) ? Color.accentColor : Color(.systemGray5))
                  .foregroundColor(selectedDays.contains(day.0) ? .white : .primary)
                  .cornerRadius(8)
              }
              .buttonStyle(.plain)
            }
          }
          
          DatePicker(
            "Time",
            selection: $reminderDate,
            displayedComponents: .hourAndMinute
          )
        }
      }
    }
  }
  
  private var scheduleButtonSection: some View {
    Section {
      Button {
        Task {
          await scheduleReminder()
        }
      } label: {
        HStack {
          if isScheduling {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Image(systemSymbol: .bellBadge)
          }
          Text("Schedule Reminder")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(
        isScheduling ||
        notificationManager.authorizationStatus != .authorized ||
        (reminderType == .custom && selectedDays.isEmpty)
      )
    }
  }
  
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