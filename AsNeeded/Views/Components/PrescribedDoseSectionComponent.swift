import ANModelKit
import SFSafeSymbols
import SwiftUI

/// A dose specification input section for medications with amount and unit selection
///
/// Features:
/// - Numeric dose amount input with decimal support
/// - Unit selection menu with comprehensive medical units
/// - Focus state management integration
/// - Comprehensive accessibility labels and hints
/// - Integrated glass card styling
///
/// **Appearance:**
/// - Section header with syringe icon and title
/// - Side-by-side amount and unit input fields
/// - Responsive dropdown menu for unit selection
/// - Clear visual hierarchy with icons and labels
/// - Consistent glass card background
///
/// **Use Cases:**
/// - Medication dosage configuration forms
/// - Prescription management interfaces
/// - Medical dosing calculators
/// - Healthcare provider input systems
/// - Patient medication tracking apps
/// - Any interface requiring precise dose specification
struct PrescribedDoseSectionComponent<Field: Hashable>: View {
    @Binding var prescribedDoseText: String
    @Binding var prescribedUnit: ANUnitConcept?
    @FocusState.Binding var focusedField: Field?

    let doseField: Field

    @Environment(\.fontFamily) private var fontFamily

    @ScaledMetric private var sectionSpacing: CGFloat = 20
    @ScaledMetric private var headerSpacing: CGFloat = 12
    @ScaledMetric private var fieldsHSpacing: CGFloat = 16
    @ScaledMetric private var fieldVSpacing: CGFloat = 8
    @ScaledMetric private var doseFieldMaxWidth: CGFloat = 120
    @ScaledMetric private var menuPaddingH: CGFloat = 12
    @ScaledMetric private var menuPaddingV: CGFloat = 8
    @ScaledMetric private var menuCornerRadius: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Section header
            HStack(spacing: headerSpacing) {
                Image(systemSymbol: .syringe)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accent, .accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Prescribed Dose")
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
            }

            HStack(spacing: fieldsHSpacing) {
                // Dose Amount
                VStack(alignment: .leading, spacing: fieldVSpacing) {
                    Label {
                        Text("Amount")
                            .font(.customFont(fontFamily, style: .subheadline, weight: .medium))
                    } icon: {
                        Image(systemSymbol: .number)
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)
                    }

                    TextField("0", text: $prescribedDoseText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: doseField)
                        .frame(maxWidth: doseFieldMaxWidth)
                        .accessibilityLabel("Dose amount")
                        .accessibilityHint("Enter the prescribed dose amount")
                }

                // Dose Unit
                VStack(alignment: .leading, spacing: fieldVSpacing) {
                    Label {
                        Text("Unit")
                            .font(.customFont(fontFamily, style: .subheadline, weight: .medium))
                    } icon: {
                        Image(systemSymbol: .ruler)
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)
                    }

                    Menu {
                        Button("None") {
                            withAnimation(.spring(response: 0.3)) {
                                prescribedUnit = nil
                            }
                        }
                        Divider()
                        ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    prescribedUnit = unit
                                }
                            } label: {
                                Text(unit.displayName)
                                    .font(.customFont(fontFamily, style: .body))
                            }
                        }
                    } label: {
                        HStack {
                            Text(prescribedUnit?.displayName ?? "Select")
                                .font(.customFont(fontFamily, style: .body))
                                .foregroundStyle(prescribedUnit == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemSymbol: .chevronUpChevronDown)
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, menuPaddingH)
                        .padding(.vertical, menuPaddingV)
                        .background(
                            RoundedRectangle(cornerRadius: menuCornerRadius)
                                .fill(.regularMaterial)
                        )
                    }
                    .accessibilityLabel("Dose unit")
                    .accessibilityHint("Select the unit for the prescribed dose")
                    .accessibilityValue(prescribedUnit?.displayName ?? "Not selected")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard()
        .padding(.horizontal)
    }
}

#if DEBUG
    // Preview with mock Field enum
    private enum PrescribedDoseMockField: Hashable {
        case dose
    }

    #Preview {
        struct PreviewWrapper: View {
            @State private var prescribedDoseText = "10"
            @State private var prescribedUnit: ANUnitConcept? = nil
            @FocusState private var focusedField: PrescribedDoseMockField?

            var body: some View {
                PrescribedDoseSectionComponent(
                    prescribedDoseText: $prescribedDoseText,
                    prescribedUnit: $prescribedUnit,
                    focusedField: $focusedField,
                    doseField: .dose
                )
                .padding()
            }
        }

        return PreviewWrapper()
    }

    #Preview("Empty State") {
        struct EmptyPreviewWrapper: View {
            @State private var prescribedDoseText = ""
            @State private var prescribedUnit: ANUnitConcept? = nil
            @FocusState private var focusedField: PrescribedDoseMockField?

            var body: some View {
                PrescribedDoseSectionComponent(
                    prescribedDoseText: $prescribedDoseText,
                    prescribedUnit: $prescribedUnit,
                    focusedField: $focusedField,
                    doseField: .dose
                )
                .padding()
            }
        }

        return EmptyPreviewWrapper()
    }
#endif
