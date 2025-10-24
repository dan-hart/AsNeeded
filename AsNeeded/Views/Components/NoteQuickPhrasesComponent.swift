/// NoteQuickPhrasesComponent - Quick phrase suggestions for note entry
///
/// This component displays tappable chips with common phrases that users can quickly
/// add to their notes. It intelligently suggests phrases based on the medication type
/// and context, learning from common patterns.
///
/// Key features:
/// - Smart phrase suggestions based on medication type
/// - Tap to insert or append phrases
/// - Visual feedback on selection
/// - Horizontal scrollable layout for multiple options
/// - Customizable phrase sets
///
/// Use cases:
/// - Quick note entry in LogDoseView
/// - Note editing in MedicationHistoryView
/// - Any text input requiring common phrase suggestions
/// - Medical forms or symptom tracking interfaces

import SFSafeSymbols
import SwiftUI

struct NoteQuickPhrasesComponent: View {
    @Binding var noteText: String
    var medicationName: String? = nil
    var customPhrases: [String]? = nil

    @StateObject private var featureToggleManager = FeatureToggleManager.shared
    @Environment(\.fontFamily) private var fontFamily
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPhrase: String? = nil

    // Scaled metrics
    @ScaledMetric private var chipHeight: CGFloat = 32
    @ScaledMetric private var chipPaddingH: CGFloat = 12
    @ScaledMetric private var chipPaddingV: CGFloat = 6
    @ScaledMetric private var chipSpacing: CGFloat = 8
    @ScaledMetric private var cornerRadius16: CGFloat = 16

    private let hapticsManager = HapticsManager.shared

    // Default phrases for general use
    private let generalPhrases = [
        "No side effects",
        "Feeling good",
        "Mild discomfort",
        "As expected",
        "Better than before",
        "Some improvement",
    ]

    // Medication-specific phrase suggestions
    private var suggestedPhrases: [String] {
        if let custom = customPhrases {
            return custom
        }

        // Add medication-specific phrases based on common medication types
        var phrases = generalPhrases

        if let name = medicationName?.lowercased() {
            // Pain medications
            if name.contains("ibuprofen") || name.contains("acetaminophen") ||
                name.contains("aspirin") || name.contains("pain")
            {
                phrases = [
                    "Pain relieved",
                    "Still some pain",
                    "No side effects",
                    "Slight stomach upset",
                    "Working well",
                    "Partial relief",
                ]
            }
            // Sleep medications
            else if name.contains("sleep") || name.contains("melatonin") ||
                name.contains("zolpidem") || name.contains("ambien")
            {
                phrases = [
                    "Slept well",
                    "Drowsy",
                    "Restless",
                    "No effect",
                    "Groggy morning",
                    "Good rest",
                ]
            }
            // Anxiety medications
            else if name.contains("anxiety") || name.contains("xanax") ||
                name.contains("lorazepam") || name.contains("calm")
            {
                phrases = [
                    "Feeling calmer",
                    "Still anxious",
                    "Working well",
                    "Mild drowsiness",
                    "No side effects",
                    "Some relief",
                ]
            }
            // Allergy medications
            else if name.contains("allergy") || name.contains("cetirizine") ||
                name.contains("loratadine") || name.contains("benadryl")
            {
                phrases = [
                    "Symptoms improved",
                    "Still congested",
                    "No drowsiness",
                    "Slight drowsiness",
                    "Working well",
                    "Partial relief",
                ]
            }
        }

        return phrases
    }

    private func addPhrase(_ phrase: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            // If note is empty, just set it to the phrase
            if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                noteText = phrase
            } else {
                // Otherwise append with proper punctuation
                let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                let lastChar = trimmedNote.last

                // Add appropriate punctuation
                if lastChar == "." || lastChar == "!" || lastChar == "?" {
                    noteText = trimmedNote + " " + phrase
                } else {
                    noteText = trimmedNote + ". " + phrase
                }
            }

            // Visual feedback
            selectedPhrase = phrase
            hapticsManager.selectionChanged()

            // Clear selection after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedPhrase = nil
            }
        }
    }

    var body: some View {
        // Check if feature is enabled
        if featureToggleManager.quickPhrasesEnabled {
            VStack(alignment: .leading, spacing: chipSpacing) {
                Text("Quick phrases")
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: chipSpacing) {
                        ForEach(suggestedPhrases, id: \.self) { phrase in
                            Button {
                                addPhrase(phrase)
                            } label: {
                                Text(phrase)
                                    .font(.customFont(fontFamily, style: .footnote, weight: .medium))
                                    .foregroundStyle(selectedPhrase == phrase ? .white : .primary)
                                    .padding(.horizontal, chipPaddingH)
                                    .padding(.vertical, chipPaddingV)
                                    .background {
                                        if selectedPhrase == phrase {
                                            Capsule()
                                                .fill(Color.accent)
                                        } else {
                                            Capsule()
                                                .fill(.regularMaterial)
                                        }
                                    }
                                    .scaleEffect(selectedPhrase == phrase ? 1.05 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct NoteQuickPhrasesComponent_Previews: PreviewProvider {
        @State static var noteText = ""

        static var previews: some View {
            VStack(spacing: 20) {
                // General phrases
                NoteQuickPhrasesComponent(
                    noteText: $noteText
                )

                // Pain medication phrases
                NoteQuickPhrasesComponent(
                    noteText: $noteText,
                    medicationName: "Ibuprofen"
                )

                // Custom phrases
                NoteQuickPhrasesComponent(
                    noteText: $noteText,
                    customPhrases: ["Custom 1", "Custom 2", "Custom 3"]
                )

                Text("Current note: \(noteText)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
            }
            .padding()
        }
    }
#endif
