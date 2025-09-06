import SwiftUI
import SFSafeSymbols

struct SupportSuggestionView: View {
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false
	
	var body: some View {
		if !hideSupportBanners {
			VStack(spacing: 8) {
				NavigationLink {
					SupportView()
				} label: {
					HStack(spacing: 14) {
					ZStack {
					Circle()
						.fill(
							LinearGradient(
								colors: [Color.red.opacity(0.1), Color.pink.opacity(0.15)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 36, height: 36)
					
					Image(systemSymbol: .heart)
						.font(.system(size: 18, weight: .semibold))
						.foregroundStyle(
							LinearGradient(
								colors: [Color.red, Color.pink],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
				}
				
				VStack(alignment: .leading, spacing: 3) {
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
			.padding(16)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
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
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.stroke(
						LinearGradient(
							colors: [
								Color.red.opacity(0.2),
								Color.pink.opacity(0.1)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 1
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
						.padding(.vertical, 8)
						.background(
							RoundedRectangle(cornerRadius: 8)
								.fill(Color(.tertiarySystemFill))
						)
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
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