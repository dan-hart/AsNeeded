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
			GeometryReader { geometry in
				VStack(spacing: 16) {
					// Success indicator with animation
					Image(systemSymbol: .checkmarkCircleFill)
						.font(.system(size: 48))
						.foregroundStyle(
							LinearGradient(
								colors: [.green, .green.opacity(0.8)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.scaleEffect(isVisible ? 1.0 : 0.5)
						.animation(.spring(response: 0.4, dampingFraction: 0.6), value: isVisible)
					
					// Main message
					Text(message)
						.font(.headline)
						.fontWeight(.semibold)
						.foregroundColor(.primary)
						.multilineTextAlignment(.center)
					
					// Support button with enhanced styling
					Button(action: onSupportTapped) {
						HStack(spacing: 6) {
							Image(systemSymbol: .heartFill)
								.font(.system(size: 14))
								.foregroundStyle(
									LinearGradient(
										colors: [.red, .pink],
										startPoint: .top,
										endPoint: .bottom
									)
								)
							Text(supportMessage)
								.font(.subheadline)
								.fontWeight(.medium)
								.foregroundColor(.accentColor)
						}
						.padding(.horizontal, 20)
						.padding(.vertical, 10)
						.background(
							RoundedRectangle(cornerRadius: 10)
								.fill(Color.accentColor.opacity(0.1))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 10)
								.strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
						)
					}
					.buttonStyle(.plain)
					
					// Dismiss button with proper tap target
					Button(action: onDismiss) {
						Image(systemSymbol: .xmarkCircleFill)
							.font(.system(size: 24))
							.foregroundStyle(.secondary)
							.frame(width: 44, height: 44) // Minimum tap target
							.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
				}
				.padding(24)
				.frame(maxWidth: 320)
				.background(
					RoundedRectangle(cornerRadius: 20)
						.fill(.regularMaterial)
						.shadow(color: .black.opacity(0.15), radius: 20, y: 10)
						.overlay(
							RoundedRectangle(cornerRadius: 20)
								.strokeBorder(
									LinearGradient(
										colors: [.white.opacity(0.5), .clear],
										startPoint: .topLeading,
										endPoint: .bottomTrailing
									),
									lineWidth: 1
								)
						)
				)
				.position(
					x: geometry.size.width / 2,
					y: geometry.size.height / 2
				)
				.scaleEffect(isVisible ? 1.0 : 0.9)
				.opacity(isVisible ? 1.0 : 0)
				.animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
			}
			.transition(.opacity.combined(with: .scale))
			.zIndex(999) // Ensure it appears above other content
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