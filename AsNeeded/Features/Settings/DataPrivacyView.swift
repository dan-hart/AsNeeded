import SFSafeSymbols
import SwiftUI

struct DataPrivacyView: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	@State private var showDisableConfirmation = false
	@Environment(\.fontFamily) private var fontFamily

	private let sectionSpacing: CGFloat = 24
	private let rowSpacing: CGFloat = 12
	private let cardPadding: CGFloat = 16
	private let cardCornerRadius: CGFloat = 12
	private let iconSize: CGFloat = 24
	private let borderWidth: CGFloat = 0.5
	private let innerSpacing: CGFloat = 4

	var body: some View {
		VerticalOnlyScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				if demoMode.isEnabled { DemoModeBanner() }
				privacySummarySection


				section(
					title: String(localized: "Backup & Recovery"),
					rows: [
						.init(
							title: String(localized: "Automatic Backup"),
							subtitle: String(localized: "Choose backup location and privacy options"),
							icon: .externaldriveConnectedToLineBelow,
							destination: AnyView(AutomaticBackupView())
						),
						.init(
							title: String(localized: "Export, Import & Clear"),
							subtitle: String(localized: "Export data, import backups, or remove stored records"),
							icon: .squareAndArrowUp,
							destination: AnyView(DataManagementView().customNavigationTitle("Data Management"))
						)
					]
				)

				section(
					title: String(localized: "Privacy Choices"),
					rows: [
						.init(
							title: String(localized: "App Preferences"),
							subtitle: String(localized: "Review feedback prompts, haptics, and import behavior"),
							icon: .gearshapeFill,
							destination: AnyView(AppPreferencesView())
						),
						.init(
							title: String(localized: "Medical Disclaimer"),
							subtitle: String(localized: "Review the app's medical and safety limitations"),
							icon: .exclamationmarkTriangleFill,
							destination: AnyView(MedicalDisclaimerDetailView())
						)
					]
				)
				VStack(alignment: .leading, spacing: rowSpacing) {
					Toggle("Demo Mode", isOn: Binding(
						get: { demoMode.isEnabled },
						set: { enabled in
							if enabled { demoMode.enable() }
							else { showDisableConfirmation = true }
						}
					))
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.tint(.accent)
						.confirmDemoModeDisable(isPresented: $showDisableConfirmation)
					Text("Temporarily hide medication names while showing the app. Everything stays tappable. Turns off when the app relaunches.")
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(.secondary)
					Text("Screen privacy only. Saved data, exports, notifications, and widgets are unchanged.")
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.secondary)
				}
				.padding(cardPadding)
				.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: cardCornerRadius))
			}
			.padding(.horizontal, cardPadding)
			.padding(.vertical, cardPadding)
		}
		.background(Color(.systemGroupedBackground))
		.customNavigationTitle("Data & Privacy")
	}

	private var privacySummarySection: some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			Label {
				Text("Data & Privacy")
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))
			} icon: {
				Image(systemSymbol: .lockShield)
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))
					.foregroundStyle(.accent)
			}

			Text("Manage backups, export or import your data, and choose your privacy settings.")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(cardPadding)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
		.accessibilityElement(children: .combine)
	}

	private func section(title: String, rows: [DataPrivacyRow]) -> some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			Text(title)
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.accessibilityAddTraits(.isHeader)

			VStack(spacing: rowSpacing) {
				ForEach(rows) { row in
					NavigationLink {
						row.destination
					} label: {
						SettingsNavigationRowLabel(
							title: row.title,
							subtitle: row.subtitle,
							icon: row.icon
						)
					}
					.buttonStyle(.plain)
					.accessibilityLabel(row.title)
					.accessibilityHint(row.subtitle)
				}
			}
		}
	}
}

private struct DataPrivacyRow: Identifiable {
	var id: String { title }
	let title: String
	let subtitle: String
	let icon: SFSymbol
	let destination: AnyView
}

#if DEBUG
	#Preview {
		NavigationStack {
			DataPrivacyView()
		}
	}
#endif
