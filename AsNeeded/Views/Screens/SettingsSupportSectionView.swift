import SwiftUI
import SFSafeSymbols

struct SettingsSupportSectionView: View {
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false
	@StateObject private var appReviewManager = AppReviewManager.shared
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Support")
				.font(.title2)
				.fontWeight(.semibold)

			NavigationLink {
				SupportView()
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .heart)
						.font(.system(size: 18, weight: .medium))
						.frame(width: 24, height: 24)
						.foregroundColor(.red)

					VStack(alignment: .leading, spacing: 2) {
						Text("Support As Needed")
							.font(.body)
							.fontWeight(.medium)
						Text("Tips, donations, and ways to help")
							.font(.caption)
							.foregroundColor(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(16)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color(.systemGray4), lineWidth: 0.5)
				)
				.cornerRadius(12)
			}
			.buttonStyle(.plain)
			
			// Hide Support Banners toggle
			HStack(spacing: 12) {
				Image(systemSymbol: .eyeSlash)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(.secondary)

				VStack(alignment: .leading, spacing: 2) {
					Text("Hide Support Banners")
						.font(.body)
					Text("Disable support reminders throughout the app")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				Spacer()
				Toggle("", isOn: $hideSupportBanners)
					.labelsHidden()
			}
			.padding(16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color(.systemGray4), lineWidth: 0.5)
			)
			.cornerRadius(12)

			// App Review Preferences toggle
			HStack(spacing: 12) {
				Image(systemSymbol: .starSlash)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(.secondary)

				VStack(alignment: .leading, spacing: 2) {
					Text("Disable Review Requests")
						.font(.body)
					Text("Opt out of automatic app review prompts")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				Spacer()
				Toggle("", isOn: $appReviewManager.hasOptedOutOfReviews)
					.labelsHidden()
			}
			.padding(16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color(.systemGray4), lineWidth: 0.5)
			)
			.cornerRadius(12)
		}
	}
}

#if DEBUG
#Preview { 
	SettingsSupportSectionView() 
}
#endif