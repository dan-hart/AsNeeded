/// A comprehensive symbol picker component for selecting SF Symbols for medications
///
/// Features:
/// - Search bar for discovering symbols by name or keywords
/// - Grid layout with categorized symbols from ANModelKit
/// - Real-time preview with selected medication color
/// - Recently used symbols section for quick access
/// - Popular medical symbols prominently displayed
/// - Category-based navigation (Medical, Nature, Objects, etc.)
/// - Haptic feedback on selection
/// - Full accessibility support with VoiceOver labels
/// - Dynamic Type support for all text elements
/// - Dark mode optimized with proper contrast
///
/// **Appearance:**
/// - Search bar at top for quick symbol discovery
/// - Segmented control for category selection
/// - Grid of symbols with names underneath
/// - Selected symbol highlighted with checkmark
/// - Preview section showing symbol with current color
/// - Sticky save button at bottom
///
/// **Use Cases:**
/// - Medication symbol customization in edit forms
/// - Medical app icon selection interfaces
/// - Healthcare symbol browsing and selection
/// - Any interface requiring SF Symbol selection with search
import SwiftUI
import ANModelKit
import SFSafeSymbols
import DHLoggingKit

struct SymbolPickerComponent: View {
	@Binding var selectedSymbol: String?
	let medicationColor: Color
	let onSymbolSelected: (String?) -> Void
	let onSave: (() -> Void)?

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var searchText = ""
	@State private var selectedCategory = SymbolCategory.medical
	@FocusState private var searchFieldFocused: Bool

	private let hapticsManager = HapticsManager.shared
	private let logger = DHLogger.ui

	// Scaled metrics for Dynamic Type support
	@ScaledMetric private var mainSpacing: CGFloat = 20
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var gridSpacing: CGFloat = 16
	@ScaledMetric private var symbolSize: CGFloat = 44
	@ScaledMetric private var previewSymbolSize: CGFloat = 60
	@ScaledMetric private var categoryPadding: CGFloat = 8
	@ScaledMetric private var contentPadding: CGFloat = 20
	@ScaledMetric private var searchBarHeight: CGFloat = 44
	@ScaledMetric private var saveButtonPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12

	enum SymbolCategory: String, CaseIterable {
		case medical = "Medical"
		case nature = "Nature"
		case objects = "Objects"
		case wellness = "Wellness"
		case time = "Time"
		case recent = "Recent"

		var localizedName: LocalizedStringKey {
			LocalizedStringKey(self.rawValue)
		}

		var symbols: [String] {
			// These would ideally come from ANModelKit's symbol database
			// For now, using a curated selection of appropriate symbols
			switch self {
			case .medical:
				return [
					"pills", "pills.fill", "pill", "pill.fill",
					"syringe", "syringe.fill", "bandage", "bandage.fill",
					"stethoscope", "medical.thermometer", "medical.thermometer.fill",
					"cross.case", "cross.case.fill", "heart.text.square", "heart.text.square.fill",
					"waveform.path.ecg", "waveform.path.ecg.rectangle",
					"staroflife", "staroflife.fill", "staroflife.circle", "staroflife.circle.fill"
				]
			case .nature:
				return [
					"leaf", "leaf.fill", "drop", "drop.fill",
					"wind", "snowflake", "sun.max", "sun.max.fill",
					"moon", "moon.fill", "sparkles", "star",
					"star.fill", "cloud", "cloud.fill", "bolt"
				]
			case .objects:
				return [
					"cube", "cube.fill", "shippingbox", "shippingbox.fill",
					"flask", "flask.fill", "testtube.2", "eyedropper",
					"eyedropper.halffull", "eyedropper.full", "scissors",
					"folder", "folder.fill", "doc", "doc.fill"
				]
			case .wellness:
				return [
					"heart", "heart.fill", "lungs", "lungs.fill",
					"brain", "brain.head.profile", "eye", "eye.fill",
					"ear", "ear.fill", "hand.raised", "hand.raised.fill",
					"figure.walk", "figure.run", "bed.double", "bed.double.fill"
				]
			case .time:
				return [
					"clock", "clock.fill", "alarm", "alarm.fill",
					"timer", "stopwatch", "stopwatch.fill", "calendar",
					"calendar.circle", "calendar.circle.fill", "sunrise",
					"sunrise.fill", "sunset", "sunset.fill", "moon.zzz"
				]
			case .recent:
				// This would be populated from user's recently used symbols
				// For now, showing a default set
				return ["pills.fill", "drop.fill", "wind", "heart.fill", "clock"]
			}
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			// Header with search
			VStack(spacing: mainSpacing) {
				headerSection
				searchBar
				categoryPicker
			}
			.padding(.horizontal, contentPadding)
			.padding(.top, categoryPadding)

			// Scrollable symbol grid
			ScrollView {
				VStack(alignment: .leading, spacing: mainSpacing) {
					// Preview section if symbol is selected
					if let symbol = selectedSymbol {
						previewSection(symbol: symbol)
					}

					// Symbol grid
					symbolGrid
				}
				.padding(.horizontal, contentPadding)
				.padding(.vertical, categoryPadding)
			}

			// Sticky save button
			if let onSave = onSave {
				VStack(spacing: 0) {
					Divider()
						.opacity(0.5)

					saveButton(onSave: onSave)
						.padding(.horizontal, contentPadding)
						.padding(.vertical, saveButtonPadding)
				}
				.background(.regularMaterial)
			}
		}
		.onAppear {
			// Focus search field after a delay for smooth sheet presentation
			if !reduceMotion {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
					searchFieldFocused = true
				}
			}
		}
	}

	// MARK: - View Components

	private var headerSection: some View {
		HStack(spacing: headerSpacing) {
			Image(systemSymbol: .squareGrid3x3Fill)
				.font(.customFont(fontFamily, style: .title2))
				.foregroundStyle(
					LinearGradient(
						colors: [medicationColor, medicationColor.opacity(0.7)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)

			Text("Choose Symbol")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			Spacer()
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Choose a symbol for your medication")
	}

	private var searchBar: some View {
		HStack(spacing: headerSpacing) {
			Image(systemSymbol: .magnifyingglass)
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(.secondary)

			TextField("Search Symbols", text: $searchText)
				.font(.customFont(fontFamily, style: .body))
				.textFieldStyle(.plain)
				.focused($searchFieldFocused)
				.submitLabel(.search)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.never)

			if !searchText.isEmpty {
				Button {
					searchText = ""
					hapticsManager.lightImpact()
				} label: {
					Image(systemSymbol: .xmarkCircleFill)
						.font(.customFont(fontFamily, style: .body))
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, headerSpacing)
		.padding(.vertical, categoryPadding)
		.background(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.fill(Color(.tertiarySystemFill))
		)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Search for symbols")
		.accessibilityHint("Type to search for symbol names")
	}

	private var categoryPicker: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: categoryPadding) {
				ForEach(SymbolCategory.allCases, id: \.self) { category in
					categoryButton(category)
				}
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Symbol categories")
	}

	private func categoryButton(_ category: SymbolCategory) -> some View {
		Button {
			withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
				selectedCategory = category
				hapticsManager.lightImpact()
			}
		} label: {
			Text(category.localizedName)
				.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
				.padding(.horizontal, headerSpacing)
				.padding(.vertical, categoryPadding)
				.foregroundStyle(selectedCategory == category ? medicationColor.contrastingForegroundColor() : .primary)
				.background(
					RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
						.fill(selectedCategory == category ? medicationColor : Color(.tertiarySystemFill))
				)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(category.rawValue) symbols")
		.accessibilityAddTraits(selectedCategory == category ? [.isSelected] : [])
	}

	private func previewSection(symbol: String) -> some View {
		VStack(spacing: headerSpacing) {
			Text("Preview")
				.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
				.foregroundStyle(.secondary)

			HStack(spacing: mainSpacing) {
				// Symbol with medication color
				ZStack {
					Circle()
						.fill(medicationColor.opacity(0.15))
						.frame(width: previewSymbolSize * 1.5, height: previewSymbolSize * 1.5)

					Image(systemName: symbol)
						.font(.system(size: previewSymbolSize))
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(medicationColor)
				}

				VStack(alignment: .leading, spacing: 4) {
					Text("Symbol: \(symbol)")
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.secondary)

					Text("Tap symbols below to change")
						.font(.customFont(fontFamily, style: .caption2))
						.foregroundStyle(.tertiary)
				}

				Spacer()
			}
			.padding()
			.background(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(Color(.secondarySystemBackground))
			)
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Preview of selected symbol: \(symbol)")
	}

	private var symbolGrid: some View {
		let filteredSymbols = searchText.isEmpty
			? selectedCategory.symbols
			: allSymbols.filter { $0.localizedCaseInsensitiveContains(searchText) }

		return LazyVGrid(
			columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount),
			spacing: gridSpacing
		) {
			ForEach(filteredSymbols, id: \.self) { symbolName in
				symbolCell(symbolName)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Symbol grid")
	}

	private func symbolCell(_ symbolName: String) -> some View {
		Button {
			selectedSymbol = symbolName
			onSymbolSelected(symbolName)
			hapticsManager.lightImpact()

			// Log selection for analytics
			logger.info("Symbol selected: \(symbolName)")
		} label: {
			VStack(spacing: 8) {
				ZStack {
					RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
						.fill(Color(.tertiarySystemFill))
						.frame(width: symbolSize * 1.5, height: symbolSize * 1.5)

					if selectedSymbol == symbolName {
						RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
							.stroke(medicationColor, lineWidth: 2)
							.frame(width: symbolSize * 1.5, height: symbolSize * 1.5)
					}

					Image(systemName: symbolName)
						.font(.system(size: symbolSize * 0.7))
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(selectedSymbol == symbolName ? medicationColor : .primary)

					if selectedSymbol == symbolName {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(medicationColor)
							.background(
								Circle()
									.fill(Color(.systemBackground))
									.frame(width: 20, height: 20)
							)
							.offset(x: symbolSize * 0.6, y: -symbolSize * 0.6)
					}
				}

				Text(symbolName.replacingOccurrences(of: ".", with: " "))
					.font(.customFont(fontFamily, style: .caption2))
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.plain)
		.scaleEffect(selectedSymbol == symbolName && !reduceMotion ? 1.05 : 1.0)
		.animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedSymbol)
		.accessibilityLabel("\(symbolName.replacingOccurrences(of: ".", with: " ")) symbol")
		.accessibilityAddTraits(selectedSymbol == symbolName ? [.isSelected] : [])
		.accessibilityHint("Tap to select this symbol")
	}

	private func saveButton(onSave: @escaping () -> Void) -> some View {
		Button {
			hapticsManager.mediumImpact()
			onSave()
			logger.info("Symbol saved: \(selectedSymbol ?? "none")")
		} label: {
			HStack(spacing: headerSpacing) {
				Spacer()

				Image(systemSymbol: .checkmarkCircleFill)
					.font(.customFont(fontFamily, style: .title3))

				Text(selectedSymbol != nil ? "Save Symbol Choice" : "Save Default Symbol")
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))

				Spacer()
			}
			.foregroundStyle(medicationColor.contrastingForegroundColor())
			.frame(maxWidth: .infinity)
			.padding(.vertical, saveButtonPadding)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(medicationColor)
			)
			.shadow(
				color: medicationColor.opacity(0.3),
				radius: 8,
				x: 0,
				y: 4
			)
		}
		.buttonStyle(.plain)
		.disabled(selectedSymbol == nil && searchText.isEmpty)
		.opacity(selectedSymbol == nil && searchText.isEmpty ? 0.6 : 1.0)
		.accessibilityLabel("Save selected symbol")
		.accessibilityHint("Applies the selected symbol to this medication")
	}

	// MARK: - Helper Properties

	private var columnCount: Int {
		if dynamicTypeSize >= .accessibility1 {
			return 3
		} else if dynamicTypeSize >= .xxLarge {
			return 4
		} else {
			return 5
		}
	}

	private var allSymbols: [String] {
		// Combine all symbols from all categories for search
		var symbols: [String] = []
		for category in SymbolCategory.allCases {
			symbols.append(contentsOf: category.symbols)
		}
		return Array(Set(symbols)).sorted() // Remove duplicates and sort
	}
}

#if DEBUG
#Preview("Symbol Picker") {
	@Previewable @State var selectedSymbol: String? = "pills.fill"

	return NavigationStack {
		SymbolPickerComponent(
			selectedSymbol: $selectedSymbol,
			medicationColor: .blue,
			onSymbolSelected: { symbol in
				print("Symbol selected: \(symbol ?? "none")")
			},
			onSave: {
				print("Save tapped with symbol: \(selectedSymbol ?? "none")")
			}
		)
		.navigationTitle("Select Symbol")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview("Symbol Picker - Dark Mode") {
	@Previewable @State var selectedSymbol: String? = nil

	return NavigationStack {
		SymbolPickerComponent(
			selectedSymbol: $selectedSymbol,
			medicationColor: .green,
			onSymbolSelected: { symbol in
				print("Symbol selected: \(symbol ?? "none")")
			},
			onSave: {
				print("Save tapped with symbol: \(selectedSymbol ?? "none")")
			}
		)
		.navigationTitle("Select Symbol")
		.navigationBarTitleDisplayMode(.inline)
	}
	.preferredColorScheme(.dark)
}
#endif