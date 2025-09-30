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
import DHLoggingKit

struct ColorPickerComponent: View {
	@Binding var selectedColorHex: String?
	let onColorSelected: (String?) -> Void
	let onSave: (() -> Void)?

	private let hapticsManager = HapticsManager.shared
	private let logger = DHLogger.ui

	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var topPadding: CGFloat = 8
	@ScaledMetric private var gridItemSpacing: CGFloat = 20
	@ScaledMetric private var gridBottomPadding: CGFloat = 8
	@ScaledMetric private var saveButtonTopPadding: CGFloat = 8
	@ScaledMetric private var contentHPadding: CGFloat = 20
	@ScaledMetric private var defaultCircleSize: CGFloat = 32
	@ScaledMetric private var defaultHPadding: CGFloat = 16
	@ScaledMetric private var defaultVPadding: CGFloat = 12
	@ScaledMetric private var defaultCornerRadius: CGFloat = 12
	@ScaledMetric private var defaultBorderWidth: CGFloat = 1.5
	@ScaledMetric private var swatchSize: CGFloat = 70
	@ScaledMetric private var saveCircleSize: CGFloat = 24
	@ScaledMetric private var saveButtonVPadding: CGFloat = 16

	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: mainSpacing) {
					// Section header
					HStack(spacing: headerSpacing) {
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
					.padding(.top, topPadding)

					// Default/Reset option
					defaultColorOption

					// Color grid with more spacing for large detent
					VStack(alignment: .leading, spacing: mainSpacing) {
						Text("Choose a Color")
							.font(.subheadline)
							.fontWeight(.medium)
							.foregroundStyle(.secondary)

						colorGrid
					}
				}
				.padding(.horizontal, contentHPadding)
				.padding(.bottom, contentHPadding)
			}

			// Sticky Save button at bottom
			if let onSave = onSave {
				VStack(spacing: 0) {
					Divider()

					saveButton(onSave: onSave)
						.padding(.horizontal, contentHPadding)
						.padding(.vertical, saveButtonVPadding)
				}
				.background(.regularMaterial)
			}
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
			HStack(spacing: headerSpacing) {
				// Preview circle with accent color
				ZStack {
					Circle()
						.fill(Color.accent)
						.frame(width: defaultCircleSize, height: defaultCircleSize)

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
			.padding(.horizontal, defaultHPadding)
			.padding(.vertical, defaultVPadding)
			.background(
				RoundedRectangle(cornerRadius: defaultCornerRadius, style: .continuous)
					.fill(selectedColorHex == nil ? Color.accent.opacity(0.1) : Color(.tertiarySystemFill))
			)
			.overlay(
				RoundedRectangle(cornerRadius: defaultCornerRadius, style: .continuous)
					.strokeBorder(
						selectedColorHex == nil ? Color.accent.opacity(0.3) : Color.clear,
						lineWidth: defaultBorderWidth
					)
			)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Default color")
		.accessibilityHint("Uses the app's accent color for this medication")
	}

	private var colorGrid: some View {
		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridItemSpacing), count: 3), spacing: gridItemSpacing) {
			ForEach(MedicationColors.colors, id: \.hex) { colorInfo in
				colorSwatch(colorInfo)
			}
		}
		.padding(.bottom, gridBottomPadding)
	}

	private func colorSwatch(_ colorInfo: MedicationColors.ColorInfo) -> some View {
		Button {
			hapticsManager.lightImpact()
			selectedColorHex = colorInfo.hex
			onColorSelected(colorInfo.hex)
		} label: {
			ZStack {
				Circle()
					.fill(colorInfo.color)
					.frame(width: swatchSize, height: swatchSize)
					.shadow(
						color: Color.black.opacity(0.15),
						radius: 5,
						x: 0,
						y: 3
					)

				// Checkmark for selected color
				if selectedColorHex == colorInfo.hex {
					Image(systemSymbol: .checkmark)
						.font(.title2.weight(.bold))
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

			HStack(spacing: headerSpacing) {
				Spacer()

				// Show selected color preview
				if let hexColor = selectedColorHex, let color = Color(hex: hexColor) {
					Circle()
						.fill(color)
						.frame(width: saveCircleSize, height: saveCircleSize)
						.shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
				} else {
					Circle()
						.fill(Color.accent)
						.frame(width: saveCircleSize, height: saveCircleSize)
				}

				Text(selectedColorHex != nil ? "Save Color Choice" : "Save Default Color")
					.font(.headline)
					.fontWeight(.semibold)

				Spacer()
			}
			.foregroundStyle(backgroundColor.contrastingForegroundColor())
			.frame(maxWidth: .infinity)
			.padding(.vertical, saveButtonVPadding)
			.background(
				RoundedRectangle(cornerRadius: defaultCornerRadius, style: .continuous)
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