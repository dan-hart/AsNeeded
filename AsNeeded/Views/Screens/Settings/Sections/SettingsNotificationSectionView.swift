// SettingsNotificationSectionView.swift
// Settings section for notification and privacy preferences

import SwiftUI
import SFSafeSymbols

struct SettingsNotificationSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	@StateObject private var notificationManager = NotificationManager.shared
	@AppStorage(UserDefaultsKeys.showMedicationNamesInNotifications) private var showMedicationNames: Bool = false
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12
	private let stackItemSpacing: CGFloat = 2
	private let iconSize: CGFloat = 24
	private let padding: CGFloat = 16
	private let cornerRadius: CGFloat = 12
	private let borderWidth: CGFloat = 0.5

	var body: some View {
		// Only show this section if notifications are authorized or not determined
		if notificationManager.authorizationStatus == .authorized ||
		   notificationManager.authorizationStatus == .notDetermined {
			VStack(alignment: .leading, spacing: itemSpacing) {
				Text("Notifications")
					.font(.customFont(fontFamily, style: .title2))
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
				.font(.callout.weight(.medium))
				.frame(width: iconSize, height: iconSize)
				.foregroundColor(.accent)

			VStack(alignment: .leading, spacing: stackItemSpacing) {
				Text("Show Medication Names")
					.font(.customFont(fontFamily, style: .body))
					.fontWeight(.medium)

				Text("Display medication names in reminders")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.secondary)
			}

			Spacer()

			Toggle("Show Medication Names", isOn: $showMedicationNames)
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
