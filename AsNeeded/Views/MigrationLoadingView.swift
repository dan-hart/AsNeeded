// MigrationLoadingView.swift
// Loading screen shown during data migration

import SwiftUI

/// Loading view displayed while data migration runs on app launch
/// Prevents users from seeing empty state or interacting with app during migration
struct MigrationLoadingView: View {
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		VStack(spacing: 24) {
			ProgressView()
				.scaleEffect(1.5)
				.tint(.accent)

			VStack(spacing: 8) {
				Text("Loading Your Data")
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))

				Text("Please wait while we prepare your medications...")
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
		}
		.padding(32)
	}
}

#Preview {
	MigrationLoadingView()
}
