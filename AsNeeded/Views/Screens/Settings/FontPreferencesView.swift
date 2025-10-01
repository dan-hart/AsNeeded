import SwiftUI
import SFSafeSymbols

/// Full-screen settings view for configuring font preferences
///
/// **Visual Appearance:**
/// - Large navigation title with "Font Preferences"
/// - Header section explaining accessibility purpose
/// - Card-style font family picker with live previews
/// - Each font option shows sample text in that font
/// - Selection indicator (checkmark) for active font
/// - External links to font provider websites
/// - Debug link to FontTestView (DEBUG builds only)
///
/// **Key Features:**
/// - Dynamic Type support with @ScaledMetric spacing
/// - Glass card design system with subtle borders
/// - Live font previews for each family
/// - Comprehensive accessibility descriptions
/// - Links to learn more about each font
/// - Persists selection to UserDefaults
///
/// **Use Cases:**
/// - Typography customization in app settings
/// - Accessibility-focused font selection
/// - Preview and compare different font families
/// - Detailed font information and testing
struct FontPreferencesView: View {
	@AppStorage(UserDefaultsKeys.selectedFontFamily) private var selectedFontFamily: String = FontFamily.system.rawValue
	@ScaledMetric private var sectionSpacing: CGFloat = 32
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var padding: CGFloat = 16

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				headerSection

				typographySection

				#if DEBUG
				debugSection
				#endif

				Spacer(minLength: sectionSpacing)
			}
			.padding(.horizontal, padding)
			.padding(.vertical, padding)
		}
		.navigationTitle("Font Preferences")
		.navigationBarTitleDisplayMode(.large)
	}

	// MARK: - View Components
	private var headerSection: some View {
		VStack(alignment: .leading, spacing: headerSpacing) {
			Text("Choose an accessibility-focused font family to improve readability throughout the app. Each font has been designed with specific accessibility benefits to support users with different visual needs.")
				.font(.body)
				.foregroundStyle(.secondary)
		}
	}

	private var typographySection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Label {
				Text("Font Family", comment: "Font family section title")
			} icon: {
				Image(systemSymbol: .textformat)
			}
			.font(.title2)
			.fontWeight(.semibold)
			.foregroundStyle(.accent)

			Text("Select a font that works best for you. Tap any option to see a live preview and learn more about its accessibility features.", comment: "Description for font family picker")
				.font(.subheadline)
				.foregroundStyle(.secondary)

			fontFamilyPicker
		}
	}

	private var fontFamilyPicker: some View {
		VStack(alignment: .leading, spacing: headerSpacing) {
			ForEach(FontFamily.allCases) { family in
				FontFamilyRow(
					fontFamily: family,
					isSelected: selectedFontFamily == family.rawValue
				) {
					selectedFontFamily = family.rawValue
				}
			}
		}
	}

	#if DEBUG
	private var debugSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Label {
				Text("Developer Tools", comment: "Debug section title")
			} icon: {
				Image(systemSymbol: .wrenchAndScrewdriver)
			}
			.font(.title2)
			.fontWeight(.semibold)
			.foregroundStyle(.orange)

			Text("Testing and debugging tools for font loading and display.", comment: "Debug section description")
				.font(.subheadline)
				.foregroundStyle(.secondary)

			NavigationLink(destination: FontTestView()) {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .textformat)
						.font(.callout.weight(.medium))
						.frame(width: 24, height: 24)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: 2) {
						Text("Font Test View", comment: "Link to font test view")
							.font(.body)
							.fontWeight(.medium)
							.foregroundStyle(.primary)

						Text("Test all font families and check availability", comment: "Font test view description")
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color(.systemGray4), lineWidth: 0.5)
				)
				.cornerRadius(12)
			}
			.buttonStyle(.plain)
		}
	}
	#endif
}

// MARK: - Font Family Row
/// Reusable font family selection row component
///
/// **Visual Appearance:**
/// - Card-style layout with rounded corners and subtle border
/// - Icon, title, and short description in header
/// - Live font preview showing sample text
/// - Full accessibility description
/// - External link button for more information (when available)
/// - Selection indicator (checkmark for selected, circle for unselected)
/// - Highlighted background when selected
///
/// **Key Features:**
/// - Dynamic Type support with @ScaledMetric spacing
/// - Supports light and dark modes
/// - VoiceOver accessible with custom labels
/// - Shows live font preview using the actual font
/// - Clickable link to font provider website
///
/// **Use Cases:**
/// - Font selection in app preferences
/// - Accessibility settings font picker
/// - Font preview and comparison views
/// - Typography customization interfaces
private struct FontFamilyRow: View {
	let fontFamily: FontFamily
	let isSelected: Bool
	let onSelect: () -> Void
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@ScaledMetric private var sampleSpacing: CGFloat = 8

	var body: some View {
		Button(action: onSelect) {
			VStack(alignment: .leading, spacing: itemSpacing) {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .textformat)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text(fontFamily.displayName)
							.font(.body)
							.fontWeight(.medium)
							.foregroundStyle(.primary)

						Text(fontFamily.shortDescription)
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					Spacer()

					if isSelected {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.title3)
							.foregroundStyle(.accent)
					} else {
						Image(systemSymbol: .circle)
							.font(.title3)
							.foregroundStyle(.secondary)
					}
				}

				// Sample text preview
				VStack(alignment: .leading, spacing: sampleSpacing) {
					Text("Sample:", comment: "Label for font sample text preview")
						.font(.caption2)
						.foregroundStyle(.secondary)

					Text(fontFamily.sampleText)
						.font(.customFont(fontFamily, style: .body))
						.foregroundStyle(.primary)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
				}

				// Accessibility description with external link
				VStack(alignment: .leading, spacing: sampleSpacing) {
					Text(fontFamily.accessibilityDescription)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(nil)

					// External link if available
					if let infoURL = fontFamily.infoURL {
						Link(destination: infoURL) {
							HStack(spacing: 4) {
								Text("Learn more", comment: "Link text to learn more about a font")
									.font(.caption)
									.fontWeight(.medium)
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.caption2)
							}
							.foregroundStyle(.accent)
						}
						.accessibilityLabel(String(localized: "Learn more about \(fontFamily.displayName)", comment: "Accessibility label for link to learn more about a specific font"))
					}
				}
			}
			.padding(padding)
			.background(isSelected ? Color.accentColor.opacity(0.05) : Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: borderWidth)
			)
			.cornerRadius(cornerRadius)
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("\(fontFamily.displayName). \(fontFamily.shortDescription). \(isSelected ? String(localized: "Selected", comment: "Accessibility label indicating this option is currently selected") : String(localized: "Not selected", comment: "Accessibility label indicating this option is not currently selected"))")
		.accessibilityHint("Double tap to select this font for the app")
	}
}

// MARK: - Preview
#Preview {
	NavigationView {
		FontPreferencesView()
	}
}
