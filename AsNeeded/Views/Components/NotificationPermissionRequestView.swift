import SwiftUI
import SFSafeSymbols

struct NotificationPermissionRequestView: View {
	@StateObject private var notificationManager = NotificationManager.shared
	@State private var isRequesting = false
	let onPermissionGranted: () -> Void
	let onPermissionDenied: () -> Void
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily

	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var iconBottomPadding: CGFloat = 8
	@ScaledMetric private var descriptionHPadding: CGFloat = 32
	@ScaledMetric private var buttonSpacing: CGFloat = 12
	@ScaledMetric private var buttonHeight: CGFloat = 50
	@ScaledMetric private var buttonHPadding: CGFloat = 32

	var body: some View {
		NavigationView {
			VStack(spacing: mainSpacing) {
				Spacer()

				// Icon
				Image(systemSymbol: .bellBadgeFill)
					.font(.largeTitle.weight(.medium))
					.foregroundColor(.accent)
					.padding(.bottom, iconBottomPadding)
				
				// Title
				Text("Enable Reminders")
					.font(.title)
					.fontWeight(.bold)
					.multilineTextAlignment(.center)
				
				// Description
				Text("Allow As Needed to send you reminders for your medications. You can customize when and how often you receive notifications.")
					.font(.body)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, descriptionHPadding)

				Spacer()

				// Buttons
				VStack(spacing: buttonSpacing) {
					Button {
						isRequesting = true
						Task {
							_ = await notificationManager.requestAuthorization()
							isRequesting = false
							
							if notificationManager.authorizationStatus == .authorized {
								onPermissionGranted()
							} else {
								onPermissionDenied()
							}
						}
					} label: {
						if isRequesting {
							ProgressView()
								.progressViewStyle(CircularProgressViewStyle())
								.frame(maxWidth: .infinity)
								.frame(height: buttonHeight)
						} else {
							Text("Enable Notifications")
								.font(.headline)
								.frame(maxWidth: .infinity)
								.frame(height: buttonHeight)
						}
					}
					.buttonStyle(.borderedProminent)
					.disabled(isRequesting)

					Button("Not Now") {
						dismiss()
					}
					.buttonStyle(.bordered)
					.frame(maxWidth: .infinity)
					.frame(height: buttonHeight)
				}
				.padding(.horizontal, buttonHPadding)
				
				Spacer()
			}
			.padding()
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				Button(role: .close) {
					dismiss()
				}
			}
		}
		.onAppear {
			// Check if status changed while view was loading
			if notificationManager.authorizationStatus == .authorized {
				onPermissionGranted()
			}
		}
	}
}

#if DEBUG
#Preview {
	NotificationPermissionRequestView(
		onPermissionGranted: { print("Granted") },
		onPermissionDenied: { print("Denied") }
	)
}
#endif