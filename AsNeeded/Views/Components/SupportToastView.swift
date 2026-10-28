import SwiftUI

struct SupportToastView: View {
	@Environment(\.fontFamily) private var fontFamily
	@AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false

	let message: String
	let supportMessage: String
	let isVisible: Bool
	let onDismiss: () -> Void
	let onSupportTapped: () -> Void

	init(
		message: String,
		supportMessage: String = "Support As Needed",
		isVisible: Bool,
		onDismiss: @escaping () -> Void,
		onSupportTapped: @escaping () -> Void
	) {
		self.message = message
		self.supportMessage = supportMessage
		self.isVisible = isVisible
		self.onDismiss = onDismiss
		self.onSupportTapped = onSupportTapped
	}

	var body: some View {
		if isVisible && !hideSupportBanners {
			ViewThatFits(in: .vertical) {
				banner
				ScrollView {
					banner
				}
				.scrollBounceBehavior(.basedOnSize)
			}
			.frame(maxWidth: 520)
			.padding(16)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
			.transition(.opacity)
			.zIndex(999)
		}
	}

	private var banner: some View {
		SupportBannerCard(
			message: message,
			onDismiss: onDismiss,
			onHide: {
				hideSupportBanners = true
				onDismiss()
			}
		) {
			Button(action: onSupportTapped) {
				Text(supportMessage)
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
		}
		.fixedSize(horizontal: false, vertical: true)
	}
}

#if DEBUG
	#Preview {
		SupportToastView(
			message: "Export completed successfully",
			isVisible: true,
			onDismiss: {},
			onSupportTapped: {}
		)
		.background(Color(.systemGroupedBackground))
	}
#endif
