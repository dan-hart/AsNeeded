/// ExpandableNoteEditorComponent - An enhanced note entry component with expandable UI
///
/// This component provides a sophisticated note-taking experience with two modes:
/// - Compact mode: Shows a tappable field with placeholder text and visual hints
/// - Expanded mode: Full-screen editor with keyboard focus, character count, and quick phrases
///
/// Key features:
/// - Smooth animations between compact and expanded states
/// - Auto-focus keyboard when expanded
/// - Character counter with limits
/// - Integration with quick phrase suggestions
/// - Visual feedback for note presence
///
/// Use cases:
/// - Primary note entry in LogDoseView when logging medication
/// - Editing existing notes in MedicationHistoryView
/// - Any form requiring enhanced text input with better UX
/// - Settings or profile screens needing detailed text entry

import SwiftUI
import SFSafeSymbols

struct ExpandableNoteEditorComponent: View {
	@Binding var noteText: String
	var placeholder: String = "How are you feeling? Any side effects?"
	var medicationName: String? = nil
	var onSave: (() -> Void)? = nil

	@State private var isExpanded = false
	@State private var localText: String = ""
	@FocusState private var isTextFieldFocused: Bool
	@StateObject private var featureToggleManager = FeatureToggleManager.shared
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dismiss) private var dismiss

	// Scaled metrics
	@ScaledMetric private var compactHeight: CGFloat = 56
	@ScaledMetric private var expandedMinHeight: CGFloat = 200
	@ScaledMetric private var padding12: CGFloat = 12
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var padding8: CGFloat = 8
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var cornerRadius16: CGFloat = 16
	@ScaledMetric private var spacing8: CGFloat = 8
	@ScaledMetric private var spacing12: CGFloat = 12
	@ScaledMetric private var spacing16: CGFloat = 16
	@ScaledMetric private var iconSize: CGFloat = 20

	private let hapticsManager = HapticsManager.shared

	private var hasContent: Bool {
		!noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	// MARK: - Compact View
	private var compactView: some View {
		Button {
			localText = noteText
			isExpanded = true
			hapticsManager.lightImpact()
		} label: {
			HStack(spacing: spacing12) {
				Image(systemSymbol: .noteText)
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(hasContent ? .accent : .secondary)

				VStack(alignment: .leading, spacing: 2) {
					if hasContent {
						Text(noteText)
							.font(.customFont(fontFamily, style: .body))
							.foregroundStyle(.primary)
							.lineLimit(1)
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
						Text(placeholder)
							.font(.customFont(fontFamily, style: .body))
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}

					if hasContent {
						Text("Tap to edit")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
					}
				}

				Spacer()

				Image(systemSymbol: hasContent ? .pencilCircleFill : .plusCircle)
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(hasContent ? .accent : .secondary)
			}
			.padding(padding12)
			.frame(minHeight: compactHeight)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
					.fill(hasContent ? Color.accent.opacity(0.08) : Color.secondary.opacity(0.08))
			)
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
					.strokeBorder(hasContent ? Color.accent.opacity(0.2) : Color.clear, lineWidth: 1)
			)
		}
		.buttonStyle(.plain)
	}

	// MARK: - Save Button
	private var saveButton: some View {
		Button(action: {
			withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
				noteText = localText.trimmingCharacters(in: .whitespacesAndNewlines)
				isExpanded = false
				onSave?()
				hapticsManager.lightImpact()
			}
		}) {
			HStack(spacing: spacing8) {
				Image(systemSymbol: .checkmarkCircle)
					.font(.customFont(fontFamily, style: .body))
				Text("Save Note")
					.font(.customFont(fontFamily, style: .headline))
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
					.fill(LinearGradient(
						colors: [.accent, .accent.opacity(0.9)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					))
					.shadow(color: .accent.opacity(0.3), radius: 4, x: 0, y: 2)
			)
		}
	}

	// MARK: - Expanded View
	private var expandedView: some View {
		NavigationStack {
			VStack(spacing: 0) {
				ScrollView {
					VStack(spacing: 0) {
						// Header with medication info if available
						if let medicationName = medicationName {
							HStack {
								Label("Note for \(medicationName)", systemSymbol: .pills)
									.font(.customFont(fontFamily, style: .subheadline))
									.foregroundStyle(.secondary)
								Spacer()
							}
							.padding(.horizontal, padding16)
							.padding(.vertical, padding8)
						}

						// Quick phrases (only if enabled)
						if featureToggleManager.quickPhrasesEnabled {
							NoteQuickPhrasesComponent(
								noteText: $localText,
								medicationName: medicationName
							)
							.padding(.horizontal, padding16)
							.padding(.bottom, padding8)
						}

						// Text field with vertical axis for multi-line support
						TextField(placeholder, text: $localText, axis: .vertical)
							.font(.customFont(fontFamily, style: .body))
							.lineLimit(8...20)
							.textFieldStyle(.plain)
							.focused($isTextFieldFocused)
							.padding(padding12)
							.background(
								RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
									.fill(colorScheme == .dark ?
										Color(uiColor: .tertiarySystemBackground) :
										Color(uiColor: .secondarySystemBackground))
							)
							.frame(minHeight: expandedMinHeight)
							.padding(.horizontal, padding16)
							.padding(.top, featureToggleManager.quickPhrasesEnabled ? 0 : padding16)
							.padding(.bottom, padding16)
							.onAppear {
								// Immediate focus attempt
								isTextFieldFocused = true
							}
					}
				}
				.scrollDismissesKeyboard(.interactively)

				// Sticky save button container
				VStack(spacing: 0) {
					Divider()
						.background(.separator.opacity(0.5))

					saveButton
						.padding(.horizontal, padding16)
						.padding(.vertical, padding12)
				}
				.background(.regularMaterial)
			}
			.navigationTitle("Add Note")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
							isExpanded = false
							localText = noteText // Reset to original
							hapticsManager.lightImpact()
						}
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
				}
			}
			.task {
				// Alternative focus approach using task
				try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
				isTextFieldFocused = true
			}
		}
	}

	// MARK: - Body
	var body: some View {
		VStack {
			compactView
		}
		.sheet(isPresented: $isExpanded) {
			expandedView
				.presentationDetents([.large])
				.interactiveDismissDisabled(!localText.isEmpty)
		}
		.onChange(of: isExpanded) { _, newValue in
			if newValue {
				// Focus with minimal delay for sheet animation
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
					isTextFieldFocused = true
				}
			} else {
				// Clear focus when dismissing
				isTextFieldFocused = false
			}
		}
	}
}

// MARK: - Preview
#if DEBUG
struct ExpandableNoteEditorComponent_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 20) {
			// Empty state
			ExpandableNoteEditorComponent(
				noteText: .constant(""),
				placeholder: "How are you feeling?",
				medicationName: "Ibuprofen"
			)

			// With content
			ExpandableNoteEditorComponent(
				noteText: .constant("Feeling better after taking this dose"),
				medicationName: "Acetaminophen"
			)
		}
		.padding()
	}
}
#endif