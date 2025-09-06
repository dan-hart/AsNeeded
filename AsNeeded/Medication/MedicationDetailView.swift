// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import SwiftUI
import UIKit
import ANModelKit
import SFSafeSymbols

struct MedicationDetailView: View {
	let medicationId: UUID
	@State private var medication: ANMedicationConcept
	@StateObject private var viewModel = MedicationDetailViewModel()
	@StateObject private var notificationManager = NotificationManager.shared
	@StateObject private var navigationManager = NavigationManager.shared
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@State private var showDeleteConfirm = false
	@State private var showLogDose = false
	@State private var showEditSheet = false
	@State private var showReminderSheet = false
	@State private var showReminderList = false
	@State private var reminderCount = 0
	
	init(medication: ANMedicationConcept) {
		self.medicationId = medication.id
		self._medication = State(initialValue: medication)
	}
	
	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				// MARK: - Hero Section
				heroSection
				
				// MARK: - Quick Actions
				quickActionsSection
				
				// MARK: - Details Cards
				VStack(spacing: 16) {
					medicationInfoCard
					
					if medication.quantity != nil || medication.lastRefillDate != nil || medication.nextRefillDate != nil {
						refillInfoCard
					}
					
					if medication.prescribedDoseAmount != nil && medication.prescribedUnit != nil {
						prescribedDoseCard
					}
					
					remindersCard
				}
				.padding(.horizontal)
				
				// MARK: - Bottom Actions
				bottomActionsSection
			}
			.padding(.vertical)
		}
		.background(Color(.systemGroupedBackground))
		.navigationTitle("")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .principal) {
				Text(medication.displayName)
					.font(.headline)
			}
			ToolbarItem(placement: .primaryAction) {
				Button("Done") { 
					dismiss() 
				}
				.fontWeight(.semibold)
			}
		}
		.confirmationDialog("Delete \(medication.displayName)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
			Button("Delete Medication", role: .destructive) {
				Task { await viewModel.delete(medication); dismiss() }
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This action cannot be undone. All history and reminders for this medication will be deleted.")
		}
		.sheet(isPresented: $showLogDose) {
			LogDoseView(medication: medication) { dose, event in
				Task {
					var medicationToUpdate = medication
					if let quantity = medication.quantity, dose.amount > 0 {
						medicationToUpdate.quantity = quantity - dose.amount
					}
					await viewModel.save(updated: medicationToUpdate)
					await viewModel.log(event: event)
					// Update the local medication state to reflect changes
					medication = medicationToUpdate
				}
			}
			.presentationDetents([.large])
		}
		.sheet(isPresented: $showEditSheet) {
			MedicationEditView(
				medication: medication,
				onSave: { updatedMedication in
					Task {
						await viewModel.save(updated: updatedMedication)
						// Update the local medication state to reflect changes
						medication = updatedMedication
					}
					showEditSheet = false
				},
				onCancel: {
					showEditSheet = false
				}
			)
		}
		.sheet(isPresented: $showReminderSheet) {
			Group {
				if notificationManager.authorizationStatus == .authorized {
					ReminderConfigurationView(medication: medication)
						.onDisappear {
							Task {
								await loadReminderCount()
							}
						}
				} else if notificationManager.authorizationStatus == .notDetermined {
					NotificationPermissionRequestView(
						onPermissionGranted: {
							// Permission granted, view will automatically update
						},
						onPermissionDenied: {
							showReminderSheet = false
						}
					)
				}
			}
		}
		.sheet(isPresented: $showReminderList) {
			ReminderListView(medication: medication)
				.onDisappear {
					Task {
						await loadReminderCount()
					}
				}
		}
		.task {
			// Refresh medication data from store
			await refreshMedication()
			
			if notificationManager.authorizationStatus == .authorized || notificationManager.authorizationStatus == .notDetermined {
				await loadReminderCount()
			}
		}
		.onAppear {
			// Refresh medication data when view appears (e.g., returning from edit)
			Task {
				await refreshMedication()
			}
		}
	}
	
	// MARK: - View Components
	private var heroSection: some View {
		VStack(spacing: 12) {
			// Large medication icon
			ZStack {
				Circle()
					.fill(Color.accentColor.opacity(0.1))
					.frame(width: 100, height: 100)
				
				Image(systemSymbol: .pills)
					.font(.system(size: 50))
					.foregroundStyle(Color.accentColor)
			}
			
			// Medication names
			VStack(spacing: 4) {
				Text(medication.displayName)
					.font(.title2)
					.fontWeight(.bold)
					.multilineTextAlignment(.center)
				
				if medication.nickname != nil && medication.nickname != medication.clinicalName {
					Text(medication.clinicalName)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
				}
			}
			.padding(.horizontal)
		}
		.frame(maxWidth: .infinity)
	}
	
	private var quickActionsSection: some View {
		HStack(spacing: 12) {
			// Edit button
			Button {
				showEditSheet = true
			} label: {
				Label("Edit", systemSymbol: .pencil)
					.font(.subheadline)
					.fontWeight(.medium)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 12)
					.background(Color(.secondarySystemGroupedBackground))
					.foregroundStyle(Color.accentColor)
					.clipShape(RoundedRectangle(cornerRadius: 10))
			}
			
			// History button
			Button {
				navigationManager.navigateToHistory(medicationID: medication.id.uuidString)
				dismiss()
			} label: {
				Label("History", systemSymbol: .clock)
					.font(.subheadline)
					.fontWeight(.medium)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 12)
					.background(Color(.secondarySystemGroupedBackground))
					.foregroundStyle(Color.accentColor)
					.clipShape(RoundedRectangle(cornerRadius: 10))
			}
			
			// Delete button
			Button {
				showDeleteConfirm = true
			} label: {
				Label("Delete", systemSymbol: .trash)
					.font(.subheadline)
					.fontWeight(.medium)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 12)
					.background(Color(.secondarySystemGroupedBackground))
					.foregroundStyle(.red)
					.clipShape(RoundedRectangle(cornerRadius: 10))
			}
		}
		.padding(.horizontal)
	}
	
	private var medicationInfoCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Label("Medication Info", systemSymbol: .info)
					.font(.headline)
					.foregroundStyle(.primary)
				Spacer()
			}
			
			VStack(spacing: 12) {
				detailRow(label: "Clinical Name", value: medication.clinicalName)
				
				if let nickname = medication.nickname {
					Divider()
					detailRow(label: "Nickname", value: nickname)
				}
			}
		}
		.padding()
		.background(Color(.secondarySystemGroupedBackground))
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var refillInfoCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Label("Supply & Refills", systemSymbol: .pills)
					.font(.headline)
					.foregroundStyle(.primary)
				Spacer()
			}
			
			VStack(spacing: 12) {
				if let quantity = medication.quantity {
					detailRow(
						label: "Current Supply",
						value: medication.prescribedUnit != nil ? "\(quantity.formattedAmount) \(medication.prescribedUnit!.abbreviation)" : quantity.formattedAmount
					)
				}
				
				if medication.lastRefillDate != nil || medication.nextRefillDate != nil {
					if medication.quantity != nil { Divider() }
					
					if let lastRefill = medication.lastRefillDate {
						detailRow(
							label: "Last Refill",
							value: lastRefill.formatted(date: .abbreviated, time: .omitted)
						)
					}
					
					if let nextRefill = medication.nextRefillDate {
						if medication.lastRefillDate != nil { Divider() }
						detailRow(
							label: "Next Refill",
							value: nextRefill.formatted(date: .abbreviated, time: .omitted),
							valueColor: isRefillSoon(nextRefill) ? .orange : .secondary
						)
					}
				}
			}
		}
		.padding()
		.background(Color(.secondarySystemGroupedBackground))
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var prescribedDoseCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Label("Prescribed Dose", systemSymbol: .pill)
					.font(.headline)
					.foregroundStyle(.primary)
				Spacer()
			}
			
			if let amount = medication.prescribedDoseAmount, let unit = medication.prescribedUnit {
				HStack {
					Text("\(amount.formattedAmount)")
						.font(.title)
						.fontWeight(.semibold)
					Text(unit.displayName(for: amount == 1 ? 1 : 2))
						.font(.title3)
						.foregroundStyle(.secondary)
				}
			}
		}
		.padding()
		.background(Color(.secondarySystemGroupedBackground))
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var remindersCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Label("Reminders", systemSymbol: .bell)
					.font(.headline)
					.foregroundStyle(.primary)
				Spacer()
				
				if reminderCount > 0 {
					Text("\(reminderCount) active")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}
			
			if notificationManager.authorizationStatus == .authorized || notificationManager.authorizationStatus == .notDetermined {
				VStack(spacing: 10) {
					if reminderCount > 0 {
						Button {
							showReminderList = true
						} label: {
							HStack {
								Text("Manage Reminders")
									.fontWeight(.medium)
								Spacer()
								Image(systemSymbol: .chevronRight)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.padding(.vertical, 10)
							.padding(.horizontal, 12)
							.background(Color(.tertiarySystemGroupedBackground))
							.clipShape(RoundedRectangle(cornerRadius: 8))
						}
						.buttonStyle(.plain)
					}
					
					Button {
						showReminderSheet = true
					} label: {
						HStack {
							Image(systemSymbol: .plus)
								.font(.subheadline)
							Text("Add Reminder")
								.fontWeight(.medium)
						}
						.frame(maxWidth: .infinity)
						.padding(.vertical, 10)
						.background(Color.accentColor.opacity(0.1))
						.foregroundStyle(Color.accentColor)
						.clipShape(RoundedRectangle(cornerRadius: 8))
					}
					.buttonStyle(.plain)
				}
			} else if notificationManager.authorizationStatus == .denied {
				VStack(spacing: 10) {
					HStack(spacing: 8) {
						Image(systemSymbol: .bellSlash)
							.foregroundColor(.orange)
						Text("Notifications Disabled")
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					
					Button {
						if let url = URL(string: UIApplication.openSettingsURLString) {
							UIApplication.shared.open(url)
						}
					} label: {
						Label("Open Settings", systemSymbol: .gearshape)
							.fontWeight(.medium)
							.frame(maxWidth: .infinity)
							.padding(.vertical, 10)
							.background(Color(.tertiarySystemGroupedBackground))
							.clipShape(RoundedRectangle(cornerRadius: 8))
					}
					.buttonStyle(.plain)
				}
			}
		}
		.padding()
		.background(Color(.secondarySystemGroupedBackground))
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var bottomActionsSection: some View {
		VStack(spacing: 12) {
			// Log dose button (primary action)
			Button {
				showLogDose = true
			} label: {
				Label("Log Dose", systemSymbol: .plusCircle)
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.background(Color.accentColor)
					.foregroundStyle(.white)
					.clipShape(RoundedRectangle(cornerRadius: 12))
			}
			.buttonStyle(.plain)
			.padding(.horizontal)
		}
		.padding(.top, 8)
	}
	
	// MARK: - Helper Views
	private func detailRow(label: String, value: String, valueColor: Color = .secondary) -> some View {
		HStack {
			Text(label)
				.font(.subheadline)
				.foregroundStyle(.secondary)
			Spacer()
			Text(value)
				.font(.subheadline)
				.fontWeight(.medium)
				.foregroundStyle(valueColor)
		}
	}
	
	private func isRefillSoon(_ date: Date) -> Bool {
		let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
		return daysUntil <= 7 && daysUntil >= 0
	}
	
	private func refreshMedication() async {
		if let updatedMedication = DataStore.shared.medications.first(where: { $0.id == medicationId }) {
			await MainActor.run {
				medication = updatedMedication
			}
		}
	}
	
	private func loadReminderCount() async {
		let reminders = await notificationManager.getReminderDetails(for: medication)
		await MainActor.run {
			reminderCount = reminders.count
		}
	}
}

#Preview {
	MedicationDetailView(medication: ANMedicationConcept(
		clinicalName: "Albuterol Inhaler",
		nickname: "Rescue Inhaler"
	))
}

#Preview("Medication with Long History") {
	MedicationDetailView(medication: ANMedicationConcept(
		clinicalName: "Metformin",
		nickname: "Diabetes Med"
	))
}

#Preview("Medication with Refill Info") {
	MedicationDetailView(medication: ANMedicationConcept(
		clinicalName: "Lisinopril",
		nickname: "Blood Pressure",
		quantity: 30,
		lastRefillDate: Date(timeIntervalSinceNow: -86400 * 10),
		nextRefillDate: Date(timeIntervalSinceNow: 86400 * 20)
	))
}
