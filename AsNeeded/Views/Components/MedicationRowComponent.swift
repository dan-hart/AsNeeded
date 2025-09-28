import SwiftUI
import ANModelKit
import SFSafeSymbols

/// A comprehensive medication row component with adaptive layout and interactive logging
///
/// Features:
/// - Adaptive layout that switches between standard and accessibility modes
/// - Animated medication icon with smart type detection
/// - Quantity tracking with color-coded status indicators
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
	let medication: ANMedicationConcept
	var onLogTapped: () -> Void = {}

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.editMode) private var editMode
	@Environment(\.colorScheme) private var colorScheme
	@State private var isPressed = false
	private let hapticsManager = HapticsManager.shared

	var body: some View {
		HStack(spacing: 0) {
			if dynamicTypeSize.isAccessibilitySize {
				// Accessibility Layout
				VStack(alignment: .leading, spacing: 16) {
					medicationHeader
					if editMode?.wrappedValue != .active {
						medicationDetails
						enhancedLogButton
							.frame(maxWidth: .infinity)
					}
				}
				.padding(20)
			} else {
				// Standard Layout
				HStack(alignment: .center, spacing: 16) {
					// Left Side: Icon and Info
					HStack(spacing: 14) {
						if editMode?.wrappedValue != .active {
							medicationIcon
						}

						VStack(alignment: .leading, spacing: 8) {
							medicationHeader
							if editMode?.wrappedValue != .active {
								medicationDetails
							}
						}
					}

					Spacer(minLength: 8)

					// Right Side: Enhanced Log Button
					if editMode?.wrappedValue != .active {
						enhancedLogButton
					}
				}
				.padding(20)
			}
		}
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
							Color.clear
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 0.5
				)
		)
		.padding(.horizontal, 4)
		.animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode?.wrappedValue)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Medication: \(medication.displayName)")
		.accessibilityHint("Tap to view details or log dose")
	}

	// MARK: - View Components
	private var medicationIcon: some View {
		ZStack {
			Circle()
				.fill(
					LinearGradient(
						colors: [
							medication.displayColor.opacity(0.15),
							medication.displayColor.opacity(0.08)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.frame(width: 44, height: 44)

			Image(systemSymbol: iconForMedication)
				.font(.title3.weight(.semibold))
				.foregroundStyle(medication.displayColor)
				.symbolEffect(.bounce, options: .speed(0.5), value: isPressed)
				.accessibilityHidden(true)
		}
	}

	private var iconForMedication: SFSymbol {
		// Choose icon based on medication type or unit
		if let unit = medication.prescribedUnit {
			switch unit {
			case .puff:
				return .wind
			case .drop:
				return .drop
			case .spray:
				return .humidity
			default:
				return .pills
			}
		}
		return .pills
	}

	private var medicationHeader: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(medication.displayName)
				.font(.system(.headline, design: .rounded))
				.fontWeight(.bold)
				.lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
				.foregroundStyle(.primary)
				.accessibilityAddTraits(.isHeader)

			if !medication.clinicalName.isEmpty && medication.clinicalName != medication.displayName {
				Text(medication.clinicalName)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
	}

	private var medicationDetails: some View {
		VStack(alignment: .leading, spacing: 6) {
			// Quantity Badge
			if let quantity = medication.quantity {
				HStack(spacing: 6) {
					Image(systemSymbol: .squareStack3dUp)
						.font(.caption2.weight(.semibold))
						.foregroundStyle(quantityColor(for: quantity))
						.accessibilityHidden(true)

					Text(quantityText(for: quantity))
						.font(.caption.weight(.semibold))
						.fontDesign(.rounded)
						.foregroundStyle(quantityColor(for: quantity))
				}
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(
					Capsule()
						.fill(quantityColor(for: quantity).opacity(0.12))
				)
				.accessibilityLabel("Quantity: \(quantityText(for: quantity))")
			}
		}
	}

	private var enhancedLogButton: some View {
		Button(action: {
			withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
				isPressed = true
			}
			hapticsManager.mediumImpact()
			onLogTapped()

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
				isPressed = false
			}
		}) {
			if dynamicTypeSize.isAccessibilitySize {
				// Full width button for accessibility
				HStack(spacing: 10) {
					Image(systemSymbol: .plusCircleFill)
						.font(.title3)
						.accessibilityHidden(true)
					Text("Log Dose")
						.font(.headline)
						.fontWeight(.semibold)
				}
				.foregroundStyle(.white)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(
							LinearGradient(
								colors: [medication.displayColor, medication.displayColor.opacity(0.85)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
				)
			} else {
				// Compact button with icon and text
				VStack(spacing: 4) {
					Image(systemSymbol: .plusCircleFill)
						.font(.title2.weight(.semibold))
						.symbolRenderingMode(.hierarchical)
						.accessibilityHidden(true)

					Text("Log")
						.font(.caption2.weight(.bold))
						.fontDesign(.rounded)
						.textCase(.uppercase)
				}
				.foregroundStyle(.white)
				.frame(width: 66, height: 66)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(
							LinearGradient(
								colors: [
									medication.displayColor,
									medication.displayColor.opacity(0.9)
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.shadow(
							color: medication.displayColor.opacity(0.4),
							radius: isPressed ? 2 : 8,
							x: 0,
							y: isPressed ? 1 : 4
						)
				)
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.strokeBorder(
							LinearGradient(
								colors: [
									Color.white.opacity(0.3),
									Color.white.opacity(0.1)
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							),
							lineWidth: 1
						)
				)
				.scaleEffect(isPressed ? 0.95 : 1.0)
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Log dose for \(medication.displayName)")
		.accessibilityHint("Opens dose logging for this medication")
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
}

#if DEBUG
#Preview("Medication Row Samples") {
	List {
		MedicationRowComponent(medication: ANMedicationConcept(
			clinicalName: "Lisinopril",
			nickname: "Blood Pressure",
			quantity: 28.5,
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
		prescribedUnit: .tablet,
		prescribedDoseAmount: 10.0
	)) {
		print("Log dose tapped")
	}
	.padding()
}
#endif