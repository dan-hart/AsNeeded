// DataManagementView.swift
// UI for data management operations (export, import, clear).

import DHLoggingKit
import SFSafeSymbols
import SwiftUI
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

struct DataManagementView: View {
    @StateObject private var viewModel = DataManagementViewModel()
    @State private var showSupportToast = false
    @State private var showSupportView = false
    @State private var redactMedicationNames = false
    @State private var redactNotes = false
    @Environment(\.fontFamily) private var fontFamily
    private let logger = DHLogger(category: "DataManagementView")

    @ScaledMetric private var sectionSpacing: CGFloat = 20
    @ScaledMetric private var contentSpacing: CGFloat = 16
    @ScaledMetric private var actionSpacing: CGFloat = 12
    @ScaledMetric private var statSpacing: CGFloat = 4
    @ScaledMetric private var toggleLabelSpacing: CGFloat = 2
    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var cardCornerRadius: CGFloat = 12
    @ScaledMetric private var borderWidth: CGFloat = 0.5
    @ScaledMetric private var actionIconSize: CGFloat = 24

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    dataOverviewSection

                    Divider()

                    automaticBackupSection

                    Divider()

                    dataActionsSection
                }
                .padding()
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

                            // Handle post-export flow (e.g., clear data if requested)
                            viewModel.onShareSheetDismissed()

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
                case let .success(urls):
                    guard let url = urls.first else { return }
                    Task {
                        await viewModel.importData(from: url)
                    }
                case let .failure(error):
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
            .sheet(isPresented: $viewModel.showingExportConfirmation) {
                NavigationStack {
                    Form {
                        Section {
                            Text("Choose what information to include in the export")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Section("Privacy Options") {
                            Toggle(isOn: $redactMedicationNames) {
                                VStack(alignment: .leading, spacing: toggleLabelSpacing) {
                                    Text("Redact Medication Names")
                                    Text("Replace medication names with [REDACTED]")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Toggle(isOn: $redactNotes) {
                                VStack(alignment: .leading, spacing: toggleLabelSpacing) {
                                    Text("Redact Notes")
                                    Text("Remove all notes from events")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section("Backup Content") {
                            Toggle(isOn: $viewModel.includeSettings) {
                                VStack(alignment: .leading, spacing: toggleLabelSpacing) {
                                    Text("Include App Settings")
                                    Text("Include preferences (fonts, haptics, privacy settings)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Export Options")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                viewModel.showingExportConfirmation = false
                                redactMedicationNames = false
                                redactNotes = false
                            } label: {
                                Image(systemSymbol: .xmark)
                                    .font(.customFont(fontFamily, style: .body, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                Task {
                                    await viewModel.exportData(
                                        redactMedicationNames: redactMedicationNames,
                                        redactNotes: redactNotes
                                    )
                                    viewModel.showingExportConfirmation = false
                                    redactMedicationNames = false
                                    redactNotes = false
                                }
                            } label: {
                                Image(systemSymbol: .checkmarkCircleFill)
                                    .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
                .dynamicDetent()
            }
            .confirmationDialog(
                "Export Before Clearing?",
                isPresented: $viewModel.showingPreClearExportDialog,
                titleVisibility: .visible
            ) {
                Button("Export & Continue") {
                    viewModel.handlePreClearExportChoice(shouldExport: true)
                }
                Button("Clear Without Export", role: .destructive) {
                    viewModel.handlePreClearExportChoice(shouldExport: false)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Would you like to export your data before permanently deleting it? This ensures you have a backup if needed.")
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $viewModel.showingClearUserDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        await viewModel.clearUserData()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all medications and events. This cannot be undone.")
            }
            .confirmationDialog(
                "Reset App Preferences",
                isPresented: $viewModel.showingResetSettingsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Preferences", role: .destructive) {
                    Task {
                        await viewModel.resetAppSettings()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will restore all app preferences to their original defaults. This cannot be undone.")
            }
            .confirmationDialog(
                "Reset & Clear All Data",
                isPresented: $viewModel.showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset & Clear All Data", role: .destructive) {
                    Task {
                        await viewModel.clearAllData()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all medications and events, and restore all app settings to their original defaults. This cannot be undone.")
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
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Export technical app logs for troubleshooting. No medication names are stored in logs - only technical information like app events, errors, and system data.")
            }
            .confirmationDialog(
                "Import Settings",
                isPresented: $viewModel.showingImportSettingsDialog,
                titleVisibility: .visible
            ) {
                Button("Keep My Settings") {
                    Task {
                        await viewModel.proceedWithImport(applySettings: false)
                    }
                }
                Button("Import Settings") {
                    Task {
                        await viewModel.proceedWithImport(applySettings: true)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.pendingImportData = nil
                    viewModel.importContainsSettings = false
                }
            } message: {
                Text("This import contains app settings (fonts, haptics, preferences). Would you like to import these settings or keep your current settings?")
            }
            .alert("Data Management", isPresented: $viewModel.showingAlert) {
                Button("OK") {}
            } message: {
                if let message = viewModel.alertMessage {
                    Text(message)
                }
            }
            .alert("Automatic Backups Require Reconfiguration", isPresented: $viewModel.showingAutomaticBackupReconfigAlert) {
                Button("Later", role: .cancel) {}
                Button("Reconfigure Now") {
                    viewModel.navigateToAutomaticBackup()
                }
            } message: {
                Text("Automatic backups were enabled before importing, but need to be reconfigured because backup location settings are device-specific.\n\nWould you like to reconfigure automatic backups now?")
            }
            .navigationDestination(isPresented: $viewModel.shouldNavigateToAutomaticBackup) {
                AutomaticBackupView()
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
        .onAppear {
            viewModel.refreshAutomaticBackupStatus()
        }
    }

    private var dataOverviewSection: some View {
        VStack(alignment: .leading, spacing: actionSpacing) {
            Text("Data Overview")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading, spacing: statSpacing) {
                    Text("Medications")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.medicationCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .center, spacing: statSpacing) {
                    Text("Events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.eventCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: statSpacing) {
                    Text("Logs (24h)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Group {
                        if viewModel.isLoadingLogCount {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("\(viewModel.logCount)")
                        }
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                }
            }
            .padding(cardPadding)
            .background(Color(.systemGray6))
            .cornerRadius(cardCornerRadius)
        }
    }

    private var automaticBackupSection: some View {
        NavigationLink(destination: AutomaticBackupView()) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic Backup")
                        .font(.customFont(fontFamily, style: .body, weight: .medium))
                        .foregroundStyle(.primary)

                    if viewModel.isAutomaticBackupEnabled {
                        if let lastBackup = viewModel.lastAutomaticBackupDate {
                            Text("Active • Last: \(lastBackup, style: .relative) ago")
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Active")
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Not Configured")
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if viewModel.isAutomaticBackupEnabled {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }

                    Image(systemSymbol: .chevronRight)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(cardPadding)
            .background(Color(.systemGray6))
            .cornerRadius(cardCornerRadius)
        }
    }

    private var dataActionsSection: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            Text("Data Actions")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: actionSpacing) {
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
                    subtitle: "Delete all medications and events",
                    systemImage: .trash,
                    isLoading: viewModel.isClearingUserData,
                    isDestructive: true,
                    action: {
                        viewModel.confirmClearUserData()
                    }
                )

                dataActionButton(
                    title: "Reset App Preferences",
                    subtitle: "Restore all app preferences to defaults",
                    systemImage: .arrowCounterclockwise,
                    isLoading: viewModel.isResettingSettings,
                    isDestructive: true,
                    action: {
                        viewModel.confirmResetSettings()
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
            HStack(spacing: actionSpacing) {
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemSymbol: systemImage)
                            .font(.callout.weight(.medium))
                    }
                }
                .frame(width: actionIconSize, height: actionIconSize)
                .foregroundStyle(isDestructive ? .red : .accent)

                VStack(alignment: .leading, spacing: toggleLabelSpacing) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isLoading {
                    Image(systemSymbol: .chevronRight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(cardPadding)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: borderWidth)
            )
            .cornerRadius(cardCornerRadius)
        }
        .disabled(isLoading || viewModel.isExporting || viewModel.isImporting || viewModel.isClearing || viewModel.isClearingUserData || viewModel.isResettingSettings || viewModel.isExportingLogs)
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

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
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

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#if DEBUG
    #Preview {
        DataManagementView()
    }
#endif
