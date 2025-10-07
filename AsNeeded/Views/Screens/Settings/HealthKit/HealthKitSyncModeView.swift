// HealthKitSyncModeView.swift
// View for selecting HealthKit synchronization mode.

import SwiftUI
import SFSafeSymbols

/// View for choosing HealthKit sync mode
struct HealthKitSyncModeView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@State private var selectedMode: HealthKitSyncMode?
	@State private var showConfirmation = false
	@State private var showMigrationView = false

	@ScaledMetric private var cardPadding: CGFloat = 20
	@ScaledMetric private var contentSpacing: CGFloat = 16
	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var iconSize: CGFloat = 40

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					// MARK: - Header
					VStack(alignment: .leading, spacing: 12) {
						Text("Choose Sync Mode")
							.font(.customFont(fontFamily, style: .title2, weight: .bold))

						Text("Select how AsNeeded should sync with Apple Health. You can change this later in Settings.")
							.font(.customFont(fontFamily, style: .body))
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					.padding(.horizontal)
					.padding(.top)

					// MARK: - Sync Mode Cards
					VStack(spacing: contentSpacing) {
						ForEach(HealthKitSyncMode.allCases) { mode in
							syncModeCard(for: mode)
						}
					}
					.padding(.horizontal)

					Spacer(minLength: 24)
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
					.accessibilityLabel("Cancel")
				}
			}
			.confirmationDialog(
				"Confirm Sync Mode",
				isPresented: $showConfirmation,
				titleVisibility: .visible,
				presenting: selectedMode
			) { mode in
				Button("Use \(mode.displayName)") {
					confirmSelection(mode)
				}
				Button("Cancel", role: .cancel) {
					selectedMode = nil
				}
			} message: { mode in
				Text(mode.detailedDescription)
			}
			.sheet(isPresented: $showMigrationView) {
				if let mode = selectedMode {
					HealthKitMigrationView(syncMode: mode)
				}
			}
		}
	}

	// MARK: - View Components
	@ViewBuilder
	private func syncModeCard(for mode: HealthKitSyncMode) -> some View {
		Button {
			selectedMode = mode
			showConfirmation = true
		} label: {
			VStack(alignment: .leading, spacing: contentSpacing) {
				// Header with icon
				HStack(spacing: 12) {
					Image(systemSymbol: iconForMode(mode))
						.font(.system(size: iconSize))
						.foregroundStyle(colorForMode(mode))
						.accessibilityHidden(true)

					VStack(alignment: .leading, spacing: 4) {
						Text(mode.displayName)
							.font(.customFont(fontFamily, style: .headline, weight: .semibold))
							.foregroundColor(.primary)

						Text(mode.shortDescription)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.customFont(fontFamily, style: .body))
						.foregroundColor(.secondary)
				}

				Divider()

				// Pros
				if !mode.pros.isEmpty {
					VStack(alignment: .leading, spacing: 8) {
						Text("Benefits")
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))
							.foregroundColor(.secondary)
							.textCase(.uppercase)

						ForEach(mode.pros, id: \.self) { pro in
							HStack(alignment: .top, spacing: 8) {
								Image(systemSymbol: .checkmarkCircleFill)
									.font(.customFont(fontFamily, style: .caption2))
									.foregroundColor(.green)
									.accessibilityHidden(true)

								Text(pro)
									.font(.customFont(fontFamily, style: .caption))
									.foregroundColor(.primary)
									.fixedSize(horizontal: false, vertical: true)
							}
						}
					}
				}

				// Cons
				if !mode.cons.isEmpty {
					VStack(alignment: .leading, spacing: 8) {
						Text("Considerations")
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))
							.foregroundColor(.secondary)
							.textCase(.uppercase)

						ForEach(mode.cons, id: \.self) { con in
							HStack(alignment: .top, spacing: 8) {
								Image(systemSymbol: .infoCircleFill)
									.font(.customFont(fontFamily, style: .caption2))
									.foregroundColor(.orange)
									.accessibilityHidden(true)

								Text(con)
									.font(.customFont(fontFamily, style: .caption))
									.foregroundColor(.secondary)
									.fixedSize(horizontal: false, vertical: true)
							}
						}
					}
				}

				// Special warning for HealthKit SOT
				if mode == .healthKitSOT {
					HStack(alignment: .top, spacing: 8) {
						Image(systemSymbol: .exclamationmarkTriangleFill)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.red)
							.accessibilityHidden(true)

						Text("Data export will not be available when using this mode")
							.font(.customFont(fontFamily, style: .caption, weight: .medium))
							.foregroundColor(.red)
							.fixedSize(horizontal: false, vertical: true)
					}
					.padding(12)
					.background(Color.red.opacity(0.1))
					.cornerRadius(8)
				}
			}
			.padding(cardPadding)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(Color(.systemGray4), lineWidth: 1)
			)
			.cornerRadius(cornerRadius)
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("\(mode.displayName). \(mode.shortDescription)")
		.accessibilityHint("Double tap to select this sync mode")
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

	private func confirmSelection(_ mode: HealthKitSyncMode) {
		// Save the sync mode
		UserDefaults.standard.set(mode.rawValue, forKey: UserDefaultsKeys.healthKitSyncMode)
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitSyncEnabled)

		// Show migration view
		showMigrationView = true
	}
}

#if DEBUG
#Preview {
	HealthKitSyncModeView()
}
#endif
