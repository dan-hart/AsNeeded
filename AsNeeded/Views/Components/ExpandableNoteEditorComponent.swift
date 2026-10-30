// ExpandableNoteEditorComponent - An enhanced note entry component with expandable UI
//
// This component provides a sophisticated note-taking experience with two modes:
// - Compact mode: Shows a tappable field with placeholder text and visual hints
// - Expanded mode: Full-screen editor with keyboard focus and character count
//
// Key features:
// - Smooth animations between compact and expanded states
// - Auto-focus keyboard when expanded
// - Character counter with limits
// - Visual feedback for note presence
//
// Use cases:
// - Primary note entry in LogDoseView when logging medication
// - Editing existing notes in MedicationHistoryView
// - Any form requiring enhanced text input with better UX
// - Settings or profile screens needing detailed text entry

import SFSafeSymbols
import SwiftUI

struct ExpandableNoteEditorComponent: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	@Binding var noteText: String
	var placeholder: String = String(localized: "How are you feeling? Any side effects?")
	var medicationName: String?
	var accentColor: Color = .accent
	var onSave: (() -> Void)?

	@State private var isExpanded = false
	@State private var localText: String = ""
	@State private var showingDiscardConfirmation = false
	@FocusState private var isTextFieldFocused: Bool
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	// Scaled metrics
	@ScaledMetric private var compactHeight: CGFloat = 56
	@ScaledMetric private var expandedMinHeight: CGFloat = 200
	@ScaledMetric private var standardPadding: CGFloat = 12
	@ScaledMetric private var horizontalPadding: CGFloat = 16
	@ScaledMetric private var verticalPadding: CGFloat = 8
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var cornerRadius16: CGFloat = 16
	@ScaledMetric private var buttonSpacing: CGFloat = 8
	@ScaledMetric private var elementSpacing: CGFloat = 12
	@ScaledMetric private var sectionSpacing: CGFloat = 16
	@ScaledMetric private var iconSize: CGFloat = 20

	private let hapticsManager = HapticsManager.shared

	private var hasContent: Bool {
		!noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var hasUnsavedChanges: Bool {
		localText != noteText
	}

	// MARK: - Compact View

	private var compactView: some View {
		Button {
			localText = noteText
			isExpanded = true
			hapticsManager.lightImpact()
		} label: {
			HStack(spacing: elementSpacing) {
				Image(systemSymbol: .noteText)
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(accentColor)

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
					.foregroundStyle(accentColor)
			}
			.padding(standardPadding)
			.frame(minHeight: compactHeight)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
					.fill(hasContent ? accentColor.opacity(0.08) : Color.secondary.opacity(0.08))
			)
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
					.strokeBorder(hasContent ? accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
			)
		}
		.buttonStyle(.plain)
	}

	// MARK: - Save Button

	private var saveButton: some View {
		Button(action: {
			withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
				noteText = localText.trimmingCharacters(in: .whitespacesAndNewlines)
				isExpanded = false
				onSave?()
				hapticsManager.lightImpact()
			}
		}) {
			HStack(spacing: buttonSpacing) {
				Image(systemSymbol: .checkmarkCircle)
					.font(.customFont(fontFamily, style: .body))
				Text("Save Note")
					.font(.customFont(fontFamily, style: .headline))
			}
			.foregroundStyle(accentColor.dynamicFilledButtonForeground)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
					.fill(LinearGradient(
						colors: [accentColor.dynamicFilledButtonBackground, accentColor.dynamicFilledButtonBackground],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					))
					.shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
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
						if let medicationName {
							HStack {
								Label("Note for \(demoMode.name(medicationName))", systemSymbol: .pills)
									.demoNameRedacted()
									.font(.customFont(fontFamily, style: .subheadline))
									.foregroundStyle(.secondary)
									.noTruncate()
								Spacer()
							}
							.padding(.horizontal, horizontalPadding)
							.padding(.vertical, verticalPadding)
						}

						// Text field with vertical axis for multi-line support
						TextField(placeholder, text: $localText, axis: .vertical)
							.font(.customFont(fontFamily, style: .body))
							.lineLimit(8 ... 20)
							.textFieldStyle(.plain)
							.focused($isTextFieldFocused)
							.padding(standardPadding)
							.background(
								RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
									.fill(colorScheme == .dark ?
										Color(uiColor: .tertiarySystemBackground) :
										Color(uiColor: .secondarySystemBackground))
							)
							.frame(minHeight: expandedMinHeight)
							.padding(.horizontal, horizontalPadding)
							.padding(.top, horizontalPadding)
							.padding(.bottom, horizontalPadding)
					}
				}
				.scrollDismissesKeyboard(.interactively)

				// Sticky save button container
				VStack(spacing: 0) {
					Divider()
						.background(.separator.opacity(0.5))

					saveButton
						.padding(.horizontal, horizontalPadding)
						.padding(.vertical, standardPadding)
				}
				.background(.regularMaterial)
			}
			.customNavigationTitle(hasContent ? "Edit Note" : "Add Note")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .close) {
						if hasUnsavedChanges {
							showingDiscardConfirmation = true
						} else {
							isExpanded = false
						}
					}
					.tint(accentColor)
				}
			}
			.tint(accentColor)
			.confirmationDialog("Discard note changes?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
				Button("Discard Changes", role: .destructive) {
					localText = noteText
					isExpanded = false
				}
				Button("Keep Editing", role: .cancel) {}
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
				.interactiveDismissDisabled(hasUnsavedChanges)
		}
		.onChange(of: isExpanded) { _, newValue in
			if !newValue {
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
					placeholder: String(localized: "How are you feeling?"),
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
