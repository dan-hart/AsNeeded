import SFSafeSymbols
import SwiftUI

struct DataPrivacyView: View {
	@Environment(\.fontFamily) private var fontFamily

	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@ScaledMetric private var innerSpacing: CGFloat = 4

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				privacySummarySection

				section(
					title: "Backup & Recovery",
					rows: [
						.init(
							title: "Automatic Backup",
							subtitle: "Choose backup location and privacy options",
							icon: .externaldriveConnectedToLineBelow,
							destination: AnyView(AutomaticBackupView())
						),
						.init(
							title: "Export, Import & Clear",
							subtitle: "Export data, import backups, or remove stored records",
							icon: .squareAndArrowUp,
							destination: AnyView(DataManagementView().customNavigationTitle("Data Management"))
						)
					]
				)

				section(
					title: "Privacy Choices",
					rows: [
						.init(
							title: "App Preferences",
							subtitle: "Review private questions, review prompts, haptics, and import behavior",
							icon: .gearshapeFill,
							destination: AnyView(AppPreferencesView())
						),
						.init(
							title: "Medical Disclaimer",
							subtitle: "Review the app's medical and safety limitations",
							icon: .exclamationmarkTriangleFill,
							destination: AnyView(MedicalDisclaimerDetailView())
						)
					]
				)
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

			Text("Your medication data stays under your control. Backup, export, import, and destructive actions are grouped here so review-sensitive choices are in one place.")
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
						HStack(spacing: rowSpacing) {
							Image(systemSymbol: row.icon)
								.font(.customFont(fontFamily, style: .callout, weight: .medium))
								.frame(width: iconSize, height: iconSize)
								.foregroundStyle(.accent)
								.accessibilityHidden(true)

							VStack(alignment: .leading, spacing: innerSpacing) {
								Text(row.title)
									.font(.customFont(fontFamily, style: .body, weight: .medium))
									.foregroundStyle(.primary)

								Text(row.subtitle)
									.font(.customFont(fontFamily, style: .caption))
									.foregroundStyle(.secondary)
									.fixedSize(horizontal: false, vertical: true)
							}

							Spacer()

							Image(systemSymbol: .chevronRight)
								.font(.customFont(fontFamily, style: .caption, weight: .medium))
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
						}
						.padding(cardPadding)
						.background(Color(.systemBackground))
						.overlay(
							RoundedRectangle(cornerRadius: cardCornerRadius)
								.stroke(Color(.systemGray4), lineWidth: borderWidth)
						)
						.clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
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
