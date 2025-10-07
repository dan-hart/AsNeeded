// HealthKitAuthorizationView.swift
// Authorization flow for HealthKit integration.

import SwiftUI
import SFSafeSymbols

/// View for requesting HealthKit authorization
struct HealthKitAuthorizationView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@StateObject private var syncManager = HealthKitSyncManager.shared
	@State private var authorizationState: AuthState = .initial
	@State private var showSyncModeSelection = false
	@State private var errorMessage: String?

	@ScaledMetric private var iconSize: CGFloat = 80
	@ScaledMetric private var contentSpacing: CGFloat = 24
	@ScaledMetric private var sectionSpacing: CGFloat = 32
	@ScaledMetric private var buttonVerticalPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 16

	enum AuthState {
		case initial
		case requesting
		case success
		case error
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					// MARK: - Header
					VStack(spacing: contentSpacing) {
						Image(systemSymbol: .heartTextSquareFill)
							.font(.system(size: iconSize))
							.foregroundStyle(
								LinearGradient(
									colors: [.pink, .red],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.accessibilityHidden(true)

						VStack(spacing: 8) {
							Text("Connect to Apple Health")
								.font(.customFont(fontFamily, style: .title2, weight: .bold))
								.multilineTextAlignment(.center)

							Text("Sync your medication data across devices")
								.font(.customFont(fontFamily, style: .body))
								.foregroundColor(.secondary)
								.multilineTextAlignment(.center)
						}
					}
					.frame(maxWidth: .infinity)
					.padding(.top)

					// MARK: - Benefits
					VStack(alignment: .leading, spacing: 16) {
						Text("What You Get")
							.font(.customFont(fontFamily, style: .headline, weight: .semibold))

						benefitRow(
							icon: .icloudFill,
							title: "iCloud Sync",
							description: "Your medication data syncs across all your devices through iCloud"
						)

						benefitRow(
							icon: .lockShieldFill,
							title: "Privacy Protected",
							description: "Your health data is encrypted and only you can access it"
						)

						benefitRow(
							icon: .chartLineUptrendXyaxis,
							title: "Complete History",
							description: "View your medication history in both AsNeeded and Health apps"
						)

						benefitRow(
							icon: .applewatch,
							title: "Cross-Platform",
							description: "Access your data on iPhone, iPad, Apple Watch, and Mac"
						)
					}

					// MARK: - What We Access
					VStack(alignment: .leading, spacing: 16) {
						Text("What AsNeeded Accesses")
							.font(.customFont(fontFamily, style: .headline, weight: .semibold))

						accessRow(icon: .pills, text: "Your medications and prescriptions")
						accessRow(icon: .clockArrowTriangleheadCounterclockwiseRotate90, text: "Dose timing and history")
						accessRow(icon: .noteText, text: "Notes about your medications")
					}

					// MARK: - State-Specific Content
					if authorizationState == .success {
						successContent
					} else if authorizationState == .error {
						errorContent
					}

					Spacer(minLength: 24)
				}
				.padding()
			}
			.navigationTitle("HealthKit Setup")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
					.accessibilityLabel("Cancel")
				}
			}
			.safeAreaInset(edge: .bottom) {
				// MARK: - Action Button
				if authorizationState != .success {
					VStack(spacing: 0) {
						Divider()
							.background(Color(.separator).opacity(0.5))

						Button {
							Task {
								await requestAuthorization()
							}
						} label: {
							HStack {
								if authorizationState == .requesting {
									ProgressView()
										.tint(.white)
								} else {
									Image(systemSymbol: .heartFill)
								}

								Text(authorizationState == .requesting ? "Requesting..." : "Connect to Apple Health")
									.font(.customFont(fontFamily, style: .body, weight: .semibold))
							}
							.foregroundColor(.white)
							.frame(maxWidth: .infinity)
							.padding(.vertical, buttonVerticalPadding)
							.background(
								LinearGradient(
									colors: [.pink, .red],
									startPoint: .leading,
									endPoint: .trailing
								)
							)
							.cornerRadius(cornerRadius)
						}
						.disabled(authorizationState == .requesting)
						.padding()
						.background(.regularMaterial)
					}
				}
			}
			.sheet(isPresented: $showSyncModeSelection) {
				HealthKitSyncModeView()
			}
		}
	}

	// MARK: - View Components
	private func benefitRow(icon: SFSymbol, title: String, description: String) -> some View {
		HStack(alignment: .top, spacing: 16) {
			Image(systemSymbol: icon)
				.font(.customFont(fontFamily, style: .title3))
				.foregroundColor(.accent)
				.frame(width: 32)
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.customFont(fontFamily, style: .body, weight: .semibold))
					.foregroundColor(.primary)

				Text(description)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private func accessRow(icon: SFSymbol, text: String) -> some View {
		HStack(spacing: 12) {
			Image(systemSymbol: .checkmarkCircleFill)
				.font(.customFont(fontFamily, style: .body))
				.foregroundColor(.green)
				.accessibilityHidden(true)

			Text(text)
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundColor(.secondary)
		}
	}

	private var successContent: some View {
		VStack(spacing: 16) {
			Image(systemSymbol: .checkmarkCircleFill)
				.font(.customFont(fontFamily, style: .largeTitle))
				.imageScale(.large)
				.foregroundColor(.green)
				.accessibilityHidden(true)

			Text("Connected Successfully!")
				.font(.customFont(fontFamily, style: .title3, weight: .semibold))

			Text("Choose how you want AsNeeded to sync with Apple Health")
				.font(.customFont(fontFamily, style: .body))
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)

			Button {
				showSyncModeSelection = true
			} label: {
				Text("Choose Sync Mode")
					.font(.customFont(fontFamily, style: .body, weight: .semibold))
					.foregroundColor(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, buttonVerticalPadding)
					.background(Color.accent)
					.cornerRadius(cornerRadius)
			}
			.padding(.top, 8)
		}
		.padding()
		.background(Color(.systemGreen).opacity(0.1))
		.cornerRadius(cornerRadius)
	}

	private var errorContent: some View {
		VStack(spacing: 16) {
			Image(systemSymbol: .exclamationmarkTriangleFill)
				.font(.customFont(fontFamily, style: .largeTitle))
				.imageScale(.large)
				.foregroundColor(.orange)
				.accessibilityHidden(true)

			Text("Authorization Failed")
				.font(.customFont(fontFamily, style: .title3, weight: .semibold))

			if let errorMessage = errorMessage {
				Text(errorMessage)
					.font(.customFont(fontFamily, style: .body))
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
			}

			Button {
				authorizationState = .initial
				errorMessage = nil
			} label: {
				Text("Try Again")
					.font(.customFont(fontFamily, style: .body, weight: .semibold))
					.foregroundColor(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, buttonVerticalPadding)
					.background(Color.accent)
					.cornerRadius(cornerRadius)
			}
			.padding(.top, 8)
		}
		.padding()
		.background(Color(.systemOrange).opacity(0.1))
		.cornerRadius(cornerRadius)
	}

	// MARK: - Actions
	private func requestAuthorization() async {
		authorizationState = .requesting

		do {
			try await syncManager.requestAuthorization()
			await MainActor.run {
				authorizationState = .success
			}
		} catch {
			await MainActor.run {
				authorizationState = .error
				errorMessage = error.localizedDescription
			}
		}
	}
}

#if DEBUG
#Preview {
	HealthKitAuthorizationView()
}
#endif
