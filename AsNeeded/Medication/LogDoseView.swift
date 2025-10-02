// LogDoseView.swift
// SwiftUI view for logging a dose taken for a medication, using ANModelKit concepts.

import SwiftUI
import ANModelKit
import SFSafeSymbols

struct LogDoseView: View {
	let medication: ANMedicationConcept
	var onLog: (ANDoseConcept, ANEventConcept) -> Void
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.fontFamily) private var fontFamily

	@State private var amount: Double = 1
	@State private var selectedUnit: ANUnitConcept = .unit
	@State private var selectedDate: Date = .now
	@State private var note: String = ""
	@State private var showingDatePicker = false
	@State private var animateHeader = false
	@State private var selectedQuickOption: String? = "Now"
	@State private var animateNoteSection = false
	private let hapticsManager = HapticsManager.shared

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
			let dose = ANDoseConcept(amount: amount, unit: selectedUnit)
			let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
			let event = ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: dose,
				date: selectedDate,
				note: trimmedNote.isEmpty ? nil : trimmedNote
			)
			onLog(dose, event)
			hapticsManager.doseLogged()
			dismiss()
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
				
				Image(systemSymbol: .pills)
					.font(.largeTitle.weight(.semibold))
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
			// Animate note section to draw attention
			withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
				animateNoteSection = true
			}
			// Stop animation after initial attention-grab
			DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
				animateNoteSection = false
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
							.foregroundStyle(amount > 0.5 ? Color.accentColor : Color.secondary.opacity(0.5))
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
							.fill(Color.accentColor.opacity(0.1))
					)
					
					Button(action: {
							if amount < 100 {
								amount += 0.5
								hapticsManager.lightImpact()
							}
					}) {
						Image(systemSymbol: .plusCircleFill)
							.font(.title2)
							.foregroundStyle(amount < 100 ? Color.accentColor : Color.secondary.opacity(0.5))
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
									.background(
										Capsule()
											.fill(selectedUnit == unit ? Color.accentColor : Color.secondary.opacity(0.1))
									)
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
							.fill(Color.accentColor.opacity(0.08))
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
						("1 hour ago", Date().addingTimeInterval(-60 * 60))
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
								.background(
									Capsule()
										.fill(selectedQuickOption == label ? Color.accentColor : Color.secondary.opacity(0.1))
								)
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
		.scaleEffect(animateNoteSection ? 1.02 : 1.0)
		.animation(
			animateNoteSection ?
				Animation.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true) :
				.default,
			value: animateNoteSection
		)
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

						noteSection  // Moved higher for better visibility

						dateTimeSection
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
				ToolbarItem(placement: .cancellationAction) {
					Button(action: { dismiss() }) {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
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
