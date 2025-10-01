// SettingsHapticsSectionView.swift
// Settings section for haptic feedback preferences

import SwiftUI
import SFSafeSymbols

struct SettingsHapticsSectionView: View {
	@StateObject private var hapticsManager = HapticsManager.shared
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Haptics")
				.font(.title2)
				.fontWeight(.semibold)

			VStack(spacing: headerSpacing) {
				hapticsToggle
			}
		}
	}

	@ViewBuilder
	private var hapticsToggle: some View {
		HStack(spacing: headerSpacing) {
			Image(systemSymbol: .iphoneRadiowavesLeftAndRight)
				.font(.callout.weight(.medium))
				.frame(width: iconSize, height: iconSize)
				.foregroundColor(.accentColor)

			VStack(alignment: .leading, spacing: stackItemSpacing) {
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
		.padding(padding)
		.background(Color(.systemBackground))
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius)
				.stroke(Color(.systemGray4), lineWidth: borderWidth)
		)
		.cornerRadius(cornerRadius)
	}
}

#Preview {
	SettingsHapticsSectionView()
		.padding()
}