// SettingsNotificationSectionView.swift
// Settings section for notification and privacy preferences

import SwiftUI
import SFSafeSymbols

struct SettingsNotificationSectionView: View {
	@StateObject private var notificationManager = NotificationManager.shared
	@AppStorage("showMedicationNamesInNotifications") private var showMedicationNames: Bool = false
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		// Only show this section if notifications are authorized or not determined
		if notificationManager.authorizationStatus == .authorized ||
		   notificationManager.authorizationStatus == .notDetermined {
			VStack(alignment: .leading, spacing: itemSpacing) {
				Text("Notifications")
					.font(.title2)
					.fontWeight(.semibold)

				VStack(spacing: headerSpacing) {
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
		HStack(spacing: headerSpacing) {
			Image(systemSymbol: .pills)
				.font(.system(.callout, design: .default, weight: .medium))
				.frame(width: iconSize, height: iconSize)
				.foregroundColor(.accentColor)

			VStack(alignment: .leading, spacing: stackItemSpacing) {
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
		.padding(padding)
		.background(Color(.systemBackground))
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius)
				.stroke(Color(.systemGray4), lineWidth: borderWidth)
		)
		.cornerRadius(cornerRadius)
	}

}

#Preview {
  SettingsNotificationSectionView()
    .padding()
}