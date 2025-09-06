import SwiftUI
import SFSafeSymbols

struct NotificationPermissionRequestView: View {
	@StateObject private var notificationManager = NotificationManager.shared
	@State private var isRequesting = false
	let onPermissionGranted: () -> Void
	let onPermissionDenied: () -> Void
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationView {
			VStack(spacing: 24) {
				Spacer()
				
				// Icon
				Image(systemSymbol: .bellBadgeFill)
					.font(.system(size: 60))
					.foregroundColor(.accentColor)
					.padding(.bottom, 8)
				
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
					.padding(.horizontal, 32)
				
				Spacer()
				
				// Buttons
				VStack(spacing: 12) {
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
								.frame(height: 50)
						} else {
							Text("Enable Notifications")
								.font(.headline)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
						}
					}
					.buttonStyle(.borderedProminent)
					.disabled(isRequesting)
					
					Button("Not Now") {
						dismiss()
					}
					.buttonStyle(.bordered)
					.frame(maxWidth: .infinity)
					.frame(height: 50)
				}
				.padding(.horizontal, 32)
				
				Spacer()
			}
			.padding()
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
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