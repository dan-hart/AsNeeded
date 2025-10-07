// SettingsHealthKitSectionView.swift
// HealthKit section for main Settings view.

import SwiftUI
import SFSafeSymbols

/// HealthKit section component for main Settings view
struct SettingsHealthKitSectionView: View {
	@StateObject private var syncManager = HealthKitSyncManager.shared
	@Environment(\.fontFamily) private var fontFamily
	@ScaledMetric private var sectionSpacing: CGFloat = 16

	var body: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			// Section header
			Label("HealthKit Sync", systemSymbol: .heartTextSquareFill)
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))
				.foregroundColor(.accent)

			// Description
			Text("Sync your medication data with Apple Health for seamless tracking across devices.")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundColor(.secondary)

			// Status card or onboarding
			if syncManager.isSyncEnabled && syncManager.authorizationStatus == .authorized {
				connectedStatusCard
			} else {
				onboardingCard
			}
		}
	}

	// MARK: - Connected Status Card
	@ViewBuilder
	private var connectedStatusCard: some View {
		NavigationLink(destination: HealthKitSettingsView()) {
			SettingsRowComponent(
				icon: .checkmarkCircleFill,
				title: "Connected",
				subtitle: syncStatusText,
				iconColor: .green,
				action: {}
			)
		}
		.buttonStyle(.plain)
	}

	// MARK: - Onboarding Card
	@ViewBuilder
	private var onboardingCard: some View {
		if syncManager.authorizationStatus == .notAvailable {
			// HealthKit not available on this device
			#if DEBUG
			// In DEBUG builds, allow navigation to diagnostics screen
			NavigationLink(destination: HealthKitSettingsView()) {
				SettingsRowComponent(
					icon: .exclamationmarkTriangleFill,
					title: "Not Available (Tap for Diagnostics)",
					subtitle: "HealthKit is not available on this device",
					iconColor: .orange,
					action: {}
				)
			}
			.buttonStyle(.plain)
			#else
			// In RELEASE builds, show non-interactive row
			SettingsRowComponent(
				icon: .exclamationmarkTriangleFill,
				title: "Not Available",
				subtitle: "HealthKit is not available on this device",
				iconColor: .orange,
				action: {}
			)
			#endif
		} else {
			// Connect CTA
			NavigationLink(destination: HealthKitSettingsView()) {
				SettingsRowComponent(
					icon: .heartFill,
					title: "Connect to Apple Health",
					subtitle: "Enable HealthKit sync",
					iconColor: .pink,
					action: {}
				)
			}
			.buttonStyle(.plain)
		}
	}

	// MARK: - Computed Properties
	private var syncStatusText: String {
		guard let syncMode = syncManager.currentSyncMode else {
			return "Sync enabled"
		}

		let modeText = syncMode.displayName

		if let lastSync = syncManager.lastSyncDate {
			let formatter = RelativeDateTimeFormatter()
			formatter.unitsStyle = .abbreviated
			let timeText = formatter.localizedString(for: lastSync, relativeTo: Date())
			return "\(modeText) • Last: \(timeText)"
		} else {
			return modeText
		}
	}
}

#if DEBUG
#Preview("Connected") {
	VStack(spacing: 32) {
		SettingsHealthKitSectionView()
		Spacer()
	}
	.padding()
}
#endif
