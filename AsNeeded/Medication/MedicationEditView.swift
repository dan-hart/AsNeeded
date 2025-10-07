// MedicationEditView.swift
// SwiftUI view for editing clinicalName, nickname, quantity, lastRefillDate, and nextRefillDate of ANMedicationConcept.

import SwiftUI
import Boutique
import ANModelKit
import SFSafeSymbols

// Button style for quick date adjustments
struct QuickDateButton: ButtonStyle {
	@ScaledMetric private var horizontalPadding: CGFloat = 16
	@ScaledMetric private var verticalPadding: CGFloat = 8

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.subheadline)
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
	@StateObject private var viewModel: MedicationEditViewModel
	@State private var showingDatePicker = false
	@State private var datePickerType: DatePickerType = .lastRefill
	@State private var showingAppearancePicker = false
	@FocusState private var focusedField: Field?
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.fontFamily) private var fontFamily
	private let hapticsManager = HapticsManager.shared

	@ScaledMetric private var sectionSpacing: CGFloat = 20
	@ScaledMetric private var iconSpacing: CGFloat = 12
	@ScaledMetric private var labelSpacing: CGFloat = 8
	@ScaledMetric private var cardSpacing: CGFloat = 12
	@ScaledMetric private var smallPadding: CGFloat = 4
	@ScaledMetric private var mediumPadding: CGFloat = 8
	@ScaledMetric private var standardPadding: CGFloat = 12
	@ScaledMetric private var largePadding: CGFloat = 16
	@ScaledMetric private var xlargePadding: CGFloat = 18
	@ScaledMetric private var buttonVerticalPadding: CGFloat = 18
	@ScaledMetric private var buttonCornerRadius: CGFloat = 16
	@ScaledMetric private var shadowRadius: CGFloat = 10
	@ScaledMetric private var shadowY: CGFloat = 5
	@ScaledMetric private var iconCircleSize: CGFloat = 64
	@ScaledMetric private var removeBorderWidth: CGFloat = 1
	@ScaledMetric private var removeButtonPadding: CGFloat = 20
	@ScaledMetric private var removeButtonVerticalPadding: CGFloat = 12
	@ScaledMetric private var removeButtonCornerRadius: CGFloat = 12
	@ScaledMetric private var toolbarButtonPadding: CGFloat = 8
	@ScaledMetric private var mainContentSpacing: CGFloat = 24
	@ScaledMetric private var clearFrameHeight: CGFloat = 20
	@ScaledMetric private var quickButtonSpacing: CGFloat = 10
	
	enum Field: Hashable {
		case clinicalName
		case nickname
		case initialQuantity
		case quantity
		case dose
	}

	enum DatePickerType {
		case lastRefill
		case nextRefill
	}

	enum ScrollTarget: Hashable {
		case searchFieldContainer
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
			searchFieldScrollID: ScrollTarget.searchFieldContainer,
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
					
					Text("Refill Information")
						.font(.headline)
						.fontWeight(.semibold)
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

				Text("Medication Appearance")
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))
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
										viewModel.displayColor.opacity(0.08)
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
			performSave()
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
		.disabled(!isFormValid)
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
										(datePickerType == .lastRefill ? Color.accent : Color.green).opacity(0.05)
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
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
				}

				ToolbarItem(placement: .confirmationAction) {
					Button {
						showingDatePicker = false
					} label: {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.customFont(fontFamily, style: .title2, weight: .semibold))
							.foregroundStyle(.accent)
					}
				}
			}
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
					heroSection
					medicationInfoSection
					prescribedDoseSection
					refillInfoSection
					appearanceSection
					archivedStatusSection
					saveButton
					Color.clear.frame(height: clearFrameHeight)
				}
			}
			.background(
				LinearGradient(
					colors: [
						Color(.systemGroupedBackground),
						.accent.opacity(0.05)
					],
					startPoint: .top,
					endPoint: .bottom
				)
				.ignoresSafeArea()
			)
			.onChange(of: focusedField) { _, newValue in
				if newValue == .clinicalName {
					withAnimation(.easeInOut(duration: 0.3)) {
						proxy.scrollTo(ScrollTarget.searchFieldContainer, anchor: .top)
					}
				}
			}
		}
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
								.font(.customFont(fontFamily, style: .body, weight: .medium))
								.foregroundStyle(.secondary)
						}
					}

					ToolbarItem(placement: .confirmationAction) {
						Button {
							performSave()
						} label: {
							Image(systemSymbol: .checkmarkCircleFill)
								.font(.customFont(fontFamily, style: .title2, weight: .semibold))
								.foregroundStyle(.accent)
						}
						.disabled(!isFormValid)
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
			initialQuantity: 90,
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
