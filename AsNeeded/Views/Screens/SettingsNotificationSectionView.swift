// SettingsNotificationSectionView.swift
// Settings section for notification and privacy preferences

import SwiftUI
import SFSafeSymbols

struct SettingsNotificationSectionView: View {
  @StateObject private var notificationManager = NotificationManager.shared
  @AppStorage("showMedicationNamesInNotifications") private var showMedicationNames: Bool = false
  
  var body: some View {
    // Only show this section if notifications are authorized or not determined
    if notificationManager.authorizationStatus == .authorized || 
       notificationManager.authorizationStatus == .notDetermined {
      VStack(alignment: .leading, spacing: 16) {
        Text("Notifications")
          .font(.title2)
          .fontWeight(.semibold)
        
        VStack(spacing: 12) {
          medicationNamesToggle
        }
      }
      .onAppear {
        // Sync the initial value from NotificationManager
        showMedicationNames = notificationManager.showMedicationNames
      }
    }
  }
  
  
  @ViewBuilder
  private var medicationNamesToggle: some View {
    HStack(spacing: 12) {
      Image(systemSymbol: .pills)
        .font(.system(size: 18, weight: .medium))
        .frame(width: 24, height: 24)
        .foregroundColor(.accentColor)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Show Medication Names")
          .font(.body)
          .fontWeight(.medium)
        
        Text("Display medication names in reminders")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Toggle("", isOn: $showMedicationNames)
        .labelsHidden()
        .onChange(of: showMedicationNames) { _, newValue in
          notificationManager.showMedicationNames = newValue
        }
    }
    .padding(16)
    .background(Color(.systemBackground))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray4), lineWidth: 0.5)
    )
    .cornerRadius(12)
  }
  
}

#Preview {
  SettingsNotificationSectionView()
    .padding()
}