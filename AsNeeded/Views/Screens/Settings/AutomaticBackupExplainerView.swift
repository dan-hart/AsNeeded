// AutomaticBackupExplainerView.swift
// Educational content explaining automatic backup in non-technical terms

import SFSafeSymbols
import SwiftUI

struct AutomaticBackupExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontFamily) private var fontFamily

	private let cornerRadius: CGFloat = 8

    var body: some View {
        NavigationStack {
            VerticalOnlyScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    whatIsSection
                    howItWorksSection
                    retentionPolicySection
                    privacyOptionsSection
                    storageSection
                    whenBackupHappensSection
                    dataSafetySection
                }
                .padding()
            }
            .customNavigationTitle("How It Works")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemSymbol: .xmark)
                    }
                    .accessibilityLabel("Close Backup Information")
                }
            }
            .tint(.accent)
        }
    }

    private var whatIsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is Automatic Backup?")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            Text("Automatically saves your medications and dose history to a location you choose after logging a dose.")
                .font(.customFont(fontFamily, style: .body))
                .foregroundStyle(.secondary)
        }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            VStack(spacing: 16) {
                stepRow(
                    number: 1,
                    icon: .pills,
                    title: String(localized: "Log a dose"),
                    description: String(localized: "Record your medication")
                )

                stepRow(
                    number: 2,
                    icon: .clock,
                    title: String(localized: "Brief wait"),
                    description: String(localized: "Prevents multiple backups in a row")
                )

                stepRow(
                    number: 3,
                    icon: .checkmarkCircleFill,
                    title: String(localized: "Auto-saved"),
                    description: String(localized: "Data saved to your location")
                )

                stepRow(
                    number: 4,
                    icon: .trash,
                    title: String(localized: "Auto-cleanup"),
                    description: String(localized: "Old backups removed automatically")
                )
            }
        }
    }

    private var retentionPolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep Backups")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            Text("Choose how long to keep backups (7 days to 1 year). Older backups are deleted daily to save space. Today's backup is always kept.")
                .font(.customFont(fontFamily, style: .body))
                .foregroundStyle(.secondary)
        }
    }

    private var privacyOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy Options")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemSymbol: .eyeSlash)
                        .foregroundStyle(.accent)
                        .font(.customFont(fontFamily, style: .title3))
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Redact Medication Names")
                            .font(.customFont(fontFamily, style: .body, weight: .medium))
                        Text("Shows [REDACTED] instead of names")
                            .font(.customFont(fontFamily, style: .callout))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemSymbol: .textDocument)
                        .foregroundStyle(.accent)
                        .font(.customFont(fontFamily, style: .title3))
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Redact Notes")
                            .font(.customFont(fontFamily, style: .body, weight: .medium))
                        Text("Removes all notes")
                            .font(.customFont(fontFamily, style: .callout))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage & Performance")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(String(localized: "Small backups (typically 2-3 MB)"))
                bulletPoint(String(localized: "Minimal battery usage"))
                bulletPoint(String(localized: "Track storage in settings"))
            }
        }
    }

    private var whenBackupHappensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When Backup Happens")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            Text("Backups occur 5 seconds after logging a dose. Multiple doses trigger one backup to save battery. Use 'Backup Now' for immediate backups.")
                .font(.customFont(fontFamily, style: .body))
                .foregroundStyle(.secondary)
        }
    }

    private var dataSafetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Is My Data Safe?")
                .font(.customFont(fontFamily, style: .title2, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(String(localized: "Backups stored in your chosen location only"))
                bulletPoint(String(localized: "Data stays on your device or personal iCloud"))
                bulletPoint(String(localized: "You control and can delete backups anytime"))
            }
        }
    }

    // MARK: - Helper Views

    private func stepRow(number: Int, icon: SFSymbol, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text("\(number)")
                    .font(.customFont(fontFamily, style: .headline, weight: .bold))
                    .foregroundStyle(.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemSymbol: icon)
                        .foregroundStyle(.accent)
                        .font(.customFont(fontFamily, style: .body))
                    Text(title)
                        .font(.customFont(fontFamily, style: .body, weight: .semibold))
                }
                Text(description)
                    .font(.customFont(fontFamily, style: .callout))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.customFont(fontFamily, style: .body))
                .foregroundStyle(.accent)
            Text(text)
                .font(.customFont(fontFamily, style: .body))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AutomaticBackupExplainerView()
}
