// DataManagementViewModel.swift
// View model for data management operations (export, import, clear).

import Foundation
import SwiftUI
import DHLoggingKit

@MainActor
final class DataManagementViewModel: ObservableObject {
  private let dataStore: DataStore
  private let logger = DHLogger(category: "DataManagement")
  
  @Published var isExporting = false
  @Published var isImporting = false
  @Published var isClearing = false
  @Published var isExportingLogs = false
  @Published var showingClearConfirmation = false
  @Published var showingExportConfirmation = false
  @Published var showingDocumentPicker = false
  @Published var showingLogExportConfirmation = false
  @Published var showingDataShareSheet = false
  @Published var showingLogShareSheet = false
  @Published var exportedDataURL: URL?
  @Published var exportedLogsURL: URL?
  @Published var alertMessage: String?
  @Published var showingAlert = false
  @Published var logCount: Int = 0
  @Published var isLoadingLogCount = false
  
  init(dataStore: DataStore = .shared) {
	self.dataStore = dataStore
	Task {
	  await fetchLogCount()
	}
  }
  
  func fetchLogCount() async {
	logger.debug("Fetching log count")
	await MainActor.run {
	  self.isLoadingLogCount = true
	}
	
	defer {
	  Task { @MainActor in
		self.isLoadingLogCount = false
	  }
	}
	
	if #available(iOS 15.0, *) {
	  let count = await DHLoggingKit.exporter.getLogCount(timeInterval: 86400) // Last 24 hours
	  await MainActor.run {
		self.logCount = count
		logger.debug("Log count updated: \(count)")
	  }
	} else {
	  await MainActor.run {
		self.logCount = 0
	  }
	}
  }
  
  func requestExport() {
	logger.info("Export requested - showing confirmation dialog")
	showingExportConfirmation = true
  }
  
  func exportData(redactMedicationNames: Bool, redactNotes: Bool) async {
	logger.info("Starting data export - redactMedicationNames: \(redactMedicationNames), redactNotes: \(redactNotes)")
	isExporting = true
	defer { 
	  isExporting = false
	  logger.debug("Export process completed - isExporting set to false")
	}
	
	do {
	  logger.debug("Calling dataStore.exportDataAsJSON with redactNames: \(redactMedicationNames), redactNotes: \(redactNotes)")
	  let data = try await dataStore.exportDataAsJSON(redactNames: redactMedicationNames, redactNotes: redactNotes)
	  logger.info("Export data generated successfully - size: \(data.count) bytes")
	  
	  // Create a file URL in the documents directory for sharing
	  let dateFormatter = DateFormatter()
	  dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
	  let filename = "AsNeeded-Export-\(dateFormatter.string(from: Date())).json"
	  
	  // Use documents directory for better compatibility
	  guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
		logger.error("Could not access documents directory")
		alertMessage = "Export failed: Could not access documents directory"
		showingAlert = true
		return
	  }
	  let tempURL = documentsPath.appendingPathComponent(filename)
	  
	  // Write with proper attributes
	  try data.write(to: tempURL, options: [.atomic])
	  logger.debug("Wrote export data to file: \(tempURL.lastPathComponent)")
	  
	  // Ensure file is accessible
	  _ = tempURL.startAccessingSecurityScopedResource()
	  
	  exportedDataURL = tempURL
	  showingDataShareSheet = true
	  logger.debug("exportedDataURL set - share sheet should be triggered")
	} catch {
	  logger.error("Export failed", error: error)
	  alertMessage = "Export failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  func importData(from url: URL) async {
	logger.info("Starting data import from: \(url.lastPathComponent)")
	isImporting = true
	defer { 
	  isImporting = false
	  logger.debug("Import process completed")
	}
	
	// Start accessing the security-scoped resource
	guard url.startAccessingSecurityScopedResource() else {
	  logger.error("Failed to access security-scoped resource")
	  alertMessage = "Import failed: Unable to access the selected file. Please try again."
	  showingAlert = true
	  return
	}
	
	// Ensure we stop accessing the resource when done
	defer {
	  url.stopAccessingSecurityScopedResource()
	  logger.debug("Stopped accessing security-scoped resource")
	}
	
	do {
	  let data = try Data(contentsOf: url)
	  logger.debug("Read data from file, size: \(data.count) bytes")
	  try await dataStore.importDataFromJSON(data)
	  logger.info("Data imported successfully")
	  alertMessage = "Data imported successfully"
	  showingAlert = true
	} catch {
	  logger.error("Import failed", error: error)
	  alertMessage = "Import failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  func clearAllData() async {
	logger.warning("Starting reset and clear all data operation")
	isClearing = true
	defer { 
	  isClearing = false
	  logger.debug("Reset and clear data process completed")
	}
	
	do {
	  try await dataStore.clearAllData()
	  logger.info("All data cleared and settings reset successfully")
	  alertMessage = "All data cleared and settings restored to defaults"
	  showingAlert = true
	} catch {
	  logger.error("Reset and clear data failed", error: error)
	  alertMessage = "Reset failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  func confirmClearData() {
	logger.info("Clear data confirmation requested")
	showingClearConfirmation = true
  }
  
  func requestLogExport() {
	logger.info("Log export requested - showing time period dialog")
	showingLogExportConfirmation = true
  }
  
  func exportLogs(timeInterval: TimeInterval = 3600) async {
	isExportingLogs = true
	defer { isExportingLogs = false }
	
	do {
	  var logData: Data
	  if #available(iOS 15.0, *) {
		logData = try await DHLoggingKit.exporter.exportLogs(timeInterval: timeInterval)
	  } else {
		logData = "Log export requires iOS 15.0 or later. This device is running iOS \(UIDevice.current.systemVersion).".data(using: .utf8) ?? Data()
	  }
	  
	  // Create a file URL in the documents directory for sharing
	  let dateFormatter = DateFormatter()
	  dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
	  let filename = "AsNeeded-Logs-\(dateFormatter.string(from: Date())).txt"
	  
	  // Use documents directory for better compatibility
	  guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
		logger.error("Could not access documents directory")
		alertMessage = "Log export failed: Could not access documents directory"
		showingAlert = true
		return
	  }
	  let tempURL = documentsPath.appendingPathComponent(filename)
	  
	  // Write with proper attributes
	  try logData.write(to: tempURL, options: [.atomic])
	  logger.debug("Wrote log data to file: \(tempURL.lastPathComponent)")
	  
	  // Ensure file is accessible
	  _ = tempURL.startAccessingSecurityScopedResource()
	  
	  exportedLogsURL = tempURL
	  showingLogShareSheet = true
	  logger.debug("exportedLogsURL set - share sheet should be triggered")
	} catch {
	  alertMessage = "Log export failed: \(error.localizedDescription)"
	  showingAlert = true
	}
  }
  
  
  var medicationCount: Int {
	dataStore.medications.count
  }
  
  var eventCount: Int {
	dataStore.events.count
  }
}
