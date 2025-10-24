// AutomaticBackupView.swift
// Dedicated view for automatic backup configuration and management

import SwiftUI
import SFSafeSymbols
import UniformTypeIdentifiers

struct AutomaticBackupView: View {
	@StateObject private var viewModel = AutomaticBackupViewModel()
	@Environment(\.fontFamily) private var fontFamily
	@State private var showAllBackups = false

	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var contentSpacing: CGFloat = 16
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var badgeCornerRadius: CGFloat = 6
	@ScaledMetric private var buttonCornerRadius: CGFloat = 12

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				enableToggleSection

				if viewModel.isEnabled {
					heroStatusCard
					quickActionsSection
					locationManagementCard
					retentionPolicySection
					privacySettingsSection
					backupHistorySection
					storageManagementSection
				}

				howItWorksSection
			}
			.padding()
		}
		.navigationTitle("Automatic Backup")
		.navigationBarTitleDisplayMode(.large)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button {
					viewModel.showingExplainer = true
				} label: {
					Image(systemSymbol: .infoCircle)
						.font(.customFont(fontFamily, style: .body))
				}
			}
		}
		.fileImporter(
			isPresented: $viewModel.showingLocationPicker,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				guard let url = urls.first else {
					viewModel.isSettingUp = false
					return
				}
				Task {
					await viewModel.saveBackupLocation(url: url)
				}
			case .failure(let error):
				viewModel.isSettingUp = false
				viewModel.alertMessage = "Location selection failed: \(error.localizedDescription)"
				viewModel.showingAlert = true
			}
		}
		.sheet(isPresented: $viewModel.showingExplainer) {
			AutomaticBackupExplainerView()
		}
		.sheet(isPresented: $viewModel.showingPrivacyOnboarding) {
			privacyOnboardingSheet
		}
		.sheet(isPresented: $viewModel.showingRestoreSheet) {
			if let backup = viewModel.selectedBackup {
				restoreSheet(for: backup)
			}
		}
		.confirmationDialog(
			"Clear All Automatic Backups?",
			isPresented: $viewModel.showingClearAllConfirmation,
			titleVisibility: .visible
		) {
			Button("Clear All Backups", role: .destructive) {
				Task {
					await viewModel.clearAllBackups()
				}
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("This will delete \(viewModel.backupHistory.count) backups (\(ByteCountFormatter.string(fromByteCount: viewModel.totalStorageUsed, countStyle: .file))). Your current data will not be affected. This cannot be undone.")
		}
		.confirmationDialog(
			"Disable Automatic Backup?",
			isPresented: $viewModel.showingDisableConfirmation,
			titleVisibility: .visible
		) {
			Button("Disable", role: .destructive) {
				viewModel.disableAutomaticBackup()
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("This will stop automatic backups. Your existing backup files will be kept.")
		}
		.alert("Success", isPresented: $viewModel.showingSuccess) {
			Button("OK", role: .cancel) { }
		} message: {
			if let message = viewModel.successMessage {
				Text(message)
			}
		}
		.alert("Error", isPresented: $viewModel.showingAlert) {
			Button("OK", role: .cancel) { }
		} message: {
			if let message = viewModel.alertMessage {
				Text(message)
			}
		}
		.onAppear {
			viewModel.loadBackupHistory()
		}
	}

	// MARK: - Enable Toggle Section
	private var enableToggleSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			if viewModel.isConfigured {
				// Show toggle when already configured
				Toggle(isOn: Binding(
					get: { viewModel.isEnabled },
					set: { newValue in
						if newValue {
							viewModel.enableAutomaticBackup()
						} else {
							viewModel.confirmDisableAutomaticBackup()
						}
					}
				)) {
					VStack(alignment: .leading, spacing: 4) {
						Text("Automatic Backup")
							.font(.customFont(fontFamily, style: .body, weight: .semibold))
						Text("Automatically save backups after logging doses")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
					}
				}
				.tint(.accent)
			} else {
				// Show button for initial setup
				VStack(alignment: .leading, spacing: 12) {
					VStack(alignment: .leading, spacing: 4) {
						Text("Automatic Backup")
							.font(.customFont(fontFamily, style: .body, weight: .semibold))
						Text("Automatically save backups after logging doses")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
					}

					Button {
						viewModel.enableAutomaticBackup()
					} label: {
						HStack {
							if viewModel.isSettingUp {
								Text("Loading...")
									.font(.customFont(fontFamily, style: .body, weight: .semibold))
							} else {
								Image(systemSymbol: .checkmarkCircleFill)
									.font(.customFont(fontFamily, style: .body))
								Text("Enable Automatic Backup")
									.font(.customFont(fontFamily, style: .body, weight: .semibold))
							}
						}
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.accent)
						.cornerRadius(buttonCornerRadius)
					}
					.disabled(viewModel.isSettingUp)
				}
			}
		}
		.padding(cardPadding)
		.background(Color(.systemGray6))
		.cornerRadius(cardCornerRadius)
	}

	// MARK: - Hero Status Card
	private var heroStatusCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				statusIcon
				VStack(alignment: .leading, spacing: 4) {
					Text(statusTitle)
						.font(.customFont(fontFamily, style: .title2, weight: .bold))
					Text(viewModel.statusMessage)
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(.secondary)
				}
				Spacer()
			}

			if let location = viewModel.locationName {
				HStack(spacing: 8) {
					Image(systemSymbol: .folderFill)
						.foregroundStyle(.accent)
						.font(.customFont(fontFamily, style: .caption))
					Text(location)
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.secondary)
				}
			}

			if viewModel.statusCardState == .active {
				Text("Next backup: After your next dose")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
			}
		}
		.padding(cardPadding)
		.background(statusBackgroundColor)
		.cornerRadius(cardCornerRadius)
	}

	private var statusIcon: some View {
		Group {
			switch viewModel.statusCardState {
			case .active:
				Image(systemSymbol: .checkmarkCircleFill)
					.foregroundStyle(.green)
			case .warning:
				Image(systemSymbol: .exclamationmarkTriangleFill)
					.foregroundStyle(.orange)
			case .error:
				Image(systemSymbol: .xmarkCircleFill)
					.foregroundStyle(.red)
			case .disabled:
				Image(systemSymbol: .circleSlash)
					.foregroundStyle(.gray)
			}
		}
		.font(.customFont(fontFamily, style: .largeTitle))
	}

	private var statusBackgroundColor: Color {
		switch viewModel.statusCardState {
		case .active:
			return Color.green.opacity(0.1)
		case .warning:
			return Color.orange.opacity(0.1)
		case .error:
			return Color.red.opacity(0.1)
		case .disabled:
			return Color.gray.opacity(0.1)
		}
	}

	private var statusTitle: String {
		switch viewModel.statusCardState {
		case .active:
			return "Active"
		case .warning:
			return "Warning"
		case .error:
			return "Error"
		case .disabled:
			return "Not Configured"
		}
	}

	// MARK: - Quick Actions
	private var quickActionsSection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Text("Quick Actions")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			Button {
				Task {
					await viewModel.performManualBackup()
				}
			} label: {
				HStack {
					Image(systemSymbol: .trayAndArrowUp)
						.font(.customFont(fontFamily, style: .title3))
					Text("Backup Now")
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
					Spacer()
					if viewModel.isBackupInProgress {
						ProgressView()
					}
				}
				.foregroundStyle(.white)
				.padding()
				.background(Color.accent)
				.cornerRadius(buttonCornerRadius)
			}
			.disabled(viewModel.isBackupInProgress)
		}
	}

	// MARK: - Location Management
	private var locationManagementCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Backup Location")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)

			HStack {
				Image(systemSymbol: .folderFill)
					.foregroundStyle(.accent)
					.font(.customFont(fontFamily, style: .body))

				Text(viewModel.locationName ?? "Not selected")
					.font(.customFont(fontFamily, style: .body))

				Spacer()

				Button("Change") {
					viewModel.changeBackupLocation()
				}
				.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
			}

			if viewModel.backupHistory.count > 0 {
				Text("\(viewModel.backupHistory.count) backups • \(ByteCountFormatter.string(fromByteCount: viewModel.totalStorageUsed, countStyle: .file))")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
			}
		}
		.padding(cardPadding)
		.background(Color(.systemGray6))
		.cornerRadius(cardCornerRadius)
	}

	// MARK: - Retention Policy
	private var retentionPolicySection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Text("Retention Policy")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Keep backups for:")
						.font(.customFont(fontFamily, style: .body))
					Spacer()
					Picker("", selection: $viewModel.retentionDays) {
						Text("7 days").tag(7)
						Text("30 days").tag(30)
						Text("90 days").tag(90)
						Text("1 year").tag(365)
					}
					.pickerStyle(.menu)
				}

				Text("Backups older than \(viewModel.retentionDays) days are automatically deleted to save space")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
			}
			.padding(cardPadding)
			.background(Color(.systemGray6))
			.cornerRadius(cardCornerRadius)
		}
	}

	// MARK: - Privacy Settings
	private var privacySettingsSection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Text("Privacy Options")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			VStack(spacing: 12) {
				Toggle(isOn: $viewModel.automaticBackupRedactMedicationNames) {
					VStack(alignment: .leading, spacing: 4) {
						Text("Redact Medication Names")
							.font(.customFont(fontFamily, style: .body))
						Text("Replace names with [REDACTED]")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
					}
				}
				.tint(.accent)

				Divider()

				Toggle(isOn: $viewModel.automaticBackupRedactNotes) {
					VStack(alignment: .leading, spacing: 4) {
						Text("Redact Notes")
							.font(.customFont(fontFamily, style: .body))
						Text("Remove all notes from backups")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
					}
				}
				.tint(.accent)
			}
			.padding(cardPadding)
			.background(Color(.systemGray6))
			.cornerRadius(cardCornerRadius)
		}
	}

	// MARK: - Backup History
	private var displayedBackups: [BackupFile] {
		if showAllBackups || viewModel.backupHistory.count <= 5 {
			return viewModel.backupHistory
		} else {
			return Array(viewModel.backupHistory.prefix(5))
		}
	}

	private var backupHistorySection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Text("Backup History")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			if viewModel.backupHistory.isEmpty {
				Text("No backups yet")
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color(.systemGray6))
					.cornerRadius(cardCornerRadius)
			} else {
				VStack(spacing: 0) {
					ForEach(Array(displayedBackups.enumerated()), id: \.element.id) { index, backup in
						Button {
							viewModel.selectBackup(backup)
						} label: {
							HStack {
								VStack(alignment: .leading, spacing: 4) {
									HStack {
										Text(backup.date, style: .date)
											.font(.customFont(fontFamily, style: .body, weight: .medium))
										if index == 0 {
											Text("Latest")
												.font(.customFont(fontFamily, style: .caption, weight: .medium))
												.foregroundStyle(.white)
												.padding(.horizontal, 8)
												.padding(.vertical, 2)
												.background(Color.accent)
												.cornerRadius(badgeCornerRadius)
										}
									}
									Text(backup.date, style: .time)
										.font(.customFont(fontFamily, style: .caption))
										.foregroundStyle(.secondary)
									Text("Tap to restore from this backup")
										.font(.customFont(fontFamily, style: .caption2))
										.foregroundStyle(.tertiary)
								}

								Spacer()

								VStack(alignment: .trailing, spacing: 4) {
									Text(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))
										.font(.customFont(fontFamily, style: .subheadline))
									if !backup.isValid {
										Image(systemSymbol: .exclamationmarkTriangleFill)
											.foregroundStyle(.orange)
											.font(.customFont(fontFamily, style: .caption))
									}
								}

								Image(systemSymbol: .chevronRight)
									.font(.customFont(fontFamily, style: .caption))
									.foregroundStyle(.tertiary)
							}
							.padding()
							.background(Color(.systemGray6))
						}
						.buttonStyle(.plain)

						if index < displayedBackups.count - 1 {
							Divider()
								.padding(.leading, cardPadding)
						}
					}
				}
				.cornerRadius(cardCornerRadius)

				// Show All / Show Less button if there are more than 5 backups
				if viewModel.backupHistory.count > 5 {
					Button {
						withAnimation {
							showAllBackups.toggle()
						}
					} label: {
						HStack {
							Spacer()
							Text(showAllBackups ? "Show Less" : "Show All (\(viewModel.backupHistory.count))")
								.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
								.foregroundStyle(.accent)
							Image(systemSymbol: showAllBackups ? .chevronUp : .chevronDown)
								.font(.customFont(fontFamily, style: .caption))
								.foregroundStyle(.accent)
							Spacer()
						}
						.padding(.vertical, 12)
					}
				}
			}
		}
	}

	// MARK: - Storage Management
	private var storageManagementSection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Text("Storage Management")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			VStack(spacing: 12) {
				HStack {
					Text("Total Storage Used")
						.font(.customFont(fontFamily, style: .body))
					Spacer()
					Text(ByteCountFormatter.string(fromByteCount: viewModel.totalStorageUsed, countStyle: .file))
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.foregroundStyle(.accent)
				}

				Button {
					viewModel.showingClearAllConfirmation = true
				} label: {
					HStack {
						Image(systemSymbol: .trash)
						Text("Clear All Backups")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
					}
					.foregroundStyle(.red)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.red.opacity(0.1))
					.cornerRadius(buttonCornerRadius)
				}
				.disabled(viewModel.backupHistory.isEmpty)
			}
			.padding(cardPadding)
			.background(Color(.systemGray6))
			.cornerRadius(cardCornerRadius)
		}
	}

	// MARK: - How It Works
	private var howItWorksSection: some View {
		DisclosureGroup {
			VStack(alignment: .leading, spacing: 12) {
				Text("Automatic backup saves your medication data to a location you choose. After you log a dose, the app waits a few seconds then backs up your data automatically.")
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(.secondary)

				Button {
					viewModel.showingExplainer = true
				} label: {
					Text("Learn More")
						.font(.customFont(fontFamily, style: .body, weight: .medium))
						.foregroundStyle(.accent)
				}
			}
			.padding(.top, 8)
		} label: {
			Text("How It Works")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
		}
		.tint(.accent)
		.padding(cardPadding)
		.background(Color(.systemGray6))
		.cornerRadius(cardCornerRadius)
	}

	// MARK: - Privacy Onboarding Sheet
	private var privacyOnboardingSheet: some View {
		NavigationStack {
			VStack(spacing: 0) {
				ScrollView {
					VStack(alignment: .leading, spacing: 24) {
						VStack(alignment: .leading, spacing: 12) {
							Image(systemSymbol: .lockShieldFill)
								.font(.system(size: 50))
								.foregroundStyle(.accent)
								.frame(maxWidth: .infinity)

							Text("Privacy Options")
								.font(.customFont(fontFamily, style: .title2, weight: .bold))
								.frame(maxWidth: .infinity)

							Text("Choose how to handle sensitive data in your backups. You can change these settings later.")
								.font(.customFont(fontFamily, style: .body))
								.foregroundStyle(.secondary)
								.multilineTextAlignment(.center)
								.frame(maxWidth: .infinity)
						}
						.padding(.bottom, 8)

						VStack(spacing: 16) {
							Toggle(isOn: $viewModel.automaticBackupRedactMedicationNames) {
								VStack(alignment: .leading, spacing: 4) {
									Text("Redact Medication Names")
										.font(.customFont(fontFamily, style: .body, weight: .semibold))
									Text("Replace medication names with [REDACTED] in backups")
										.font(.customFont(fontFamily, style: .caption))
										.foregroundStyle(.secondary)
								}
							}
							.tint(.accent)
							.padding(cardPadding)
							.background(Color(.systemGray6))
							.cornerRadius(cardCornerRadius)

							Toggle(isOn: $viewModel.automaticBackupRedactNotes) {
								VStack(alignment: .leading, spacing: 4) {
									Text("Redact Notes")
										.font(.customFont(fontFamily, style: .body, weight: .semibold))
									Text("Remove all notes from backups")
										.font(.customFont(fontFamily, style: .caption))
										.foregroundStyle(.secondary)
								}
							}
							.tint(.accent)
							.padding(cardPadding)
							.background(Color(.systemGray6))
							.cornerRadius(cardCornerRadius)
						}

						HStack(alignment: .top, spacing: 8) {
							Image(systemSymbol: .infoCircle)
								.foregroundStyle(.accent)
								.font(.customFont(fontFamily, style: .caption))
							Text("Your backup files are stored only in the location you choose")
								.font(.customFont(fontFamily, style: .caption))
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
						.padding(12)
						.frame(maxWidth: .infinity)
						.background(Color.accent.opacity(0.1))
						.cornerRadius(badgeCornerRadius)
					}
					.padding()
				}

				Divider()

				VStack(spacing: 0) {
					Button {
						viewModel.proceedWithLocationSelection()
					} label: {
						HStack {
							Text("Continue")
								.font(.customFont(fontFamily, style: .body, weight: .semibold))
							Image(systemSymbol: .arrowRight)
								.font(.customFont(fontFamily, style: .body))
						}
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.accent)
						.cornerRadius(buttonCornerRadius)
					}
					.padding()
				}
				.background(.regularMaterial)
			}
			.navigationTitle("Setup Backup")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						viewModel.showingPrivacyOnboarding = false
						viewModel.isSettingUp = false
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
				}
			}
		}
	}

	// MARK: - Restore Sheet
	private func restoreSheet(for backup: BackupFile) -> some View {
		NavigationStack {
			VStack(spacing: 24) {
				VStack(spacing: 12) {
					Image(systemSymbol: .trayAndArrowDown)
						.font(.system(size: 50))
						.foregroundStyle(.accent)

					Text("Restore from Backup")
						.font(.customFont(fontFamily, style: .title2, weight: .bold))

					Text(backup.date, style: .date)
						.font(.customFont(fontFamily, style: .body))
						.foregroundStyle(.secondary)
				}

				VStack(alignment: .leading, spacing: 16) {
					VStack(alignment: .leading, spacing: 8) {
						Image(systemSymbol: .exclamationmarkTriangleFill)
							.font(.system(size: 40))
							.foregroundStyle(.orange)
							.frame(maxWidth: .infinity)

						Text("Warning")
							.font(.customFont(fontFamily, style: .headline, weight: .bold))
							.frame(maxWidth: .infinity)

						Text("This will replace all current data with the backup. This cannot be undone.")
							.font(.customFont(fontFamily, style: .body))
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.noTruncate()
							.frame(maxWidth: .infinity)
					}
					.padding()
					.background(Color.orange.opacity(0.1))
					.cornerRadius(cardCornerRadius)

					Button {
						Task {
							await viewModel.restoreFromBackup(mergeExisting: false)
						}
					} label: {
						HStack {
							Image(systemSymbol: .arrowCounterclockwise)
								.font(.customFont(fontFamily, style: .body))
							Text("Replace All Data")
								.font(.customFont(fontFamily, style: .body, weight: .semibold))
						}
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.red)
						.cornerRadius(buttonCornerRadius)
					}
				}

				Spacer()
			}
			.padding()
			.navigationTitle("Restore Backup")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						viewModel.showingRestoreSheet = false
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.dynamicDetent()
	}
}

#Preview {
	NavigationStack {
		AutomaticBackupView()
	}
}
