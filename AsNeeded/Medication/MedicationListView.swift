// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import SwiftUI
import ANModelKit
import SFSafeSymbols

struct MedicationListView: View {
	@StateObject private var viewModel = MedicationListViewModel()
	@State private var showAddSheet = false
	@State private var editMedication: ANMedicationConcept?
	@State private var viewMedication: ANMedicationConcept?
	@State private var logMedication: ANMedicationConcept?
	@State private var pendingDelete: ANMedicationConcept?
	
	var body: some View {
		NavigationStack {
			Group {
				if viewModel.items.isEmpty {
					VStack {
						Spacer()
						Text("No medications found.")
							.foregroundStyle(.secondary)
						Spacer()
					}
				} else {
					List {
						ForEach(viewModel.items) { med in
							HStack {
								MedicationRow(medication: med) {
									logMedication = med
								}
							}
							.contentShape(Rectangle())
							.onTapGesture { viewMedication = med }
							.swipeActions(edge: .trailing, allowsFullSwipe: true) {
								Button {
									editMedication = med
								} label: {
									Label("Edit", systemImage: "pencil")
								}
								.tint(.blue)

								Button(role: .destructive) {
									pendingDelete = med
								} label: {
									Label("Delete", systemImage: "trash")
								}
							}
						}
					}
				}
			}
			.navigationTitle("Medication")
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button(action: { showAddSheet = true }) {
						Label("Add Medication", systemImage: "plus")
					}
				}
			}
			.sheet(item: $editMedication) { med in
				MedicationEditView(
					medication: med,
					onSave: { updated in
						Task { await viewModel.update(updated); editMedication = nil }
					},
					onCancel: { editMedication = nil }
				)
			}
			.sheet(isPresented: $showAddSheet) {
				MedicationEditView(
					medication: nil,
					onSave: { newMed in
						Task { await viewModel.add(newMed); showAddSheet = false }
					},
					onCancel: { showAddSheet = false }
				)
			}
			.sheet(item: $viewMedication) { med in
				NavigationView {
					MedicationDetailView(medication: med)
				}
			}
			.sheet(item: $logMedication) { med in
				LogDoseView(medication: med) { dose, event in
					Task {
						var updated = med
						if let quantity = updated.quantity, dose.amount > 0 {
							updated.quantity = quantity - dose.amount
						}
						await viewModel.update(updated)
						await viewModel.addEvent(event)
						logMedication = nil
					}
				}
				.presentationDetents([.medium, .large])
			}
			.alert("Delete Medication?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
				Button("Delete", role: .destructive) {
					if let med = pendingDelete {
						Task { await viewModel.delete(med); pendingDelete = nil }
					}
				}
				Button("Cancel", role: .cancel) { pendingDelete = nil }
			} message: {
				Text("This action cannot be undone.")
			}
		}
	}
}

// MARK: - Medication Row
struct MedicationRow: View {
	let medication: ANMedicationConcept
	var onLogTapped: () -> Void = {}
	
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	
	var body: some View {
		if dynamicTypeSize.isAccessibilitySize {
			VStack(alignment: .leading, spacing: 12) {
				medicationTitle
				medicationInfo
				logButton
					.frame(maxWidth: .infinity)
			}
		} else {
			HStack(alignment: .center) {
				VStack(alignment: .leading, spacing: 4) {
					medicationTitle
					medicationInfo
				}
				Spacer(minLength: 8)
				logButton
			}
		}
	}
	
	private var medicationTitle: some View {
		Text(medication.displayName.isEmpty ? medication.clinicalName : medication.displayName)
			.font(.headline)
			.lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
			.multilineTextAlignment(.leading)
	}
	
	private var medicationInfo: some View {
		VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 6 : 2) {
			quantityView
			datesView
		}
	}
	
	@ViewBuilder
	private var quantityView: some View {
		if let quantity = medication.quantity {
			let quantityText = if let unit = medication.prescribedUnit {
				"\(quantity.formattedAmount) \(unit.abbreviation)"
			} else {
				quantity.formattedAmount
			}
			
			Text(quantityText)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
	}
	
	@ViewBuilder
	private var datesView: some View {
		VStack(alignment: .leading, spacing: 2) {
			if let lastRefill = medication.lastRefillDate {
				Text("Last refill \(lastRefill.relativeFormattedAsPast)")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			if let nextRefill = medication.nextRefillDate {
				let isOverdue = nextRefill < Date()
				Text("Next refill \(nextRefill.relativeFormattedAsFuture)")
					.font(.caption)
					.foregroundStyle(isOverdue ? .orange : .secondary)
			}
		}
	}
	
	private var logButton: some View {
		Button(action: onLogTapped) {
			if dynamicTypeSize.isAccessibilitySize {
				Label("Log Dose", systemImage: "plus.circle.fill")
					.labelStyle(.titleAndIcon)
			} else {
				Label("Log Dose", systemImage: "plus.circle.fill")
					.labelStyle(.iconOnly)
			}
		}
		.buttonStyle(.borderedProminent)
		.accessibilityLabel("Log dose for \(medication.displayName.isEmpty ? medication.clinicalName : medication.displayName)")
		.accessibilityHint("Opens dose logging for this medication")
	}
	
}

#Preview {
	MedicationListView()
}

#Preview("Empty List") {
	MedicationListView()
}

#Preview("Medication Row Samples") {
	List {
		MedicationRow(medication: ANMedicationConcept(
			clinicalName: "Lisinopril",
			nickname: "Blood Pressure",
			quantity: 28.5,
			lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
			nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
			prescribedUnit: .tablet,
			prescribedDoseAmount: 10.0
		))
		
		MedicationRow(medication: ANMedicationConcept(
			clinicalName: "Metformin",
			quantity: 90.0,
			lastRefillDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()), // Yesterday
			nextRefillDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), // In 1 month
			prescribedUnit: .tablet
		))
		
		MedicationRow(medication: ANMedicationConcept(
			clinicalName: "Very Long Medication Name That Could Wrap",
			quantity: 250.0,
			prescribedUnit: .milligram
		))
		
		MedicationRow(medication: ANMedicationConcept(
			clinicalName: "Albuterol",
			nickname: "Rescue Inhaler",
			quantity: 150.0,
			lastRefillDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()), // 1 week ago
			nextRefillDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()), // Overdue
			prescribedUnit: .puff
		))
		
		MedicationRow(medication: ANMedicationConcept(
			clinicalName: "Vitamin D3",
			quantity: 75.0,
			nextRefillDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), // Tomorrow
			prescribedUnit: .tablet
		))
	}
	.listStyle(.insetGrouped)
}
