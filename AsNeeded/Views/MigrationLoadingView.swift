// MigrationLoadingView.swift
// Tab previews shown while startup prepares local data.

import SFSafeSymbols
import SwiftUI

struct MigrationLoadingView: View {
	@AppStorage(UserDefaultsKeys.selectedTab) private var savedTab = 0
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		TabView(selection: .constant((0...3).contains(savedTab) ? savedTab : 0)) {
			NavigationStack {
				MedicationLoadingRows()
					.customNavigationTitle("Medication", displayMode: .large)
			}
			.tabItem { Label("Medication", systemSymbol: .pills) }
			.tag(0)

			preview("History") { historyPlaceholder }
				.tabItem { Label("History", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90) }
				.tag(1)

			preview("Trends") { trendsPlaceholder }
				.tabItem { Label("Trends", systemSymbol: .chartXyaxisLine) }
				.tag(2)

			preview("Settings") { settingsPlaceholder }
				.tabItem { Label("Settings", systemSymbol: .gearshape) }
				.tag(3)
		}
		.tint(.accent)
		.allowsHitTesting(false)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text("Loading Your Data"))
	}

	private func preview<Content: View>(
		_ title: LocalizedStringKey,
		@ViewBuilder content: () -> Content
	) -> some View {
		NavigationStack {
			ScrollView {
				content()
					.redacted(reason: .placeholder)
					.padding(16)
			}
			.background(Color(.systemGroupedBackground))
			.customNavigationTitle(title, displayMode: .large)
		}
	}

	private var historyPlaceholder: some View {
		VStack(alignment: .leading, spacing: 24) {
			ForEach(0..<2) { _ in
				VStack(alignment: .leading, spacing: 8) {
					Text(verbatim: "Day and date")
						.font(.customFont(fontFamily, style: .subheadline))
						.padding(.horizontal, 12)

					VStack(spacing: 12) {
						placeholderRow(icon: Circle(), title: "Medication name", detail: "Time and dose")
						Divider()
						placeholderRow(icon: Circle(), title: "Medication", detail: "Time and dose")
					}
					.padding(16)
					.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
				}
			}
		}
	}

	private var trendsPlaceholder: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(verbatim: "Medication name")
				.font(.customFont(fontFamily, style: .headline, weight: .bold))
			Text(verbatim: "Daily usage date range")
				.font(.customFont(fontFamily, style: .subheadline))
			RoundedRectangle(cornerRadius: 8)
				.fill(.quaternary)
				.frame(height: 280)
		}
		.padding(16)
		.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
	}

	private var settingsPlaceholder: some View {
		VStack(alignment: .leading, spacing: 24) {
			ForEach(["Preferences", "Data and Privacy", "About"], id: \.self) { section in
				VStack(alignment: .leading, spacing: 12) {
					Text(verbatim: section)
						.font(.customFont(fontFamily, style: .title2, weight: .semibold))
					placeholderRow(icon: RoundedRectangle(cornerRadius: 6), title: section, detail: "Setting description")
						.padding(16)
						.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
				}
			}
		}
	}

	private func placeholderRow<Icon: Shape>(icon: Icon, title: String, detail: String) -> some View {
		HStack(spacing: 12) {
			if !dynamicTypeSize.isAccessibilitySize {
				icon.fill(.quaternary)
					.frame(width: 28, height: 28)
			}
			VStack(alignment: .leading, spacing: 4) {
				Text(verbatim: title)
					.font(.customFont(fontFamily, style: .body))
				Text(verbatim: detail)
					.font(.customFont(fontFamily, style: .caption))
			}
			.lineLimit(1)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

#Preview("Light") {
	MigrationLoadingView()
		.preferredColorScheme(.light)
}

#Preview("Dark") {
	MigrationLoadingView()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility Size") {
	MigrationLoadingView()
		.dynamicTypeSize(.accessibility3)
}
