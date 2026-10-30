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
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private let sectionSpacing: CGFloat = 20
	private let headerSpacing: CGFloat = 12
	private let fieldsHSpacing: CGFloat = 16
	private let fieldVSpacing: CGFloat = 8
	private let doseFieldMaxWidth: CGFloat = 120
	private let menuPaddingH: CGFloat = 12
	private let menuPaddingV: CGFloat = 8
	private let menuCornerRadius: CGFloat = 8

	var body: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			// Section header
			HStack(spacing: headerSpacing) {
				if !dynamicTypeSize.isAccessibilitySize {
					Image(systemSymbol: .syringe)
						.font(.customFont(fontFamily, style: .title2))
						.foregroundStyle(
							LinearGradient(
								colors: [.accent, .accent.opacity(0.7)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.accessibilityHidden(true)
				}

				Text("Prescribed Dose (optional)")
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))
					.accessibilityAddTraits(.isHeader)
					.noTruncate()
			}

			let fieldsLayout = dynamicTypeSize.isAccessibilitySize
				? AnyLayout(VStackLayout(alignment: .leading, spacing: fieldsHSpacing))
				: AnyLayout(HStackLayout(alignment: .top, spacing: fieldsHSpacing))
			fieldsLayout {
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
						.font(.customFont(fontFamily, style: .body))
						.textFieldStyle(.roundedBorder)
						.keyboardType(.decimalPad)
						.focused($focusedField, equals: doseField)
						.frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : doseFieldMaxWidth, minHeight: 44)
						.accessibilityLabel("Dose amount")
						.accessibilityHint("Enter the prescribed dose amount")
				}
				.frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : doseFieldMaxWidth, alignment: .leading)

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
							withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
								prescribedUnit = nil
							}
						}
						Divider()
						ForEach(ANUnitConcept.allCases, id: \.self) { unit in
							Button {
								withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
									prescribedUnit = unit
								}
							} label: {
								Text(unit.localizedDisplayName)
									.font(.customFont(fontFamily, style: .body))
							}
						}
					} label: {
						HStack {
							Text(prescribedUnit?.localizedDisplayName ?? String(localized: "Select"))
								.font(.customFont(fontFamily, style: .body))
								.foregroundStyle(prescribedUnit == nil ? .secondary : .primary)
								.noTruncate()
							Spacer()
							Image(systemSymbol: .chevronUpChevronDown)
								.font(.customFont(fontFamily, style: .caption))
								.foregroundStyle(.secondary)
						}
						.padding(.horizontal, menuPaddingH)
						.padding(.vertical, menuPaddingV)
						.frame(minHeight: 44)
						.background(
							RoundedRectangle(cornerRadius: menuCornerRadius)
								.fill(.regularMaterial)
						)
					}
					.accessibilityLabel("Dose unit")
					.accessibilityHint("Select the unit for the prescribed dose")
					.accessibilityValue(prescribedUnit?.localizedDisplayName ?? String(localized: "Not selected"))
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
