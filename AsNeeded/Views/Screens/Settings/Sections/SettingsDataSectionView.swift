import SwiftUI
import SFSafeSymbols

struct SettingsDataSectionView: View {
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Data")
				.font(.title2)
				.fontWeight(.semibold)

			NavigationLink {
				DataManagementView()
					.navigationTitle("Data Management")
					.navigationBarTitleDisplayMode(.large)
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .externaldriveConnectedToLineBelow)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accent)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Data Management")
							.font(.body)
							.fontWeight(.medium)
						Text("Export, import, and clear your data")
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

			NavigationLink {
				StorageDiagnosticView()
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .infoCircle)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accent)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Storage Diagnostic")
							.font(.body)
							.fontWeight(.medium)
						Text("View storage locations and migration status")
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

#if DEBUG
#Preview {
  SettingsDataSectionView()
}
#endif
