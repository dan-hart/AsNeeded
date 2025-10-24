/// NoteDisplayCardComponent - Enhanced visual display for medication notes
///
/// This component presents notes in an attractive, interactive card format with
/// expandable preview, visual indicators, and smooth animations. It provides
/// a better reading experience and clear affordances for editing.
///
/// Key features:
/// - Expandable text preview (2 lines → full text)
/// - Visual note icon and gradient background
/// - Tap to edit functionality
/// - Character limit indicators
/// - Smooth expand/collapse animations
/// - Accessibility support for VoiceOver
///
/// Use cases:
/// - Displaying notes in MedicationHistoryView
/// - Showing notes in medication detail views
/// - Any list or detail view requiring rich note display
/// - Medical records or journal entry displays

import SFSafeSymbols
import SwiftUI

struct NoteDisplayCardComponent: View {
    let noteText: String
    var medicationColor: Color = .accent
    var onTap: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    @State private var isExpanded = false
    @Environment(\.fontFamily) private var fontFamily
    @Environment(\.colorScheme) private var colorScheme

    // Scaled metrics
    @ScaledMetric private var iconSize: CGFloat = 16
    @ScaledMetric private var cardPadding: CGFloat = 12
    @ScaledMetric private var mediumPadding: CGFloat = 8
    @ScaledMetric private var smallPadding: CGFloat = 4
    @ScaledMetric private var cornerRadius12: CGFloat = 12
    @ScaledMetric private var elementSpacing: CGFloat = 8
    @ScaledMetric private var tightSpacing: CGFloat = 4
    @ScaledMetric private var editButtonSize: CGFloat = 28

    private let hapticsManager = HapticsManager.shared

    private var displayText: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLongNote: Bool {
        displayText.count > 100 || displayText.contains("\n")
    }

    private var previewText: String {
        if isExpanded || !isLongNote {
            return displayText
        } else {
            // Show first 100 characters or up to first newline
            let preview = String(displayText.prefix(100))
            if let newlineIndex = preview.firstIndex(of: "\n") {
                return String(preview[..<newlineIndex]) + "..."
            }
            return preview + "..."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Note content
            Button {
                if isLongNote {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                        hapticsManager.lightImpact()
                    }
                }
                onTap?()
            } label: {
                VStack(alignment: .leading, spacing: elementSpacing) {
                    // Header with icon and expand indicator
                    HStack(spacing: elementSpacing) {
                        Image(systemSymbol: .noteText)
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(medicationColor)

                        Text("Note")
                            .font(.customFont(fontFamily, style: .caption, weight: .medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if isLongNote {
                            Image(systemSymbol: isExpanded ? .chevronUp : .chevronDown)
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.secondary)
                                .transition(.scale.combined(with: .opacity))
                        }

                        if onEdit != nil {
                            Button {
                                onEdit?()
                                hapticsManager.selectionChanged()
                            } label: {
                                Image(systemSymbol: .pencilCircle)
                                    .font(.customFont(fontFamily, style: .footnote))
                                    .foregroundStyle(medicationColor)
                                    .frame(width: editButtonSize, height: editButtonSize)
                                    .background(
                                        Circle()
                                            .fill(medicationColor.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Note text
                    Text(previewText)
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(isExpanded ? nil : 3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)

                    // Metadata
                    if isExpanded && displayText.count > 100 {
                        HStack {
                            Spacer()
                            Text("\(displayText.count) characters")
                                .font(.customFont(fontFamily, style: .caption2))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, tightSpacing)
                    }
                }
                .padding(cardPadding)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                medicationColor.opacity(0.05),
                                medicationColor.opacity(0.02),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
                    .strokeBorder(
                        medicationColor.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note: \(displayText)")
        .accessibilityHint(isLongNote ? "Double tap to \(isExpanded ? "collapse" : "expand") note" : "")
    }
}

// MARK: - Add Note Button Component

struct AddNoteButtonComponent: View {
    var medicationColor: Color = .accent
    var onTap: () -> Void

    @Environment(\.fontFamily) private var fontFamily
    @State private var isPulsing = false

    // Scaled metrics
    @ScaledMetric private var horizontalPadding: CGFloat = 10
    @ScaledMetric private var verticalPadding: CGFloat = 6
    @ScaledMetric private var textSpacing: CGFloat = 4

    private let hapticsManager = HapticsManager.shared

    var body: some View {
        Button {
            onTap()
            hapticsManager.selectionChanged()
        } label: {
            HStack(spacing: textSpacing) {
                Text("Add Note")
                    .font(.customFont(fontFamily, style: .subheadline))
                Image(systemSymbol: .squareAndPencil)
                    .font(.customFont(fontFamily, style: .caption))
            }
            .foregroundStyle(medicationColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .scaleEffect(isPulsing ? 1.02 : 1.0)
        .animation(
            isPulsing ?
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                .default,
            value: isPulsing
        )
        .onAppear {
            // Subtle pulse animation to draw attention
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct NoteDisplayCardComponent_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 20) {
                // Short note
                NoteDisplayCardComponent(
                    noteText: "No side effects, feeling good.",
                    medicationColor: .blue,
                    onEdit: { print("Edit tapped") }
                )

                // Long note (expandable)
                NoteDisplayCardComponent(
                    noteText: """
                    Took the medication after breakfast. Initially felt a bit drowsy but that passed after about 30 minutes. \
                    Overall feeling much better than yesterday. The pain has reduced significantly and I'm able to move around more comfortably. \
                    Will continue monitoring for any other effects.
                    """,
                    medicationColor: .green,
                    onEdit: { print("Edit tapped") }
                )

                // Add note button
                AddNoteButtonComponent(
                    medicationColor: .orange,
                    onTap: { print("Add note tapped") }
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
#endif
