// HealthKitMigrationView.swift
// View for migrating data between AsNeeded and HealthKit.

import SwiftUI
import SFSafeSymbols

/// View for data migration options and progress
struct HealthKitMigrationView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@StateObject private var migrationManager = HealthKitMigrationManager.shared
	@State private var selectedDirection: HealthKitMigrationDirection?
	@State private var migrationState: MigrationState = .selection
	@State private var migrationProgress: Double = 0
	@State private var migrationMessage: String = ""
	@State private var migrationResult: HealthKitMigrationResult?
	@State private var showBackupPrompt = false
	@State private var backupURL: URL?

	let syncMode: HealthKitSyncMode

	@ScaledMetric private var cardPadding: CGFloat = 20
	@ScaledMetric private var contentSpacing: CGFloat = 16
	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var progressHeight: CGFloat = 8

	enum MigrationState {
		case selection
		case backup
		case migrating
		case completed
		case error
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					// MARK: - Header
					VStack(alignment: .leading, spacing: 12) {
						Text("Data Migration")
							.font(.customFont(fontFamily, style: .title2, weight: .bold))

						Text("You've selected \(syncMode.displayName). Would you like to migrate existing data?")
							.font(.customFont(fontFamily, style: .body))
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					.padding(.horizontal)
					.padding(.top)

					// MARK: - State-Specific Content
					switch migrationState {
					case .selection:
						migrationSelectionContent
					case .backup:
						backupContent
					case .migrating:
						migrationProgressContent
					case .completed:
						completedContent
					case .error:
						errorContent
					}

					Spacer(minLength: 24)
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					if migrationState == .selection || migrationState == .completed {
						Button {
							if migrationState == .completed {
								completeSetup()
							} else {
								dismiss()
							}
						} label: {
							Image(systemSymbol: .xmark)
								.font(.customFont(fontFamily, style: .body, weight: .medium))
								.foregroundStyle(.secondary)
						}
						.accessibilityLabel(migrationState == .completed ? "Done" : "Cancel")
					}
				}
			}
			.interactiveDismissDisabled(migrationState == .migrating)
			.task {
				// Get migration suggestion
				if let suggestion = await migrationManager.getMigrationSuggestion() {
					selectedDirection = suggestion
				} else {
					selectedDirection = .skip
				}
			}
		}
	}

	// MARK: - Migration Selection Content
	@ViewBuilder
	private var migrationSelectionContent: some View {
		VStack(spacing: contentSpacing) {
			ForEach(HealthKitMigrationDirection.allCases) { direction in
				migrationDirectionCard(for: direction)
			}
		}
		.padding(.horizontal)
	}

	@ViewBuilder
	private func migrationDirectionCard(for direction: HealthKitMigrationDirection) -> some View {
		Button {
			selectedDirection = direction
			if migrationManager.shouldOfferBackup(for: direction) {
				showBackupPrompt = true
			} else {
				startMigration(direction)
			}
		} label: {
			VStack(alignment: .leading, spacing: 12) {
				HStack {
					Image(systemSymbol: iconForDirection(direction))
						.font(.customFont(fontFamily, style: .title2))
						.foregroundColor(colorForDirection(direction))
						.accessibilityHidden(true)

					VStack(alignment: .leading, spacing: 4) {
						Text(direction.displayName)
							.font(.customFont(fontFamily, style: .headline, weight: .semibold))
							.foregroundColor(.primary)

						Text(direction.shortDescription)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}

					Spacer()

					if selectedDirection == direction {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.customFont(fontFamily, style: .title3))
							.foregroundColor(.green)
							.accessibilityHidden(true)
					}
				}

				if let warning = direction.warningMessage {
					HStack(alignment: .top, spacing: 8) {
						Image(systemSymbol: .exclamationmarkTriangleFill)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.orange)
							.accessibilityHidden(true)

						Text(warning)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
			.padding(cardPadding)
			.background(selectedDirection == direction ? Color.accent.opacity(0.1) : Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(selectedDirection == direction ? Color.accent : Color(.systemGray4), lineWidth: selectedDirection == direction ? 2 : 1)
			)
			.cornerRadius(cornerRadius)
		}
		.buttonStyle(.plain)
		.alert("Create Backup?", isPresented: $showBackupPrompt) {
			Button("Create Backup") {
				Task {
					await createBackupAndMigrate()
				}
			}
			Button("Skip Backup") {
				if let direction = selectedDirection {
					startMigration(direction)
				}
			}
			Button("Cancel", role: .cancel) {
				selectedDirection = nil
			}
		} message: {
			Text("It's recommended to create a backup before migrating data. This backup will be saved to your Files app.")
		}
	}

	// MARK: - Backup Content
	@ViewBuilder
	private var backupContent: some View {
		VStack(spacing: contentSpacing) {
			ProgressView("Creating backup...")
				.tint(.accent)

			if let backupURL = backupURL {
				Text("Backup saved to: \(backupURL.lastPathComponent)")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.secondary)
			}
		}
		.padding()
	}

	// MARK: - Migration Progress Content
	@ViewBuilder
	private var migrationProgressContent: some View {
		VStack(spacing: contentSpacing) {
			ProgressView(value: migrationProgress)
				.tint(.accent)
				.frame(height: progressHeight)

			Text(migrationMessage)
				.font(.customFont(fontFamily, style: .body))
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)

			Text("\(Int(migrationProgress * 100))%")
				.font(.customFont(fontFamily, style: .title, weight: .bold))
				.foregroundColor(.accent)
		}
		.padding()
	}

	// MARK: - Completed Content
	@ViewBuilder
	private var completedContent: some View {
		VStack(spacing: contentSpacing) {
			Image(systemSymbol: .checkmarkCircleFill)
				.font(.customFont(fontFamily, style: .largeTitle))
				.imageScale(.large)
				.foregroundColor(.green)
				.accessibilityHidden(true)

			Text("Migration Complete!")
				.font(.customFont(fontFamily, style: .title3, weight: .semibold))

			if let result = migrationResult {
				Text(result.summaryMessage)
					.font(.customFont(fontFamily, style: .body))
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
			}

			Button {
				completeSetup()
			} label: {
				Text("Done")
					.font(.customFont(fontFamily, style: .body, weight: .semibold))
					.foregroundColor(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.background(Color.accent)
					.cornerRadius(cornerRadius)
			}
			.padding(.top, 8)
		}
		.padding()
	}

	// MARK: - Error Content
	@ViewBuilder
	private var errorContent: some View {
		VStack(spacing: contentSpacing) {
			Image(systemSymbol: .exclamationmarkTriangleFill)
				.font(.customFont(fontFamily, style: .largeTitle))
				.imageScale(.large)
				.foregroundColor(.red)
				.accessibilityHidden(true)

			Text("Migration Failed")
				.font(.customFont(fontFamily, style: .title3, weight: .semibold))

			if let result = migrationResult {
				Text(result.summaryMessage)
					.font(.customFont(fontFamily, style: .body))
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
			}

			Button {
				migrationState = .selection
				migrationResult = nil
			} label: {
				Text("Try Again")
					.font(.customFont(fontFamily, style: .body, weight: .semibold))
					.foregroundColor(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.background(Color.accent)
					.cornerRadius(cornerRadius)
			}
			.padding(.top, 8)
		}
		.padding()
	}

	// MARK: - Helper Methods
	private func iconForDirection(_ direction: HealthKitMigrationDirection) -> SFSymbol {
		switch direction {
		case .toHealthKit:
			return .arrowUpForward
		case .toAsNeeded:
			return .arrowDownForward
		case .skip:
			return .forwardFill
		}
	}

	private func colorForDirection(_ direction: HealthKitMigrationDirection) -> Color {
		switch direction {
		case .toHealthKit:
			return .pink
		case .toAsNeeded:
			return .blue
		case .skip:
			return .gray
		}
	}

	private func createBackupAndMigrate() async {
		migrationState = .backup

		do {
			let url = try await migrationManager.createBackup()
			await MainActor.run {
				backupURL = url
			}

			// Wait a moment to show backup success
			try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

			if let direction = selectedDirection {
				startMigration(direction)
			}
		} catch {
			await MainActor.run {
				migrationState = .error
				migrationResult = HealthKitMigrationResult(
					medicationsMigrated: 0,
					eventsMigrated: 0,
					success: false,
					errors: [error],
					duration: 0
				)
			}
		}
	}

	private func startMigration(_ direction: HealthKitMigrationDirection) {
		migrationState = .migrating

		Task {
			do {
				let result = try await migrationManager.performMigration(
					direction: direction,
					progressHandler: { progress, message in
						Task { @MainActor in
							migrationProgress = progress
							migrationMessage = message
						}
					}
				)

				await MainActor.run {
					migrationResult = result
					migrationState = result.success ? .completed : .error
				}
			} catch {
				await MainActor.run {
					migrationResult = HealthKitMigrationResult(
						medicationsMigrated: 0,
						eventsMigrated: 0,
						success: false,
						errors: [error],
						duration: 0
					)
					migrationState = .error
				}
			}
		}
	}

	private func completeSetup() {
		// Mark setup as complete
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitHasCompletedInitialSetup)

		// Dismiss the entire flow
		dismiss()
	}
}

#if DEBUG
#Preview {
	HealthKitMigrationView(syncMode: .bidirectional)
}
#endif
