import SwiftUI
import SFSafeSymbols

struct SupportSuggestionView: View {
	var body: some View {
		NavigationLink {
			SupportView()
		} label: {
			HStack(spacing: 12) {
				Image(systemSymbol: .heart)
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.red)
				
				VStack(alignment: .leading, spacing: 2) {
					Text("Enjoying As Needed?")
						.font(.subheadline)
						.fontWeight(.medium)
					Text("Consider supporting continued development")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				Spacer()
				
				Image(systemSymbol: .chevronRight)
					.font(.caption2)
					.foregroundColor(.secondary)
			}
			.padding(.vertical, 12)
			.padding(.horizontal, 16)
			.background(
				RoundedRectangle(cornerRadius: 10)
					.fill(Color(.secondarySystemBackground))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 10)
					.stroke(Color.red.opacity(0.2), lineWidth: 1)
			)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
		.padding(.top, 8)
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