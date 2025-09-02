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
  @Published var showingLogFileSaver = false
  @Published var showingDataExporter = false
  @Published var exportedData: Data?
  @Published var exportedLogsData: Data?
  @Published var alertMessage: String?
  @Published var showingAlert = false
  @Published var logCount: Int = 0
  
  init(dataStore: DataStore = .shared) {
	self.dataStore = dataStore
	Task {
	  await fetchLogCount()
	}
  }
  
  func fetchLogCount() async {
	logger.debug("Fetching log count")
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
  
  func exportData(includeNames: Bool) async {
	logger.info("Starting data export - includeNames: \(includeNames)")
	isExporting = true
	defer { 
	  isExporting = false
	  logger.debug("Export process completed - isExporting set to false")
	}
	
	do {
	  logger.debug("Calling dataStore.exportDataAsJSON with redactNames: \(!includeNames)")
	  let data = try await dataStore.exportDataAsJSON(redactNames: !includeNames)
	  logger.info("Export data generated successfully - size: \(data.count) bytes")
	  
	  // Set the exported data which should trigger the file exporter
	  exportedData = data
	  showingDataExporter = true
	  logger.debug("exportedData set - file exporter should be triggered")
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
	logger.warning("Starting clear all data operation")
	isClearing = true
	defer { 
	  isClearing = false
	  logger.debug("Clear data process completed")
	}
	
	do {
	  try await dataStore.clearAllData()
	  logger.info("All data cleared successfully")
	  alertMessage = "All data cleared successfully"
	  showingAlert = true
	} catch {
	  logger.error("Clear data failed", error: error)
	  alertMessage = "Clear data failed: \(error.localizedDescription)"
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
	  if #available(iOS 15.0, *) {
		let logData = try await DHLoggingKit.exporter.exportLogs(timeInterval: timeInterval)
		exportedLogsData = logData
	  } else {
		exportedLogsData = "Log export requires iOS 15.0 or later. This device is running iOS \(UIDevice.current.systemVersion).".data(using: .utf8)
	  }
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