import SwiftUI
import SFSafeSymbols

struct SettingsDisclaimersSectionView: View {
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Disclaimers")
				.font(.title2)
				.fontWeight(.semibold)

			VStack(spacing: headerSpacing) {
				// Medical Disclaimer
				NavigationLink {
					MedicalDisclaimerDetailView()
				} label: {
					HStack(spacing: headerSpacing) {
						Image(systemSymbol: .exclamationmarkTriangle)
							.font(.callout.weight(.medium))
							.frame(width: iconSize, height: iconSize)
							.foregroundColor(.yellow)

						VStack(alignment: .leading, spacing: stackItemSpacing) {
							Text("Medical Disclaimer")
								.font(.body)
								.fontWeight(.medium)
							Text("Important medical advice information")
								.font(.caption)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .chevronRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding(padding)
					.background(Color(.systemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: cornerRadius)
							.stroke(Color(.systemGray4), lineWidth: borderWidth)
					)
					.cornerRadius(cornerRadius)
				}
				.buttonStyle(.plain)

				// NIH/NLM Data Attribution
				NavigationLink {
					NIHDisclaimerDetailView()
				} label: {
					HStack(spacing: headerSpacing) {
						Image(systemSymbol: .buildingColumns)
							.font(.callout.weight(.medium))
							.frame(width: iconSize, height: iconSize)
							.foregroundColor(.accent)

						VStack(alignment: .leading, spacing: stackItemSpacing) {
							Text("Medical Data Sources")
								.font(.body)
								.fontWeight(.medium)
							Text("NIH/NLM RxNorm database citations")
								.font(.caption)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .chevronRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding(padding)
					.background(Color(.systemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: cornerRadius)
							.stroke(Color(.systemGray4), lineWidth: borderWidth)
					)
					.cornerRadius(cornerRadius)
				}
				.buttonStyle(.plain)
			}
		}
	}
}

#if DEBUG
#Preview {
	NavigationView {
		SettingsDisclaimersSectionView()
			.padding()
	}
}
#endif