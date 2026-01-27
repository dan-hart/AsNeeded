import ANModelKit
import DHLoggingKit
import SFSafeSymbols

/// A comprehensive medication appearance picker combining color and symbol selection
///
/// Features:
/// - Segmented control for switching between Color and Symbol tabs
/// - Reuses existing ColorPickerComponent for color selection
/// - Integrates new SymbolPickerComponent for symbol selection
/// - Live preview showing combined color + symbol appearance
/// - Sticky save button at bottom for applying changes
/// - Full accessibility support with proper labels
/// - Haptic feedback for all interactions
///
/// **Appearance:**
/// - Clean navigation with segmented control at top
/// - Tab-based interface for color and symbol selection
/// - Live preview header showing current selection
/// - Professional glass morphism design
/// - Consistent with iOS 26 design patterns
///
/// **Use Cases:**
/// - Medication appearance customization in edit forms
/// - Quick appearance changes from medication rows
/// - Settings screens for medication personalization
/// - Any interface requiring combined color and symbol selection
import SwiftUI

struct MedicationAppearancePickerComponent: View {
    let medication: ANMedicationConcept
    @Binding var selectedColorHex: String?
    @Binding var selectedSymbol: String?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var selectedTab = AppearanceTab.color
    @State private var tempColorHex: String?
    @State private var tempSymbol: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontFamily) private var fontFamily
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let hapticsManager = HapticsManager.shared
    private let logger = DHLogger.ui

    @ScaledMetric private var mainSpacing: CGFloat = 20
    @ScaledMetric private var headerPadding: CGFloat = 16
    @ScaledMetric private var previewHeight: CGFloat = 80
    @ScaledMetric private var iconSize: CGFloat = 56
    @ScaledMetric private var segmentedPadding: CGFloat = 8
    @ScaledMetric private var cornerRadius: CGFloat = 12

    enum AppearanceTab: String, CaseIterable {
        case color = "Color"
        case symbol = "Symbol"

        var localizedName: LocalizedStringKey {
            LocalizedStringKey(rawValue)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview Header
                previewHeader

                // Segmented Control
                segmentedControl
                    .padding(.horizontal, headerPadding)
                    .padding(.vertical, segmentedPadding)

                // Tab Content
                Group {
                    switch selectedTab {
                    case .color:
                        ColorPickerComponent(
                            selectedColorHex: $tempColorHex,
                            onColorSelected: { color in
                                tempColorHex = color
                            },
                            onSave: nil // We handle save at the top level
                        )
                    case .symbol:
                        SymbolPickerComponent(
                            selectedSymbol: $tempSymbol,
                            medicationColor: displayColor,
                            onSymbolSelected: { symbol in
                                tempSymbol = symbol
                            },
                            onSave: nil // We handle save at the top level
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)

                // Sticky Save Button
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.5)

                    saveButton
                        .padding(.horizontal, headerPadding)
                        .padding(.vertical, headerPadding)
                }
                .background(.regularMaterial)
            }
            .navigationTitle("Medication Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                        onCancel()
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        performSave()
                    } label: {
                        Image(systemSymbol: .checkmark)
                            .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                    }
                    .tint(.accent)
                    .accessibilityLabel("Save appearance")
                }
            }
        }
        .onAppear {
            tempColorHex = selectedColorHex ?? medication.displayColorHex
            tempSymbol = selectedSymbol ?? medication.symbolInfo?.name
            logger.info("Appearance picker opened for medication: \(medication.displayName)")
        }
    }

    // MARK: - View Components

    private var previewHeader: some View {
        // Only show preview on Color tab to save space on Symbol tab
        Group {
            if selectedTab == .color {
                HStack(spacing: 12) {
                    // Small icon preview
                    ZStack {
                        Circle()
                            .fill(displayColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: displaySymbol)
                            .font(.body.weight(.medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(displayColor)
                    }

                    // Medication name only
                    Text(medication.displayName)
                        .font(.customFont(fontFamily, style: .subheadline, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Current selection indicator
                    Text(selectedTab == .color ? "Color" : "Symbol")
                        .font(.customFont(fontFamily, style: .caption2))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, headerPadding)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.displayName) appearance")
    }

    private var segmentedControl: some View {
        Picker("Appearance", selection: $selectedTab) {
            ForEach(AppearanceTab.allCases, id: \.self) { tab in
                Text(tab.localizedName)
                    .font(.customFont(fontFamily, style: .subheadline, weight: .medium))
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTab) { _, _ in
            hapticsManager.lightImpact()
        }
        .accessibilityLabel("Choose appearance aspect to customize")
    }

    private var saveButton: some View {
        Button {
            performSave()
        } label: {
            HStack(spacing: mainSpacing / 2) {
                Spacer()

                Image(systemSymbol: .checkmarkCircleFill)
                    .font(.customFont(fontFamily, style: .title3))

                Text("Save Appearance")
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(displayColor.contrastingForegroundColor())
            .frame(maxWidth: .infinity)
            .padding(.vertical, headerPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(displayColor)
            )
            .shadow(
                color: displayColor.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save appearance changes")
        .accessibilityHint("Applies the selected color and symbol to this medication")
    }

    // MARK: - Helper Properties & Methods

    private var displayColor: Color {
        if let hex = tempColorHex, let color = Color(hex: hex) {
            return color
        }
        return medication.displayColor
    }

    private var displaySymbol: String {
        tempSymbol ?? medication.defaultSymbol // Use defaultSymbol until displaySymbol is available
    }

    private func performSave() {
        selectedColorHex = tempColorHex
        selectedSymbol = tempSymbol
        hapticsManager.mediumImpact()
        logger.info("Appearance saved - Color: \(tempColorHex ?? "default"), Symbol: \(tempSymbol ?? "default")")
        onSave()
        dismiss()
    }
}

#if DEBUG
    #Preview("Appearance Picker") {
        @Previewable @State var selectedColor: String? = "#3498db"
        @Previewable @State var selectedSymbol: String? = "pills.fill"

        MedicationAppearancePickerComponent(
            medication: ANMedicationConcept(
                clinicalName: "Lisinopril",
                nickname: "Blood Pressure",
                displayColorHex: "#3498db"
            ),
            selectedColorHex: $selectedColor,
            selectedSymbol: $selectedSymbol,
            onSave: {
                print("Saved - Color: \(selectedColor ?? "none"), Symbol: \(selectedSymbol ?? "none")")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }

    #Preview("Appearance Picker - Dark Mode") {
        @Previewable @State var selectedColor: String? = nil
        @Previewable @State var selectedSymbol: String? = nil

        MedicationAppearancePickerComponent(
            medication: ANMedicationConcept(
                clinicalName: "Albuterol",
                nickname: "Inhaler"
            ),
            selectedColorHex: $selectedColor,
            selectedSymbol: $selectedSymbol,
            onSave: {
                print("Saved - Color: \(selectedColor ?? "none"), Symbol: \(selectedSymbol ?? "none")")
            },
            onCancel: {
                print("Cancelled")
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
