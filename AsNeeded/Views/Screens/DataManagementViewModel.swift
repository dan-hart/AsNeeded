// DataManagementViewModel.swift
// View model for data management operations (export, import, clear).

import Foundation
import SwiftUI

@MainActor
final class DataManagementViewModel: ObservableObject {
  private let dataStore: DataStore
  
  @Published var isExporting = false
  @Published var isImporting = false
  @Published var isClearing = false
  @Published var showingClearConfirmation = false
  @Published var showingExportConfirmation = false
  @Published var showingDocumentPicker = false
  @Published var showingFileSaver = false
  @Published var exportedData: Data?
  @Published var alertMessage: String?
  @Published var showingAlert = false
  
  init(dataStore: DataStore = .shared) {
	self.dataStore = dataStore
  }
  
  func requestExport() {
	showingExportConfirmation = true
  }
  
  func exportData(includeNames: Bool) async {
	isExporting = true
	defer { isExporting = false }
	
	do {
	  let data = try await dataStore.exportDataAsJSON(redactNames: !includeNames)
	  exportedData = data
	  showingFileSaver = true
	} catch {
	  alertMessage = "Export failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  func importData(from url: URL) async {
	isImporting = true
	defer { isImporting = false }
	
	do {
	  let data = try Data(contentsOf: url)
	  try await dataStore.importDataFromJSON(data)
	  alertMessage = "Data imported successfully"
	  showingAlert = true
	} catch {
	  alertMessage = "Import failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  func clearAllData() async {
	isClearing = true
	defer { isClearing = false }
	
	do {
	  try await dataStore.clearAllData()
	  alertMessage = "All data cleared successfully"
	  showingAlert = true
	} catch {
	  alertMessage = "Clear data failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  func confirmClearData() {
	showingClearConfirmation = true
  }
  
  var medicationCount: Int {
	dataStore.medications.count
  }
  
  var eventCount: Int {
	dataStore.events.count
  }
}