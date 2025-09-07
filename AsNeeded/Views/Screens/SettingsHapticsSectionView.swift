// SettingsHapticsSectionView.swift
// Settings section for haptic feedback preferences

import SwiftUI
import SFSafeSymbols

struct SettingsHapticsSectionView: View {
	@StateObject private var hapticsManager = HapticsManager.shared
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Haptics")
				.font(.title2)
				.fontWeight(.semibold)
			
			VStack(spacing: 12) {
				hapticsToggle
			}
		}
	}
	
	@ViewBuilder
	private var hapticsToggle: some View {
		HStack(spacing: 12) {
			Image(systemSymbol: .iphoneRadiowavesLeftAndRight)
				.font(.system(size: 18, weight: .medium))
				.frame(width: 24, height: 24)
				.foregroundColor(.accentColor)
			
			VStack(alignment: .leading, spacing: 2) {
				Text("Haptic Feedback")
					.font(.body)
					.fontWeight(.medium)
				
				Text("Feel touches and actions throughout the app")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			
			Spacer()
			
			Toggle("", isOn: $hapticsManager.hapticsEnabled)
				.labelsHidden()
				.onChange(of: hapticsManager.hapticsEnabled) { _, _ in
					// Provide immediate feedback when toggling
					if hapticsManager.hapticsEnabled {
						HapticsManager.shared.selectionChanged()
					}
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
}

#Preview {
	SettingsHapticsSectionView()
		.padding()
}