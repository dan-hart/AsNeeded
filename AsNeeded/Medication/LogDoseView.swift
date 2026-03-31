// LogDoseView.swift
// SwiftUI view for logging a dose taken for a medication, using ANModelKit concepts.

import ANModelKit
import SFSafeSymbols
import SwiftUI

struct LogDoseView: View {
    let medication: ANMedicationConcept
    var onLog: (ANDoseConcept, ANEventConcept) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fontFamily) private var fontFamily

    @State private var amount: Double = 1
    @State private var selectedUnit: ANUnitConcept = .unit
    @State private var selectedDate: Date = .now
    @State private var reason: String = ""
    @State private var symptomSeverityBefore: Int = 0
    @State private var symptomSeverityAfter: Int = 0
    @State private var effectiveness: Int = 0
    @State private var sideEffectsText: String = ""
    @State private var note: String = ""
    @State private var showingDatePicker = false
    @State private var animateHeader = false
    @State private var selectedQuickOption: String? = "Now"
    private let hapticsManager = HapticsManager.shared
    private let dataStore = DataStore.shared
    private let safetyProfileStore = MedicationSafetyProfileStore.shared
    private let guidanceService = MedicationDoseGuidanceService()

    @ScaledMetric private var iconSize: CGFloat = 80
    @ScaledMetric private var iconShadowRadius: CGFloat = 12
    @ScaledMetric private var iconShadowY: CGFloat = 6
    @ScaledMetric private var topPadding: CGFloat = 8
    @ScaledMetric private var cardVerticalPadding: CGFloat = 20
    @ScaledMetric private var cardCornerRadius: CGFloat = 20
    @ScaledMetric private var shadowRadius: CGFloat = 10
    @ScaledMetric private var shadowY: CGFloat = 4
    @ScaledMetric private var sectionPadding: CGFloat = 20
    @ScaledMetric private var sectionSpacing: CGFloat = 16
    @ScaledMetric private var sectionCornerRadius: CGFloat = 20
    @ScaledMetric private var contentSpacing: CGFloat = 24
    @ScaledMetric private var doseSpacing: CGFloat = 20
    @ScaledMetric private var stepperSpacing: CGFloat = 16
    @ScaledMetric private var amountMinWidth: CGFloat = 120
    @ScaledMetric private var amountVerticalPadding: CGFloat = 12
    @ScaledMetric private var amountHorizontalPadding: CGFloat = 24
    @ScaledMetric private var amountCornerRadius: CGFloat = 16
    @ScaledMetric private var unitScrollSpacing: CGFloat = 12
    @ScaledMetric private var unitHorizontalPadding: CGFloat = 16
    @ScaledMetric private var unitVerticalPadding: CGFloat = 10
    @ScaledMetric private var unitScrollPadding: CGFloat = 4
    @ScaledMetric private var dateDisplayPadding: CGFloat = 16
    @ScaledMetric private var dateDisplayCornerRadius: CGFloat = 14
    @ScaledMetric private var quickButtonSpacing: CGFloat = 12
    @ScaledMetric private var quickButtonHorizontalPadding: CGFloat = 12
    @ScaledMetric private var quickButtonVerticalPadding: CGFloat = 8
    @ScaledMetric private var noteHorizontalPadding: CGFloat = 8
    @ScaledMetric private var noteVerticalPadding: CGFloat = 4
    @ScaledMetric private var noteTextFieldPadding: CGFloat = 12
    @ScaledMetric private var noteTextFieldCornerRadius: CGFloat = 12
    @ScaledMetric private var labelSpacing: CGFloat = 8
    @ScaledMetric private var standardPadding: CGFloat = 12
    @ScaledMetric private var buttonHorizontalPadding: CGFloat = 16
    @ScaledMetric private var buttonVerticalPadding: CGFloat = 16
    @ScaledMetric private var buttonCornerRadius: CGFloat = 16
    @ScaledMetric private var buttonShadowRadius: CGFloat = 8
    @ScaledMetric private var borderWidth: CGFloat = 1
    @ScaledMetric private var smallSpacing: CGFloat = 4
    @ScaledMetric private var mediumSpacing: CGFloat = 8
    @ScaledMetric private var bottomPadding: CGFloat = 20
    @ScaledMetric private var sectionShadowRadius: CGFloat = 8
    @ScaledMetric private var sectionShadowY: CGFloat = 2
    @ScaledMetric private var guidanceBadgePaddingH: CGFloat = 10
    @ScaledMetric private var guidanceBadgePaddingV: CGFloat = 6
    @ScaledMetric private var reflectionGridSpacing: CGFloat = 10
    @ScaledMetric private var scaleButtonMinWidth: CGFloat = 36

    private var safetyProfile: MedicationSafetyProfile {
        safetyProfileStore.profile(for: medication.id)
    }

    private var proposedDose: ANDoseConcept {
        ANDoseConcept(amount: amount, unit: selectedUnit)
    }

    private var assessment: MedicationDoseGuidanceService.Assessment {
        guidanceService.assessment(
            for: medication,
            proposedDose: proposedDose,
            at: selectedDate,
            events: dataStore.events,
            profile: safetyProfile
        )
    }

    private var parsedSideEffects: [String] {
        sideEffectsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    init(
        medication: ANMedicationConcept,
        onLog: @escaping (ANDoseConcept, ANEventConcept) -> Void
    ) {
        self.medication = medication
        self.onLog = onLog
        _amount = State(initialValue: medication.prescribedDoseAmount ?? 1)
        _selectedUnit = State(initialValue: medication.prescribedUnit ?? .unit)
    }

    // MARK: - Private Methods

    private func performLogDose() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            let dose = proposedDose
            let reflection = DoseReflection(
                reason: reason,
                symptomSeverityBefore: nilIfZero(symptomSeverityBefore),
                symptomSeverityAfter: nilIfZero(symptomSeverityAfter),
                effectiveness: nilIfZero(effectiveness),
                sideEffects: parsedSideEffects,
                note: note
            )
            let encodedNote = (try? DoseReflectionCodec.encode(reflection)) ?? note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let event = ANEventConcept(
                eventType: .doseTaken,
                medication: medication,
                dose: dose,
                date: selectedDate,
                note: encodedNote
            )
            onLog(dose, event)
            hapticsManager.doseLogged()
            dismiss()
        }
    }

    private func nilIfZero(_ value: Int) -> Int? {
        value == 0 ? nil : value
    }

    private func tintColor(for severity: MedicationDoseGuidanceService.Severity) -> Color {
        switch severity {
        case .clear:
            return medication.displayColor
        case .caution:
            return .orange
        case .warning:
            return .red
        }
    }

    // MARK: - View Components

    private var headerCard: some View {
        VStack(spacing: quickButtonSpacing) {
            // Medication Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [medication.displayColor.opacity(0.8), medication.displayColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: medication.displayColor.opacity(0.3), radius: iconShadowRadius, x: 0, y: iconShadowY)

                Image(systemName: medication.effectiveDisplaySymbol)
                    .font(.largeTitle.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5), value: animateHeader)
            }
            .padding(.top, topPadding)

            // Medication Name
            VStack(spacing: smallSpacing) {
                Text(medication.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if !medication.clinicalName.isEmpty && medication.clinicalName != medication.displayName {
                    Text(medication.clinicalName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, cardVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.06), radius: shadowRadius, x: 0, y: shadowY)
        )
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                animateHeader = true
            }
        }
    }

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Label("Dose Amount", systemSymbol: .pills)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: doseSpacing) {
                // Amount Stepper with Visual Feedback
                HStack(spacing: stepperSpacing) {
                    Button(action: {
                        if amount > 0.5 {
                            amount -= 0.5
                            hapticsManager.lightImpact()
                        }
                    }) {
                        Image(systemSymbol: .minusCircleFill)
                            .font(.title2)
                            .foregroundStyle(amount > 0.5 ? .accent : Color.secondary.opacity(0.5))
                            .scaleEffect(amount > 0.5 ? 1.0 : 0.9)
                    }
                    .disabled(amount <= 0.5)

                    VStack(spacing: smallSpacing) {
                        Text("\(amount, specifier: "%.1f")")
                            .font(.title.weight(.semibold))
                            .contentTransition(.numericText())

                        Text(selectedUnit.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    .frame(minWidth: amountMinWidth)
                    .padding(.vertical, amountVerticalPadding)
                    .padding(.horizontal, amountHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: amountCornerRadius, style: .continuous)
                            .fill(.accent.opacity(0.1))
                    )

                    Button(action: {
                        if amount < 100 {
                            amount += 0.5
                            hapticsManager.lightImpact()
                        }
                    }) {
                        Image(systemSymbol: .plusCircleFill)
                            .font(.title2)
                            .foregroundStyle(amount < 100 ? .accent : Color.secondary.opacity(0.5))
                            .scaleEffect(amount < 100 ? 1.0 : 0.9)
                    }
                    .disabled(amount >= 100)
                }

                // Unit Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: unitScrollSpacing) {
                        ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedUnit = unit
                                    hapticsManager.selectionChanged()
                                }
                            }) {
                                Text(unit.displayName)
                                    .font(.subheadline)
                                    .fontWeight(selectedUnit == unit ? .semibold : .regular)
                                    .padding(.horizontal, unitHorizontalPadding)
                                    .padding(.vertical, unitVerticalPadding)
                                    .background {
                                        if selectedUnit == unit {
                                            Capsule()
                                                .fill(.accent.gradient)
                                        } else {
                                            Capsule()
                                                .fill(.regularMaterial)
                                        }
                                    }
                                    .foregroundStyle(selectedUnit == unit ? .white : .primary)
                            }
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
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: quickButtonSpacing) {
                // Date Display Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingDatePicker.toggle()
                        hapticsManager.selectionChanged()
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: smallSpacing) {
                            Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(selectedDate, format: .dateTime.hour().minute())
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemSymbol: .chevronUpChevronDown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(dateDisplayPadding)
                    .background(
                        RoundedRectangle(cornerRadius: dateDisplayCornerRadius, style: .continuous)
                            .fill(.accent.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                if showingDatePicker {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .onChange(of: selectedDate) { _, _ in
                        selectedQuickOption = nil
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }

                // Quick Actions
                HStack(spacing: quickButtonSpacing) {
                    ForEach([
                        ("Now", Date()),
                        ("30 min ago", Date().addingTimeInterval(-30 * 60)),
                        ("1 hour ago", Date().addingTimeInterval(-60 * 60)),
                    ], id: \.0) { label, date in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDate = date
                                selectedQuickOption = label
                                showingDatePicker = false
                                hapticsManager.selectionChanged()
                            }
                        }) {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, quickButtonHorizontalPadding)
                                .padding(.vertical, quickButtonVerticalPadding)
                                .background {
                                    if selectedQuickOption == label {
                                        Capsule()
                                            .fill(.accent.gradient)
                                    } else {
                                        Capsule()
                                            .fill(.regularMaterial)
                                    }
                                }
                                .foregroundStyle(selectedQuickOption == label ? .white : .primary)
                        }
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

    private var guidanceSection: some View {
        let tint = tintColor(for: assessment.severity)

        return VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Dose Check", systemSymbol: .crossCaseFill)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)

                Spacer()

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

            if let nextEligibleDate = assessment.nextEligibleDate, nextEligibleDate > selectedDate {
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

                    Text("Daily total would be \(assessment.projectedDailyTotal.formattedAmount) out of \(maxDailyAmount.formattedAmount) \(selectedUnit.abbreviation).")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !assessment.reasons.isEmpty {
                VStack(alignment: .leading, spacing: smallSpacing) {
                    ForEach(assessment.reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: smallSpacing) {
                            Image(systemSymbol: .circleFill)
                                .font(.customFont(fontFamily, style: .caption2))
                                .foregroundStyle(tint)
                                .padding(.top, smallSpacing)

                            Text(reason)
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
    }

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("How It Went", systemSymbol: .heartTextSquareFill)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)

                Spacer()

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

                TextField("Example: headache, cramps, trouble sleeping", text: $reason)
                    .font(.customFont(fontFamily, style: .body))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Reason for taking this dose")
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: reflectionGridSpacing), GridItem(.flexible(), spacing: reflectionGridSpacing)], spacing: reflectionGridSpacing) {
                scalePickerCard(
                    title: "Before",
                    subtitle: "Symptom level before logging",
                    selection: $symptomSeverityBefore
                )

                scalePickerCard(
                    title: "After",
                    subtitle: "How you feel afterward",
                    selection: $symptomSeverityAfter
                )

                scalePickerCard(
                    title: "Effect",
                    subtitle: "How helpful this dose feels",
                    selection: $effectiveness
                )

                VStack(alignment: .leading, spacing: labelSpacing) {
                    Text("Side Effects")
                        .font(.customFont(fontFamily, style: .subheadline, weight: .medium))

                    Text("Separate with commas if needed.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)

                    TextField("Sleepy, dry mouth, nausea", text: $sideEffectsText, axis: .vertical)
                        .font(.customFont(fontFamily, style: .body))
                        .lineLimit(2 ... 4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Side effects")
                }
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

            HStack(spacing: smallSpacing) {
                ForEach(0 ... 5, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                        hapticsManager.selectionChanged()
                    } label: {
                        Text(value == 0 ? "—" : "\(value)")
                            .font(.customFont(fontFamily, style: .caption, weight: .medium))
                            .frame(minWidth: scaleButtonMinWidth)
                            .padding(.vertical, mediumSpacing)
                            .background(
                                RoundedRectangle(cornerRadius: noteTextFieldCornerRadius, style: .continuous)
                                    .fill(selection.wrappedValue == value ? medication.displayColor.opacity(0.14) : Color(.systemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: noteTextFieldCornerRadius, style: .continuous)
                                    .strokeBorder(selection.wrappedValue == value ? medication.displayColor.opacity(0.4) : Color(.systemGray4), lineWidth: borderWidth)
                            )
                            .foregroundStyle(selection.wrappedValue == value ? medication.displayColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(value == 0 ? "not set" : "\(value)")")
                }
            }
        }
        .padding(standardPadding)
        .background(
            RoundedRectangle(cornerRadius: dateDisplayCornerRadius, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                Label("Note", systemSymbol: .noteText)
                    .font(.customFont(fontFamily, style: .headline))
                    .foregroundStyle(.primary)

                Spacer()

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
                noteText: $note,
                placeholder: "How are you feeling? Any side effects?",
                medicationName: medication.displayName,
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
        Button(action: performLogDose) {
            HStack(spacing: quickButtonSpacing) {
                Image(systemSymbol: .checkmarkCircleFill)
                    .font(.title3)

                Text("Log Dose")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [medication.displayColor, medication.displayColor.opacity(0.9)],
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
        .disabled(amount <= 0)
        .opacity(amount <= 0 ? 0.6 : 1.0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: contentSpacing) {
                        headerCard
                            .padding(.top, topPadding)

                        doseSection

                        dateTimeSection

                        guidanceSection

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
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled(amount != (medication.prescribedDoseAmount ?? 1) || !note.isEmpty)
    }
}

#if DEBUG
    import SwiftUI

    #Preview {
        LogDoseView(
            medication: ANMedicationConcept(clinicalName: "Ibuprofen", nickname: "Pain Relief"),
            onLog: { _, _ in }
        )
    }
#endif

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
