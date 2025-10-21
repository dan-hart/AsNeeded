// ReminderListView.swift
// SwiftUI view for displaying and managing existing medication reminders

import SwiftUI
import ANModelKit
import SFSafeSymbols
import DHLoggingKit

struct ReminderListView: View {
  let medication: ANMedicationConcept
  @Environment(\.dismiss) private var dismiss
  @Environment(\.fontFamily) private var fontFamily
  @StateObject private var notificationManager = NotificationManager.shared
  private let logger = DHLogger(category: "ReminderListView")

  @State private var reminders: [ReminderDetail] = []
  @State private var isLoading = true
  @State private var showingDeleteConfirm = false
  @State private var reminderToDelete: ReminderDetail?

  @ScaledMetric private var emptyStateSpacing: CGFloat = 16
  @ScaledMetric private var rowSpacing: CGFloat = 8
  @ScaledMetric private var smallSpacing: CGFloat = 4
  
  var body: some View {
    NavigationView {
      Group {
        if isLoading {
          ProgressView("Loading reminders...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reminders.isEmpty {
          emptyStateView
        } else {
          remindersList
        }
      }
      .navigationTitle("Active Reminders")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .close) {
            dismiss()
          }
        }

        if !reminders.isEmpty {
          ToolbarItem(placement: .primaryAction) {
            Button("Clear All") {
              showingDeleteConfirm = true
              reminderToDelete = nil
            }
            .font(.customFont(fontFamily, style: .body))
            .foregroundColor(.red)
          }
        }
      }
      .task {
        await loadReminders()
      }
      .refreshable {
        await loadReminders()
      }
      .alert("Delete Reminder", isPresented: $showingDeleteConfirm) {
        if let reminder = reminderToDelete {
          Button("Delete", role: .destructive) {
            Task {
              await deleteReminder(reminder)
            }
          }
        } else {
          Button("Clear All", role: .destructive) {
            Task {
              await clearAllReminders()
            }
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        if reminderToDelete != nil {
          Text("Are you sure you want to delete this reminder?")
        } else {
          Text("Are you sure you want to clear all reminders for this medication?")
        }
      }
    }
  }
  
  private var emptyStateView: some View {
    VStack(spacing: emptyStateSpacing) {
      Image(systemSymbol: .bellSlash)
        .font(.largeTitle.weight(.medium))
        .foregroundColor(.secondary)

      Text("No Active Reminders")
        .font(.title2)
        .fontWeight(.semibold)
      
      Text("You haven't set any reminders for \(medication.displayName) yet.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  private var remindersList: some View {
    List {
      ForEach(reminders) { reminder in
        ReminderRow(
          reminder: reminder,
          onDelete: {
            reminderToDelete = reminder
            showingDeleteConfirm = true
          }
        )
      }
    }
  }
  
  private func loadReminders() async {
    logger.debug("Loading reminders for medication: \(medication.displayName)")
    isLoading = true
    
    let reminderDetails = await notificationManager.getReminderDetails(for: medication)
    await MainActor.run {
      self.reminders = reminderDetails
      self.isLoading = false
    }
    logger.info("Loaded \(reminderDetails.count) reminders")
  }
  
  private func deleteReminder(_ reminder: ReminderDetail) async {
    logger.info("Deleting reminder: \(reminder.id)")
    
    await notificationManager.cancelSpecificReminder(withIdentifier: reminder.id)
    await loadReminders()
    
    logger.info("Reminder deleted successfully")
  }
  
  private func clearAllReminders() async {
    logger.info("Clearing all reminders for medication: \(medication.displayName)")
    
    await notificationManager.cancelReminder(for: medication)
    await loadReminders()
    
    logger.info("All reminders cleared successfully")
  }
}

struct ReminderRow: View {
  let reminder: ReminderDetail
  let onDelete: () -> Void

  @ScaledMetric private var rowSpacing: CGFloat = 8
  @ScaledMetric private var smallSpacing: CGFloat = 4
  @ScaledMetric private var rowVerticalPadding: CGFloat = 4

  var body: some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      HStack {
        VStack(alignment: .leading, spacing: smallSpacing) {
          Text(reminder.title)
            .font(.headline)
            .lineLimit(1)
          
          if !reminder.body.isEmpty {
            Text(reminder.body)
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }
        }
        
        Spacer()
        
        Button {
          onDelete()
        } label: {
          Image(systemSymbol: .trash)
            .foregroundColor(.red)
        }
        .buttonStyle(.plain)
      }
      
      HStack {
        Label {
          Text(nextFireText)
            .font(.caption)
            .foregroundColor(.secondary)
        } icon: {
          Image(systemSymbol: .clock)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        if reminder.isRepeating {
          Label {
            Text(reminder.repeatInfo ?? "Recurring")
              .font(.caption)
              .foregroundColor(.secondary)
          } icon: {
            Image(systemSymbol: .repeat)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding(.vertical, rowVerticalPadding)
  }
  
  private var nextFireText: String {
    let calendar = Calendar.current
    let now = Date()
    
    if calendar.isDate(reminder.nextFireDate, inSameDayAs: now) {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      return "Today at \(formatter.string(from: reminder.nextFireDate))"
    } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              calendar.isDate(reminder.nextFireDate, inSameDayAs: tomorrow) {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      return "Tomorrow at \(formatter.string(from: reminder.nextFireDate))"
    } else if calendar.isDate(reminder.nextFireDate, equalTo: now, toGranularity: .weekOfYear) {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE 'at' h:mm a"
      return formatter.string(from: reminder.nextFireDate)
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMM d 'at' h:mm a"
      return formatter.string(from: reminder.nextFireDate)
    }
  }
}

#Preview {
  ReminderListView(
    medication: ANMedicationConcept(
      clinicalName: "Albuterol",
      nickname: "Inhaler"
    )
  )
}