import SFSafeSymbols
import SwiftUI

/// Medication name search and an optional personal nickname.
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
	@ObservedObject private var demoMode = DemoModeState.shared
    @Binding var clinicalName: String
    @Binding var nickname: String
    @FocusState.Binding var focusedField: Field?

    let clinicalNameField: Field
    let nicknameField: Field
    let searchFieldScrollID: ScrollID?
    let onMedicationSelected: (String, String) -> Void

	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Medication name (required)")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.accessibilityAddTraits(.isHeader)

			EnhancedMedicationSearchField(
				text: $clinicalName,
				placeholder: String(localized: "Enter medication name"),
				scrollID: searchFieldScrollID,
				onMedicationSelected: { name, nickname in
					onMedicationSelected(name, nickname)
				}
			)
			.focused($focusedField, equals: clinicalNameField)

			Text("Nickname (optional)")
				.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
			Group {
				if demoMode.isEnabled {
					SecureField("Nickname", text: $nickname)
						.demoNameRedacted()
				} else {
					TextField("e.g. Headache relief", text: $nickname)
				}
			}
				.font(.customFont(fontFamily, style: .body))
				.textFieldStyle(.roundedBorder)
				.textInputAutocapitalization(.words)
				.autocorrectionDisabled()
				.focused($focusedField, equals: nicknameField)
				.accessibilityLabel("Nickname, optional")
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
