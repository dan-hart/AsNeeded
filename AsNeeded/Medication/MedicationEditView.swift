// MedicationEditView.swift
// SwiftUI view for editing clinicalName, nickname, quantity, lastRefillDate, and nextRefillDate of ANMedicationConcept.

import ANModelKit
import Boutique
import SFSafeSymbols
import SwiftUI

// Button style for quick date adjustments
struct QuickDateButton: ButtonStyle {
    @Environment(\.fontFamily) private var fontFamily
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.customFont(fontFamily, style: .subheadline))
            .fontWeight(.medium)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(.accent.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct MedicationEditView: View {
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: MedicationEditViewModel
	@ObservedObject private var notificationManager = NotificationManager.shared
	@Environment(\.scenePhase) private var scenePhase
    @State private var showingDatePicker = false
	@State private var isSaving = false
	@State private var showingSaveError = false
	@State private var showingDiscardConfirmation = false
	@State private var originalDraft: [String]?
	@State private var showingDoseLimits = false
	@State private var showingSupply = false
	@State private var showingAppearance = false
    @State private var datePickerType: DatePickerType = .lastRefill
    @State private var showingAppearancePicker = false
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fontFamily) private var fontFamily
    private let hapticsManager = HapticsManager.shared
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sectionSpacing: CGFloat = 20
    private let iconSpacing: CGFloat = 12
    private let labelSpacing: CGFloat = 8
    private let cardSpacing: CGFloat = 12
    private let smallPadding: CGFloat = 4
    private let mediumPadding: CGFloat = 8
    private let standardPadding: CGFloat = 12
    private let largePadding: CGFloat = 16
    private let xlargePadding: CGFloat = 18
    private let buttonVerticalPadding: CGFloat = 18
    private let buttonCornerRadius: CGFloat = 16
    private let shadowRadius: CGFloat = 10
    private let shadowY: CGFloat = 5
    @ScaledMetric private var iconCircleSize: CGFloat = 64
    private let removeBorderWidth: CGFloat = 1
    private let removeButtonPadding: CGFloat = 20
    private let removeButtonVerticalPadding: CGFloat = 12
    private let removeButtonCornerRadius: CGFloat = 12
    private let toolbarButtonPadding: CGFloat = 8
    private let mainContentSpacing: CGFloat = 24
    @ScaledMetric private var clearFrameHeight: CGFloat = 20
    private let quickButtonSpacing: CGFloat = 10

    enum Field: Hashable {
        case clinicalName
        case nickname
        case initialQuantity
        case quantity
        case dose
        case minimumHoursBetweenDoses
        case cautionHoursBetweenDoses
        case maxDailyAmount
        case lowStockThreshold
    }

    enum DatePickerType {
        case lastRefill
        case nextRefill
    }

    enum ScrollTarget: Hashable {
        case searchFieldContainer
    }

    let medication: ANMedicationConcept?
    let onSave: (ANMedicationConcept) async -> Bool
    let onCancel: () -> Void

    init(
        medication: ANMedicationConcept?,
        onSave: @escaping (ANMedicationConcept) async -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.medication = medication
        _viewModel = StateObject(wrappedValue: MedicationEditViewModel(medication: medication))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isFormValid: Bool { viewModel.isFormValid }

	private var draftValues: [String] {
		[
			viewModel.clinicalName, viewModel.nickname, viewModel.initialQuantityText,
			viewModel.quantityText, String(describing: viewModel.lastRefillDate),
			String(describing: viewModel.nextRefillDate), viewModel.prescribedDoseText,
			viewModel.prescribedUnit?.rawValue ?? "", viewModel.displayColorHex ?? "",
			viewModel.displaySymbol ?? "", String(viewModel.isArchived),
			String(viewModel.nextDoseNotificationEnabled), viewModel.minimumHoursBetweenDosesText,
			viewModel.cautionHoursBetweenDosesText, viewModel.maxDailyAmountText,
			viewModel.lowStockThresholdText, String(viewModel.duplicateDoseWindowMinutes),
			String(viewModel.refillLeadDays)
		]
	}

	private var hasChanges: Bool {
		originalDraft.map { $0 != draftValues } ?? false
	}

	private var validationMessage: String? {
		guard !isFormValid else { return nil }
		if viewModel.clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return "Enter a medication name to save."
		}
		if let lastRefill = viewModel.lastRefillDate, lastRefill > Date() {
			return "Last refill must be today or earlier."
		}
		if let nextRefill = viewModel.nextRefillDate, nextRefill < Calendar.current.startOfDay(for: Date()) {
			return "Update or clear the past next-refill date in Supply & Refills."
		}
		if let message = viewModel.doseLimitValidationMessage { return message }
		return "Add a positive dose amount and a unit, or leave both blank."
	}

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func performSave() async {
		guard !isSaving else { return }
		isSaving = true
		defer { isSaving = false }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
            hideKeyboard()
        }
		if await viewModel.saveMedication(using: onSave) {
			hapticsManager.medicationAdded()
		} else {
			showingSaveError = true
		}
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        HeroSectionComponent(isEditing: medication != nil)
    }

    @ViewBuilder
    private func progressiveSectionHeader(title: String, subtitle: String, systemSymbol: SFSymbol) -> some View {
        HStack(alignment: .top, spacing: iconSpacing) {
            Image(systemSymbol: systemSymbol)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: smallPadding) {
                Text(title)
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Medication Info Section

    @ViewBuilder
    private var medicationInfoSection: some View {
        MedicationInfoSectionComponent(
            clinicalName: $viewModel.clinicalName,
            nickname: $viewModel.nickname,
            focusedField: $focusedField,
            clinicalNameField: .clinicalName,
            nicknameField: .nickname,
            searchFieldScrollID: ScrollTarget.searchFieldContainer,
            onMedicationSelected: { clinicalName, nickname in
                viewModel.clinicalName = clinicalName
                viewModel.nickname = nickname
                withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                    focusedField = nil
                }
            }
        )
    }

    // MARK: - Prescribed Dose Section

    @ViewBuilder
    private var prescribedDoseSection: some View {
        PrescribedDoseSectionComponent(
            prescribedDoseText: $viewModel.prescribedDoseText,
            prescribedUnit: $viewModel.prescribedUnit,
            focusedField: $focusedField,
            doseField: .dose
        )
    }

    // MARK: - Refill Info Section

    @ViewBuilder
    private var refillInfoSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Section header
            HStack(spacing: iconSpacing) {
                Image(systemSymbol: .arrowTrianglehead2ClockwiseRotate90CircleFill)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accent, .accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Track Supply")
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
            }

            // Initial Quantity
            VStack(alignment: .leading, spacing: labelSpacing) {
                Label {
                    HStack(spacing: smallPadding) {
                        Text("Initial Quantity")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Optional")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, mediumPadding)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                } icon: {
                    Image(systemSymbol: .archiveboxFill)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Original amount when prescription filled", text: $viewModel.initialQuantityText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .initialQuantity)
                    .accessibilityLabel("Initial Quantity, optional")
            }

            // Current Quantity
            VStack(alignment: .leading, spacing: labelSpacing) {
                Label {
                    HStack(spacing: smallPadding) {
                        Text("Current Quantity")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Optional")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, mediumPadding)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                } icon: {
                    Image(systemSymbol: .shippingboxFill)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("How many pills, mL, etc. you have", text: $viewModel.quantityText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .quantity)
            }

            // Date Cards Section
            VStack(alignment: .leading, spacing: labelSpacing) {
                Text("Refill Tracking")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.leading, smallPadding)

                VStack(spacing: cardSpacing) {
                    // Last Refill Date Card
                    DateCardComponent(
                        title: "Last Refill",
                        icon: .clockArrowTriangleheadCounterclockwiseRotate90,
                        date: viewModel.lastRefillDate,
                        color: .accent,
                        onTap: {
                            datePickerType = .lastRefill
                            showingDatePicker = true
                        },
                        onRemove: viewModel.lastRefillDate != nil ? {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                                viewModel.lastRefillDate = nil
                            }
                        } : nil
                    )

                    // Next Refill Date Card
                    DateCardComponent(
                        title: "Next Refill",
                        icon: .calendarBadgePlus,
                        date: viewModel.nextRefillDate,
                        color: .green,
                        onTap: {
                            datePickerType = .nextRefill
                            showingDatePicker = true
                        },
                        onRemove: viewModel.nextRefillDate != nil ? {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                                viewModel.nextRefillDate = nil
                            }
                        } : nil
                    )
                }
            }
        }
        .glassCard()
        .padding(.horizontal)
    }

    // MARK: - Clinical Guidance Section

    @ViewBuilder
    private var clinicalGuidanceSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: iconSpacing) {
                Image(systemSymbol: .crossCaseFill)
                    .font(.customFont(fontFamily, style: .title2))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accent, .accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: smallPadding) {
                    Text("Dose Limits")
                        .font(.customFont(fontFamily, style: .headline, weight: .semibold))

                    Text("Use the instructions from your prescription or care team. Every field is optional.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: sectionSpacing) {
                guidanceField(
                    title: "Minimum Hours Between Doses",
                    subtitle: "Use the interval from your prescription or care instructions.",
                    text: $viewModel.minimumHoursBetweenDosesText,
                    placeholder: "Example: 4",
                    field: .minimumHoursBetweenDoses
                )

                guidanceField(
                    title: "Extra Caution Period (Hours)",
                    subtitle: "Show a caution message while a dose is still close to the last one.",
                    text: $viewModel.cautionHoursBetweenDosesText,
                    placeholder: "Example: 6",
                    field: .cautionHoursBetweenDoses
                )

                guidanceField(
                    title: "Maximum in 24 Hours\(viewModel.prescribedUnit.map { " (\($0.abbreviation))" } ?? "")",
                    subtitle: "The total allowed in any 24 hours, including the next dose. This does not reset at midnight.",
                    text: $viewModel.maxDailyAmountText,
                    placeholder: "Example: 6",
                    field: .maxDailyAmount
                )

                guidanceField(
                    title: "Low-Stock Threshold",
                    subtitle: "Highlight when the remaining quantity falls to this amount.",
                    text: $viewModel.lowStockThresholdText,
                    placeholder: "Example: 10",
                    field: .lowStockThreshold
                )
            }

			if let message = viewModel.doseLimitValidationMessage {
				Text(message)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.red)
			}

			VStack(alignment: .leading, spacing: 8) {
				Toggle("Next-Dose Alerts", isOn: $viewModel.nextDoseNotificationEnabled)
					.font(.customFont(fontFamily, style: .subheadline))
					.tint(.accent)
				Text("After you log a dose, get an alert when your saved limits allow another. These alerts are separate from scheduled reminders and are not medical advice.")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				if viewModel.nextDoseNotificationEnabled {
					Text(availabilityNotificationStatus)
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.secondary)
					if notificationManager.authorizationStatus == .denied {
						Button("Open Notification Settings") {
							if let url = URL(string: UIApplication.openSettingsURLString) {
								UIApplication.shared.open(url)
							}
						}
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.accent)
					}
				}
			}

            VStack(spacing: cardSpacing) {
                counterCard(
                    title: "Check for Duplicate Logs",
                    subtitle: "Flag matching doses logged within this many minutes.",
                    value: viewModel.duplicateDoseWindowMinutes,
                    valueLabel: "\(viewModel.duplicateDoseWindowMinutes) min",
                    step: 5,
                    range: 5 ... 180,
                    decrement: { viewModel.duplicateDoseWindowMinutes = max(5, viewModel.duplicateDoseWindowMinutes - 5) },
                    increment: { viewModel.duplicateDoseWindowMinutes = min(180, viewModel.duplicateDoseWindowMinutes + 5) }
                )

                counterCard(
                    title: "Refill Lead Time",
                    subtitle: "Show refill guidance this many days before your saved refill date or estimated run-out date.",
                    value: viewModel.refillLeadDays,
                    valueLabel: "\(viewModel.refillLeadDays) days",
                    step: 1,
                    range: 1 ... 30,
                    decrement: { viewModel.refillLeadDays = max(1, viewModel.refillLeadDays - 1) },
                    increment: { viewModel.refillLeadDays = min(30, viewModel.refillLeadDays + 1) }
                )
            }
        }
        .glassCard()
        .padding(.horizontal)
    }

    @ViewBuilder
    private func guidanceField(
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            Text(title)
                .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

            Text(subtitle)
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(placeholder, text: text)
                .font(.customFont(fontFamily, style: .body))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .accessibilityLabel(title)
        }
    }

    @ViewBuilder
    private func counterCard(
        title: String,
        subtitle: String,
        value: Int,
        valueLabel: String,
        step: Int,
        range: ClosedRange<Int>,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            Text(title)
                .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

            Text(subtitle)
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: iconSpacing) {
                Button {
                    decrement()
                    hapticsManager.lightImpact()
                } label: {
                    Image(systemSymbol: .minusCircleFill)
                        .font(.customFont(fontFamily, style: .title3))
                        .foregroundStyle(value > range.lowerBound ? .accent : .secondary)
                }
                .disabled(value <= range.lowerBound)
				.frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Decrease \(title.lowercased()) by \(step)")

                Text(valueLabel)
                    .font(.customFont(fontFamily, style: .body, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, mediumPadding)
                    .background(
                        RoundedRectangle(cornerRadius: buttonCornerRadius - 4, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )

                Button {
                    increment()
                    hapticsManager.lightImpact()
                } label: {
                    Image(systemSymbol: .plusCircleFill)
                        .font(.customFont(fontFamily, style: .title3))
                        .foregroundStyle(value < range.upperBound ? .accent : .secondary)
                }
                .disabled(value >= range.upperBound)
				.frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Increase \(title.lowercased()) by \(step)")
            }
        }
        .padding(standardPadding)
        .background(
            RoundedRectangle(cornerRadius: buttonCornerRadius - 4, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    // MARK: - Appearance Section

    @ViewBuilder
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Section header
            HStack(spacing: iconSpacing) {
                Image(systemSymbol: .paintbrushPointedFill)
                    .font(.customFont(fontFamily, style: .title2))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accent, Color.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Personalize Appearance")
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
            }

            // Appearance preview button
            Button {
                hapticsManager.lightImpact()
                showingAppearancePicker = true
            } label: {
                HStack(spacing: iconSpacing) {
                    // Icon preview
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        viewModel.displayColor.opacity(0.15),
                                        viewModel.displayColor.opacity(0.08),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: iconCircleSize, height: iconCircleSize)

                        Image(systemName: viewModel.displaySymbol ?? (medication?.effectiveDisplaySymbol ?? "pills.fill"))
                            .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(viewModel.displayColor)
                    }

                    VStack(alignment: .leading, spacing: smallPadding) {
                        Text("Tap to customize")
                            .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

                        Text("Color & Symbol")
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemSymbol: .chevronRight)
                        .font(.customFont(fontFamily, style: .caption, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: buttonCornerRadius - 4, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Customize medication appearance")
            .accessibilityHint("Opens color and symbol picker")
        }
        .glassCard()
        .padding(.horizontal)
        .sheet(isPresented: $showingAppearancePicker) {
            MedicationAppearancePickerComponent(
                medication: viewModel.buildMedication(),
                selectedColorHex: $viewModel.displayColorHex,
                selectedSymbol: $viewModel.displaySymbol,
                onSave: {
                    showingAppearancePicker = false
                },
                onCancel: {
                    showingAppearancePicker = false
                }
            )
        }
    }

    // MARK: - Archived Status Section

    @ViewBuilder
    private var archivedStatusSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Section header
            HStack(spacing: iconSpacing) {
                Image(systemSymbol: .archiveboxFill)
                    .font(.customFont(fontFamily, style: .title2))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gray, Color.gray.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Status")
                    .font(.customFont(fontFamily, style: .headline, weight: .semibold))
            }

            // Archive toggle
            Toggle(isOn: $viewModel.isArchived) {
                VStack(alignment: .leading, spacing: smallPadding) {
                    Text("Archive Medication")
                        .font(.customFont(fontFamily, style: .body, weight: .medium))

                    Text("Archived medications are hidden from your active list but retained for history")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(standardPadding)
            .background(
                RoundedRectangle(cornerRadius: buttonCornerRadius - 4, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
            .accessibilityLabel("Archive medication")
            .accessibilityHint("Toggle to archive or unarchive this medication")
        }
        .glassCard()
        .padding(.horizontal)
    }

    // MARK: - Save Button

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task { await performSave() }
        } label: {
            let backgroundColor = isFormValid ? .accent : Color.gray

            HStack(spacing: iconSpacing) {
                Image(systemSymbol: .checkmarkCircleFill)
                    .font(.title3)

                Text("Save Medication")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(backgroundColor.contrastingForegroundColor())
            .frame(maxWidth: .infinity)
            .padding(.vertical, buttonVerticalPadding)
            .background(
                LinearGradient(
                    colors: isFormValid ?
                        [.accent, .accent.opacity(0.8)] :
                        [Color.gray, Color.gray.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
            .shadow(color: isFormValid ? .accent.opacity(0.3) : .clear, radius: shadowRadius, y: shadowY)
        }
        .disabled(!isFormValid || isSaving)
        .padding(.horizontal)
        .padding(.vertical, quickButtonSpacing)
    }

    // MARK: - Date Picker Binding

    private var currentDateBinding: Binding<Date> {
        Binding(
            get: {
                if datePickerType == .lastRefill {
                    return viewModel.lastRefillDate ?? Date()
                } else {
                    return viewModel.nextRefillDate ?? Date()
                }
            },
            set: { newDate in
                if datePickerType == .lastRefill {
                    viewModel.lastRefillDate = newDate
                } else {
                    viewModel.nextRefillDate = newDate
                }
            }
        )
    }

    // MARK: - Date Picker Sheet

    @ViewBuilder
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: sectionSpacing) {
                // Date picker header
                VStack(spacing: labelSpacing) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (datePickerType == .lastRefill ? Color.accent : Color.green).opacity(0.2),
                                        (datePickerType == .lastRefill ? Color.accent : Color.green).opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: iconCircleSize, height: iconCircleSize)

                        Image(systemSymbol: datePickerType == .lastRefill ? .clockArrowTriangleheadCounterclockwiseRotate90 : .calendarBadgePlus)
                            .font(.largeTitle.weight(.medium))
                            .foregroundStyle(datePickerType == .lastRefill ? Color.accent : Color.green)
                    }

                    Text(datePickerType == .lastRefill ? "Last Refill Date" : "Next Refill Date")
                        .font(.title3)
                        .fontWeight(.bold)

                    if let currentDate = (datePickerType == .lastRefill ? viewModel.lastRefillDate : viewModel.nextRefillDate) {
                        Text(currentDate.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, quickButtonSpacing)

                if datePickerType == .lastRefill {
                    DatePicker("", selection: currentDateBinding, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                } else {
                    DatePicker("", selection: currentDateBinding, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                }

                // Quick select buttons
                VStack(spacing: cardSpacing) {
                    Text("Quick Adjust")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: quickButtonSpacing) {
                        Button { adjustDate(by: -30) } label: {
                            Text("-30d")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(QuickDateButton())

                        Button { adjustDate(by: -7) } label: {
                            Text("-7d")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(QuickDateButton())

                        Button { adjustDate(by: 7) } label: {
                            Text("+7d")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(QuickDateButton())

                        Button { adjustDate(by: 30) } label: {
                            Text("+30d")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(QuickDateButton())
                    }
                }
                .padding(.horizontal)

                // Remove date button (more prominent)
                if (datePickerType == .lastRefill ? viewModel.lastRefillDate : viewModel.nextRefillDate) != nil {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                            if datePickerType == .lastRefill {
                                viewModel.lastRefillDate = nil
                            } else {
                                viewModel.nextRefillDate = nil
                            }
                            showingDatePicker = false
                            hapticsManager.mediumImpact()
                        }
                    } label: {
                        HStack(spacing: labelSpacing) {
                            Image(systemSymbol: .trashCircle)
                                .font(.callout)
                            Text("Remove Date")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, removeButtonPadding)
                        .padding(.vertical, removeButtonVerticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: removeButtonCornerRadius, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: removeButtonCornerRadius, style: .continuous)
                                        .strokeBorder(Color.red.opacity(0.2), lineWidth: removeBorderWidth)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingDatePicker = false
                    } label: {
                        Image(systemSymbol: .xmark)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingDatePicker = false
                    } label: {
                        Image(systemSymbol: .checkmark)
                    }
                }
            }
            .tint(.accent)
        }
        .presentationDetents([.large])
    }

    private func adjustDate(by days: Int) {
        let currentDate = datePickerType == .lastRefill ?
            (viewModel.lastRefillDate ?? Date()) :
            (viewModel.nextRefillDate ?? Date())
        let newDate = Calendar.current.date(byAdding: .day, value: days, to: currentDate)

        if datePickerType == .lastRefill {
            viewModel.lastRefillDate = newDate
        } else {
            viewModel.nextRefillDate = newDate
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: mainContentSpacing) {
                    medicationInfoSection
                    prescribedDoseSection
					DisclosureGroup("Dose Limits & Alerts", isExpanded: $showingDoseLimits) {
						clinicalGuidanceSection
					}
					.font(.customFont(fontFamily, style: .headline))
					.padding(.horizontal)
					DisclosureGroup("Supply & Refills", isExpanded: $showingSupply) {
						refillInfoSection
					}
					.font(.customFont(fontFamily, style: .headline))
					.padding(.horizontal)
					DisclosureGroup("Appearance & Archive", isExpanded: $showingAppearance) {
						appearanceSection
						archivedStatusSection
					}
					.font(.customFont(fontFamily, style: .headline))
					.padding(.horizontal)
					if dynamicTypeSize.isAccessibilitySize { saveFooter }
                }
				.padding(.vertical)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        .accent.opacity(0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onChange(of: focusedField) { _, newValue in
                if newValue == .clinicalName {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                        proxy.scrollTo(ScrollTarget.searchFieldContainer, anchor: .top)
                    }
                }
            }
        }
    }

	private var availabilityNotificationStatus: String {
		switch notificationManager.authorizationStatus {
		case .denied:
			return "Notifications are off. Open Settings to turn on next-dose alerts."
		case .authorized, .provisional, .ephemeral:
			return "Notifications are on. Add a dose limit and log a dose to start receiving alerts."
		case .notDetermined:
			return "Notification permission is required."
		case .unknown:
			return "Notification permission status is unavailable."
		}
	}

	private var saveFooter: some View {
					VStack(spacing: 4) {
						if let validationMessage {
							Text(validationMessage)
								.font(.customFont(fontFamily, style: .caption))
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
								.padding(.horizontal)
						}
					saveButton
					}
						.padding(.vertical, 8)
						.background(.regularMaterial)
	}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainContent
				.disabled(isSaving)
				.task { await notificationManager.checkAuthorizationStatus() }
				.onChange(of: scenePhase) { _, phase in
					if phase == .active {
						Task { await notificationManager.checkAuthorizationStatus() }
					}
				}
				.onChange(of: viewModel.nextDoseNotificationEnabled) { _, enabled in
					if enabled {
						Task { _ = await notificationManager.requestAuthorization() }
					}
				}
				.customNavigationTitle(medication == nil ? "Add Medication" : "Edit Medication", displayMode: .inline)
				.onAppear {
					if originalDraft == nil {
						originalDraft = draftValues
						showingDoseLimits = !viewModel.minimumHoursBetweenDosesText.isEmpty || !viewModel.maxDailyAmountText.isEmpty || viewModel.nextDoseNotificationEnabled
						showingSupply = !viewModel.quantityText.isEmpty || !viewModel.initialQuantityText.isEmpty || viewModel.lastRefillDate != nil || viewModel.nextRefillDate != nil
					}
				}
				.safeAreaInset(edge: .bottom) {
					if !dynamicTypeSize.isAccessibilitySize { saveFooter }
				}
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
							if hasChanges { showingDiscardConfirmation = true } else { onCancel() }
                        } label: {
                            Image(systemSymbol: .xmark)
                        }
						.disabled(isSaving)
						.accessibilityLabel("Cancel medication changes")
                    }

					ToolbarItemGroup(placement: .keyboard) {
						Spacer()
						Button("Done") { hideKeyboard(); focusedField = nil }
							.font(.customFont(fontFamily, style: .body))
					}
                }
                .tint(.accent)
				.interactiveDismissDisabled(isSaving || hasChanges)
				.alert("Medication not saved", isPresented: $showingSaveError) {
					Button("Keep Editing", role: .cancel) {}
				} message: {
					Text("Your changes are still here. Please try again.")
				}
				.confirmationDialog("Discard medication changes?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
					Button("Discard Changes", role: .destructive) { onCancel() }
					Button("Keep Editing", role: .cancel) {}
				}
                .scrollDismissesKeyboard(.interactively)
                .sheet(isPresented: $showingDatePicker) {
                    datePickerSheet
                }
        }
    }
}

#Preview {
    MedicationEditView(
        medication: nil,
        onSave: { _ in true },
        onCancel: {}
    )
}

#Preview("Edit Existing Medication") {
    MedicationEditView(
        medication: ANMedicationConcept(
            id: UUID(),
            clinicalName: "Lisinopril",
            nickname: "Lisi",
            quantity: 30,
            initialQuantity: 90,
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())
        ),
        onSave: { _ in true },
        onCancel: {}
    )
}

#Preview("Add New Medication") {
    MedicationEditView(
        medication: nil,
        onSave: { _ in true },
        onCancel: {}
    )
}
