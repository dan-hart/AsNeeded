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
	@State private var animateHero = false
	@FocusState private var focusedField: Field?
	@Environment(\.colorScheme) private var colorScheme
	
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
					.scaleEffect(animateHero ? 1.1 : 0.9)
					.animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateHero)
				
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
					.font(.system(size: 50, weight: .medium))
					.foregroundStyle(
						LinearGradient(
							colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
							startPoint: .top,
							endPoint: .bottom
						)
					)
					.scaleEffect(animateHero ? 1.05 : 0.95)
					.animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateHero)
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
		.onAppear {
			animateHero = true
		}
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
				
				// Clinical Name Field
				VStack(alignment: .leading, spacing: 8) {
					Label {
						HStack(spacing: 4) {
							Text("Clinical Name")
								.font(.subheadline)
								.fontWeight(.medium)
							Text("*")
								.foregroundStyle(.red)
						}
					} icon: {
						Image(systemSymbol: .pill)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					
					EnhancedMedicationSearchField(
						text: $viewModel.clinicalName,
						placeholder: "Search for medication...",
						onMedicationSelected: { clinicalName, nickname in
							viewModel.clinicalName = clinicalName
							viewModel.nickname = nickname
							withAnimation(.spring(response: 0.3)) {
								focusedField = nil
							}
						}
					)
					.focused($focusedField, equals: .clinicalName)
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
				
				// Date Cards
				HStack(spacing: 12) {
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
		.padding(.horizontal)
	}
	
	// MARK: - Date Card Component
	@ViewBuilder
	private func dateCard(title: String, icon: SFSymbol, date: Date?, dateType: DatePickerType, color: Color) -> some View {
		Button {
			datePickerType = dateType
			showingDatePicker = true
		} label: {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 6) {
					Image(systemSymbol: icon)
						.font(.caption)
						.foregroundStyle(color)
					
					Text(title)
						.font(.caption)
						.fontWeight(.medium)
						.foregroundStyle(.secondary)
				}
				
				if let date = date {
					Text(date.formatted(date: .abbreviated, time: .omitted))
						.font(.subheadline)
						.fontWeight(.semibold)
						.foregroundStyle(.primary)
				} else {
					Text("Not Set")
						.font(.subheadline)
						.foregroundStyle(.tertiary)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(12)
			.background(
				RoundedRectangle(cornerRadius: 12)
					.fill(Color(.tertiarySystemGroupedBackground))
					.overlay(
						RoundedRectangle(cornerRadius: 12)
							.strokeBorder(color.opacity(0.2), lineWidth: 1)
					)
			)
		}
		.buttonStyle(.plain)
	}
	
	// MARK: - Save Button
	@ViewBuilder
	private var saveButton: some View {
		Button {
			withAnimation(.spring(response: 0.3)) {
				hideKeyboard()
			}
			let updated = viewModel.buildMedication()
			onSave(updated)
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
					Image(systemSymbol: datePickerType == .lastRefill ? .clockArrowTriangleheadCounterclockwiseRotate90 : .calendarBadgePlus)
						.font(.largeTitle)
						.foregroundStyle(Color.accentColor)
					
					Text(datePickerType == .lastRefill ? "Last Refill Date" : "Next Refill Date")
						.font(.headline)
						.fontWeight(.semibold)
				}
				.padding(.top, 20)
				
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
				HStack(spacing: 12) {
					Button("-30d") { adjustDate(by: -30) }
						.buttonStyle(QuickDateButton())
					Button("-7d") { adjustDate(by: -7) }
						.buttonStyle(QuickDateButton())
					Button("+7d") { adjustDate(by: 7) }
						.buttonStyle(QuickDateButton())
					Button("+30d") { adjustDate(by: 30) }
						.buttonStyle(QuickDateButton())
				}
				.padding(.horizontal)
				
				// Clear button
				Button("Clear Date") {
					if datePickerType == .lastRefill {
						viewModel.lastRefillDate = nil
					} else {
						viewModel.nextRefillDate = nil
					}
					showingDatePicker = false
				}
				.foregroundStyle(.red)
				
				Spacer()
			}
			.navigationTitle("")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						showingDatePicker = false
					}
					.fontWeight(.semibold)
				}
			}
		}
		.presentationDetents([.medium])
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