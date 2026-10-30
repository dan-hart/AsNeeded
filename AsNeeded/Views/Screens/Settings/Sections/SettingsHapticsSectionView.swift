// SettingsHapticsSectionView.swift
// Settings section for haptic feedback preferences

import SwiftUI
import SFSafeSymbols

struct SettingsHapticsSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	@StateObject private var hapticsManager = HapticsManager.shared
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12
	private let stackItemSpacing: CGFloat = 2
	private let iconSize: CGFloat = 24
	private let padding: CGFloat = 16
	private let cornerRadius: CGFloat = 12
	private let borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Haptics")
				.font(.customFont(fontFamily, style: .title2))
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
				.foregroundColor(.accent)

			VStack(alignment: .leading, spacing: stackItemSpacing) {
				Text("Haptic Feedback")
					.font(.customFont(fontFamily, style: .body))
					.fontWeight(.medium)

				Text("Feel touches and actions throughout the app")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.secondary)
			}

			Spacer()

			Toggle("Haptic Feedback", isOn: $hapticsManager.hapticsEnabled)
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
