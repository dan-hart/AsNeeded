// DataManagementView.swift
// UI for data management operations (export, import, clear).

import SwiftUI
import UniformTypeIdentifiers
import SFSafeSymbols
import DHLoggingKit

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  
  func makeUIViewController(context: Context) -> UIActivityViewController {
	let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
	return controller
  }
  
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DataManagementView: View {
  @StateObject private var viewModel = DataManagementViewModel()
  @State private var showSupportToast = false
  @State private var showSupportView = false
  private let logger = DHLogger(category: "DataManagementView")
  
  var body: some View {
	  ZStack(alignment: .top) {
		  ScrollView {
			  VStack(alignment: .leading, spacing: 20) {
			  dataOverviewSection
			  
			  Divider()
			  
			  dataActionsSection
		  }
	  }
		  .sheet(isPresented: $viewModel.showingDataShareSheet) {
			  if let url = viewModel.exportedDataURL {
				  ShareSheet(items: [url])
					  .onDisappear {
						  logger.info("Data share sheet dismissed")
						  // Stop accessing security scoped resource and clean up
						  url.stopAccessingSecurityScopedResource()
						  DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
							  // Clean up file after a small delay to ensure share completion
							  try? FileManager.default.removeItem(at: url)
						  }
						  viewModel.exportedDataURL = nil
						  
						  DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
							  withAnimation(.easeInOut(duration: 0.3)) {
								  showSupportToast = true
							  }
							  DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
								  withAnimation(.easeInOut(duration: 0.3)) {
									  showSupportToast = false
								  }
							  }
						  }
					  }
			  }
		  }
	.fileImporter(
	  isPresented: $viewModel.showingDocumentPicker,
	  allowedContentTypes: [.json],
	  allowsMultipleSelection: false
	) { result in
	  switch result {
	  case .success(let urls):
		guard let url = urls.first else { return }
		Task {
		  await viewModel.importData(from: url)
		}
	  case .failure(let error):
		viewModel.alertMessage = "Import selection failed: \(error.localizedDescription)"
		viewModel.showingAlert = true
	  }
	}
	.sheet(isPresented: $viewModel.showingLogShareSheet) {
	  if let url = viewModel.exportedLogsURL {
		ShareSheet(items: [url])
		  .onDisappear {
			logger.info("Log share sheet dismissed")
			// Stop accessing security scoped resource and clean up
			url.stopAccessingSecurityScopedResource()
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			  // Clean up file after a small delay to ensure share completion
			  try? FileManager.default.removeItem(at: url)
			}
			viewModel.exportedLogsURL = nil
			viewModel.alertMessage = "Logs exported successfully. No medication names are included - only technical information."
			viewModel.showingAlert = true
		  }
	  }
	}
	.confirmationDialog(
	  "Export Data",
	  isPresented: $viewModel.showingExportConfirmation,
	  titleVisibility: .visible
	) {
	  Button("Include Medication Names") {
		Task {
		  await viewModel.exportData(includeNames: true)
		}
	  }
	  Button("Redact Medication Names") {
		Task {
		  await viewModel.exportData(includeNames: false)
		}
	  }
	  Button("Cancel", role: .cancel) { }
	} message: {
	  Text("Would you like to include clinical names and nicknames in the export, or redact them for privacy?")
	}
	.confirmationDialog(
	  "Clear All Data",
	  isPresented: $viewModel.showingClearConfirmation,
	  titleVisibility: .visible
	) {
	  Button("Clear All Data", role: .destructive) {
		Task {
		  await viewModel.clearAllData()
		}
	  }
	  Button("Cancel", role: .cancel) { }
	} message: {
	  Text("This will permanently delete all medications and events. This cannot be undone.")
	}
	.confirmationDialog(
	  "Export App Logs",
	  isPresented: $viewModel.showingLogExportConfirmation,
	  titleVisibility: .visible
	) {
	  Button("Last Hour") {
		Task {
		  await viewModel.exportLogs(timeInterval: 3600)
		}
	  }
	  Button("Last 4 Hours") {
		Task {
		  await viewModel.exportLogs(timeInterval: 14400)
		}
	  }
	  Button("Last 24 Hours") {
		Task {
		  await viewModel.exportLogs(timeInterval: 86400)
		}
	  }
	  Button("Cancel", role: .cancel) { }
	} message: {
	  Text("Export technical app logs for troubleshooting. No medication names are stored in logs - only technical information like app events, errors, and system data.")
	}
	.alert("Data Management", isPresented: $viewModel.showingAlert) {
	  Button("OK") { }
	} message: {
	  if let message = viewModel.alertMessage {
		Text(message)
	  }
	}
		  
		  SupportToastView(
			  message: "Data exported successfully",
			  supportMessage: "Support As Needed",
			  isVisible: showSupportToast,
			  onDismiss: { 
				  withAnimation(.easeInOut(duration: 0.3)) {
					  showSupportToast = false
				  }
			  },
			  onSupportTapped: {
				  withAnimation(.easeInOut(duration: 0.3)) {
					  showSupportToast = false
					  showSupportView = true
				  }
			  }
		  )
	  }
	  .sheet(isPresented: $showSupportView) {
		  NavigationView {
			  SupportView()
		  }
	  }
  }
  
  private var dataOverviewSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("Data Overview")
		.font(.headline)
		.fontWeight(.semibold)
	  
	  HStack {
		VStack(alignment: .leading, spacing: 4) {
		  Text("Medications")
			.font(.subheadline)
			.foregroundColor(.secondary)
		  Text("\(viewModel.medicationCount)")
			.font(.title2)
			.fontWeight(.semibold)
		}
		
		Spacer()
		
		VStack(alignment: .center, spacing: 4) {
		  Text("Events")
			.font(.subheadline)
			.foregroundColor(.secondary)
		  Text("\(viewModel.eventCount)")
			.font(.title2)
			.fontWeight(.semibold)
		}
		
		Spacer()
		
		VStack(alignment: .trailing, spacing: 4) {
		  Text("Logs (24h)")
			.font(.subheadline)
			.foregroundColor(.secondary)
		  Text("\(viewModel.logCount)")
			.font(.title2)
			.fontWeight(.semibold)
		}
	  }
	  .padding(16)
	  .background(Color(.systemGray6))
	  .cornerRadius(12)
	}
  }
  
  private var dataActionsSection: some View {
	VStack(alignment: .leading, spacing: 16) {
	  Text("Data Actions")
		.font(.headline)
		.fontWeight(.semibold)
	  
	  VStack(spacing: 12) {
		dataActionButton(
		  title: "Export Data",
		  subtitle: "Save all your data as a JSON file",
		  systemImage: .squareAndArrowUp,
		  isLoading: viewModel.isExporting,
		  action: {
			viewModel.requestExport()
		  }
		)
		
		dataActionButton(
		  title: "Import Data",
		  subtitle: "Replace current data with a JSON file",
		  systemImage: .squareAndArrowDown,
		  isLoading: viewModel.isImporting,
		  action: {
			viewModel.showingDocumentPicker = true
		  }
		)
		
		dataActionButton(
		  title: "Export App Logs",
		  subtitle: "Export technical logs (no medication names)",
		  systemImage: .textDocument,
		  isLoading: viewModel.isExportingLogs,
		  action: {
			viewModel.requestLogExport()
		  }
		)
		
		dataActionButton(
		  title: "Clear All Data",
		  subtitle: "Permanently delete all medications and events",
		  systemImage: .trash,
		  isLoading: viewModel.isClearing,
		  isDestructive: true,
		  action: {
			viewModel.confirmClearData()
		  }
		)
		
	  }
	}
  }
  
  private func dataActionButton(
	title: String,
	subtitle: String,
	systemImage: SFSymbol,
	isLoading: Bool,
	isDestructive: Bool = false,
	action: @escaping () -> Void
  ) -> some View {
	Button(action: action) {
	  HStack(spacing: 12) {
		Group {
		  if isLoading {
			ProgressView()
			  .scaleEffect(0.8)
		  } else {
			Image(systemSymbol: systemImage)
			  .font(.system(size: 18, weight: .medium))
		  }
		}
		.frame(width: 24, height: 24)
		.foregroundColor(isDestructive ? .red : .blue)
		
		VStack(alignment: .leading, spacing: 2) {
		  Text(title)
			.font(.body)
			.fontWeight(.medium)
			.foregroundColor(isDestructive ? .red : .primary)
		  
		  Text(subtitle)
			.font(.caption)
			.foregroundColor(.secondary)
		}
		
		Spacer()
		
		if !isLoading {
		  Image(systemSymbol: .chevronRight)
			.font(.caption)
			.foregroundColor(.secondary)
		}
	  }
	  .padding(16)
	  .background(Color(.systemBackground))
	  .overlay(
		RoundedRectangle(cornerRadius: 12)
		  .stroke(Color(.systemGray4), lineWidth: 0.5)
	  )
	  .cornerRadius(12)
	}
	.disabled(isLoading || viewModel.isExporting || viewModel.isImporting || viewModel.isClearing || viewModel.isExportingLogs)
	.buttonStyle(.plain)
  }
  
  private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.dateFormat = "yyyy-MM-dd-HHmm"
	return formatter
  }()
}

// Document wrapper for file export
private struct DataDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]
  static let writableContentTypes: [UTType] = [.json]
  
  let data: Data
  
  init(data: Data) {
	self.data = data
  }
  
  init(configuration: ReadConfiguration) throws {
	guard let data = configuration.file.regularFileContents else {
	  throw CocoaError(.fileReadCorruptFile)
	}
	self.data = data
  }
  
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
	return FileWrapper(regularFileWithContents: data)
  }
}

// Document wrapper for log file export
private struct LogDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.plainText]
  static let writableContentTypes: [UTType] = [.plainText]
  
  let data: Data
  
  init(data: Data) {
	self.data = data
  }
  
  init(configuration: ReadConfiguration) throws {
	guard let data = configuration.file.regularFileContents else {
	  throw CocoaError(.fileReadCorruptFile)
	}
	self.data = data
  }
  
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
	return FileWrapper(regularFileWithContents: data)
  }
}

#if DEBUG
#Preview {
  DataManagementView()
}
#endif
