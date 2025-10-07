// HealthKitSettingsView.swift
// Main HealthKit settings hub for managing sync configuration.

import SwiftUI
import SFSafeSymbols

/// Main HealthKit settings and configuration view
struct HealthKitSettingsView: View {
	@Environment(\.fontFamily) private var fontFamily
	@StateObject private var syncManager = HealthKitSyncManager.shared
	@State private var showSyncModeChange = false
	@State private var showAuthorizationFlow = false
	@State private var isSyncing = false
	@State private var lastSyncText = "Never"

	@ScaledMetric private var sectionSpacing: CGFloat = 32
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@ScaledMetric private var iconSize: CGFloat = 24

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				// MARK: - Header
				VStack(alignment: .leading, spacing: 12) {
					Text("Sync your medication data with Apple Health for seamless tracking across all your devices.")
						.font(.customFont(fontFamily, style: .body))
						.foregroundColor(.secondary)
				}
				.padding(.horizontal)
				.padding(.top)

				// MARK: - Status Section
				statusSection

				// MARK: - Sync Mode Section
				if syncManager.isSyncEnabled {
					syncModeSection
				}

				// MARK: - Manual Sync Section
				if syncManager.isSyncEnabled && syncManager.authorizationStatus == .authorized {
					manualSyncSection
				}

				// MARK: - Background Sync Section
				if syncManager.isSyncEnabled && syncManager.authorizationStatus == .authorized {
					backgroundSyncSection
				}

				// MARK: - Connect Section
				if !syncManager.isSyncEnabled || syncManager.authorizationStatus != .authorized {
					connectSection
				}

				// MARK: - Advanced Section
				if syncManager.isSyncEnabled {
					advancedSection
				}

				Spacer(minLength: 24)
			}
			.padding(.vertical)
		}
		.navigationTitle("HealthKit Sync")
		.navigationBarTitleDisplayMode(.large)
		.sheet(isPresented: $showSyncModeChange) {
			HealthKitSyncModeView()
		}
		.sheet(isPresented: $showAuthorizationFlow) {
			HealthKitAuthorizationView()
		}
		.task {
			await updateLastSyncText()
		}
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
			Task {
				await syncManager.updateAuthorizationStatus()
				await updateLastSyncText()
			}
		}
	}

	// MARK: - Status Section
	@ViewBuilder
	private var statusSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Status")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.horizontal)

			settingRow(
				icon: syncManager.authorizationStatus == .authorized ? .heartFill : .heartSlash,
				iconColor: syncManager.authorizationStatus == .authorized ? .pink : .gray,
				title: "Connection Status",
				detail: syncManager.authorizationStatus.displayText
			)

			if syncManager.isSyncEnabled {
				settingRow(
					icon: .clockArrowTriangleheadCounterclockwiseRotate90,
					iconColor: .blue,
					title: "Last Sync",
					detail: lastSyncText
				)
			}
		}
	}

	// MARK: - Sync Mode Section
	@ViewBuilder
	private var syncModeSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Sync Mode")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.horizontal)

			if let currentMode = syncManager.currentSyncMode {
				Button {
					showSyncModeChange = true
				} label: {
					HStack(spacing: 12) {
						Image(systemSymbol: iconForMode(currentMode))
							.font(.callout.weight(.medium))
							.frame(width: iconSize, height: iconSize)
							.foregroundColor(colorForMode(currentMode))

						VStack(alignment: .leading, spacing: 2) {
							Text(currentMode.displayName)
								.font(.customFont(fontFamily, style: .body, weight: .medium))
								.foregroundColor(.primary)

							Text(currentMode.shortDescription)
								.font(.customFont(fontFamily, style: .caption))
								.foregroundColor(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}

						Spacer()

						Image(systemSymbol: .chevronRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding(cardPadding)
					.background(Color(.systemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: cornerRadius)
							.stroke(Color(.systemGray4), lineWidth: borderWidth)
					)
					.cornerRadius(cornerRadius)
				}
				.buttonStyle(.plain)
				.padding(.horizontal)
			}
		}
	}

	// MARK: - Manual Sync Section
	@ViewBuilder
	private var manualSyncSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Manual Sync")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.horizontal)

			Button {
				Task {
					await performSync()
				}
			} label: {
				HStack(spacing: 12) {
					if isSyncing {
						ProgressView()
							.scaleEffect(0.8)
							.frame(width: iconSize, height: iconSize)
					} else {
						Image(systemSymbol: .arrowTriangle2Circlepath)
							.font(.callout.weight(.medium))
							.frame(width: iconSize, height: iconSize)
							.foregroundColor(.accent)
					}

					VStack(alignment: .leading, spacing: 2) {
						Text("Sync Now")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundColor(.primary)

						Text("Manually trigger a sync with HealthKit")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}

					Spacer()

					if !isSyncing {
						Image(systemSymbol: .chevronRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				.padding(cardPadding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.disabled(isSyncing)
			.buttonStyle(.plain)
			.padding(.horizontal)
		}
	}

	// MARK: - Background Sync Section
	@ViewBuilder
	private var backgroundSyncSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Background Sync")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.horizontal)

			Toggle(isOn: Binding(
				get: { UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled) },
				set: { newValue in
					if newValue {
						syncManager.startBackgroundSync()
					} else {
						syncManager.stopBackgroundSync()
					}
				}
			)) {
				HStack(spacing: 12) {
					Image(systemSymbol: .timerCircle)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.green)

					VStack(alignment: .leading, spacing: 2) {
						Text("Automatic Sync")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundColor(.primary)

						Text("Sync automatically every 5 minutes")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}
				}
			}
			.padding(cardPadding)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(Color(.systemGray4), lineWidth: borderWidth)
			)
			.cornerRadius(cornerRadius)
			.padding(.horizontal)
		}
	}

	// MARK: - Connect Section
	@ViewBuilder
	private var connectSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Get Started")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.horizontal)

			Button {
				showAuthorizationFlow = true
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .heartFill)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.pink)

					VStack(alignment: .leading, spacing: 2) {
						Text("Connect to Apple Health")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundColor(.primary)

						Text("Enable HealthKit sync")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(cardPadding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.buttonStyle(.plain)
			.padding(.horizontal)
		}
	}

	// MARK: - Advanced Section
	@ViewBuilder
	private var advancedSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Advanced")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.horizontal)

			NavigationLink(destination: DataManagementView()) {
				settingRow(
					icon: .folderFill,
					iconColor: .orange,
					title: "Data Management",
					detail: "Export, import, and backup"
				)
			}
			.buttonStyle(.plain)

			Button {
				disconnectHealthKit()
			} label: {
				settingRow(
					icon: .linkCircleFill,
					iconColor: .red,
					title: "Disconnect HealthKit",
					detail: "Stop syncing with Apple Health",
					isDestructive: true
				)
			}
			.buttonStyle(.plain)
		}
	}

	// MARK: - Helper Views
	@ViewBuilder
	private func settingRow(
		icon: SFSymbol,
		iconColor: Color,
		title: String,
		detail: String,
		isDestructive: Bool = false
	) -> some View {
		HStack(spacing: 12) {
			Image(systemSymbol: icon)
				.font(.callout.weight(.medium))
				.frame(width: iconSize, height: iconSize)
				.foregroundColor(iconColor)

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.customFont(fontFamily, style: .body, weight: .medium))
					.foregroundColor(isDestructive ? .red : .primary)

				Text(detail)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.secondary)
			}

			Spacer()
		}
		.padding(cardPadding)
		.background(Color(.systemBackground))
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius)
				.stroke(Color(.systemGray4), lineWidth: borderWidth)
		)
		.cornerRadius(cornerRadius)
		.padding(.horizontal)
	}

	// MARK: - Helper Methods
	private func iconForMode(_ mode: HealthKitSyncMode) -> SFSymbol {
		switch mode {
		case .bidirectional:
			return .arrowLeftArrowRightCircleFill
		case .healthKitSOT:
			return .heartCircleFill
		case .asNeededSOT:
			return .appBadgeFill
		}
	}

	private func colorForMode(_ mode: HealthKitSyncMode) -> Color {
		switch mode {
		case .bidirectional:
			return .accent
		case .healthKitSOT:
			return .pink
		case .asNeededSOT:
			return .blue
		}
	}

	private func performSync() async {
		isSyncing = true
		defer { isSyncing = false }

		do {
			_ = try await syncManager.performSync()
			await updateLastSyncText()
		} catch {
			// Error handled by sync manager
		}
	}

	private func updateLastSyncText() async {
		if let lastSync = syncManager.lastSyncDate {
			let formatter = RelativeDateTimeFormatter()
			formatter.unitsStyle = .full
			lastSyncText = formatter.localizedString(for: lastSync, relativeTo: Date())
		} else {
			lastSyncText = "Never"
		}
	}

	private func disconnectHealthKit() {
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitSyncEnabled)
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitHasCompletedInitialSetup)
		syncManager.stopBackgroundSync()
	}
}

#if DEBUG
#Preview {
	NavigationStack {
		HealthKitSettingsView()
	}
}
#endif
