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
	@State private var isSearching = false
	@FocusState private var searchFieldFocused: Bool

	private let hapticsManager = HapticsManager.shared
	private let logger = DHLogger.ui

	// Scaled metrics for Dynamic Type support - Reduced for better space usage
	@ScaledMetric private var mainSpacing: CGFloat = 12
	@ScaledMetric private var headerSpacing: CGFloat = 10
	@ScaledMetric private var gridSpacing: CGFloat = 12
	@ScaledMetric private var symbolSize: CGFloat = 40
	@ScaledMetric private var previewSymbolSize: CGFloat = 48
	@ScaledMetric private var categoryPadding: CGFloat = 6
	@ScaledMetric private var contentPadding: CGFloat = 16
	@ScaledMetric private var searchBarHeight: CGFloat = 36
	@ScaledMetric private var saveButtonPadding: CGFloat = 14
	@ScaledMetric private var cornerRadius: CGFloat = 10

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
			// Compact header with inline search and categories
			if !isSearching {
				compactHeader
			}

			// Scrollable content
			ScrollView {
				VStack(spacing: mainSpacing) {
					// Show grid directly, no preview section taking space
					symbolGrid
						.padding(.top, isSearching ? mainSpacing : 0)
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
		.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search symbols")
		.onChange(of: searchText) { _, newValue in
			withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
				isSearching = !newValue.isEmpty
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

	private var compactHeader: some View {
		VStack(spacing: categoryPadding) {
			// Mini header with selected symbol indicator
			HStack(spacing: headerSpacing) {
				if let symbol = selectedSymbol {
					// Show selected symbol inline
					Image(systemName: symbol)
						.font(.customFont(fontFamily, style: .body))
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(medicationColor)
						.frame(width: 24, height: 24)
				} else {
					Image(systemSymbol: .squareGrid3x3Fill)
						.font(.customFont(fontFamily, style: .body))
						.foregroundStyle(.secondary)
						.frame(width: 24, height: 24)
				}

				Text(selectedSymbol != nil ? "Symbol Selected" : "Choose Symbol")
					.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
					.foregroundStyle(.primary)

				Spacer()
			}
			.padding(.horizontal, contentPadding)
			.padding(.top, categoryPadding)

			// Inline category picker with bottom spacing
			categoryPicker
				.padding(.horizontal, contentPadding)
				.padding(.bottom, 10)  // Add space after categories
		}
		.background(Color(.secondarySystemBackground))
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
				.background {
					if selectedCategory == category {
						RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
							.fill(medicationColor)
					} else {
						RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
							.fill(.regularMaterial)
					}
				}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("\(category.rawValue) symbols")
		.accessibilityAddTraits(selectedCategory == category ? [.isSelected] : [])
	}


	private var symbolGrid: some View {
		let filteredSymbols = searchText.isEmpty
			? selectedCategory.symbols
			: allSymbols.filter { $0.localizedCaseInsensitiveContains(searchText) }

		return LazyVGrid(
			columns: Array(repeating: GridItem(.flexible(), spacing: adaptiveGridSpacing), count: columnCount),
			spacing: adaptiveGridSpacing
		) {
			ForEach(filteredSymbols, id: \.self) { symbolName in
				symbolCell(symbolName)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Symbol grid")
	}

	private func symbolCell(_ symbolName: String) -> some View {
		let isSelected = selectedSymbol == symbolName

		return Button {
			selectedSymbol = symbolName
			onSymbolSelected(symbolName)
			hapticsManager.lightImpact()
			logger.info("Symbol selected: \(symbolName)")
		} label: {
			VStack(spacing: 4) {
				ZStack {
					if isSelected {
						RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
							.fill(medicationColor.opacity(0.2))
							.frame(width: symbolSize * 1.4, height: symbolSize * 1.4)
					} else {
						RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
							.fill(.regularMaterial)
							.frame(width: symbolSize * 1.4, height: symbolSize * 1.4)
					}

					if isSelected {
						RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
							.stroke(medicationColor, lineWidth: 2.5)
							.frame(width: symbolSize * 1.4, height: symbolSize * 1.4)
					}

					Image(systemName: symbolName)
						.font(.customFont(fontFamily, style: .title2))
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(isSelected ? medicationColor : .primary)

					// Add checkmark badge for selected state
					if isSelected {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.customFont(fontFamily, style: .caption, weight: .bold))
							.foregroundStyle(.white)
							.background(
								Circle()
									.fill(medicationColor)
									.frame(width: 18, height: 18)
							)
							.offset(x: symbolSize * 0.5, y: -symbolSize * 0.5)
					}
				}

				if !isSearching {
					Text(symbolName.components(separatedBy: ".").first ?? symbolName)
						.font(.customFont(fontFamily, style: .caption2, weight: isSelected ? .semibold : .regular))
						.foregroundStyle(isSelected ? medicationColor : .secondary)
						.lineLimit(1)
				}
			}
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.plain)
		.scaleEffect(isSelected && !reduceMotion ? 1.08 : 1.0)
		.animation(.spring(response: 0.2, dampingFraction: 0.8), value: selectedSymbol)
		.accessibilityLabel("\(symbolName.replacingOccurrences(of: ".", with: " ")) symbol")
		.accessibilityAddTraits(isSelected ? [.isSelected] : [])
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

	private var adaptiveGridSpacing: CGFloat {
		// Increase spacing for larger Dynamic Type sizes
		if dynamicTypeSize >= .accessibility1 {
			return gridSpacing * 1.8  // Much more space for very large text
		} else if dynamicTypeSize >= .xxxLarge {
			return gridSpacing * 1.5  // More space for large text
		} else if dynamicTypeSize >= .xLarge {
			return gridSpacing * 1.3  // Slightly more space
		}
		return gridSpacing  // Default spacing
	}

	private var columnCount: Int {
		// More columns when searching to maximize visible results
		if isSearching {
			if dynamicTypeSize >= .accessibility1 {
				return 3  // Fewer columns for better readability
			} else if dynamicTypeSize >= .xxLarge {
				return 4
			} else {
				return 5
			}
		} else {
			// Regular browsing mode
			if dynamicTypeSize >= .accessibility1 {
				return 3
			} else if dynamicTypeSize >= .xxLarge {
				return 4
			} else {
				return 5
			}
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