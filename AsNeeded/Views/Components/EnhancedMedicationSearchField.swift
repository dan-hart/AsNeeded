//
//  EnhancedMedicationSearchField.swift
//  AsNeeded
//
//  Beautiful and functional medication search field with RxNorm integration
//

import SwiftUI
import SwiftRxNorm
import SFSafeSymbols

struct EnhancedMedicationSearchField: View {
	// MARK: - Properties

	@Binding var text: String
	let placeholder: String
	let onMedicationSelected: ((clinicalName: String, nickname: String)) -> Void
	
	@StateObject private var searchService = MedicationSearchService.shared
	@State private var suggestions: [RxNormDrug] = []
	@State private var showSuggestions = false
	@State private var isSearching = false
	@State private var searchTask: Task<Void, Never>?
	@State private var isQuickMedicationsExpanded = false
	@FocusState private var isFocused: Bool
	
	private let debounceDelay: TimeInterval = 0.3
	
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
				.font(.system(size: 18))
			
			TextField(placeholder, text: $text)
				.textFieldStyle(.plain)
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
					text = ""
					suggestions = []
					showSuggestions = false
				}) {
					Image(systemSymbol: .xmarkCircleFill)
						.foregroundColor(.gray)
						.font(.system(size: 18))
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.background(
			RoundedRectangle(cornerRadius: 12)
				.fill(Color(.systemGray6))
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
				)
		)
		.animation(.easeInOut(duration: 0.2), value: isFocused)
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
					subtitle: "RxCUI: \(drug.rxCUI)",
					icon: .starFill,
					iconColor: .orange,
					action: {
						selectDrug(drug)
					}
				)
			}
		}
	}
	
	private var searchResultsView: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 0) {
				sectionHeader("Search Results")
				ForEach(suggestions, id: \.rxCUI) { drug in
					drugResultRow(drug)
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
	
	private func drugResultRow(_ drug: RxNormDrug) -> some View {
		Button(action: { selectDrug(drug) }) {
			HStack(spacing: 12) {
				Image(systemSymbol: .pillsFill)
					.font(.system(size: 16))
					.foregroundColor(.accentColor)
					.frame(width: 24)
				
				VStack(alignment: .leading, spacing: 2) {
					Text(drug.name)
						.font(.body)
						.foregroundColor(.primary)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
					
					Text("RxCUI: \(drug.rxCUI)")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				Spacer()
				
				Image(systemSymbol: .plusCircleFill)
					.font(.system(size: 20))
					.foregroundColor(.accentColor)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.contentShape(Rectangle())
		}
		.buttonStyle(SuggestionButtonStyle())
	}
	
	private var quickMedicationCapsules: some View {
		VStack(alignment: .leading, spacing: 8) {
			Button(action: {
				withAnimation(.easeInOut(duration: 0.3)) {
					isQuickMedicationsExpanded.toggle()
				}
			}) {
				HStack {
					Text("Common As-Needed Medications")
						.font(.caption)
						.fontWeight(.semibold)
						.foregroundColor(.secondary)
						.textCase(.uppercase)
					
					Spacer()
					
					Image(systemSymbol: isQuickMedicationsExpanded ? .chevronUp : .chevronDown)
						.font(.caption)
						.foregroundColor(.secondary)
						.rotationEffect(.degrees(isQuickMedicationsExpanded ? 0 : 0))
				}
			}
			.buttonStyle(.plain)
			
			if isQuickMedicationsExpanded {
				LazyVGrid(columns: [
					GridItem(.flexible(), spacing: 6),
					GridItem(.flexible(), spacing: 6),
					GridItem(.flexible(), spacing: 6)
				], spacing: 8) {
					ForEach(commonAsNeededMedications, id: \.clinicalName) { medication in
						medicationCapsule(medication)
					}
				}
				.transition(.asymmetric(
					insertion: .opacity.combined(with: .move(edge: .top)),
					removal: .opacity
				))
			}
		}
	}
	
	private func medicationCapsule(_ medication: CommonMedication) -> some View {
		Button(action: {
			text = medication.clinicalName
			onMedicationSelected((clinicalName: medication.clinicalName, nickname: medication.brandName))
			showSuggestions = false
			isFocused = false
		}) {
			Text(medication.brandName)
				.font(.caption)
				.fontWeight(.semibold)
				.foregroundColor(.white)
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
				.background(
					Capsule()
						.fill(
							LinearGradient(
								colors: [.accentColor.opacity(0.9), .accentColor.opacity(0.7)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.overlay(
							Capsule()
								.stroke(Color.white.opacity(0.2), lineWidth: 1)
						)
						.shadow(color: .accentColor.opacity(0.4), radius: 3, x: 0, y: 2)
				)
		}
		.buttonStyle(CapsuleButtonStyle())
		.scaleEffect(text == medication.clinicalName ? 1.05 : 1.0)
		.animation(.spring(response: 0.3, dampingFraction: 0.6), value: text == medication.clinicalName)
	}
	
	private var commonAsNeededMedications: [CommonMedication] {
		[
			CommonMedication(clinicalName: "Acetaminophen", brandName: "Tylenol"),
			CommonMedication(clinicalName: "Ibuprofen", brandName: "Advil"),
			CommonMedication(clinicalName: "Ibuprofen", brandName: "Motrin"),
			CommonMedication(clinicalName: "Aspirin", brandName: "Aspirin"),
			CommonMedication(clinicalName: "Diphenhydramine", brandName: "Benadryl"),
			CommonMedication(clinicalName: "Loratadine", brandName: "Claritin"),
			CommonMedication(clinicalName: "Cetirizine", brandName: "Zyrtec"),
			CommonMedication(clinicalName: "Pseudoephedrine", brandName: "Sudafed"),
			CommonMedication(clinicalName: "Calcium Carbonate", brandName: "Tums"),
			CommonMedication(clinicalName: "Bismuth Subsalicylate", brandName: "Pepto-Bismol"),
			CommonMedication(clinicalName: "Loperamide", brandName: "Imodium"),
			CommonMedication(clinicalName: "Aluminum/Magnesium Hydroxide", brandName: "Mylanta"),
			CommonMedication(clinicalName: "Albuterol", brandName: "ProAir"),
			CommonMedication(clinicalName: "Acetaminophen/Aspirin/Caffeine", brandName: "Excedrin"),
			CommonMedication(clinicalName: "Guaifenesin", brandName: "Mucinex"),
			CommonMedication(clinicalName: "Dextromethorphan", brandName: "Robitussin")
		]
	}
	
	// MARK: - Actions

	private func handleTextChange(_ newValue: String) {
		searchTask?.cancel()
		
		let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
		
		if trimmed.isEmpty {
			suggestions = []
			showSuggestions = true
			isSearching = false
			return
		}
		
		// Show instant suggestions from cache
		suggestions = searchService.getSuggestions(for: trimmed)
		showSuggestions = true
		
		// Debounced API search
		searchTask = Task {
			try? await Task.sleep(for: .milliseconds(Int(debounceDelay * 1000)))
			
			guard !Task.isCancelled else { return }
			
			await performSearch(trimmed)
		}
	}
	
	private func performSearch(_ query: String) async {
		await MainActor.run {
			isSearching = true
		}
		
		let results = await searchService.searchMedications(query)
		
		await MainActor.run {
			self.suggestions = results
			self.isSearching = false
			self.showSuggestions = true
		}
	}
	
	private func selectDrug(_ drug: RxNormDrug) {
		text = drug.name
		showSuggestions = false
		suggestions = []
		isFocused = false
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
					print("Selected: \(clinicalName) (\(nickname))")
				}
			)
		}
		
		Spacer()
	}
	.padding()
}
