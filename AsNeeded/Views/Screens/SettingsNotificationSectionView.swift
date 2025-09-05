// SettingsNotificationSectionView.swift
// Settings section for notification and privacy preferences

import SwiftUI
import SFSafeSymbols

struct SettingsNotificationSectionView: View {
  @StateObject private var notificationManager = NotificationManager.shared
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Notifications & Privacy")
        .font(.headline)
        .fontWeight(.semibold)
      
      VStack(spacing: 12) {
        notificationStatusRow
        
        if notificationManager.authorizationStatus == .authorized {
          privacyToggleRow
        }
      }
      .padding(16)
      .background(Color(.systemGray6))
      .cornerRadius(12)
    }
  }
  
  private var notificationStatusRow: some View {
    HStack(spacing: 12) {
      Image(systemSymbol: notificationStatusIcon)
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(notificationStatusColor)
        .frame(width: 24, height: 24)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Medication Reminders")
          .font(.body)
          .fontWeight(.medium)
        
        Text(notificationStatusText)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      if notificationManager.authorizationStatus == .notDetermined {
        Button("Enable") {
          Task {
            await notificationManager.requestAuthorization()
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      } else if notificationManager.authorizationStatus == .denied {
        Button("Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
  }
  
  @ViewBuilder
  private var privacyToggleRow: some View {
    HStack(spacing: 12) {
      Image(systemSymbol: .textBubble)
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(.accentColor)
        .frame(width: 24, height: 24)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Show Medication Names")
          .font(.body)
          .fontWeight(.medium)
        
        Text("Include medication names in reminder notifications")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Toggle("", isOn: $notificationManager.showMedicationNames)
        .labelsHidden()
    }
  }
  
  private var notificationStatusIcon: SFSymbol {
    switch notificationManager.authorizationStatus {
    case .authorized:
      return .bellBadge
    case .denied:
      return .bellSlash
    case .notDetermined:
      return .bell
    default:
      return .bell
    }
  }
  
  private var notificationStatusColor: Color {
    switch notificationManager.authorizationStatus {
    case .authorized:
      return .green
    case .denied:
      return .red
    case .notDetermined:
      return .orange
    default:
      return .gray
    }
  }
  
  private var notificationStatusText: String {
    switch notificationManager.authorizationStatus {
    case .authorized:
      return "Enabled - you can set medication reminders"
    case .denied:
      return "Disabled - enable in Settings to set reminders"
    case .notDetermined:
      return "Not configured - tap Enable to allow reminders"
    case .provisional:
      return "Provisional access - reminders will be delivered quietly"
    case .ephemeral:
      return "Temporary access - reminders available for this session"
    case .unknown:
      return "Unknown status - check Settings"
    }
  }
}

#Preview {
  SettingsNotificationSectionView()
    .padding()
}