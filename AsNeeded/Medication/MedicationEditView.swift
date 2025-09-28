// MedicationEditView.swift
// SwiftUI view for editing clinicalName, nickname, quantity, lastRefillDate, and nextRefillDate of ANMedicationConcept.

import SwiftUI
import Boutique
import ANModelKit
import SFSafeSymbols

// Button style for quick date adjustments
struct QuickDateButton: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.subheadline)
			.fontWeight(.medium)
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.background(
				Capsule()
					.fill(Color.accentColor.opacity(configuration.isPressed ? 0.2 : 0.1))
			)
			.scaleEffect(configuration.isPressed ? 0.95 : 1)
	}
}

struct MedicationEditView: View {
	@StateObject private var viewModel: MedicationEditViewModel
	@State private var showingDatePicker = false
	@State private var datePickerType: DatePickerType = .lastRefill
	@FocusState private var focusedField: Field?
	@Environment(\.colorScheme) private var colorScheme
	private let hapticsManager = HapticsManager.shared
	
	enum Field: Hashable {
		case clinicalName
		case nickname
		case quantity
		case dose
	}
	
	enum DatePickerType {
		case lastRefill
		case nextRefill
	}
	
	let medication: ANMedicationConcept?
	let onSave: (ANMedicationConcept) -> Void
	let onCancel: () -> Void

	init(
		medication: ANMedicationConcept?,
		onSave: @escaping (ANMedicationConcept) -> Void,
		onCancel: @escaping () -> Void
	) {
		self.medication = medication
		_viewModel = StateObject(wrappedValue: MedicationEditViewModel(medication: medication))
		self.onSave = onSave
		self.onCancel = onCancel
	}
	
	private var isFormValid: Bool { viewModel.isFormValid }
	
	private func hideKeyboard() {
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	}
	
	private func performSave() {
		withAnimation(.spring(response: 0.3)) {
			hideKeyboard()
		}
		let updated = viewModel.buildMedication()
		hapticsManager.medicationAdded()
		onSave(updated)
	}
	
	// MARK: - Hero Section
	@ViewBuilder
	private var heroSection: some View {
		HeroSectionComponent(isEditing: medication != nil)
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
			onMedicationSelected: { clinicalName, nickname in
				viewModel.clinicalName = clinicalName
				viewModel.nickname = nickname
				withAnimation(.spring(response: 0.3)) {
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
		VStack(alignment: .leading, spacing: 20) {
				// Section header
				HStack(spacing: 12) {
					Image(systemSymbol: .arrowTrianglehead2ClockwiseRotate90CircleFill)
						.font(.title2)
						.foregroundStyle(
							LinearGradient(
								colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
					
					Text("Refill Information")
						.font(.headline)
						.fontWeight(.semibold)
				}
				
				// Current Quantity
				VStack(alignment: .leading, spacing: 8) {
					Label {
						HStack(spacing: 4) {
							Text("Current Quantity")
								.font(.subheadline)
								.fontWeight(.medium)
							Text("Optional")
								.font(.caption)
								.foregroundStyle(.tertiary)
								.padding(.horizontal, 8)
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
				VStack(alignment: .leading, spacing: 8) {
					Text("Refill Tracking")
						.font(.caption)
						.fontWeight(.medium)
						.foregroundStyle(.secondary)
						.padding(.leading, 4)
					
					VStack(spacing: 12) {
						// Last Refill Date Card
						DateCardComponent(
							title: "Last Refill",
							icon: .clockArrowTriangleheadCounterclockwiseRotate90,
							date: viewModel.lastRefillDate,
							color: .blue,
							onTap: {
								datePickerType = .lastRefill
								showingDatePicker = true
							},
							onRemove: viewModel.lastRefillDate != nil ? {
								withAnimation(.spring(response: 0.3)) {
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
								withAnimation(.spring(response: 0.3)) {
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

	// MARK: - Color Section
	@ViewBuilder
	private var colorSection: some View {
		ColorPickerComponent(
			selectedColorHex: $viewModel.displayColorHex,
			onColorSelected: { newColorHex in
				withAnimation(.spring(response: 0.3)) {
					viewModel.displayColorHex = newColorHex
				}
			},
			onSave: nil // No save button needed in edit form
		)
		.glassCard()
		.padding(.horizontal)
	}

	// MARK: - Save Button
	@ViewBuilder
	private var saveButton: some View {
		Button {
			performSave()
		} label: {
			let backgroundColor = isFormValid ? Color.accentColor : Color.gray

			HStack(spacing: 12) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.title3)

				Text("Save Medication")
					.font(.headline)
					.fontWeight(.semibold)
			}
			.foregroundStyle(backgroundColor.contrastingForegroundColor())
			.frame(maxWidth: .infinity)
			.padding(.vertical, 18)
			.background(
				LinearGradient(
					colors: isFormValid ?
						[Color.accentColor, Color.accentColor.opacity(0.8)] :
						[Color.gray, Color.gray.opacity(0.8)],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.clipShape(RoundedRectangle(cornerRadius: 16))
			.shadow(color: isFormValid ? Color.accentColor.opacity(0.3) : .clear, radius: 10, y: 5)
		}
		.disabled(!isFormValid)
		.padding(.horizontal)
		.padding(.vertical, 10)
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
			VStack(spacing: 20) {
				// Date picker header
				VStack(spacing: 8) {
					ZStack {
						Circle()
							.fill(
								LinearGradient(
									colors: [
										(datePickerType == .lastRefill ? Color.blue : Color.green).opacity(0.2),
										(datePickerType == .lastRefill ? Color.blue : Color.green).opacity(0.05)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.frame(width: 64, height: 64)
						
						Image(systemSymbol: datePickerType == .lastRefill ? .clockArrowTriangleheadCounterclockwiseRotate90 : .calendarBadgePlus)
							.font(.largeTitle.weight(.medium))
							.foregroundStyle(datePickerType == .lastRefill ? Color.blue : Color.green)
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
				.padding(.top, 10)
				
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
				VStack(spacing: 12) {
					Text("Quick Adjust")
						.font(.caption)
						.fontWeight(.medium)
						.foregroundStyle(.secondary)
					
					HStack(spacing: 10) {
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
						withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
							if datePickerType == .lastRefill {
								viewModel.lastRefillDate = nil
							} else {
								viewModel.nextRefillDate = nil
							}
							showingDatePicker = false
							hapticsManager.mediumImpact()
						}
					} label: {
						HStack(spacing: 8) {
							Image(systemSymbol: .trashCircle)
								.font(.callout)
							Text("Remove Date")
								.font(.subheadline)
								.fontWeight(.medium)
						}
						.foregroundStyle(.red)
						.padding(.horizontal, 20)
						.padding(.vertical, 12)
						.background(
							RoundedRectangle(cornerRadius: 12, style: .continuous)
								.fill(Color.red.opacity(0.1))
								.overlay(
									RoundedRectangle(cornerRadius: 12, style: .continuous)
										.strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
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
					Button("Cancel") {
						showingDatePicker = false
					}
					.foregroundStyle(.secondary)
				}
				
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						showingDatePicker = false
					}
					.fontWeight(.bold)
					.foregroundStyle(Color.accentColor)
				}
			}
		}
		.dynamicDetent()
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
		ScrollView {
			VStack(spacing: 24) {
				heroSection
				medicationInfoSection
				prescribedDoseSection
				refillInfoSection
				colorSection
				saveButton
				Color.clear.frame(height: 20)
			}
		}
		.background(
			LinearGradient(
				colors: [
					Color(.systemGroupedBackground),
					Color.accentColor.opacity(0.05)
				],
				startPoint: .top,
				endPoint: .bottom
			)
			.ignoresSafeArea()
		)
	}
	
	// MARK: - Body
	var body: some View {
		NavigationStack {
			mainContent
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button {
							onCancel()
						} label: {
							Image(systemSymbol: .xmark)
								.font(.body.weight(.medium))
								.foregroundStyle(.secondary)
								.padding(8)
								.background(
									Circle()
										.fill(.ultraThinMaterial)
								)
						}
					}
					
					ToolbarItem(placement: .confirmationAction) {
						Button {
							performSave()
						} label: {
							Text("Save")
								.font(.body.weight(.semibold))
						}
						.disabled(!isFormValid)
						.foregroundColor(isFormValid ? .accentColor : .secondary)
						.accessibilityLabel("Save medication")
						.accessibilityHint(isFormValid ? "Saves the medication details" : "Complete required fields to save")
					}
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
		onSave: { _ in },
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
			lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
			nextRefillDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())
		),
		onSave: { _ in },
		onCancel: {}
	)
}

#Preview("Add New Medication") {
	MedicationEditView(
		medication: nil,
		onSave: { _ in },
		onCancel: {}
	)
}
