/// A reusable color picker component for selecting medication colors from all DHFlatUIColors palettes
///
/// Features:
/// - All 14 DHFlatUIColors palettes available (Flat UI v1, American, Russian, etc.)
/// - Segmented control for palette selection
/// - Grid layout with palette-specific colors
/// - Shows current selection with checkmark
/// - Includes "Default" option that uses app accent color
/// - Haptic feedback on selection
/// - Accessible design with proper labels
///
/// **Appearance:**
/// - Palette selector at top with scrollable segments
/// - 5 colors per row in grid layout for each palette
/// - Circular color swatches with shadow
/// - Checkmark overlay for selected color
/// - "Reset to Default" option prominently displayed
///
/// **Use Cases:**
/// - Medication color customization in edit forms
/// - User preference color selection
/// - Any interface requiring comprehensive color choice from professional palettes
import SwiftUI
import SFSafeSymbols
import DHFlatUIColors

struct ColorPickerComponent: View {
	@Binding var selectedColorHex: String?
	let onColorSelected: (String?) -> Void

	@State private var selectedPalette: DHFlatUIColors.Palette = .russian
	private let hapticsManager = HapticsManager.shared

	var body: some View {
		VStack(alignment: .leading, spacing: 20) {
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

			// Palette selector
			paletteSelector

			// Color grid for selected palette
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

	private var paletteSelector: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Color Palette")
				.font(.subheadline)
				.fontWeight(.medium)
				.foregroundStyle(.secondary)

			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					ForEach(DHFlatUIColors.Palette.allCases, id: \.self) { palette in
						paletteTab(palette)
					}
				}
				.padding(.horizontal, 2)
			}
		}
	}

	private func paletteTab(_ palette: DHFlatUIColors.Palette) -> some View {
		Button {
			hapticsManager.lightImpact()
			withAnimation(.spring(response: 0.3)) {
				selectedPalette = palette
			}
		} label: {
			Text(palette.name)
				.font(.caption)
				.fontWeight(.medium)
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(
					Capsule()
						.fill(selectedPalette == palette ? Color.accent : Color(.tertiarySystemFill))
				)
				.foregroundStyle(selectedPalette == palette ? .white : .primary)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(palette.name) palette")
		.accessibilityHint("Select \(palette.name) color palette")
	}

	private var colorGrid: some View {
		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
			ForEach(selectedPalette.colors, id: \.hex) { colorInfo in
				colorSwatch(colorInfo)
			}
		}
	}

	private func colorSwatch(_ colorInfo: ColorInfo) -> some View {
		Button {
			hapticsManager.lightImpact()
			selectedColorHex = colorInfo.hex
			onColorSelected(colorInfo.hex)
		} label: {
			ZStack {
				Circle()
					.fill(colorInfo.color)
					.frame(width: 44, height: 44)
					.shadow(
						color: Color.black.opacity(0.15),
						radius: 2,
						x: 0,
						y: 1
					)

				// Checkmark for selected color
				if selectedColorHex == colorInfo.hex {
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
		.accessibilityLabel("\(colorInfo.name) color")
		.accessibilityHint("Select \(colorInfo.name) as medication color")
		.scaleEffect(selectedColorHex == colorInfo.hex ? 1.1 : 1.0)
		.animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColorHex)
	}
}

#if DEBUG
#Preview("Color Picker with All Palettes") {
	@Previewable @State var selectedColor: String? = "#F3A683"

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