import SwiftUI

struct DoseLogPreview: View {
	let summary: String?

	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		Text(summary ?? String(localized: "Enter a dose amount"))
			.font(.customFont(fontFamily, style: .headline, weight: .semibold))
			.multilineTextAlignment(.leading)
			.noTruncate()
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}
