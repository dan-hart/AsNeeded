// DataManagementView.swift
// UI for data management operations (export, import, clear).

import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
  @StateObject private var viewModel = DataManagementViewModel()
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      dataOverviewSection
      
      Divider()
      
      dataActionsSection
    }
    .fileExporter(
      isPresented: $viewModel.showingFileSaver,
      document: viewModel.exportedData.map { DataDocument(data: $0) },
      contentType: .json,
      defaultFilename: "AsNeeded-Export-\(dateFormatter.string(from: Date()))"
    ) { result in
      switch result {
      case .success:
        viewModel.alertMessage = "Data exported successfully"
        viewModel.showingAlert = true
      case .failure(let error):
        viewModel.alertMessage = "Export save failed: \(error.localizedDescription)"
        viewModel.showingAlert = true
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
    .alert("Data Management", isPresented: $viewModel.showingAlert) {
      Button("OK") { }
    } message: {
      if let message = viewModel.alertMessage {
        Text(message)
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
        
        VStack(alignment: .trailing, spacing: 4) {
          Text("Events")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Text("\(viewModel.eventCount)")
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
          systemImage: "square.and.arrow.up",
          isLoading: viewModel.isExporting,
          action: {
            Task { await viewModel.exportData() }
          }
        )
        
        dataActionButton(
          title: "Import Data",
          subtitle: "Replace current data with a JSON file",
          systemImage: "square.and.arrow.down",
          isLoading: viewModel.isImporting,
          action: {
            viewModel.showingDocumentPicker = true
          }
        )
        
        dataActionButton(
          title: "Clear All Data",
          subtitle: "Permanently delete all medications and events",
          systemImage: "trash",
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
    systemImage: String,
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
            Image(systemName: systemImage)
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
          Image(systemName: "chevron.right")
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
    .disabled(isLoading || viewModel.isExporting || viewModel.isImporting || viewModel.isClearing)
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