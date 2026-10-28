// LogDoseView.swift
// SwiftUI view for logging a dose taken for a medication, using ANModelKit concepts.

import ANModelKit
import DHLoggingKit
import SFSafeSymbols
import SwiftUI
import TipKit

struct LogDoseView: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	private enum ScrollTarget {
		case guidance
	}
	@MainActor
	final class Draft: ObservableObject {
		@Published var amount: Double
		@Published var selectedUnit: ANUnitConcept
		@Published var selectedDate: Date = .now
		@Published var reason = ""
		@Published var symptomSeverityBefore = 0
		@Published var symptomSeverityAfter = 0
		@Published var effectiveness = 0
		@Published var sideEffectsText = ""
		@Published var note = ""
		@Published var showingDatePicker = false
		@Published var showingLogError = false
		@Published var showingDiscardConfirmation = false
		@Published var selectedQuickOption: String? = "Now"
		@Published var isLogging = false

		init(medication: ANMedicationConcept) {
			amount = medication.prescribedDoseAmount ?? 1
			selectedUnit = medication.prescribedUnit ?? .unit
		}
	}

	@MainActor
	final class Session: ObservableObject {
		private var medicationID: UUID?
		private var retainedDraft: Draft?

		func draft(for medication: ANMedicationConcept) -> Draft {
			if let retainedDraft, medicationID == medication.id { return retainedDraft }
			let draft = Draft(medication: medication)
			medicationID = medication.id
			retainedDraft = draft
			return draft
		}

		func reset() {
			retainedDraft = nil
			medicationID = nil
		}
	}

	@StateObject private var draft: Draft
	@State private var amountInput: String?
	@FocusState private var amountIsFocused: Bool
    let medication: ANMedicationConcept
    let source: String
    var onLog: (ANDoseConcept, ANEventConcept, UUID) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption) private var stepperIconSize: CGFloat = 22
    @Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = DHLogger(category: "DoseLogView")
    private let hapticsManager = HapticsManager.shared
    private let dataStore = DataStore.shared
    private let safetyProfileStore = MedicationSafetyProfileStore.shared
    private let guidanceService = MedicationDoseGuidanceService()

    @ScaledMetric(relativeTo: .title2) private var medicationSymbolSize: CGFloat = 28
    private let iconShadowRadius: CGFloat = 12
    private let iconShadowY: CGFloat = 6
    private let topPadding: CGFloat = 8
    private let cardVerticalPadding: CGFloat = 20
    private let cardCornerRadius: CGFloat = 20
    private let shadowRadius: CGFloat = 10
    private let shadowY: CGFloat = 4
    private let sectionPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 16
    private let sectionCornerRadius: CGFloat = 20
    private let contentSpacing: CGFloat = 24
    private let doseSpacing: CGFloat = 20
    private let stepperSpacing: CGFloat = 16
    private let amountMinWidth: CGFloat = 120
    private let amountVerticalPadding: CGFloat = 12
    private let amountHorizontalPadding: CGFloat = 24
    private let amountCornerRadius: CGFloat = 16
    private let unitScrollSpacing: CGFloat = 12
    private let unitHorizontalPadding: CGFloat = 16
    private let unitVerticalPadding: CGFloat = 10
    private let unitScrollPadding: CGFloat = 4
    private let dateDisplayPadding: CGFloat = 16
    private let dateDisplayCornerRadius: CGFloat = 14
    private let quickButtonSpacing: CGFloat = 12
    private let quickButtonHorizontalPadding: CGFloat = 12
    private let quickButtonVerticalPadding: CGFloat = 8
    private let noteHorizontalPadding: CGFloat = 8
    private let noteVerticalPadding: CGFloat = 4
    private let noteTextFieldPadding: CGFloat = 12
    private let noteTextFieldCornerRadius: CGFloat = 12
    private let labelSpacing: CGFloat = 8
    private let standardPadding: CGFloat = 12
    private let buttonHorizontalPadding: CGFloat = 16
    private let buttonVerticalPadding: CGFloat = 16
    private let buttonCornerRadius: CGFloat = 16
    private let buttonShadowRadius: CGFloat = 8
    private let borderWidth: CGFloat = 1
    private let smallSpacing: CGFloat = 4
    private let mediumSpacing: CGFloat = 8
    private let bottomPadding: CGFloat = 20
    private let sectionShadowRadius: CGFloat = 8
    private let sectionShadowY: CGFloat = 2
	@ScaledMetric private var quickTimeOptionMinWidth: CGFloat = 100
    private let guidanceBadgePaddingH: CGFloat = 10
    private let guidanceBadgePaddingV: CGFloat = 6
    private let reflectionGridSpacing: CGFloat = 10
    @ScaledMetric private var scaleButtonMinWidth: CGFloat = 36

	private static let quickTimeSelections: [(label: String, secondsAgo: TimeInterval)] = [
		("Now", 0),
		("15 min ago", 900),
		("30 min ago", 1_800),
		("1 hour ago", 3_600),
		("4 hours ago", 14_400),
		("1 day ago", 86_400),
	]

    private var safetyProfile: MedicationSafetyProfile {
        safetyProfileStore.profile(for: medication.id)
    }

    private var proposedDose: ANDoseConcept {
        ANDoseConcept(amount: draft.amount, unit: draft.selectedUnit)
    }

	private var amountText: Binding<String> {
		Binding(
			get: { amountInput ?? draft.amount.formatted(.number.grouping(.never)) },
			set: { text in
				amountInput = text
				let separator = Locale.current.decimalSeparator ?? "."
				let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
					.replacingOccurrences(of: separator, with: ".")
				let parsed = Double(normalized)
				draft.amount = parsed.flatMap { $0.isFinite ? $0 : nil } ?? 0
			}
		)
	}

    private var assessment: MedicationDoseGuidanceService.Assessment {
        guidanceService.assessment(
            for: medication,
            proposedDose: proposedDose,
            at: draft.selectedDate,
            events: dataStore.events,
            profile: safetyProfile
        )
    }

    private var parsedSideEffects: [String] {
        draft.sideEffectsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

	private var hasChanges: Bool {
		draft.amount != (medication.prescribedDoseAmount ?? 1) ||
		draft.selectedUnit != (medication.prescribedUnit ?? .unit) ||
		draft.selectedQuickOption != "Now" || !draft.reason.isEmpty ||
		draft.symptomSeverityBefore != 0 || draft.symptomSeverityAfter != 0 ||
		draft.effectiveness != 0 || !draft.sideEffectsText.isEmpty || !draft.note.isEmpty
	}

    init(
        medication: ANMedicationConcept,
        source: String = "unknown",
		draft: Draft? = nil,
        onLog: @escaping (ANDoseConcept, ANEventConcept, UUID) async -> Bool
    ) {
        self.medication = medication
        self.source = source
        self.onLog = onLog
		_draft = StateObject(wrappedValue: draft ?? Draft(medication: medication))
    }

    // MARK: - Private Methods

	@MainActor
	private func performLogDose() async {
		guard draft.amount.isFinite, draft.amount > 0 else { return }
        guard !draft.isLogging else {
            logger.warning("Ignored duplicate dose log tap while request is in flight: source=\(source)")
            return
        }

        let operationID = UUID()
        let dose = proposedDose
        let reflection = DoseReflection(
            reason: draft.reason,
            symptomSeverityBefore: nilIfZero(draft.symptomSeverityBefore),
            symptomSeverityAfter: nilIfZero(draft.symptomSeverityAfter),
            effectiveness: nilIfZero(draft.effectiveness),
            sideEffects: parsedSideEffects,
            note: draft.note
        )
        let encodedNote = (try? DoseReflectionCodec.encode(reflection)) ?? draft.note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: draft.selectedDate,
            note: encodedNote
        )

        draft.isLogging = true
        logger.logDoseOperation(
            "Submitting",
            source: source,
            operationID: operationID
        )

        let success = await onLog(dose, event, operationID)
        if success {
            logger.logDoseOperation(
                "Completed",
                source: source,
                operationID: operationID
            )
            hapticsManager.doseLogged()
            dismiss()
        } else {
            logger.error("Dose log failed: source=\(source), operationID=\(operationID.uuidString)")
            draft.isLogging = false
			draft.showingLogError = true
        }
    }

    private func nilIfZero(_ value: Int) -> Int? {
        value == 0 ? nil : value
    }

    private func tintColor(for severity: MedicationDoseGuidanceService.Severity) -> Color {
        switch severity {
        case .clear:
            return .guidanceGreen(for: colorScheme)
        case .caution:
            return .orange
        case .warning:
            return .red
        }
    }

    private var guidanceAccessibilityLabel: String {
        var parts = [assessment.headline, assessment.detail]

        if let nextEligibleDate = assessment.nextEligibleDate, nextEligibleDate > draft.selectedDate {
            parts.append("Next saved interval opens \(nextEligibleDate.formatted(date: .omitted, time: .shortened)).")
        }

        if let maxDailyAmount = assessment.maxDailyAmount {
            parts.append("Daily total would be \(assessment.projectedDailyTotal.formattedAmount) out of \(maxDailyAmount.formattedAmount) \(draft.selectedUnit.abbreviation).")
        }

        parts.append(contentsOf: assessment.reasons)
        return parts.joined(separator: " ")
    }

    // MARK: - View Components

    private var headerCard: some View {
		HStack(alignment: .center, spacing: quickButtonSpacing) {
			// Medication Icon
			Image(systemName: medication.effectiveDisplaySymbol)
				.resizable()
				.scaledToFit()
				.symbolRenderingMode(.monochrome)
				.foregroundStyle(medication.displayColor.dynamicFilledButtonForeground)
				.frame(width: medicationSymbolSize, height: medicationSymbolSize)
				.padding(18)
				.background(medication.displayColor.dynamicFilledButtonBackground, in: Circle())
				.shadow(color: medication.displayColor.opacity(0.3), radius: iconShadowRadius, x: 0, y: iconShadowY)
				.accessibilityHidden(true)

            // Medication Name
            VStack(alignment: .leading, spacing: smallSpacing) {
                Text(medication.demoDisplayName)
                    .demoNameRedacted()
                    .font(.customFont(fontFamily, style: .headline, weight: .bold))
                    .noTruncate()

                if !medication.clinicalName.isEmpty && medication.clinicalName != medication.displayName {
                    Text(medication.demoClinicalName)
                        .demoNameRedacted()
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
                        .noTruncate()
                }
            }
			.padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.06), radius: shadowRadius, x: 0, y: shadowY)
        )
        .padding(.horizontal)
    }

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Label("Dose Amount", systemSymbol: .pills)
                .font(.customFont(fontFamily, style: .headline))
                .foregroundStyle(.primary)

            VStack(spacing: doseSpacing) {
                // Amount Stepper with Visual Feedback
				let amountLayout = dynamicTypeSize.isAccessibilitySize
					? AnyLayout(VStackLayout(spacing: stepperSpacing))
					: AnyLayout(HStackLayout(spacing: stepperSpacing))
				amountLayout {
                    Button(action: {
                        amountIsFocused = false
                        amountInput = nil
                        if draft.amount > 0.5 {
                            draft.amount -= 0.5
                            hapticsManager.lightImpact()
                        }
                    }) {
                        Image(systemSymbol: .minus)
							.font(.customFont(fontFamily, style: .caption, weight: .bold))
							.foregroundStyle(medication.displayColor.dynamicFilledButtonForeground)
							.frame(width: stepperIconSize, height: stepperIconSize)
							.background(medication.displayColor.dynamicFilledButtonBackground, in: Circle())
							.opacity(draft.amount > 0.5 ? 1 : 0.5)
                            .scaleEffect(draft.amount > 0.5 ? 1.0 : 0.9)
                    }
                    .disabled(draft.amount <= 0.5)
					.frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Decrease dose amount")
                    .accessibilityValue("\(draft.amount.formattedAmount) \(draft.selectedUnit.displayName)")

                    VStack(spacing: smallSpacing) {
						TextField("Amount", text: amountText)
                            .font(.customFont(fontFamily, style: .title, weight: .semibold))
							.keyboardType(.decimalPad)
							.multilineTextAlignment(.center)
							.focused($amountIsFocused)
							.accessibilityLabel("Dose amount")
							.accessibilityHint("Enter the amount in \(draft.selectedUnit.displayName)")

                        Text(draft.selectedUnit.displayName)
                            .font(.customFont(fontFamily, style: .subheadline))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    .frame(minWidth: amountMinWidth)
                    .padding(.vertical, amountVerticalPadding)
                    .padding(.horizontal, amountHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: amountCornerRadius, style: .continuous)
                            .fill(medication.displayColor.opacity(0.1))
                    )

                    Button(action: {
                        amountIsFocused = false
                        amountInput = nil
                        if draft.amount < 100 {
                            draft.amount += 0.5
                            hapticsManager.lightImpact()
                        }
                    }) {
                        Image(systemSymbol: .plus)
							.font(.customFont(fontFamily, style: .caption, weight: .bold))
							.foregroundStyle(medication.displayColor.dynamicFilledButtonForeground)
							.frame(width: stepperIconSize, height: stepperIconSize)
							.background(medication.displayColor.dynamicFilledButtonBackground, in: Circle())
							.opacity(draft.amount < 100 ? 1 : 0.5)
                            .scaleEffect(draft.amount < 100 ? 1.0 : 0.9)
                    }
                    .disabled(draft.amount >= 100)
					.frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Increase dose amount")
                    .accessibilityValue("\(draft.amount.formattedAmount) \(draft.selectedUnit.displayName)")
                }
                .accessibilityElement(children: .contain)

                // Unit Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: unitScrollSpacing) {
                        ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                            Button(action: {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                                    draft.selectedUnit = unit
                                    hapticsManager.selectionChanged()
                                }
                            }) {
                                Text(unit.displayName)
                                    .font(.customFont(fontFamily, style: .subheadline, weight: draft.selectedUnit == unit ? .semibold : .regular))
                                    .padding(.horizontal, unitHorizontalPadding)
                                    .padding(.vertical, unitVerticalPadding)
                                    .background {
                                        if draft.selectedUnit == unit {
                                            Capsule()
                                                .fill(medication.displayColor.dynamicFilledButtonBackground)
                                        } else {
                                            Capsule()
                                                .fill(.regularMaterial)
                                        }
                                    }
                                    .foregroundStyle(draft.selectedUnit == unit ? medication.displayColor.dynamicFilledButtonForeground : medication.displayColor)
                            }
                            .accessibilityLabel(unit.displayName)
                            .accessibilityValue(draft.selectedUnit == unit ? "Selected" : "Not selected")
                        }
                    }
                    .padding(.horizontal, unitScrollPadding)
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
                .shadow(color: Color.black.opacity(0.04), radius: sectionShadowRadius, x: 0, y: sectionShadowY)
        )
        .padding(.horizontal)
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Label("When", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
                .font(.customFont(fontFamily, style: .headline))
                .foregroundStyle(.primary)

            VStack(spacing: quickButtonSpacing) {
                // Date Display Button
                Button(action: {
					DoseTimeTip().invalidate(reason: .actionPerformed)
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        draft.showingDatePicker.toggle()
                        hapticsManager.selectionChanged()
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: smallSpacing) {
                            Text(draft.selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                                .font(.customFont(fontFamily, style: .subheadline))
                                .foregroundStyle(.secondary)

                            Text(draft.selectedDate, format: .dateTime.hour().minute())
                                .font(.customFont(fontFamily, style: .title3))
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemSymbol: .chevronUpChevronDown)
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(medication.displayColor)
                    }
                    .padding(dateDisplayPadding)
                    .background(
                        RoundedRectangle(cornerRadius: dateDisplayCornerRadius, style: .continuous)
                            .fill(medication.displayColor.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dose time")
                .accessibilityValue(draft.selectedDate.formatted(date: .abbreviated, time: .shortened))
                .accessibilityHint("Tap to show or hide the date picker")
				.popoverTip(AppTips.isConfigured ? DoseTimeTip() : nil)

                if draft.showingDatePicker {
                    DatePicker(
                            "Dose date and time",
                        selection: $draft.selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .onChange(of: draft.selectedDate) { _, _ in
                        draft.selectedQuickOption = nil
                    }
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }

				LazyVGrid(
					columns: [GridItem(
						dynamicTypeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum: quickTimeOptionMinWidth),
						spacing: quickButtonSpacing
					)],
					spacing: quickButtonSpacing
				) {
					ForEach(Self.quickTimeSelections, id: \.label) { label, secondsAgo in
                        Button(action: {
							DoseTimeTip().invalidate(reason: .actionPerformed)
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                                draft.selectedDate = Date().addingTimeInterval(-secondsAgo)
                                draft.selectedQuickOption = label
                                draft.showingDatePicker = false
                                hapticsManager.selectionChanged()
                            }
                        }) {
                            Text(label)
                                .font(.customFont(fontFamily, style: .caption, weight: .medium))
                                .padding(.horizontal, quickButtonHorizontalPadding)
                                .padding(.vertical, quickButtonVerticalPadding)
								.frame(maxWidth: .infinity, minHeight: 44)
								.fixedSize(horizontal: false, vertical: true)
                                .background {
                                    if draft.selectedQuickOption == label {
                                        Capsule()
                                            .fill(medication.displayColor.dynamicFilledButtonBackground)
                                    } else {
                                        Capsule()
                                            .fill(.regularMaterial)
                                    }
                                }
                                .foregroundStyle(draft.selectedQuickOption == label ? medication.displayColor.dynamicFilledButtonForeground : medication.displayColor)
                        }
                        .accessibilityLabel(label)
                        .accessibilityValue(draft.selectedQuickOption == label ? "Selected" : "Not selected")
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
                .shadow(color: Color.black.opacity(0.04), radius: sectionShadowRadius, x: 0, y: sectionShadowY)
        )
        .padding(.horizontal)
    }

	private var sectionHeaderLayout: AnyLayout {
		dynamicTypeSize.isAccessibilitySize
			? AnyLayout(VStackLayout(alignment: .leading, spacing: labelSpacing))
			: AnyLayout(HStackLayout())
	}

    private var guidanceSection: some View {
        let tint = tintColor(for: assessment.severity)

        return VStack(alignment: .leading, spacing: sectionSpacing) {
            sectionHeaderLayout {
                Label("Dose Check", systemSymbol: .crossCaseFill)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)

				if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                Text(assessment.severity == .clear ? "Saved Guidance" : "Review")
                    .font(.customFont(fontFamily, style: .caption, weight: .medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, guidanceBadgePaddingH)
                    .padding(.vertical, guidanceBadgePaddingV)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: mediumSpacing) {
                Text(assessment.headline)
                    .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(assessment.detail)
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let nextEligibleDate = assessment.nextEligibleDate, nextEligibleDate > draft.selectedDate {
                HStack(alignment: .top, spacing: mediumSpacing) {
                    Image(systemSymbol: .clockBadgeExclamationmark)
                        .foregroundStyle(tint)
                        .padding(.top, smallSpacing)

                    Text("Next saved interval opens \(nextEligibleDate.formatted(date: .omitted, time: .shortened)).")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let maxDailyAmount = assessment.maxDailyAmount {
                HStack(alignment: .top, spacing: mediumSpacing) {
                    Image(systemSymbol: .chartBarFill)
                        .foregroundStyle(tint)
                        .padding(.top, smallSpacing)

                    Text("Daily total would be \(assessment.projectedDailyTotal.formattedAmount) out of \(maxDailyAmount.formattedAmount) \(draft.selectedUnit.abbreviation).")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !assessment.reasons.isEmpty {
                VStack(alignment: .leading, spacing: smallSpacing) {
                    ForEach(assessment.reasons, id: \.self) { guidanceReason in
                        HStack(alignment: .top, spacing: smallSpacing) {
                            Image(systemSymbol: .circleFill)
                                .font(.customFont(fontFamily, style: .caption2))
                                .foregroundStyle(tint)
                                .padding(.top, smallSpacing)

                            Text(guidanceReason)
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.14 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                        .strokeBorder(tint.opacity(0.14), lineWidth: borderWidth)
                )
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(guidanceAccessibilityLabel)
    }

	private func reviewGuidanceButton(proxy: ScrollViewProxy) -> some View {
		Button {
			amountIsFocused = false
			UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
			withAnimation(reduceMotion ? nil : .easeInOut) {
				proxy.scrollTo(ScrollTarget.guidance, anchor: .top)
			}
		} label: {
			HStack(spacing: 12) {
				Image(systemSymbol: .exclamationmarkTriangleFill)
					.accessibilityHidden(true)
				Text("Review before logging")
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))
					.noTruncate()
				Spacer(minLength: 0)
				Image(systemSymbol: .arrowDown)
					.accessibilityHidden(true)
			}
			.font(.customFont(fontFamily, style: .body))
			.foregroundStyle(.black)
			.padding(16)
			.frame(maxWidth: .infinity, minHeight: 44)
			.background(.yellow, in: RoundedRectangle(cornerRadius: 12))
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
		.padding(.top, topPadding)
		.accessibilityHint("Scroll to the dose check warning")
	}

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            sectionHeaderLayout {
                Label("How It Went", systemSymbol: .heartTextSquareFill)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)

				if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                Text("Optional")
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, noteHorizontalPadding)
                    .padding(.vertical, noteVerticalPadding)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }

            VStack(alignment: .leading, spacing: labelSpacing) {
                Text("Reason")
                    .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

                TextField("Example: headache", text: $draft.reason, axis: .vertical)
					.lineLimit(1 ... 3)
                    .font(.customFont(fontFamily, style: .body))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Reason for taking this dose")
            }

			LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
				? [GridItem(.flexible())]
				: [GridItem(.adaptive(minimum: 220), spacing: reflectionGridSpacing)], spacing: reflectionGridSpacing) {
                scalePickerCard(
                    title: "Before",
                    subtitle: "Symptom level before logging",
                    selection: $draft.symptomSeverityBefore
                )

                scalePickerCard(
                    title: "After",
                    subtitle: "How you feel afterward",
                    selection: $draft.symptomSeverityAfter
                )

                scalePickerCard(
                    title: "Effect",
                    subtitle: "How helpful this dose feels",
                    selection: $draft.effectiveness
                )

                VStack(alignment: .leading, spacing: labelSpacing) {
                    Text("Side Effects")
                        .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

                    Text("Separate with commas if needed.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)

                    TextField("Sleepy, dry mouth, nausea", text: $draft.sideEffectsText, axis: .vertical)
                        .font(.customFont(fontFamily, style: .body))
                        .lineLimit(2 ... 4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Side effects")
                }
				.frame(maxWidth: .infinity, alignment: .leading)
                .padding(standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: dateDisplayCornerRadius, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
                .shadow(color: Color.black.opacity(0.04), radius: sectionShadowRadius, x: 0, y: sectionShadowY)
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private func scalePickerCard(title: String, subtitle: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            Text(title)
                .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

            Text(subtitle)
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

			Text(selection.wrappedValue == 0 ? "Not rated" : "\(selection.wrappedValue) of 5")
				.font(.customFont(fontFamily, style: .body, weight: .medium))
				.foregroundStyle(.primary)

			Slider(
				value: Binding(
					get: { Double(selection.wrappedValue) },
					set: { selection.wrappedValue = Int($0.rounded()) }
				),
				in: 0 ... 5,
				step: 1
			) {
				Text("\(title): \(subtitle)")
					.font(.customFont(fontFamily, style: .body))
			} currentValueLabel: {
				Text(selection.wrappedValue == 0 ? "Not rated" : "\(selection.wrappedValue) of 5")
					.font(.customFont(fontFamily, style: .body))
			} minimumValueLabel: {
				Text("Not rated")
					.font(.customFont(fontFamily, style: .caption))
			} maximumValueLabel: {
				Text("5")
					.font(.customFont(fontFamily, style: .caption))
			}
			.frame(maxWidth: .infinity, minHeight: 44)
			.tint(medication.displayColor)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel("\(title): \(subtitle)")
			.accessibilityValue(selection.wrappedValue == 0 ? "Not rated" : "\(selection.wrappedValue) of 5")
			.accessibilityAdjustableAction { direction in
				switch direction {
				case .increment: selection.wrappedValue = min(5, selection.wrappedValue + 1)
				case .decrement: selection.wrappedValue = max(0, selection.wrappedValue - 1)
				@unknown default: break
				}
			}
        }
		.frame(maxWidth: .infinity, alignment: .leading)
        .padding(standardPadding)
        .background(
            RoundedRectangle(cornerRadius: dateDisplayCornerRadius, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            sectionHeaderLayout {
                Label("Note", systemSymbol: .noteText)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)

				if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                Text("Optional")
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, noteHorizontalPadding)
                    .padding(.vertical, noteVerticalPadding)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }

            // Use the new expandable note editor component
            ExpandableNoteEditorComponent(
                noteText: $draft.note,
                placeholder: "How are you feeling? Any side effects?",
                medicationName: medication.demoDisplayName,
				accentColor: medication.displayColor,
                onSave: {
                    // Haptic feedback when note is saved
                    hapticsManager.lightImpact()
                }
            )
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
                .shadow(color: Color.black.opacity(0.04), radius: sectionShadowRadius, x: 0, y: sectionShadowY)
        )
        .padding(.horizontal)
    }

    private var logButton: some View {
        Button {
            Task {
                await performLogDose()
            }
        } label: {
            HStack(spacing: quickButtonSpacing) {
                if draft.isLogging {
                    ProgressView()
                        .tint(medication.displayColor.dynamicFilledButtonForeground)
                } else {
                    Image(systemSymbol: .checkmarkCircleFill)
                        .font(.customFont(fontFamily, style: .title3))
                }

                Text(draft.isLogging ? "Logging" : "Log Dose")
                    .font(.customFont(fontFamily, style: .headline))
					.fixedSize(horizontal: false, vertical: true)
					.multilineTextAlignment(.center)
            }
            .foregroundStyle(medication.displayColor.dynamicFilledButtonForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [medication.displayColor.dynamicFilledButtonBackground, medication.displayColor.dynamicFilledButtonBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: medication.displayColor.opacity(0.3), radius: buttonShadowRadius, x: 0, y: shadowY)
            )
            .overlay(
                RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
        }
        .disabled(!draft.amount.isFinite || draft.amount <= 0 || draft.isLogging)
        .opacity(draft.amount <= 0 || draft.isLogging ? 0.6 : 1.0)
        .accessibilityLabel(draft.isLogging ? "Logging dose" : "Log dose")
        .accessibilityValue("\(draft.amount.formattedAmount) \(draft.selectedUnit.displayName)")
        .accessibilityHint(assessment.severity == .clear ? "Saves this dose entry" : "Saves this dose entry with the shown guidance warning")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
				ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: contentSpacing) {
						if assessment.severity != .clear {
							reviewGuidanceButton(proxy: proxy)
						}
                        headerCard
                            .padding(.top, topPadding)

                        doseSection

                        dateTimeSection

						if assessment.severity != .clear ||
							medication.minimumHoursBetweenDoses != nil ||
							safetyProfile.minimumHoursBetweenDoses != nil ||
							assessment.maxDailyAmount != nil {
							guidanceSection
								.id(ScrollTarget.guidance)
						}

                        reflectionSection

                        noteSection
                    }
                    .padding(.bottom, bottomPadding)
                }
                .background(
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()
                )
                .scrollDismissesKeyboard(.interactively)
				.disabled(draft.isLogging)
				}

                // Sticky button container
                VStack(spacing: 0) {
                    Divider()
                        .background(.separator.opacity(0.5))

                    logButton
                        .padding(.horizontal, buttonHorizontalPadding)
                        .padding(.vertical, buttonVerticalPadding)
                }
                .background(.regularMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
			.customNavigationTitle("Log Dose", displayMode: .inline)
            .toolbar {
				ToolbarItemGroup(placement: .keyboard) {
					if amountIsFocused {
						Spacer()
						Button("Done") { amountIsFocused = false }
							.font(.customFont(fontFamily, style: .body))
					}
				}
				ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
					if hasChanges { draft.showingDiscardConfirmation = true } else { dismiss() }
                }
				.disabled(draft.isLogging)
				.tint(medication.displayColor)
				}
            }
            .tint(medication.displayColor)
			.alert("Check Dose History", isPresented: $draft.showingLogError) {
				Button("Keep Editing", role: .cancel) {}
			} message: {
				Text("Some changes may already be saved. Your entry is still here. Check History before logging again.")
			}
			.confirmationDialog("Discard this dose entry?", isPresented: $draft.showingDiscardConfirmation, titleVisibility: .visible) {
				Button("Discard Entry", role: .destructive) { dismiss() }
				Button("Keep Editing", role: .cancel) {}
			}
        }
        .interactiveDismissDisabled(draft.isLogging || hasChanges)
    }
}

#if DEBUG
    import SwiftUI

    #Preview {
        LogDoseView(
            medication: ANMedicationConcept(clinicalName: "Ibuprofen", nickname: "Pain Relief"),
            onLog: { _, _, _ in true }
        )
    }
#endif

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
