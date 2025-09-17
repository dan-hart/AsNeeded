//
//  EnhancedMedicationSearchField.swift
//  AsNeeded
//
//  Beautiful and functional medication search field with RxNorm integration
//

import SwiftUI
import SwiftRxNorm
import SFSafeSymbols
import DHLoggingKit

struct EnhancedMedicationSearchField: View {
	// MARK: - Properties

	@Binding var text: String
	let placeholder: String
	let onMedicationSelected: ((clinicalName: String, nickname: String)) -> Void
	
	@StateObject private var searchService = MedicationSearchService.shared
	@State private var suggestions: [RxNormSearchResult] = []
	@State private var showSuggestions = false
	@State private var isSearching = false
	@State private var searchTask: Task<Void, Never>?
	@State private var isQuickMedicationsExpanded = false
	@State private var selectedMedication: RxNormDrug?
	@State private var animateSelection = false
	@FocusState private var isFocused: Bool
	
	private let debounceDelay: TimeInterval = 0.5 // Increased to prevent flashing
	
	// MARK: - Body

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Quick Medication Capsules
			quickMedicationCapsules
			
			// Search Field
			searchFieldView
			
			// Suggestions Overlay
			if showSuggestions && isFocused {
				suggestionsOverlay
			}
		}
		.onTapGesture {
			// Prevent dismissing keyboard when tapping within component
		}
	}
	
	// MARK: - View Components

	private var searchFieldView: some View {
		HStack(spacing: 12) {
			Image(systemSymbol: .pillsFill)
				.foregroundColor(.accentColor)
				.font(.title3)
			
			TextField(placeholder, text: $text)
				.textFieldStyle(.plain)
				.font(.body.weight(.medium))
				.autocapitalization(.words)
				.disableAutocorrection(true)
				.focused($isFocused)
				.onChange(of: text) { _, newValue in
					handleTextChange(newValue)
				}
				.onSubmit {
					showSuggestions = false
				}
			
			
			if isSearching {
				ProgressView()
					.scaleEffect(0.8)
					.frame(width: 20, height: 20)
			} else if !text.isEmpty {
				Button(action: {
					withAnimation(.easeInOut(duration: 0.2)) {
						text = ""
						suggestions = []
						showSuggestions = false
						selectedMedication = nil
					}
				}) {
					Image(systemSymbol: .xmarkCircleFill)
						.foregroundColor(.gray)
						.font(.title3)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 14)
		.background(
			RoundedRectangle(cornerRadius: 12)
				.fill(
					animateSelection ? 
						Color.accentColor.opacity(0.08) : 
						(isFocused ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.strokeBorder(
							animateSelection ? Color.accentColor : 
							(isFocused ? Color.accentColor.opacity(0.4) : Color(.separator).opacity(0.2)),
							lineWidth: animateSelection ? 2 : (isFocused ? 1.5 : 1)
						)
				)
		)
		.animation(.easeInOut(duration: 0.2), value: isFocused)
		.animation(.spring(response: 0.3, dampingFraction: 0.7), value: animateSelection)
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
			RoundedRectangle(cornerRadius: 12)
				.fill(Color(.systemBackground))
				.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
		)
		.padding(.top, 4)
		.transition(.asymmetric(
			insertion: .move(edge: .top).combined(with: .opacity),
			removal: .opacity
		))
		.animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuggestions)
	}
	
	private var quickSuggestionsView: some View {
		VStack(alignment: .leading, spacing: 0) {
			// Recent Searches
			if !searchService.recentSearches.isEmpty {
				sectionHeader("Recent Searches")
				ForEach(searchService.recentSearches.prefix(3), id: \.self) { recent in
					suggestionRow(
						title: recent,
						subtitle: nil,
						icon: .clockArrowTriangleheadCounterclockwiseRotate90,
						action: {
							text = recent
							Task {
								await performSearch(recent)
							}
						}
					)
				}
			}
			
			// Popular Medications
			sectionHeader("Popular Medications")
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
				sectionHeader("Search Results")
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
				.font(.system(size: 32))
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
						.foregroundColor(.accentColor)
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
		iconColor: Color = .accentColor,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			HStack(spacing: 12) {
				Image(systemSymbol: icon)
					.font(.system(size: 16))
					.foregroundColor(iconColor)
					.frame(width: 24)
				
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.body)
						.foregroundColor(.primary)
					
					if let subtitle = subtitle {
						Text(subtitle)
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				
				Spacer()
				
				Image(systemSymbol: .chevronRight)
					.font(.system(size: 12, weight: .semibold))
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
						.foregroundColor(.accentColor)
					
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
						Text(result.drug.name)
							.font(.body)
							.foregroundColor(.primary)
							.lineLimit(2)
							.multilineTextAlignment(.leading)
						
						if result.isExactMatch {
							Text("EXACT")
								.font(.caption2.weight(.bold))
								.foregroundColor(.white)
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
					.foregroundColor(.accentColor)
					.rotationEffect(.degrees(selectedMedication?.rxCUI == result.drug.rxCUI ? 45 : 0))
					.animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedMedication?.rxCUI == result.drug.rxCUI)
					.accessibilityHidden(true) // Decorative
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.contentShape(Rectangle())
			.background(
				selectedMedication?.rxCUI == result.drug.rxCUI ?
				Color.accentColor.opacity(0.08) : Color.clear
			)
		}
		.buttonStyle(SuggestionButtonStyle())
		.accessibilityLabel(result.drug.name + (result.isExactMatch ? ", exact match" : "") + (result.score >= 0.95 ? ", high confidence" : ""))
		.accessibilityHint("Double tap to select this medication")
		.accessibilityAddTraits(.isButton)
	}
	
	private var quickMedicationCapsules: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Common Medications")
				.font(.caption)
				.fontWeight(.semibold)
				.foregroundColor(.secondary)
				.textCase(.uppercase)
			
			// Simplified grid with just the most common medications
			LazyVGrid(columns: [
				GridItem(.flexible(), spacing: 8),
				GridItem(.flexible(), spacing: 8)
			], spacing: 8) {
				ForEach(simplifiedCommonMedications, id: \.clinicalName) { medication in
					simplifiedMedicationButton(medication)
				}
			}
		}
	}
	
	private func simplifiedMedicationButton(_ medication: CommonMedication) -> some View {
		Button(action: {
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
					.font(.system(size: 12))
				
				Text(medication.brandName)
					.font(.system(size: 13, weight: .medium))
					.lineLimit(1)
			}
			.foregroundColor(.primary)
			.frame(maxWidth: .infinity)
			.padding(.horizontal, 12)
			.padding(.vertical, 10)
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
		.scaleEffect(text == medication.clinicalName ? 0.95 : 1.0)
		.animation(.easeInOut(duration: 0.1), value: text == medication.clinicalName)
	}
	
	// Simplified list with just the most common medications
	private var simplifiedCommonMedications: [CommonMedication] {
		[
			CommonMedication(clinicalName: "Acetaminophen", brandName: "Tylenol"),
			CommonMedication(clinicalName: "Ibuprofen", brandName: "Advil"),
			CommonMedication(clinicalName: "Aspirin", brandName: "Aspirin"),
			CommonMedication(clinicalName: "Diphenhydramine", brandName: "Benadryl"),
			CommonMedication(clinicalName: "Loratadine", brandName: "Claritin"),
			CommonMedication(clinicalName: "Cetirizine", brandName: "Zyrtec"),
			CommonMedication(clinicalName: "Calcium Carbonate", brandName: "Tums"),
			CommonMedication(clinicalName: "Loperamide", brandName: "Imodium")
		]
	}
	
	// MARK: - Actions

	private func handleTextChange(_ newValue: String) {
		searchTask?.cancel()
		
		let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Reset selection if text changes after selection
		if selectedMedication != nil && text != selectedMedication?.name {
			selectedMedication = nil
			animateSelection = false
		}
		
		if trimmed.isEmpty {
			suggestions = []
			showSuggestions = isFocused
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
			await performSearch(trimmed)
		}
	}
	
	private func performSearch(_ query: String) async {
		await MainActor.run {
			isSearching = true
		}
		
		// Use enhanced search for better results with scoring
		let results = await searchService.searchMedicationsEnhanced(query)
		
		await MainActor.run {
			// Merge with existing cached suggestions and deduplicate
			var allSuggestions = self.suggestions
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
			
			self.suggestions = finalSuggestions
			self.isSearching = false
			self.showSuggestions = true
		}
	}
	
	private func selectDrug(_ drug: RxNormDrug, nickname: String) {
		// Animate selection
		withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
				showSuggestions = false
				suggestions = []
				isFocused = false
				animateSelection = false
			}
		}
		
		searchTask?.cancel()
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
				onMedicationSelected: { clinicalName, nickname in
                    DHLogger.ui.oslog.debug("Medication selected: clinical=\\(clinicalName, privacy: .private) nickname=\\(nickname, privacy: .private)")
				}
			)
		}
		
		Spacer()
	}
	.padding()
}
