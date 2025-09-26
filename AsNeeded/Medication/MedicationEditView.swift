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
		VStack(spacing: 20) {
			// Animated icon with liquid glass effect
			ZStack {
				// Animated gradient background
				Circle()
					.fill(
						LinearGradient(
							colors: [
								Color.accentColor.opacity(0.3),
								Color.accentColor.opacity(0.1)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: 120, height: 120)
					.blur(radius: 20)

				// Glass circle
				Circle()
					.fill(.ultraThinMaterial)
					.frame(width: 100, height: 100)
					.overlay(
						Circle()
							.strokeBorder(
								LinearGradient(
									colors: [
										.white.opacity(0.6),
										.white.opacity(0.2)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
					)
				
				// Icon
				Image(systemSymbol: medication == nil ? .pillsFill : .pills)
					.font(.largeTitle.weight(.medium))
					.foregroundStyle(
						LinearGradient(
							colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
							startPoint: .top,
							endPoint: .bottom
						)
					)
			}
			
			Text(medication == nil ? "Add New Medication" : "Edit Medication")
				.font(.largeTitle)
				.fontWeight(.bold)
				.foregroundStyle(
					LinearGradient(
						colors: [.primary, .primary.opacity(0.8)],
						startPoint: .leading,
						endPoint: .trailing
					)
				)
			
			Text(medication == nil ? "Set up a new medication to track" : "Update medication details")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding(.vertical, 30)
	}
	
	// MARK: - Glass Card Component
	@ViewBuilder
	private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
		content()
			.padding(20)
			.background(
				RoundedRectangle(cornerRadius: 20)
					.fill(.regularMaterial)
					.shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
					.overlay(
						RoundedRectangle(cornerRadius: 20)
							.strokeBorder(
								LinearGradient(
									colors: [
										.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
										.white.opacity(0.1)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
					)
			)
	}
	
	// MARK: - Medication Info Section
	@ViewBuilder
	private var medicationInfoSection: some View {
		glassCard {
			VStack(alignment: .leading, spacing: 20) {
				// Section header with icon
				HStack(spacing: 12) {
					Image(systemSymbol: .textBookClosedFill)
						.font(.title2)
						.foregroundStyle(
							LinearGradient(
								colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
					
					Text("Medication Information")
						.font(.headline)
						.fontWeight(.semibold)
				}
				
				// Clinical Name Field - Primary Input
				VStack(alignment: .leading, spacing: 12) {
					// Enhanced header with better visual hierarchy
					HStack(spacing: 8) {
						ZStack {
							Circle()
								.fill(Color.accentColor.opacity(0.15))
								.frame(width: 28, height: 28)
							
							Image(systemSymbol: .pill)
								.font(.subheadline.weight(.semibold))
								.foregroundColor(.accentColor)
								.accessibilityHidden(true) // Decorative icon
						}
						
						VStack(alignment: .leading, spacing: 2) {
							HStack(spacing: 4) {
								Text("Clinical Name")
									.font(.subheadline)
									.fontWeight(.semibold)
								Text("*")
									.foregroundStyle(.red)
									.font(.subheadline)
									.fontWeight(.bold)
									.accessibilityLabel("required")
							}
							.accessibilityElement(children: .combine)
							
							Text("Start typing to search medications")
								.font(.caption)
								.foregroundStyle(.secondary)
								.accessibilityHidden(true) // Redundant with field hint
						}
						
						Spacer()
						
						// Priority indicator
						if viewModel.clinicalName.isEmpty {
							Text("REQUIRED")
								.font(.caption2.weight(.bold))
								.foregroundStyle(.white)
								.padding(.horizontal, 8)
								.padding(.vertical, 3)
								.background(
									Capsule()
										.fill(Color.accentColor)
								)
								.accessibilityLabel("Required field indicator")
								.accessibilityHidden(true) // Hide from VoiceOver since it's already conveyed in the hint
						}
					}
					
					// Enhanced search field container
					VStack(spacing: 0) {
						EnhancedMedicationSearchField(
							text: $viewModel.clinicalName,
							placeholder: "Type medication name (e.g., Ibuprofen, Tylenol)",
							onMedicationSelected: { clinicalName, nickname in
								viewModel.clinicalName = clinicalName
								viewModel.nickname = nickname
								withAnimation(.spring(response: 0.3)) {
									focusedField = nil
								}
							}
						)
						.focused($focusedField, equals: .clinicalName)
						.accessibilityLabel("Clinical Name")
						.accessibilityHint("Required field. Type to search for medications.")
						.accessibilityValue(viewModel.clinicalName.isEmpty ? "Empty" : viewModel.clinicalName)
					}
					.padding(16)
					.background(
						RoundedRectangle(cornerRadius: 16)
							.fill(.ultraThinMaterial)
							.overlay(
								RoundedRectangle(cornerRadius: 16)
									.strokeBorder(
										focusedField == .clinicalName ? 
											Color.accentColor.opacity(0.6) : 
											Color(.separator).opacity(0.3),
										lineWidth: focusedField == .clinicalName ? 2 : 1
									)
							)
							.shadow(
								color: focusedField == .clinicalName ? 
									Color.accentColor.opacity(0.2) : 
									Color.black.opacity(0.05),
								radius: focusedField == .clinicalName ? 8 : 4,
								x: 0,
								y: focusedField == .clinicalName ? 4 : 2
							)
					)
					.scaleEffect(focusedField == .clinicalName ? 1.02 : 1.0)
					.animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField)
				}
				
				// Nickname Field
				VStack(alignment: .leading, spacing: 8) {
					Label {
						HStack(spacing: 4) {
							Text("Nickname")
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
						Image(systemSymbol: .tagFill)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					
					TextField("Personal name for easy identification", text: $viewModel.nickname)
						.textFieldStyle(.roundedBorder)
						.autocapitalization(.words)
						.disableAutocorrection(true)
						.focused($focusedField, equals: .nickname)
				}
			}
		}
		.padding(.horizontal)
	}
	
	// MARK: - Prescribed Dose Section
	@ViewBuilder
	private var prescribedDoseSection: some View {
		glassCard {
			VStack(alignment: .leading, spacing: 20) {
				// Section header
				HStack(spacing: 12) {
					Image(systemSymbol: .syringe)
						.font(.title2)
						.foregroundStyle(
							LinearGradient(
								colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
					
					Text("Prescribed Dose")
						.font(.headline)
						.fontWeight(.semibold)
				}
				
				HStack(spacing: 16) {
					// Dose Amount
					VStack(alignment: .leading, spacing: 8) {
						Label {
							Text("Amount")
								.font(.subheadline)
								.fontWeight(.medium)
						} icon: {
							Image(systemSymbol: .number)
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						
						TextField("0", text: $viewModel.prescribedDoseText)
							.textFieldStyle(.roundedBorder)
							.keyboardType(.decimalPad)
							.focused($focusedField, equals: .dose)
							.frame(maxWidth: 120)
					}
					
					// Dose Unit
					VStack(alignment: .leading, spacing: 8) {
						Label {
							Text("Unit")
								.font(.subheadline)
								.fontWeight(.medium)
						} icon: {
							Image(systemSymbol: .ruler)
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						
						Menu {
							Button("None") { viewModel.prescribedUnit = nil }
							Divider()
							ForEach(ANUnitConcept.allCases, id: \.self) { unit in
								Button(unit.displayName) { 
									withAnimation(.spring(response: 0.3)) {
										viewModel.prescribedUnit = unit 
									}
								}
							}
						} label: {
							HStack {
								Text(viewModel.prescribedUnit?.displayName ?? "Select")
									.foregroundStyle(viewModel.prescribedUnit == nil ? .secondary : .primary)
								Spacer()
								Image(systemSymbol: .chevronUpChevronDown)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.padding(.horizontal, 12)
							.padding(.vertical, 8)
							.background(
								RoundedRectangle(cornerRadius: 8)
									.fill(Color(.secondarySystemGroupedBackground))
							)
						}
					}
					.frame(maxWidth: .infinity)
				}
			}
		}
		.padding(.horizontal)
	}
	
	// MARK: - Refill Info Section
	@ViewBuilder
	private var refillInfoSection: some View {
		glassCard {
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
						dateCard(
							title: "Last Refill",
							icon: .clockArrowTriangleheadCounterclockwiseRotate90,
							date: viewModel.lastRefillDate,
							dateType: .lastRefill,
							color: .blue
						)
						
						// Next Refill Date Card
						dateCard(
							title: "Next Refill",
							icon: .calendarBadgePlus,
							date: viewModel.nextRefillDate,
							dateType: .nextRefill,
							color: .green
						)
					}
				}
			}
		}
		.padding(.horizontal)
	}
	
	// MARK: - Date Card Component
	@ViewBuilder
	private func dateCard(title: String, icon: SFSymbol, date: Date?, dateType: DatePickerType, color: Color) -> some View {
		VStack(spacing: 0) {
			// Main card button
			Button {
				datePickerType = dateType
				showingDatePicker = true
			} label: {
				HStack(spacing: 12) {
					// Icon with colored background
					ZStack {
						Circle()
							.fill(color.opacity(0.15))
							.frame(width: 36, height: 36)
						
						Image(systemSymbol: icon)
							.font(.body.weight(.semibold))
							.foregroundStyle(color)
					}
					
					// Date info
					VStack(alignment: .leading, spacing: 4) {
						Text(title)
							.font(.caption)
							.fontWeight(.medium)
							.foregroundStyle(.secondary)
						
						if let date = date {
							Text(date.formatted(date: .abbreviated, time: .omitted))
								.font(.subheadline)
								.fontWeight(.semibold)
								.foregroundStyle(.primary)
						} else {
							HStack(spacing: 4) {
								Image(systemSymbol: .plusCircle)
									.font(.caption2)
								Text("Add Date")
									.font(.subheadline)
							}
							.foregroundStyle(color)
						}
					}
					
					Spacer()
					
					// Remove button (only show if date is set)
					if date != nil {
						Button {
							withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
								if dateType == .lastRefill {
									viewModel.lastRefillDate = nil
								} else {
									viewModel.nextRefillDate = nil
								}
								hapticsManager.lightImpact()
							}
						} label: {
							Image(systemSymbol: .xmarkCircleFill)
								.font(.title3)
								.foregroundStyle(.tertiary)
								.symbolRenderingMode(.hierarchical)
						}
						.buttonStyle(.plain)
						.transition(.scale.combined(with: .opacity))
					}
				}
				.padding(14)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.fill(date != nil ? 
							Color(.tertiarySystemGroupedBackground) : 
							color.opacity(0.05)
						)
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.strokeBorder(
									date != nil ? 
										color.opacity(0.15) : 
										color.opacity(0.3),
									lineWidth: date != nil ? 1 : 1.5
								)
						)
				)
			}
			.buttonStyle(.plain)
		}
	}
	
	// MARK: - Save Button
	@ViewBuilder
	private var saveButton: some View {
		Button {
			performSave()
		} label: {
			HStack(spacing: 12) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.title3)
				
				Text("Save Medication")
					.font(.headline)
					.fontWeight(.semibold)
			}
			.foregroundStyle(.white)
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
		.presentationDetents([.medium, .large])
		.presentationDragIndicator(.visible)
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
