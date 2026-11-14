import SwiftUI

/// Decorative cards shared by the startup preview and the live list's loading state.
struct MedicationLoadingRows: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		List {
			ForEach(0..<3) { index in
				card(at: index)
					.listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
					.accessibilityHidden(true)
			}
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Color(.systemGroupedBackground))
	}

	private func card(at index: Int) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 10) {
					if !dynamicTypeSize.isAccessibilitySize {
						Circle()
							.fill(.quaternary)
							.frame(width: 40, height: 40)
							.frame(width: 44, height: 44)
					}

					VStack(alignment: .leading, spacing: 4) {
						Text(verbatim: index == 1 ? "Medication name" : "Medication")
							.font(.customFont(fontFamily, style: .headline, weight: .bold))
						Text(verbatim: "Medication type")
							.font(.customFont(fontFamily, style: .caption))
					}
				}

				Capsule()
					.fill(.quaternary)
					.frame(width: 94, height: 22)

				if index == 1 {
					Text(verbatim: "Medication status")
						.font(.customFont(fontFamily, style: .caption2))
				}
			}
			.lineLimit(1)
			.frame(maxWidth: .infinity, alignment: .leading)

			if !dynamicTypeSize.isAccessibilitySize {
				RoundedRectangle(cornerRadius: 14)
					.fill(.quaternary)
					.frame(width: 60, height: 60)
			}
		}
		.redacted(reason: .placeholder)
		.padding(dynamicTypeSize.isAccessibilitySize ? 16 : 12)
		.background {
			RoundedRectangle(cornerRadius: 16)
				.fill(colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : .white)
				.shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.06), radius: 8, y: 3)
		}
		.padding(.horizontal, 4)
	}
}
