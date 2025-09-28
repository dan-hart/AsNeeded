/// A reusable color picker component for selecting medication colors from the Flat UI v1 color palette
///
/// Features:
/// - Flat UI v1 color palette with professional colors
/// - Grid layout with circular color swatches
/// - Shows current selection with checkmark
/// - Includes "Default" option that uses app accent color
/// - Haptic feedback on selection
/// - Accessible design with proper labels
///
/// **Appearance:**
/// - 5 colors per row in grid layout
/// - Circular color swatches with shadow
/// - Checkmark overlay for selected color
/// - "Reset to Default" option prominently displayed
///
/// **Use Cases:**
/// - Medication color customization in edit forms
/// - User preference color selection
/// - Any interface requiring professional color choice
import SwiftUI
import SFSafeSymbols
import DHFlatUIColors
import DHLoggingKit

struct ColorPickerComponent: View {
	@Binding var selectedColorHex: String?
	let onColorSelected: (String?) -> Void
	let onSave: (() -> Void)?

	private let palette: DHFlatUIColors.Palette = .flatUiV1
	private let hapticsManager = HapticsManager.shared
	private let logger = DHLogger.ui

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
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
				.padding(.top, 8)

				// Default/Reset option
				defaultColorOption

				// Color grid with more spacing for large detent
				VStack(alignment: .leading, spacing: 16) {
					Text("Choose a Color")
						.font(.subheadline)
						.fontWeight(.medium)
						.foregroundStyle(.secondary)

					colorGrid
				}

				// Save button CTA (no spacer needed - let ScrollView handle spacing)
				if let onSave = onSave {
					saveButton(onSave: onSave)
						.padding(.top, 8)
				}
			}
			.padding(.horizontal, 20)
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
							.foregroundStyle(Color.accent.contrastingForegroundColor())
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
			ForEach(palette.colors, id: \.hex) { colorInfo in
				colorSwatch(colorInfo)
			}
		}
		.padding(.bottom, 8)
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
					.frame(width: 50, height: 50)
					.shadow(
						color: Color.black.opacity(0.15),
						radius: 3,
						x: 0,
						y: 2
					)

				// Checkmark for selected color
				if selectedColorHex == colorInfo.hex {
					Circle()
						.fill(Color.black.opacity(0.2))
						.frame(width: 50, height: 50)

					Image(systemSymbol: .checkmark)
						.font(.body.weight(.bold))
						.foregroundStyle(colorInfo.color.contrastingForegroundColor())
				}
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(colorInfo.name) color")
		.accessibilityHint("Select \(colorInfo.name) as medication color")
		.scaleEffect(selectedColorHex == colorInfo.hex ? 1.1 : 1.0)
		.animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColorHex)
	}

	private func saveButton(onSave: @escaping () -> Void) -> some View {
		Button {
			hapticsManager.mediumImpact()
			onSave()
		} label: {
			let backgroundColor = selectedColorHex != nil
				? (Color(hex: selectedColorHex!) ?? Color.accent)
				: Color.accent

			HStack(spacing: 12) {
				// Show selected color preview
				if let hexColor = selectedColorHex, let color = Color(hex: hexColor) {
					Circle()
						.fill(color)
						.frame(width: 24, height: 24)
						.shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
				} else {
					Circle()
						.fill(Color.accent)
						.frame(width: 24, height: 24)
				}

				Text(selectedColorHex != nil ? "Save Color Choice" : "Save Default Color")
					.font(.headline)
					.fontWeight(.semibold)
			}
			.foregroundStyle(backgroundColor.contrastingForegroundColor())
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
			.background(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(backgroundColor)
			)
			.shadow(
				color: backgroundColor.opacity(0.3),
				radius: 8,
				x: 0,
				y: 4
			)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Save selected color")
		.accessibilityHint("Applies the selected color to this medication")
	}
}

#if DEBUG
#Preview("Color Picker with All Palettes") {
	@Previewable @State var selectedColor: String? = "#F3A683"

	return VStack {
		ColorPickerComponent(
			selectedColorHex: $selectedColor,
			onColorSelected: { newColor in
				// Color selection handled by binding
			},
			onSave: {
				// Save action handled by callback
			}
		)
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