//
//  EnhancedMedicationSearchField.swift
//  AsNeeded
//
//  Beautiful and functional medication search field with RxNorm integration
//

import DHLoggingKit
import SFSafeSymbols
import SwiftRxNorm
import SwiftUI

struct EnhancedMedicationSearchField<ScrollID: Hashable>: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	// MARK: - Properties

	@Binding var text: String
	let placeholder: String
	let scrollID: ScrollID?
	let onMedicationSelected: ((clinicalName: String, nickname: String)) -> Void

	@StateObject private var searchService = MedicationSearchService.shared
	@State private var suggestions: [RxNormSearchResult] = []
	@State private var showSuggestions = false
	@State private var isSearching = false
	@State private var searchTask: Task<Void, Never>?
	@State private var searchRequestID = UUID()
	@State private var isQuickMedicationsExpanded = false
	@State private var selectedMedication: RxNormDrug?
	@State private var animateSelection = false
	@FocusState private var isFocused: Bool
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	private let sectionSpacing: CGFloat = 8
	private let fieldHorizontalPadding: CGFloat = 12
	private let fieldVerticalPadding: CGFloat = 12
	private let fieldCornerRadius: CGFloat = 12
	private let fieldBorderWidth: CGFloat = 1
	@ScaledMetric private var suggestionRowSpacing: CGFloat = 12
	@ScaledMetric private var suggestionRowPadding: CGFloat = 16
	@ScaledMetric private var quickMedicationSpacing: CGFloat = 8
	@ScaledMetric private var iconWidth: CGFloat = 24
	private let progressViewSize: CGFloat = 20
	@ScaledMetric private var overlayPadding: CGFloat = 4
	@ScaledMetric private var citationPadding: CGFloat = 12
	@ScaledMetric private var buttonSpacing: CGFloat = 4
	@ScaledMetric private var buttonHorizontalPadding: CGFloat = 12
	@ScaledMetric private var buttonVerticalPadding: CGFloat = 10
	@ScaledMetric private var buttonCornerRadius: CGFloat = 8
	@ScaledMetric private var pillIconSpacing: CGFloat = 4
	@ScaledMetric private var badgeHorizontalPadding: CGFloat = 4
	@ScaledMetric private var badgeVerticalPadding: CGFloat = 2
	@ScaledMetric private var checkmarkOffset: CGFloat = 8

	private let debounceDelay: TimeInterval = 0.5 // Increased to prevent flashing

	// MARK: - Body

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Search Field
			searchFieldView

			// Suggestions Overlay
			if showSuggestions, isFocused {
				suggestionsOverlay
			}

			quickMedicationCapsules
		}
		.onTapGesture {
			// Prevent dismissing keyboard when tapping within component
		}
		.onDisappear {
			searchTask?.cancel()
			searchRequestID = UUID()
		}
	}

	// MARK: - View Components

	private var searchFieldView: some View {
		HStack(spacing: sectionSpacing) {
			if !dynamicTypeSize.isAccessibilitySize {
				Image(systemSymbol: .pillsFill)
					.foregroundColor(.accent)
					.font(.customFont(fontFamily, style: .title3))
					.frame(width: 24)
					.accessibilityHidden(true)
			}

			Group {
				if demoMode.isEnabled {
					SecureField("Medication name", text: $text)
						.demoNameRedacted()
				} else {
					TextField(dynamicTypeSize.isAccessibilitySize ? String(localized: "Name") : placeholder, text: $text)
				}
			}
				.accessibilityLabel("Medication name, required")
				.accessibilityHint("Type a name or choose a search result.")
				.textFieldStyle(.plain)
				.font(.customFont(fontFamily, style: .body, weight: .medium))
				.frame(maxWidth: .infinity, minHeight: 44)
				.layoutPriority(1)
				.autocapitalization(.words)
				.disableAutocorrection(true)
				.focused($isFocused)
				.onChange(of: text) { _, newValue in
					handleTextChange(newValue)
				}
				.onSubmit {
					showSuggestions = false
					isFocused = false
				}

			if isSearching {
				ProgressView()
					.scaleEffect(0.8)
					.frame(width: progressViewSize, height: progressViewSize)
			}
			if !text.isEmpty {
				Button(action: {
					searchTask?.cancel()
					searchRequestID = UUID()
					withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
						text = ""
						suggestions = []
						showSuggestions = false
						selectedMedication = nil
						isSearching = false
					}
				}) {
					Image(systemSymbol: .xmarkCircleFill)
						.foregroundColor(.gray)
						.font(.title3)
						.frame(minWidth: 44, minHeight: 44)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Clear medication name")
			}
		}
		.id(scrollID)
		.padding(.horizontal, fieldHorizontalPadding)
		.padding(.vertical, fieldVerticalPadding)
		.background {
			if animateSelection {
				RoundedRectangle(cornerRadius: fieldCornerRadius)
					.fill(.accent.opacity(0.08))
					.overlay(
						RoundedRectangle(cornerRadius: fieldCornerRadius)
							.strokeBorder(.accent, lineWidth: 2)
					)
			} else if isFocused {
				RoundedRectangle(cornerRadius: fieldCornerRadius)
					.fill(Color(.systemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: fieldCornerRadius)
							.strokeBorder(.accent.opacity(0.4), lineWidth: 1.5)
					)
			} else {
				RoundedRectangle(cornerRadius: fieldCornerRadius)
					.fill(.regularMaterial)
					.overlay(
						RoundedRectangle(cornerRadius: fieldCornerRadius)
							.strokeBorder(Color(.separator).opacity(0.2), lineWidth: fieldBorderWidth)
					)
			}
		}
		.animation(.easeInOut(duration: 0.2), value: isFocused)
		.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: animateSelection)
	}

	private var suggestionsOverlay: some View {
		VStack(spacing: 0) {
			// Quick suggestions if no search results yet
			if suggestions.isEmpty && text.isEmpty {
				quickSuggestionsView
			} else if !suggestions.isEmpty {
				searchResultsView
			} else if isSearching {
				loadingView
			} else if !text.isEmpty && suggestions.isEmpty {
				noResultsView
			}

			// Citation footer for medical data
			if !suggestions.isEmpty || !text.isEmpty {
				medicationDataCitation
			}
		}
		.frame(maxHeight: 400)
		.background(
			RoundedRectangle(cornerRadius: fieldCornerRadius)
				.fill(Color(.systemBackground))
				.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
		)
		.padding(.top, overlayPadding)
		.transition(reduceMotion ? .opacity : .asymmetric(
			insertion: .move(edge: .top).combined(with: .opacity),
			removal: .opacity
		))
		.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: showSuggestions)
	}

	private var quickSuggestionsView: some View {
		VStack(alignment: .leading, spacing: 0) {
			// Recent Searches
			if !searchService.recentSearches.isEmpty {
				sectionHeader(String(localized: "Recent Searches"))
				ForEach(searchService.recentSearches.prefix(3), id: \.self) { recent in
					suggestionRow(
						title: recent,
						subtitle: nil,
						icon: .clockArrowTriangleheadCounterclockwiseRotate90,
						action: {
							text = recent
						}
					)
				}
			}

			// Popular Medications
			sectionHeader(String(localized: "Popular Medications"))
			ForEach(searchService.popularMedications.prefix(5), id: \.rxCUI) { drug in
				suggestionRow(
					title: drug.name,
					subtitle: nil,
					icon: .starFill,
					iconColor: .orange,
					action: {
						selectDrug(drug, nickname: drug.name)
					}
				)
			}
		}
	}

	private var searchResultsView: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 0) {
				sectionHeader(String(localized: "Search Results"))
				ForEach(suggestions, id: \.drug.rxCUI) { result in
					drugResultRow(result)
				}
			}
		}
	}

	private var loadingView: some View {
		VStack(spacing: 16) {
			ProgressView()
			Text("Searching medications...")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 32)
	}

	private var noResultsView: some View {
		VStack(spacing: 12) {
			Image(systemSymbol: .magnifyingglass)
				.font(.largeTitle)
				.foregroundColor(.secondary)
			Text("No medications found")
				.font(.headline)
			Text("Try checking your spelling or using a different name")
				.font(.caption)
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 24)
		.padding(.horizontal, 16)
	}

	private var medicationDataCitation: some View {
		VStack(spacing: 4) {
			Divider()
			HStack(spacing: 4) {
				Text("Data provided by")
					.font(.caption2)
					.foregroundColor(.secondary)
				Button(action: {
					if let url = URL(string: "https://www.nlm.nih.gov/research/umls/rxnorm/") {
						UIApplication.shared.open(url)
					}
				}) {
					Text("NIH/NLM RxNorm")
						.font(.caption2)
						.fontWeight(.medium)
						.foregroundColor(.accent)
						.underline()
				}
				.buttonStyle(.plain)
			}
			.padding(.vertical, 8)
			.padding(.horizontal, 12)
		}
	}

	// MARK: - Helper Views

	private func sectionHeader(_ title: String) -> some View {
		Text(title)
			.font(.caption)
			.fontWeight(.semibold)
			.foregroundColor(.secondary)
			.textCase(.uppercase)
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(.systemGray6))
			.accessibilityAddTraits(.isHeader)
	}

	private func suggestionRow(
		title: String,
		subtitle: String?,
		icon: SFSymbol,
		iconColor: Color = .accent,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			HStack(spacing: 12) {
				Image(systemSymbol: icon)
					.font(.body)
					.foregroundColor(iconColor)
					.frame(width: 24)

				VStack(alignment: .leading, spacing: 2) {
					Text(demoMode.name(title))
						.demoNameRedacted()
						.font(.body)
						.foregroundColor(.primary)

					if let subtitle {
						Text(demoMode.name(subtitle))
							.demoNameRedacted()
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}

				Spacer()

				Image(systemSymbol: .chevronRight)
					.font(.caption.weight(.semibold))
					.foregroundStyle(Color.secondary)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.contentShape(Rectangle())
		}
		.buttonStyle(SuggestionButtonStyle())
	}

	private func drugResultRow(_ result: RxNormSearchResult) -> some View {
		Button(action: { selectDrug(result.drug, nickname: result.drug.name) }) {
			HStack(spacing: 12) {
				// Icon with relevance indicator
				ZStack {
					Image(systemSymbol: .pillsFill)
						.font(.body)
						.foregroundColor(.accent)

					if result.score >= 0.95 {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.caption2)
							.foregroundColor(.green)
							.offset(x: 8, y: -8)
							.accessibilityHidden(true) // Conveyed in accessibility label
					}
				}
				.frame(width: 24)
				.accessibilityHidden(true) // Decorative

				VStack(alignment: .leading, spacing: 3) {
					HStack(spacing: 6) {
						Text(demoMode.name(result.drug.name))
							.demoNameRedacted()
							.font(.body)
							.foregroundColor(.primary)
							.noTruncate()
							.multilineTextAlignment(.leading)

						if result.isExactMatch {
							Text("EXACT")
								.font(.caption2.weight(.bold))
								.contrastingForeground(against: .green)
								.padding(.horizontal, 4)
								.padding(.vertical, 2)
								.background(Capsule().fill(Color.green))
								.accessibilityHidden(true) // Conveyed in accessibility label
						}
					}
				}

				Spacer()

				Image(systemSymbol: .plusCircleFill)
					.font(.title3)
					.foregroundColor(.accent)
					.rotationEffect(.degrees(!reduceMotion && selectedMedication?.rxCUI == result.drug.rxCUI ? 45 : 0))
					.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: selectedMedication?.rxCUI == result.drug.rxCUI)
					.accessibilityHidden(true) // Decorative
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.contentShape(Rectangle())
			.background(
				selectedMedication?.rxCUI == result.drug.rxCUI ?
					.accent.opacity(0.08) : Color.clear
			)
		}
		.buttonStyle(SuggestionButtonStyle())
		.accessibilityLabel(demoMode.name(result.drug.name) + (result.isExactMatch ? String(localized: ", exact match") : "") + (result.score >= 0.95 ? String(localized: ", high confidence") : ""))
		.accessibilityHint("Double tap to select this medication")
		.accessibilityAddTraits(.isButton)
	}

	private var quickMedicationCapsules: some View {
		DisclosureGroup(isExpanded: $isQuickMedicationsExpanded) {
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
				ForEach(simplifiedCommonMedications, id: \.clinicalName) { medication in
					simplifiedMedicationButton(medication)
				}
			}
			.padding(.top, 8)
		} label: {
			Text("Common Medications")
				.font(.customFont(fontFamily, style: .subheadline))
		}
	}

	private func simplifiedMedicationButton(_ medication: CommonMedication) -> some View {
		Button(action: {
			searchTask?.cancel()
			searchRequestID = UUID()
			// Set the simplified clinical name
			let simplifiedName = MedicationNameSimplifier.simplifyName(medication.clinicalName)
			text = simplifiedName

			// Get brand name or use simplified name as nickname
			let nickname = MedicationNameSimplifier.getCommonBrandName(for: simplifiedName) ?? medication.brandName

			onMedicationSelected((clinicalName: simplifiedName, nickname: nickname))
			showSuggestions = false
			isFocused = false
		}) {
			HStack(spacing: 4) {
				Image(systemSymbol: .pillsFill)
					.font(.caption)

				Text(demoMode.name(medication.brandName))
					.demoNameRedacted()
					.font(.customFont(fontFamily, style: .caption, weight: .medium))
					.noTruncate()
			}
			.foregroundColor(.primary)
			.frame(maxWidth: .infinity)
			.padding(.horizontal, 12)
			.padding(.vertical, 10)
			.frame(minHeight: 44)
			.background(
				RoundedRectangle(cornerRadius: 8)
					.fill(Color(.systemGray6))
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(Color(.systemGray4), lineWidth: 0.5)
					)
			)
		}
		.buttonStyle(.plain)
		.scaleEffect(!reduceMotion && text == medication.clinicalName ? 0.95 : 1.0)
		.animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: text == medication.clinicalName)
	}

	/// Simplified list with just the most common medications
	private var simplifiedCommonMedications: [CommonMedication] {
		[
			CommonMedication(clinicalName: "Acetaminophen", brandName: "Tylenol"),
			CommonMedication(clinicalName: "Ibuprofen", brandName: "Advil"),
			CommonMedication(clinicalName: "Aspirin", brandName: "Aspirin"),
			CommonMedication(clinicalName: "Diphenhydramine", brandName: "Benadryl"),
			CommonMedication(clinicalName: "Loratadine", brandName: "Claritin"),
			CommonMedication(clinicalName: "Cetirizine", brandName: "Zyrtec"),
			CommonMedication(clinicalName: "Calcium Carbonate", brandName: "Tums"),
			CommonMedication(clinicalName: "Loperamide", brandName: "Imodium"),
		]
	}

	// MARK: - Actions

	private func handleTextChange(_ newValue: String) {
		searchTask?.cancel()
		let requestID = UUID()
		searchRequestID = requestID
		suggestions = []

		let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

		// Reset selection if text changes after selection
		if selectedMedication != nil, text != selectedMedication?.name {
			selectedMedication = nil
			animateSelection = false
		}

		if trimmed.isEmpty || !isFocused || selectedMedication?.name == newValue {
			suggestions = []
			showSuggestions = trimmed.isEmpty && isFocused
			isSearching = false
			return
		}

		// Don't show cached suggestions immediately - wait for debounce
		// This prevents flashing of temporary results
		showSuggestions = true
		isSearching = true // Show loading state during debounce

		// Debounced API search
		searchTask = Task {
			try? await Task.sleep(for: .milliseconds(Int(debounceDelay * 1000)))

			guard !Task.isCancelled else { return }

			// Show cached suggestions first if available
			let cachedDrugs = searchService.getSuggestions(for: trimmed)
			if !cachedDrugs.isEmpty {
				await MainActor.run {
					guard !Task.isCancelled, searchRequestID == requestID,
					      text.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
					// Convert to RxNormSearchResult first
					let cachedResults = cachedDrugs.map { drug in
						RxNormSearchResult(
							drug: drug,
							score: 0.8,
							source: .direct,
							isExactMatch: false,
							matchedTerm: drug.name
						)
					}

					// Process through name simplifier for proper deduplication
					let processedResults = MedicationNameSimplifier.processSearchResults(cachedResults)
					let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

					// Convert back to RxNormSearchResult format with simplified names
					let simplifiedCached = deduplicatedResults.map { result in
						RxNormSearchResult(
							drug: RxNormDrug(rxCUI: result.original.drug.rxCUI, name: result.clinicalName),
							score: result.original.score,
							source: result.original.source,
							isExactMatch: result.original.isExactMatch,
							matchedTerm: result.clinicalName
						)
					}

					suggestions = simplifiedCached
					isSearching = false
				}
			}

			// Then perform actual search
			guard !Task.isCancelled else { return }
			await performSearch(trimmed, requestID: requestID)
		}
	}

	private func performSearch(_ query: String, requestID: UUID) async {
		let shouldSearch = await MainActor.run {
			guard searchRequestID == requestID else { return false }
			isSearching = true
			return true
		}
		guard shouldSearch, !Task.isCancelled else { return }

		// Use enhanced search for better results with scoring
		let results = await searchService.searchMedicationsEnhanced(query)

		await MainActor.run {
			guard !Task.isCancelled, searchRequestID == requestID,
			      text.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
			// Merge with existing cached suggestions and deduplicate
			var allSuggestions = suggestions
			allSuggestions.append(contentsOf: results)

			// Process all suggestions through name simplifier for proper deduplication
			let processedResults = MedicationNameSimplifier.processSearchResults(allSuggestions)
			let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

			// Convert back to RxNormSearchResult format with simplified names
			let finalSuggestions = deduplicatedResults.map { result in
				RxNormSearchResult(
					drug: RxNormDrug(rxCUI: result.original.drug.rxCUI, name: result.clinicalName),
					score: result.original.score,
					source: result.original.source,
					isExactMatch: result.original.isExactMatch,
					matchedTerm: result.clinicalName
				)
			}

			suggestions = finalSuggestions
			isSearching = false
			showSuggestions = true
		}
	}

	private func selectDrug(_ drug: RxNormDrug, nickname: String) {
		// Animate selection
		withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
			selectedMedication = drug
			animateSelection = true
		}

		// Update text
		text = drug.name

		// Call callback with both clinical name and nickname
		onMedicationSelected((clinicalName: drug.name, nickname: nickname))

		// Delay hiding suggestions to show selection animation
		Task {
			try? await Task.sleep(for: .milliseconds(300))
			await MainActor.run {
				guard selectedMedication?.rxCUI == drug.rxCUI else { return }
				showSuggestions = false
				suggestions = []
				isFocused = false
				animateSelection = false
			}
		}

		searchTask?.cancel()
		searchRequestID = UUID()
	}
}

// MARK: - Supporting Types

struct CommonMedication {
	let clinicalName: String
	let brandName: String
}

struct CapsuleButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? 0.95 : 1.0)
			.brightness(configuration.isPressed ? -0.1 : 0)
			.animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
	}
}

struct SuggestionButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.background(
				configuration.isPressed
					? Color(.systemGray5)
					: Color.clear
			)
			.animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
	}
}

// MARK: - Preview

#Preview {
	VStack(spacing: 32) {
		VStack(alignment: .leading, spacing: 8) {
			Text("Clinical Name")
				.font(.subheadline)
				.foregroundStyle(.secondary)

			EnhancedMedicationSearchField(
				text: .constant(""),
				placeholder: "Search for medication...",
				scrollID: nil as String?,
				onMedicationSelected: { _, _ in
					DHLogger.ui.oslog.debug("Medication selected: clinical=\\(clinicalName, privacy: .private) nickname=\\(nickname, privacy: .private)")
				}
			)
		}

		Spacer()
	}
	.padding()
}
