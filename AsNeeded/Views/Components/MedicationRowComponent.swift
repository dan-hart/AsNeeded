import ANModelKit
import SFSafeSymbols
import SwiftUI

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
    var onQuickLog: (() async -> Bool)? = nil // Quick log with default dose
    var onQuickLogSuccess: (() -> Void)? = nil // Called when quick log succeeds to show toast
    var onAppearanceChanged: ((String?, String?) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fontFamily) private var fontFamily
    @State private var isPressed = false
    @State private var isLongPressing = false
    @State private var longPressWorkItem: DispatchWorkItem?
    @State private var hasTriggeredQuickLog = false
    @State private var showingAppearancePicker = false
    @State private var tempSelectedColor: String?
    @State private var tempSelectedSymbol: String?
    @State private var showCopyToast = false
    private let hapticsManager = HapticsManager.shared
    private let longPressDuration: TimeInterval = 0.5

    @ScaledMetric private var rowPadding: CGFloat = 16
    @ScaledMetric private var iconContentSpacing: CGFloat = 14
    @ScaledMetric private var logButtonSize: CGFloat = 66
    @ScaledMetric private var medicationIconSize: CGFloat = 56

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
                .padding(rowPadding)
            } else {
                // Standard Layout
                HStack(alignment: .center, spacing: 16) {
                    // Left Side: Icon and Info
                    HStack(spacing: iconContentSpacing) {
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
                .padding(rowPadding)
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
                            Color.clear,
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
        .overlay(alignment: .top) {
            if showCopyToast {
                CopyToastView(
                    message: "Clinical name copied",
                    isVisible: showCopyToast,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showCopyToast = false
                        }
                    }
                )
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
                    .symbolEffect(.bounce, options: .speed(0.5), value: isPressed)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change medication appearance")
        .accessibilityHint("Tap to change the color and symbol for \(medication.displayName)")
        .sheet(isPresented: $showingAppearancePicker) {
            medicationAppearanceSheet
        }
    }

    private var medicationHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(medication.displayName)
                    .font(.customFont(fontFamily, style: .headline, weight: .bold))
                    .noTruncate()
                    .foregroundStyle(.primary)
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
                    medication.clinicalName,
                    font: .customFont(fontFamily, style: .caption),
                    color: .secondary
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCopyToast = true
                    }

                    // Auto-dismiss after 2.5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        await MainActor.run {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showCopyToast = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var medicationDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Quantity Badge
            if let quantity = medication.quantity {
                VStack(alignment: .leading, spacing: 4) {
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
                    .background(
                        Capsule()
                            .fill(quantityColor(for: quantity).opacity(0.12))
                    )
                    .accessibilityLabel("Quantity: \(quantityText(for: quantity))")

                    // Usage Progress Bar (only if initialQuantity is available)
                    if let usagePercentage = usagePercentage {
                        usageProgressBar(percentage: usagePercentage)
                            .accessibilityLabel("Usage progress: \(Int(usagePercentage))% used")
                    }
                }
            }
        }
    }

    private var enhancedLogButton: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Full width button for accessibility
                HStack(spacing: 10) {
                    Image(systemSymbol: .plusCircleFill)
                        .font(.title3)
                        .accessibilityHidden(true)
                    Text("Log Dose")
                        .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                }
                .foregroundStyle(medication.displayColor.contrastingForegroundColor())
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
                        .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Text("Log")
                        .font(.customFont(fontFamily, style: .caption2, weight: .bold))
                        .textCase(.uppercase)
                }
                .foregroundStyle(medication.displayColor.contrastingForegroundColor())
                .frame(width: logButtonSize, height: logButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    medication.displayColor,
                                    medication.displayColor.opacity(0.9),
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
                                    medication.displayColor.contrastingForegroundColor().opacity(0.3),
                                    medication.displayColor.contrastingForegroundColor().opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .scaleEffect(isPressed || isLongPressing ? 0.95 : 1.0)
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Only set up the timer on first change event
                    if longPressWorkItem == nil {
                        // Visual feedback - press started
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }

                        // Schedule long press action to fire at exact threshold
                        let workItem = DispatchWorkItem { [self] in
                            guard !hasTriggeredQuickLog else { return }

                            // Trigger quick log immediately when threshold reached
                            hasTriggeredQuickLog = true
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isLongPressing = true
                            }
                            hapticsManager.heavyImpact()

                            // Execute quick log
                            if let quickLog = onQuickLog {
                                Task {
                                    let success = await quickLog()
                                    if success {
                                        await MainActor.run {
                                            // Notify parent to show toast
                                            onQuickLogSuccess?()
                                        }
                                    }
                                }
                            }
                        }

                        longPressWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration, execute: workItem)
                    }
                }
                .onEnded { _ in
                    // Cancel scheduled long press if it hasn't fired yet
                    longPressWorkItem?.cancel()
                    longPressWorkItem = nil

                    // Reset visual states
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                        isLongPressing = false
                    }

                    // Only trigger tap action if it was a short press (long press wasn't triggered)
                    if !hasTriggeredQuickLog {
                        // Short press - show log sheet
                        hapticsManager.mediumImpact()
                        onLogTapped()
                    }

                    // Reset for next interaction
                    hasTriggeredQuickLog = false
                }
        )
        .accessibilityLabel("Log dose for \(medication.displayName)")
        .accessibilityHint("Tap to customize dose, hold to log default dose")
    }

    // MARK: - Helper Methods

    /// Calculates the percentage of medication used (0-100) if both quantities are available
    private var usagePercentage: Double? {
        guard let initial = medication.initialQuantity,
              let current = medication.quantity,
              initial > 0
        else {
            return nil
        }
        let used = initial - current
        return max(0, min(100, (used / initial) * 100))
    }

    /// Creates a thin progress bar showing usage percentage
    @ViewBuilder
    private func usageProgressBar(percentage: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.regularMaterial)
                    .frame(height: 4)

                // Progress fill
                Capsule()
                    .fill(progressBarColor(for: percentage))
                    .frame(width: geometry.size.width * (percentage / 100), height: 4)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 10)
    }

    /// Returns color for progress bar based on percentage used
    private func progressBarColor(for percentage: Double) -> Color {
        if percentage < 33 {
            return .green
        } else if percentage < 66 {
            return .orange
        } else {
            return .red
        }
    }

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
