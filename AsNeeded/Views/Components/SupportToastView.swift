import SwiftUI
import SFSafeSymbols

struct SupportToastView: View {
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
		if isVisible {
			VStack(spacing: 8) {
				HStack {
					Image(systemSymbol: .checkmarkCircleFill)
						.foregroundColor(.green)
					Text(message)
						.font(.subheadline)
						.foregroundColor(.primary)
					Spacer()
					Button(action: onDismiss) {
						Image(systemSymbol: .xmark)
							.font(.system(size: 12))
							.foregroundColor(.secondary)
					}
				}
				
				Button(action: onSupportTapped) {
					HStack(spacing: 4) {
						Image(systemSymbol: .heart)
							.font(.system(size: 10))
							.foregroundColor(.red.opacity(0.7))
						Text(supportMessage)
							.font(.caption)
							.foregroundColor(.accentColor)
					}
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(
				RoundedRectangle(cornerRadius: 12)
					.fill(.regularMaterial)
					.shadow(radius: 8)
			)
			.padding(.horizontal)
			.transition(.move(edge: .top).combined(with: .opacity))
		}
	}
}

#if DEBUG
#Preview {
	VStack {
		Spacer()
		SupportToastView(
			message: "Dose logged successfully",
			isVisible: true,
			onDismiss: {},
			onSupportTapped: {}
		)
		Spacer()
	}
	.background(Color(.systemGroupedBackground))
}
#endif