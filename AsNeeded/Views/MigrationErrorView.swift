// MigrationErrorView.swift
// Error screen shown when data migration fails

import SwiftUI
import SFSafeSymbols

/// Error view displayed when data migration fails on app launch
/// Provides clear error information and recovery options for users
struct MigrationErrorView: View {
	@Environment(\.fontFamily) private var fontFamily
	let error: Error
	let onRetry: () async -> Void

	var body: some View {
		VStack(spacing: 32) {
			// Error icon
			Image(systemSymbol: .exclamationmarkTriangle)
				.font(.customFont(fontFamily, style: .largeTitle, weight: .semibold))
				.foregroundStyle(.red)
				.symbolRenderingMode(.multicolor)

			// Error message
			VStack(spacing: 12) {
				Text("Migration Failed")
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))

				Text(errorMessage)
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 8)
			}

			// Action buttons
			VStack(spacing: 16) {
				// Retry button
				Button {
					Task {
						await onRetry()
					}
				} label: {
					Label("Retry Migration", systemSymbol: .arrowClockwise)
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.frame(maxWidth: .infinity)
						.padding(.vertical, 12)
				}
				.buttonStyle(.borderedProminent)
				.tint(.accent)

				// Technical details (collapsible)
				DisclosureGroup {
					VStack(alignment: .leading, spacing: 8) {
						Text("Error Details:")
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))

						Text(error.localizedDescription)
							.font(.customFont(fontFamily, style: .caption))
							.foregroundStyle(.secondary)
							.noTruncate()

						if let migrationError = error as? MigrationError {
							Text("\nTechnical: \(String(describing: migrationError))")
								.font(.customFont(fontFamily, style: .caption2))
								.foregroundStyle(.tertiary)
								.noTruncate()
						}
					}
					.padding(12)
					.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
				} label: {
					Text("Technical Details")
						.font(.customFont(fontFamily, style: .caption, weight: .medium))
				}
				.tint(.secondary)
			}
		}
		.padding(32)
	}

	private var errorMessage: String {
		if let migrationError = error as? MigrationError {
			switch migrationError {
			case .appGroupUnavailable:
				return "Unable to access secure data storage. This may be a configuration issue. Please try again or contact support if the problem persists."
			case .invalidPath:
				return "Unable to locate your medication data. Please try again or contact support if the problem persists."
			case let .verificationFailed(expected, actual, type):
				return "Data verification failed after migration. Expected \(expected) \(type) but found \(actual). Please retry or contact support immediately."
			}
		}
		return "An unexpected error occurred while loading your data. Please try again or contact support if the problem persists."
	}
}

#Preview("App Group Unavailable") {
	MigrationErrorView(
		error: MigrationError.appGroupUnavailable,
		onRetry: {
			print("Retry tapped")
		}
	)
}

#Preview("Invalid Path") {
	MigrationErrorView(
		error: MigrationError.invalidPath,
		onRetry: {
			print("Retry tapped")
		}
	)
}
