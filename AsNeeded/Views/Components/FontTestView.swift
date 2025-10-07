import SwiftUI
import SFSafeSymbols

/// Debug view to test font loading and availability
/// Shows sample text in all available font families
struct FontTestView: View {
	@State private var availableFonts: [String: [String]] = [:]

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				Text("Font Loading Test")
					.font(.largeTitle)
					.fontWeight(.bold)
					.padding(.bottom)

				// Test each font family
				ForEach(FontFamily.allCases) { fontFamily in
					fontTestSection(for: fontFamily)
				}

				// Show system available fonts
				if !availableFonts.isEmpty {
					systemFontsSection
				}
			}
			.padding()
		}
		.navigationTitle("Font Test")
		.navigationBarTitleDisplayMode(.large)
		.onAppear {
			loadAvailableFonts()
		}
	}

	private func fontTestSection(for fontFamily: FontFamily) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(fontFamily.displayName)
				.font(.headline)
				.foregroundColor(.accent)

			Text(fontFamily.accessibilityDescription)
				.font(.caption)
				.foregroundColor(.secondary)

			// Test regular weight
			VStack(alignment: .leading, spacing: 8) {
				Text("Regular: \(fontFamily.sampleText)")
					.font(.customFont(fontFamily, style: .body))

				Text("Bold: \(fontFamily.sampleText)")
					.font(.customFont(fontFamily, style: .body, weight: .bold))

				Text("Large Title: The Quick Brown Fox")
					.font(.customFont(fontFamily, style: .largeTitle))

				Text("Caption: Small text for testing")
					.font(.customFont(fontFamily, style: .caption))
			}

			// Test font availability
			HStack {
				Image(systemSymbol: FontManager.isFontAvailable(fontFamily) ? .checkmarkCircleFill : .xmarkCircleFill)
					.foregroundStyle(FontManager.isFontAvailable(fontFamily) ? .green : .red)

				Text("Font Available: \(FontManager.isFontAvailable(fontFamily) ? "Yes" : "No")")
					.font(.caption)
					.foregroundColor(.secondary)
			}

			Divider()
		}
	}

	private var systemFontsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("System Available Fonts")
				.font(.headline)
				.foregroundColor(.accent)

			ForEach(Array(availableFonts.keys.sorted()), id: \.self) { family in
				VStack(alignment: .leading, spacing: 4) {
					Text("Family: \(family)")
						.font(.subheadline)
						.fontWeight(.medium)

					ForEach(availableFonts[family] ?? [], id: \.self) { fontName in
						Text("  • \(fontName)")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
			}
		}
	}

	private func loadAvailableFonts() {
		availableFonts = FontManager.getAvailableFontInfo()
	}
}

#Preview {
	NavigationView {
		FontTestView()
	}
}