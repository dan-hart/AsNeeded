/// A reusable color picker component for selecting medication colors
///
/// Features:
/// - Grid layout with preset color options
/// - Shows current selection with checkmark
/// - Includes "Default" option that uses app accent color
/// - Haptic feedback on selection
/// - Accessible design with proper labels
///
/// **Appearance:**
/// - 6 colors per row in a grid layout
/// - Circular color swatches with shadow
/// - Checkmark overlay for selected color
/// - "Reset to Default" option prominently displayed
///
/// **Use Cases:**
/// - Medication color customization in edit forms
/// - User preference color selection
/// - Any interface requiring simple color choice from preset options
import SwiftUI
import SFSafeSymbols
import DHFlatUIColors

struct ColorPickerComponent: View {
	@Binding var selectedColorHex: String?
	let onColorSelected: (String?) -> Void

	private let hapticsManager = HapticsManager.shared

	// DHFlatUIColors Russian palette - all 20 colors for medication customization
	private let presetColors: [(name: String, hex: String)] = [
		("Creamy Peach", "#F3A683"),
		("Rosy Highlight", "#F7D794"),
		("Soft Blue", "#778BEB"),
		("Brewed Mustard", "#E77F67"),
		("Old Geranium", "#CF6A87"),
		("Sawtooth Aak", "#F19066"),
		("Summertime", "#F5CD79"),
		("Cornflower", "#546DE5"),
		("Tigerlily", "#E15F41"),
		("Deep Rose", "#C44569"),
		("Purple Mountain", "#786FA6"),
		("Rogue Pink", "#F8A5C2"),
		("Squeaky", "#63CDDA"),
		("Apple Valley", "#EA8685"),
		("Pencil Lead", "#596275"),
		("Purple Corallite", "#574B90"),
		("Flamingo Pink", "#F78FB3"),
		("Blue Curacao", "#3DC1D3"),
		("Porcelain Rose", "#E66767"),
		("Biscay", "#303952")
	]

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Section header
			HStack(spacing: 12) {
				Image(systemSymbol: .paintbrushPointedFill)
					.font(.title2)
					.foregroundStyle(
						LinearGradient(
							colors: [Color.accent, Color.accent.opacity(0.7)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				Text("Medication Color")
					.font(.headline)
					.fontWeight(.semibold)
			}

			// Default/Reset option
			defaultColorOption

			// Color grid
			colorGrid
		}
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Color picker for medication")
	}

	// MARK: - View Components
	private var defaultColorOption: some View {
		Button {
			hapticsManager.lightImpact()
			selectedColorHex = nil
			onColorSelected(nil)
		} label: {
			HStack(spacing: 12) {
				// Preview circle with accent color
				ZStack {
					Circle()
						.fill(Color.accent)
						.frame(width: 32, height: 32)

					if selectedColorHex == nil {
						Image(systemSymbol: .checkmark)
							.font(.caption.weight(.bold))
							.foregroundStyle(.white)
					}
				}

				VStack(alignment: .leading, spacing: 2) {
					Text("Default")
						.font(.subheadline)
						.fontWeight(.medium)
						.foregroundStyle(.primary)

					Text("Uses app accent color")
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer()
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(selectedColorHex == nil ? Color.accent.opacity(0.1) : Color(.tertiarySystemFill))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.strokeBorder(
						selectedColorHex == nil ? Color.accent.opacity(0.3) : Color.clear,
						lineWidth: 1.5
					)
			)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Default color")
		.accessibilityHint("Uses the app's accent color for this medication")
	}

	private var colorGrid: some View {
		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
			ForEach(presetColors, id: \.hex) { colorOption in
				colorSwatch(colorOption)
			}
		}
	}

	private func colorSwatch(_ colorOption: (name: String, hex: String)) -> some View {
		Button {
			hapticsManager.lightImpact()
			selectedColorHex = colorOption.hex
			onColorSelected(colorOption.hex)
		} label: {
			ZStack {
				Circle()
					.fill(Color(hex: colorOption.hex) ?? .gray)
					.frame(width: 44, height: 44)
					.shadow(
						color: Color.black.opacity(0.15),
						radius: 2,
						x: 0,
						y: 1
					)

				// Checkmark for selected color
				if selectedColorHex == colorOption.hex {
					Circle()
						.fill(Color.black.opacity(0.2))
						.frame(width: 44, height: 44)

					Image(systemSymbol: .checkmark)
						.font(.caption.weight(.bold))
						.foregroundStyle(.white)
				}
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(colorOption.name) color")
		.accessibilityHint("Select \(colorOption.name.lowercased()) as medication color")
		.scaleEffect(selectedColorHex == colorOption.hex ? 1.1 : 1.0)
		.animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColorHex)
	}
}

#if DEBUG
#Preview("Color Picker Preview") {
	@Previewable @State var selectedColor: String? = "#007AFF"

	return VStack {
		ColorPickerComponent(selectedColorHex: $selectedColor) { newColor in
			print("Selected color: \(newColor ?? "default")")
		}
		.padding()

		Spacer()

		// Show selected color
		if let hex = selectedColor, let color = Color(hex: hex) {
			HStack {
				Text("Selected:")
				Circle()
					.fill(color)
					.frame(width: 24, height: 24)
				Text(hex)
			}
			.padding()
		} else {
			Text("Default color selected")
				.padding()
		}
	}
}
#endif