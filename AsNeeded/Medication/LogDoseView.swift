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
	
	@State private var amount: Double = 1
	@State private var selectedUnit: ANUnitConcept = .unit
	@State private var selectedDate: Date = .now
	@State private var note: String = ""
	@FocusState private var isNoteFocused: Bool
	@State private var showingDatePicker = false
	@State private var animateHeader = false
	@State private var selectedQuickOption: String? = "Now"
	private let hapticsManager = HapticsManager.shared

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
		VStack(spacing: 12) {
			// Medication Icon
			ZStack {
				Circle()
					.fill(
						LinearGradient(
							colors: [Color.accentColor.opacity(0.8), Color.accentColor],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: 80, height: 80)
					.shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
				
				Image(systemSymbol: .pills)
					.font(.system(.largeTitle, design: .default, weight: .semibold))
					.foregroundStyle(.white)
					.symbolEffect(.pulse, options: .repeating.speed(0.5), value: animateHeader)
			}
			.padding(.top, 8)
			
			// Medication Name
			VStack(spacing: 4) {
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
		.padding(.vertical, 20)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(.regularMaterial)
				.shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
		)
		.padding(.horizontal)
		.onAppear {
			withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
				animateHeader = true
			}
		}
	}
	
	private var doseSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Dose Amount", systemSymbol: .pills)
				.font(.headline)
				.foregroundStyle(.primary)
			
			VStack(spacing: 20) {
				// Amount Stepper with Visual Feedback
				HStack(spacing: 16) {
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
					
					VStack(spacing: 4) {
						Text("\(amount, specifier: "%.1f")")
							.font(.system(.title, design: .rounded, weight: .semibold))
							.contentTransition(.numericText())
						
						Text(selectedUnit.displayName)
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.textCase(.uppercase)
					}
					.frame(minWidth: 120)
					.padding(.vertical, 12)
					.padding(.horizontal, 24)
					.background(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
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
					HStack(spacing: 12) {
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
									.padding(.horizontal, 16)
									.padding(.vertical, 10)
									.background(
										Capsule()
											.fill(selectedUnit == unit ? Color.accentColor : Color.secondary.opacity(0.1))
									)
									.foregroundStyle(selectedUnit == unit ? .white : .primary)
							}
						}
					}
					.padding(.horizontal, 4)
				}
			}
		}
		.padding(20)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
				.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
		)
		.padding(.horizontal)
	}
	
	private var dateTimeSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("When", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
				.font(.headline)
				.foregroundStyle(.primary)
			
			VStack(spacing: 12) {
				// Date Display Button
				Button(action: { 
					withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
						showingDatePicker.toggle()
						hapticsManager.selectionChanged()
					}
				}) {
					HStack {
						VStack(alignment: .leading, spacing: 4) {
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
					.padding(16)
					.background(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
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
				HStack(spacing: 12) {
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
								.padding(.horizontal, 12)
								.padding(.vertical, 8)
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
		.padding(20)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
				.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
		)
		.padding(.horizontal)
	}
	
	private var noteSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Label("Note", systemSymbol: .noteText)
					.font(.headline)
					.foregroundStyle(.primary)
				
				Spacer()
				
				Text("Optional")
					.font(.caption)
					.foregroundStyle(.secondary)
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
					.background(
						Capsule()
							.fill(Color.secondary.opacity(0.1))
					)
			}
			
			TextField("How are you feeling? Any side effects?", text: $note, axis: .vertical)
				.lineLimit(3...6)
				.padding(12)
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(Color.secondary.opacity(0.08))
				)
				.focused($isNoteFocused)
		}
		.padding(20)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white)
				.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
		)
		.padding(.horizontal)
	}
	
	private var logButton: some View {
		Button(action: performLogDose) {
			HStack(spacing: 12) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.title3)
				
				Text("Log Dose")
					.font(.headline)
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 18)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.accentColor, Color.accentColor.opacity(0.9)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			)
		}
		.disabled(amount <= 0)
		.opacity(amount <= 0 ? 0.6 : 1.0)
		.padding(.horizontal)
		.padding(.bottom, 8)
	}
	
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 24) {
					headerCard
						.padding(.top, 8)
					
					doseSection
					
					dateTimeSection
					
					noteSection
					
					logButton
						.padding(.top, 8)
				}
				.padding(.bottom, 20)
			}
			.background(
				Color(uiColor: .systemGroupedBackground)
					.ignoresSafeArea()
			)
			.navigationBarTitleDisplayMode(.inline)
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(action: { dismiss() }) {
						Image(systemSymbol: .xmarkCircleFill)
							.font(.title3)
							.symbolRenderingMode(.hierarchical)
							.foregroundStyle(.secondary)
					}
				}
				
				ToolbarItem(placement: .confirmationAction) {
					Button(action: performLogDose) {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.title3)
							.symbolRenderingMode(.hierarchical)
							.foregroundColor(.accentColor)
					}
					.disabled(amount <= 0)
					.opacity(amount <= 0 ? 0.6 : 1.0)
					.accessibilityLabel("Log dose")
					.accessibilityHint("Logs the dose with current settings")
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
