import SwiftUI
import SFSafeSymbols

struct SupportSuggestionView: View {
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false
	@ScaledMetric private var containerSpacing: CGFloat = 8
	@ScaledMetric private var contentSpacing: CGFloat = 14
	@ScaledMetric private var iconSize: CGFloat = 36
	@ScaledMetric private var labelSpacing: CGFloat = 3
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var buttonVerticalPadding: CGFloat = 8
	@ScaledMetric private var buttonCornerRadius: CGFloat = 8
	@ScaledMetric private var borderWidth: CGFloat = 1

	var body: some View {
		if !hideSupportBanners {
			VStack(spacing: containerSpacing) {
				NavigationLink {
					SupportView()
				} label: {
					HStack(spacing: contentSpacing) {
					ZStack {
					Circle()
						.fill(
							LinearGradient(
								colors: [Color.red.opacity(0.1), Color.pink.opacity(0.15)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: iconSize, height: iconSize)
					
					Image(systemSymbol: .heart)
						.font(.system(.callout, design: .default, weight: .semibold))
						.foregroundStyle(
							LinearGradient(
								colors: [Color.red, Color.pink],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
				}
				
				VStack(alignment: .leading, spacing: labelSpacing) {
					Text("Enjoying As Needed?")
						.font(.subheadline)
						.fontWeight(.semibold)
						.foregroundColor(.primary)
					Text("Consider supporting continued development")
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemSymbol: .chevronRight)
					.font(.caption)
					.foregroundColor(.secondary.opacity(0.5))
			}
			.padding(cardPadding)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(
						LinearGradient(
							colors: [
								Color(.systemBackground),
								Color(.secondarySystemBackground).opacity(0.5)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
			)
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.stroke(
						LinearGradient(
							colors: [
								Color.red.opacity(0.2),
								Color.pink.opacity(0.1)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: borderWidth
					)
			)
				}
				.buttonStyle(.plain)

				Button {
					hideSupportBanners = true
				} label: {
					Text("Don't Show Again")
						.font(.caption)
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity)
						.padding(.vertical, buttonVerticalPadding)
						.background(
							RoundedRectangle(cornerRadius: buttonCornerRadius)
								.fill(Color(.tertiarySystemFill))
						)
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, cardPadding)
			.padding(.top, containerSpacing)
		}
	}
}

#if DEBUG
#Preview {
	List {
		SupportSuggestionView()
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}
#endif