import SFSafeSymbols
import SwiftUI

struct SupportSuggestionView: View {
	@Environment(\.fontFamily) private var fontFamily
	@AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false
	@State private var isDismissed = false

	var message: String = "Consider supporting continued development"

	var body: some View {
		if !hideSupportBanners && !isDismissed {
			SupportBannerCard(
				message: message,
				onDismiss: { isDismissed = true },
				onHide: { hideSupportBanners = true }
			) { label in
				NavigationLink {
					SupportView()
				} label: {
					label
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 16)
			.padding(.top, 8)
		}
	}
}

/// Shared support presentation keeps dismissal separate from the support action.
struct SupportBannerCard<SupportAction: View>: View {
	@Environment(\.fontFamily) private var fontFamily

	let message: String
	let onDismiss: () -> Void
	let onHide: () -> Void
	@ViewBuilder let supportAction: (SupportBannerLabel) -> SupportAction

	var body: some View {
		VStack(spacing: 8) {
			ZStack(alignment: .topTrailing) {
				supportAction(SupportBannerLabel(message: message))
					.buttonStyle(.plain)

				Button(action: onDismiss) {
					Image(systemSymbol: .xmark)
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.foregroundStyle(.accent)
						.frame(width: 44, height: 44)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Close support banner")
				.padding(16)
			}

			Button(action: onDismiss) {
				Text("Close")
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.foregroundStyle(.accent)
			.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
			.overlay {
				RoundedRectangle(cornerRadius: 10)
					.strokeBorder(Color.accent, lineWidth: 1)
			}

			Button(action: onHide) {
				Text("Don't Show Again")
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.foregroundStyle(.secondary)
			.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
			.overlay {
				RoundedRectangle(cornerRadius: 10)
					.strokeBorder(Color.secondary, lineWidth: 1)
			}
		}
	}
}


/// The whole outlined card is the support link; Close remains a separate control.
struct SupportBannerLabel: View {
	@Environment(\.fontFamily) private var fontFamily
	let message: String

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .top, spacing: 8) {
				Image(systemSymbol: .heart)
					.font(.customFont(fontFamily, style: .title3, weight: .semibold))
					.frame(minHeight: 44)
					.foregroundStyle(.accent)
					.accessibilityHidden(true)
				Text("Enjoying As Needed?")
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(.trailing, 52)

			Text(message)
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.foregroundStyle(.primary)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.strokeBorder(Color.accent, lineWidth: 1)
		}
		.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.accessibilityElement(children: .combine)
		.accessibilityHint("View ways to support As Needed")
	}
}

#if DEBUG
	#Preview {
		NavigationStack {
			List {
				SupportSuggestionView()
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
			}
		}
	}
#endif
