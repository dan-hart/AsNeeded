import ANModelKit
import SFSafeSymbols
import SwiftUI

/// A comprehensive medication row component with adaptive layout and interactive logging
///
/// Features:
/// - Adaptive layout that switches between standard and accessibility modes
/// - Animated medication icon with smart type detection
/// - Quantity tracking with color-coded stock indicators
/// - Interactive log button with haptic feedback
/// - Comprehensive accessibility support
/// - Edit mode integration for list management
///
/// **Appearance:**
/// - Card-style design with glass morphism background
/// - Gradient borders and shadows for depth
/// - Color-coded quantity indicators (red/orange/green)
/// - Animated log button with symbol effects
/// - Responsive to Dynamic Type and edit mode states
///
/// **Use Cases:**
/// - Medication list displays in health apps
/// - Patient medication management interfaces
/// - Pharmacy management systems
/// - Medical record display components
/// - Healthcare provider dashboards
/// - Any interface displaying medication information with interaction capabilities
struct MedicationRowComponent: View {
	@ObservedObject private var demoMode = DemoModeState.shared
    let medication: ANMedicationConcept
    var statusSummary: MedicationStatusSummaryService.Summary?
    var onLogTapped: () -> Void = {}
	var onOpen: (() -> Void)?
    var onQuickLog: (() async -> Bool)? = nil // Quick log with default dose
    var onQuickLogSuccess: (() -> Void)? = nil // Called when quick log succeeds to show toast
	var showQuickLogHintAnchor = false
    var onAppearanceChanged: ((String?, String?) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var isLongPressing = false
	@State private var holdProgress: Double = 0
    @State private var showingAppearancePicker = false
    @State private var tempSelectedColor: String?
    @State private var tempSelectedSymbol: String?
    private let hapticsManager = HapticsManager.shared

    private let rowPadding: CGFloat = 16
    private let iconContentSpacing: CGFloat = 14
    @ScaledMetric private var medicationIconSize: CGFloat = 40

    var body: some View {
		HStack(alignment: .center, spacing: 12) {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 10) {
					if !dynamicTypeSize.isAccessibilitySize, editMode?.wrappedValue != .active {
						medicationIcon
							.frame(minWidth: 44, minHeight: 44)
					}
					medicationHeader
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				if editMode?.wrappedValue != .active {
					medicationDetails
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			if editMode?.wrappedValue != .active {
				enhancedLogButton
			}
		}
		.padding(dynamicTypeSize.isAccessibilitySize ? rowPadding : 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ?
                    Color(uiColor: .secondarySystemGroupedBackground) :
                    Color.white
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.06),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.5),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 4)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: editMode?.wrappedValue)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Medication: \(medication.demoDisplayName)")
        .accessibilityHint("Tap to view details or log dose")
		.accessibilityAction { if editMode?.wrappedValue != .active { onOpen?() } }
		.accessibilityAction(named: "View details") { if editMode?.wrappedValue != .active { onOpen?() } }
        .accessibilityAction(named: "Log custom dose") {
			guard editMode?.wrappedValue != .active else { return }
            onLogTapped()
        }
        .accessibilityAction(named: "Quick log default dose") {
            guard editMode?.wrappedValue != .active, let onQuickLog else { return }
            Task {
                let success = await onQuickLog()
                if success {
                    await MainActor.run {
                        onQuickLogSuccess?()
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private var medicationIcon: some View {
        Button {
            hapticsManager.lightImpact()
            tempSelectedColor = medication.displayColorHex
            tempSelectedSymbol = medication.symbolInfo?.name
            showingAppearancePicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                medication.displayColor.opacity(0.15),
                                medication.displayColor.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: medicationIconSize, height: medicationIconSize)

                Image(systemName: medication.effectiveDisplaySymbol)
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(medication.displayColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change medication appearance")
        .accessibilityHint("Tap to change the color and symbol for \(medication.demoDisplayName)")
        .sheet(isPresented: $showingAppearancePicker) {
            medicationAppearanceSheet
        }
    }

    private var medicationHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
				CopyableText(
					medication.demoDisplayName,
					font: .customFont(fontFamily, style: .headline, weight: .bold),
					color: .primary,
					onTap: { if editMode?.wrappedValue != .active { onOpen?() } }
				)
                    .accessibilityAddTraits(.isHeader)

                if medication.isArchived {
                    Image(systemSymbol: .archiveboxFill)
                        .font(.customFont(fontFamily, style: .caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Archived")
                }
            }

            if !medication.clinicalName.isEmpty && medication.clinicalName != medication.displayName {
                CopyableText(
                    medication.demoClinicalName,
                    font: .customFont(fontFamily, style: .caption),
                    color: .secondary,
					onTap: { if editMode?.wrappedValue != .active { onOpen?() } }
                )
            }
        }
    }

	private var medicationDetails: some View {
		VStack(alignment: .leading, spacing: 6) {
			if let quantity = medication.quantity {
				HStack(spacing: 6) {
					Image(systemSymbol: .squareStack3dUp)
						.font(.caption2.weight(.semibold))
						.foregroundStyle(quantityColor(for: quantity))
						.accessibilityHidden(true)

					Text(quantityText(for: quantity))
						.font(.customFont(fontFamily, style: .caption, weight: .semibold))
						.fontDesign(.rounded)
						.foregroundStyle(quantityColor(for: quantity))
				}
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(Capsule().fill(quantityColor(for: quantity).opacity(0.12)))
				.accessibilityLabel("Quantity: \(quantityText(for: quantity))")
			}

			if let nextWindowText = statusSummary?.nextWindowText {
				Text(nextWindowText)
					.font(.customFont(fontFamily, style: .caption2))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

    private var enhancedLogButton: some View {
		Button {
			onLogTapped()
		} label: {
			VStack(spacing: 6) {
				Image(systemSymbol: .plusCircleFill)
					.font(.customFont(fontFamily, style: .caption, weight: .semibold))
					.symbolRenderingMode(.monochrome)
					.accessibilityHidden(true)
				Text("Log")
					.font(.customFont(fontFamily, style: .caption2, weight: .bold))
					.lineLimit(1)
					.fixedSize(horizontal: true, vertical: true)
			}
			.fixedSize(horizontal: true, vertical: true)
			.foregroundStyle(medication.displayColor.dynamicFilledButtonForeground)
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.frame(minWidth: 60, minHeight: 60)
			.background(medication.displayColor.dynamicFilledButtonBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			.shadow(color: medication.displayColor.opacity(0.4), radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
			.overlay {
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.strokeBorder(medication.displayColor.dynamicFilledButtonForeground.opacity(0.2), lineWidth: 1)
			}
			.scaleEffect(reduceMotion ? 1 : (isPressed || isLongPressing ? 0.95 : 1))
		}
		.buttonStyle(.plain)
        .contentShape(Rectangle())
		.overlay {
			RoundedRectangle(cornerRadius: 14)
				.trim(from: 0, to: holdProgress)
				.stroke(medication.displayColor.dynamicFilledButtonForeground, style: StrokeStyle(lineWidth: 3, lineCap: .round))
				.padding(2)
				.allowsHitTesting(false)
				.accessibilityHidden(true)
		}
		.anchorPreference(key: QuickLogHintAnchorKey.self, value: .bounds) { showQuickLogHintAnchor ? $0 : nil }
		.doseLogPressGesture(
			isPressed: $isPressed, isLongPressing: $isLongPressing, holdProgress: $holdProgress,
			onTap: onLogTapped, onQuickLog: onQuickLog, onQuickLogSuccess: onQuickLogSuccess
		)
        .accessibilityLabel("Log dose for \(medication.demoDisplayName)")
        .accessibilityHint("Tap to customize dose, hold to log default dose")

    }

    // MARK: - Helper Methods

    private func quantityColor(for quantity: Double) -> Color {
        if quantity < 10 {
            return .red
        } else if quantity < 30 {
            return .orange
        } else {
            return .green
        }
    }

    private func quantityText(for quantity: Double) -> String {
        let quantityStr = quantity.formattedAmount
        if let unit = medication.prescribedUnit {
            return "\(quantityStr) \(unit.abbreviation) left"
        } else {
            return "\(quantityStr) left"
        }
    }

    // MARK: - Medication Appearance Sheet

    private var medicationAppearanceSheet: some View {
        MedicationAppearancePickerComponent(
            medication: medication,
            selectedColorHex: $tempSelectedColor,
            selectedSymbol: $tempSelectedSymbol,
            onSave: {
                onAppearanceChanged?(tempSelectedColor, tempSelectedSymbol)
                showingAppearancePicker = false
            },
            onCancel: {
                tempSelectedColor = medication.displayColorHex
                tempSelectedSymbol = medication.symbolInfo?.name
                showingAppearancePicker = false
            }
        )
    }
}

#if DEBUG
    #Preview("Medication Row Samples") {
        List {
            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Lisinopril",
                nickname: "Blood Pressure",
                quantity: 28.5,
                initialQuantity: 90.0,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                prescribedUnit: .tablet,
                prescribedDoseAmount: 10.0
            )) {
                print("Log dose tapped")
            }

            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Albuterol Inhaler",
                nickname: "Rescue Inhaler",
                quantity: 5,
                initialQuantity: 60,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
                nextRefillDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
                prescribedUnit: .puff,
                prescribedDoseAmount: 2.0
            )) {
                print("Log dose tapped")
            }

            MedicationRowComponent(medication: ANMedicationConcept(
                clinicalName: "Vitamin D3",
                nickname: "",
                quantity: 45,
                initialQuantity: 60,
                lastRefillDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()),
                nextRefillDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()),
                prescribedUnit: .tablet,
                prescribedDoseAmount: 1000.0
            )) {
                print("Log dose tapped")
            }
        }
        .listStyle(.plain)
    }

    #Preview("Single Row") {
        MedicationRowComponent(medication: ANMedicationConcept(
            clinicalName: "Lisinopril",
            nickname: "Blood Pressure Med",
            quantity: 15,
            initialQuantity: 30,
            prescribedUnit: .tablet,
            prescribedDoseAmount: 10.0
        )) {
            print("Log dose tapped")
        }
        .padding()
    }
#endif
