import SwiftUI
import SFSafeSymbols

/// A comprehensive medication information input section with enhanced search capabilities
///
/// Features:
/// - Required clinical name field with real-time medication search
/// - Optional nickname field for personalization
/// - Enhanced visual feedback for focused fields
/// - Comprehensive accessibility support
/// - Integrated glass card styling
///
/// **Appearance:**
/// - Section header with medication icon and title
/// - Clinical name field with search integration and focus animations
/// - Required field indicators and validation feedback
/// - Nickname field with optional label styling
/// - Consistent glass card background
///
/// **Use Cases:**
/// - Medication creation and editing forms
/// - Patient medication management interfaces
/// - Prescription data entry screens
/// - Medical record input sections
/// - Healthcare app medication forms
/// - Any form requiring medication identification with search
struct MedicationInfoSectionComponent<Field: Hashable, ScrollID: Hashable>: View {
	@Binding var clinicalName: String
	@Binding var nickname: String
	@FocusState.Binding var focusedField: Field?

	let clinicalNameField: Field
	let nicknameField: Field
	let searchFieldScrollID: ScrollID?
	let onMedicationSelected: (String, String) -> Void

	@ScaledMetric private var sectionSpacing: CGFloat = 20
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 28
	@ScaledMetric private var fieldContainerPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var borderWidth: CGFloat = 1
	@ScaledMetric private var focusedBorderWidth: CGFloat = 2
	@ScaledMetric private var fieldSpacing: CGFloat = 12
	@ScaledMetric private var innerVStackSpacing: CGFloat = 8
	@ScaledMetric private var requiredPaddingH: CGFloat = 8
	@ScaledMetric private var requiredPaddingV: CGFloat = 3
	@ScaledMetric private var optionalPaddingH: CGFloat = 8
	@ScaledMetric private var optionalPaddingV: CGFloat = 2

	var body: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			// Section header with icon
			HStack(spacing: headerSpacing) {
				Image(systemSymbol: .textBookClosedFill)
					.font(.title2)
					.foregroundStyle(
						LinearGradient(
							colors: [.accent, .accent.opacity(0.7)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				Text("Medication Information")
					.font(.headline)
					.fontWeight(.semibold)
					.accessibilityAddTraits(.isHeader)
			}

			// Clinical Name Field - Primary Input
			VStack(alignment: .leading, spacing: fieldSpacing) {
				// Enhanced header with better visual hierarchy
				HStack(spacing: innerVStackSpacing) {
					ZStack {
						Circle()
							.fill(.accent.opacity(0.15))
							.frame(width: iconSize, height: iconSize)

						Image(systemSymbol: .pill)
							.font(.subheadline.weight(.semibold))
							.foregroundColor(.accent)
							.accessibilityHidden(true) // Decorative icon
					}

					VStack(alignment: .leading, spacing: 2) {
						HStack(spacing: 4) {
							Text("Clinical Name")
								.font(.subheadline)
								.fontWeight(.semibold)
							Text("*")
								.foregroundStyle(.red)
								.font(.subheadline)
								.fontWeight(.bold)
								.accessibilityLabel("required")
						}
						.accessibilityElement(children: .combine)

						Text("Start typing to search medications")
							.font(.caption)
							.foregroundStyle(.secondary)
							.accessibilityHidden(true) // Redundant with field hint
					}

					Spacer()

					// Priority indicator
					if clinicalName.isEmpty {
						Text("REQUIRED")
							.font(.caption2.weight(.bold))
							.foregroundStyle(.white)
							.padding(.horizontal, requiredPaddingH)
							.padding(.vertical, requiredPaddingV)
							.background(
								Capsule()
									.fill(.accent)
							)
							.accessibilityLabel("Required field indicator")
							.accessibilityHidden(true) // Hide from VoiceOver since it's already conveyed in the hint
					}
				}

				// Enhanced search field container
				VStack(spacing: 0) {
					EnhancedMedicationSearchField(
						text: $clinicalName,
						placeholder: "Type medication name (e.g., Ibuprofen, Tylenol)",
						scrollID: searchFieldScrollID,
						onMedicationSelected: { clinicalName, nickname in
							onMedicationSelected(clinicalName, nickname)
						}
					)
					.focused($focusedField, equals: clinicalNameField)
					.accessibilityLabel("Clinical Name")
					.accessibilityHint("Required field. Type to search for medications.")
					.accessibilityValue(clinicalName.isEmpty ? "Empty" : clinicalName)
				}
				.padding(fieldContainerPadding)
				.background(
					RoundedRectangle(cornerRadius: cornerRadius)
						.fill(.ultraThinMaterial)
						.overlay(
							RoundedRectangle(cornerRadius: cornerRadius)
								.strokeBorder(
									focusedField == clinicalNameField ?
										.accent.opacity(0.6) :
										Color(.separator).opacity(0.3),
									lineWidth: focusedField == clinicalNameField ? focusedBorderWidth : borderWidth
								)
						)
						.shadow(
							color: focusedField == clinicalNameField ?
								.accent.opacity(0.2) :
								Color.black.opacity(0.05),
							radius: focusedField == clinicalNameField ? 8 : 4,
							x: 0,
							y: focusedField == clinicalNameField ? 4 : 2
						)
				)
				.scaleEffect(focusedField == clinicalNameField ? 1.02 : 1.0)
				.animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField)
			}

			// Nickname Field
			VStack(alignment: .leading, spacing: innerVStackSpacing) {
				Label {
					HStack(spacing: 4) {
						Text("Nickname")
							.font(.subheadline)
							.fontWeight(.medium)
						Text("Optional")
							.font(.caption)
							.foregroundStyle(.tertiary)
							.padding(.horizontal, optionalPaddingH)
							.padding(.vertical, optionalPaddingV)
							.background(
								Capsule()
									.fill(Color(.tertiarySystemFill))
							)
					}
				} icon: {
					Image(systemSymbol: .tagFill)
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				TextField("Personal name for easy identification", text: $nickname)
					.textFieldStyle(.roundedBorder)
					.autocapitalization(.words)
					.disableAutocorrection(true)
					.focused($focusedField, equals: nicknameField)
					.accessibilityLabel("Nickname")
					.accessibilityHint("Optional personal name for easy identification")
			}
		}
		.glassCard()
		.padding(.horizontal)
	}
}

#if DEBUG
// Preview with mock Field enum
private enum MedicationInfoMockField: Hashable {
	case clinicalName
	case nickname
}

#Preview {
	struct PreviewWrapper: View {
		@State private var clinicalName = ""
		@State private var nickname = ""
		@FocusState private var focusedField: MedicationInfoMockField?

		var body: some View {
			MedicationInfoSectionComponent(
				clinicalName: $clinicalName,
				nickname: $nickname,
				focusedField: $focusedField,
				clinicalNameField: .clinicalName,
				nicknameField: .nickname,
				searchFieldScrollID: nil as String?,
				onMedicationSelected: { clinicalName, nickname in
					self.clinicalName = clinicalName
					self.nickname = nickname
				}
			)
			.padding()
		}
	}

	return PreviewWrapper()
}
#endif