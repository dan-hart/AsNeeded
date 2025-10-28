// StorageDiagnosticView.swift
// Diagnostic view showing storage locations and migration status.

import SwiftUI
import SFSafeSymbols

struct StorageDiagnosticView: View {
	@StateObject private var viewModel = StorageDiagnosticViewModel()
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dismiss) private var dismiss
	@State private var showingShareSheet = false
	@State private var shareText: String = ""

	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 24

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: itemSpacing) {
				// Summary Section
				summarySectionView

				// Legacy Storage Section
				if let legacy = viewModel.legacyLocation {
					storageLocationCard(
						title: "Legacy Storage",
						subtitle: "Default App Container",
						icon: .folderFill,
						info: legacy,
						iconColor: .orange
					)
				}

				// App Group Storage Section
				if let appGroup = viewModel.appGroupLocation {
					storageLocationCard(
						title: "App Group Storage",
						subtitle: "Shared Container",
						icon: .folderBadgeGearshape,
						info: appGroup,
						iconColor: .accent
					)
				}

				// Export Button
				exportButtonView

				// Manual Migration Button
				migrationButtonView
			}
			.padding()
		}
		.navigationTitle("Storage Diagnostic")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					viewModel.refreshDiagnostics()
				} label: {
					Image(systemSymbol: .arrowClockwise)
						.font(.customFont(fontFamily, style: .body, weight: .medium))
				}
				.disabled(viewModel.isLoading)
			}
		}
		.sheet(isPresented: $showingShareSheet) {
			if #available(iOS 16.0, *) {
				ShareLink(item: shareText) {
					Label("Share Diagnostic Report", systemSymbol: .squareAndArrowUp)
				}
				.presentationDetents([.medium])
			} else {
				ActivityViewController(activityItems: [shareText])
			}
		}
		.overlay {
			if viewModel.isLoading || viewModel.isMigrating {
				VStack(spacing: 12) {
					ProgressView()
					if viewModel.isMigrating {
						Text("Migrating data...")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}
				}
				.padding()
				.background(.regularMaterial)
				.cornerRadius(12)
			}
		}
		.confirmationDialog(
			"Run Migration?",
			isPresented: $viewModel.showingMigrationConfirmation,
			titleVisibility: .visible
		) {
			Button("Run Migration", role: .destructive) {
				viewModel.runManualMigration()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This will migrate data from the legacy storage location to the App Group container. This operation is safe and will merge existing data.")
		}
		.alert("Migration Complete", isPresented: $viewModel.showingMigrationSuccess) {
			Button("OK") {
				viewModel.showingMigrationSuccess = false
			}
		} message: {
			Text("Data migration completed successfully. Check the diagnostic information above to verify.")
		}
		.alert("Migration Error", isPresented: $viewModel.showingAlert) {
			Button("OK") {
				viewModel.showingAlert = false
			}
		} message: {
			Text(viewModel.migrationError ?? "An unknown error occurred during migration.")
		}
	}

	// MARK: - Summary Section

	private var summarySectionView: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Summary")
				.font(.customFont(fontFamily, style: .headline))

			VStack(spacing: 8) {
				infoRow(label: "Bundle ID", value: viewModel.bundleIdentifier)
				infoRow(label: "Migration Completed", value: viewModel.migrationCompleted ? "Yes" : "No")
				infoRow(label: "Current Container", value: viewModel.currentContainerType)
			}
			.padding(cardPadding)
			.background(Material.regularMaterial)
			.cornerRadius(cornerRadius)
		}
	}

	// MARK: - Storage Location Card

	private func storageLocationCard(
		title: String,
		subtitle: String,
		icon: SFSymbol,
		info: StorageLocationInfo,
		iconColor: Color
	) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 12) {
				Image(systemSymbol: icon)
					.font(.title2)
					.foregroundStyle(iconColor)
					.frame(width: iconSize, height: iconSize)

				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.customFont(fontFamily, style: .headline))
					Text(subtitle)
						.font(.customFont(fontFamily, style: .caption))
						.foregroundColor(.secondary)
				}

				Spacer()

				if info.isCurrentLocation {
					Text("Active")
						.font(.customFont(fontFamily, style: .caption, weight: .semibold))
						.foregroundStyle(.accent)
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
						.background(.accent.opacity(0.15))
						.cornerRadius(6)
				}
			}

			Divider()

			VStack(alignment: .leading, spacing: 8) {
				infoRow(label: "Exists", value: info.exists ? "Yes" : "No")
				infoRow(label: "Path", value: info.path, monospaced: true)

				if info.exists {
					Divider()
						.padding(.vertical, 4)

					infoRow(
						label: "Medications DB",
						value: formatOptional(info.medicationsDBSize, formatter: formatFileSize)
					)
					infoRow(
						label: "Events DB",
						value: formatOptional(info.eventsDBSize, formatter: formatFileSize)
					)

					if let medCount = info.medicationsCount {
						infoRow(label: "Medications", value: "\(medCount)")
					}
					if let eventCount = info.eventsCount {
						infoRow(label: "Events", value: "\(eventCount)")
					}
				}
			}
		}
		.padding(cardPadding)
		.background(Material.regularMaterial)
		.opacity(info.exists ? 1.0 : 0.7)
		.cornerRadius(cornerRadius)
	}

	// MARK: - Export Button

	private var exportButtonView: some View {
		Button {
			shareText = viewModel.exportReport()
			showingShareSheet = true
		} label: {
			HStack {
				Image(systemSymbol: .squareAndArrowUp)
					.font(.customFont(fontFamily, style: .body, weight: .medium))
				Text("Export Diagnostic Report")
					.font(.customFont(fontFamily, style: .body, weight: .medium))
			}
			.frame(maxWidth: .infinity)
			.padding()
			.background(.accent)
			.foregroundStyle(.white)
			.cornerRadius(cornerRadius)
		}
		.padding(.top, 8)
	}

	// MARK: - Migration Button

	private var migrationButtonView: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Warning text
			if viewModel.legacyLocation?.exists == true || !viewModel.migrationCompleted {
				HStack(alignment: .top, spacing: 8) {
					Image(systemSymbol: .exclamationmarkTriangle)
						.font(.caption)
						.foregroundColor(.orange)
					VStack(alignment: .leading, spacing: 4) {
						Text("Manual Migration Available")
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))
							.foregroundColor(.orange)
						Text("Use this if your data isn't showing up or if migration failed.")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}
				}
				.padding(12)
				.background(Color.orange.opacity(0.1))
				.cornerRadius(8)
			}

			Button {
				viewModel.showingMigrationConfirmation = true
			} label: {
				HStack {
					Image(systemSymbol: .arrowTriangleSwap)
						.font(.customFont(fontFamily, style: .body, weight: .medium))
					Text("Run Manual Migration")
						.font(.customFont(fontFamily, style: .body, weight: .medium))
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.orange)
				.foregroundStyle(.white)
				.cornerRadius(cornerRadius)
			}
			.disabled(viewModel.isMigrating || viewModel.isLoading)
		}
	}

	// MARK: - Helper Views

	private func infoRow(label: String, value: String, monospaced: Bool = false) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Text(label)
				.font(.customFont(fontFamily, style: .caption))
				.foregroundColor(.secondary)
				.frame(width: 120, alignment: .leading)

			if monospaced {
				Text(value)
					.font(.caption.monospaced())
					.foregroundColor(.primary)
					.multilineTextAlignment(.leading)
					.frame(maxWidth: .infinity, alignment: .leading)
			} else {
				Text(value)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.primary)
					.multilineTextAlignment(.leading)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
	}

	// MARK: - Helper Functions

	private func formatOptional<T>(_ value: T?, formatter: (T) -> String) -> String {
		guard let value = value else { return "N/A" }
		return formatter(value)
	}

	private func formatFileSize(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

// MARK: - Activity View Controller (iOS 15 fallback)

struct ActivityViewController: UIViewControllerRepresentable {
	let activityItems: [Any]

	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
	}

	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Storage Diagnostic") {
	NavigationStack {
		StorageDiagnosticView()
	}
}
