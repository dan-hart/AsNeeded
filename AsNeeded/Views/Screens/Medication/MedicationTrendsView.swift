import ANModelKit
import Charts
import SFSafeSymbols
import SwiftUI

enum VisualizationType: String, CaseIterable {
	case chart
	case heatmap

	var displayName: String {
		switch self {
		case .chart: return "Chart"
		case .heatmap: return "Calendar"
		}
	}

	var systemImage: String {
		switch self {
		case .chart: return "chart.xyaxis.line"
		case .heatmap: return "calendar"
		}
	}
}

struct MedicationTrendsView: View {
	@StateObject private var viewModel = MedicationTrendsViewModel()
	@EnvironmentObject private var navigationManager: NavigationManager
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@AppStorage(UserDefaultsKeys.trendsDaysWindow) private var daysWindow: Int = 14
	@AppStorage(UserDefaultsKeys.trendsVisualizationType) private var visualizationType: VisualizationType = .chart

	@ScaledMetric private var sectionSpacing: CGFloat = 16
	@ScaledMetric private var controlsSpacing: CGFloat = 12
	@ScaledMetric private var heatmapSpacing: CGFloat = 8
	@ScaledMetric private var metricLabelSpacing: CGFloat = 6
	@ScaledMetric private var metricTitleSpacing: CGFloat = 4
	@ScaledMetric private var heatmapCellSpacing: CGFloat = 2
	@ScaledMetric private var pickerMaxWidth: CGFloat = 160
	@ScaledMetric private var metricCardPadding: CGFloat = 12
	@ScaledMetric private var metricCardMinHeight: CGFloat = 90
	@ScaledMetric private var metricCardCornerRadius: CGFloat = 10
	@ScaledMetric private var chartHeight: CGFloat = 280
	@ScaledMetric private var chartPaddingH: CGFloat = 4
	@ScaledMetric private var chartContainerPadding: CGFloat = 16
	@ScaledMetric private var chartContainerCornerRadius: CGFloat = 12
	@ScaledMetric private var heatmapCellHeight: CGFloat = 20
	@ScaledMetric private var heatmapCellCornerRadius: CGFloat = 3
	@ScaledMetric private var heatmapCellBorderWidth: CGFloat = 0.5
	@ScaledMetric private var legendSquareCornerRadius: CGFloat = 2
	@ScaledMetric private var legendSquareSize: CGFloat = 12
	@ScaledMetric private var chartLineWidth: CGFloat = 2
	@ScaledMetric private var chartSymbolSize: CGFloat = 30
	@ScaledMetric private var clinicalCardPadding: CGFloat = 18
	@ScaledMetric private var insightBadgePaddingH: CGFloat = 10
	@ScaledMetric private var insightBadgePaddingV: CGFloat = 6

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					if let med = viewModel.selectedMedication {
						switch visualizationType {
						case .chart:
							usageChart(for: med)
						case .heatmap:
							calendarHeatmap(for: med)
						}

						controlsSection
						summaryCard(for: med)
						metricsView(for: med)
					} else {
						controlsSection
						Text(viewModel.medications.isEmpty ? "Add a medication in the Medication tab to see its recorded doses and trends." : "Select a medication above to see its trends.")
							.font(.customFont(fontFamily, style: .body))
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}

					if viewModel.selectedMedication != nil,
					   viewModel.dailyTotals(last: daysWindow).contains(where: { $0.total > 0 }) {
						SupportSuggestionView()
							.padding(.bottom, chartContainerPadding)
					}
				}
				.padding(.horizontal)
				.padding(.vertical)
			}
			.customNavigationTitle("Trends", displayMode: .large)
			.onAppear {
				viewModel.ensureValidSelection()
			}
		}
	}

	private var controlsSection: some View {
		VStack(alignment: .leading, spacing: controlsSpacing) {
			Text("Showing complete days through yesterday. Today’s doses appear after the day is complete.")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			let controlsLayout = dynamicTypeSize.isAccessibilitySize
				? AnyLayout(VStackLayout(alignment: .leading, spacing: controlsSpacing))
				: AnyLayout(HStackLayout(alignment: .center, spacing: controlsSpacing))
			controlsLayout {
				Menu {
					ForEach(viewModel.medications, id: \.id) { med in
						Button {
							viewModel.selectedMedicationID = med.id
						} label: {
							Text(med.displayName)
								.font(.customFont(fontFamily, style: .body))
						}
					}
				} label: {
					HStack {
						Text(viewModel.selectedMedication?.displayName ?? "Select Medication")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
							.noTruncate()

						Image(systemSymbol: .chevronUpChevronDown)
							.font(.customFont(fontFamily, style: .caption2))
							.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.frame(minHeight: 44)
				}
				.accessibilityLabel("Medication")
				.accessibilityValue(viewModel.selectedMedication?.displayName ?? "Not selected")

				Picker("Range", selection: $daysWindow) {
					Text("14 Days")
						.font(.customFont(fontFamily, style: .body))
						.tag(14)
					Text("30 Days")
						.font(.customFont(fontFamily, style: .body))
						.tag(30)
					Text("90 Days")
						.font(.customFont(fontFamily, style: .body))
						.tag(90)
				}
				.font(.customFont(fontFamily, style: .body))
				.pickerStyle(.menu)
				.tint(.accent)
				.frame(minHeight: 44)
			}

			if dynamicTypeSize.isAccessibilitySize {
				visualizationPicker
					.pickerStyle(.menu)
			} else {
				visualizationPicker
					.pickerStyle(.segmented)
			}
		}
		.padding(clinicalCardPadding)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous))
	}

	private var visualizationPicker: some View {
		Picker("View", selection: $visualizationType) {
			ForEach(VisualizationType.allCases, id: \.self) { type in
				Text(type.displayName)
					.font(.customFont(fontFamily, style: .body))
					.tag(type)
			}
		}
		.font(.customFont(fontFamily, style: .body))
		.tint(.accent)
		.frame(minHeight: 44)
	}

	@ViewBuilder
	private func summaryCard(for med: ANMedicationConcept) -> some View {
		VStack(alignment: .leading, spacing: controlsSpacing) {
			VStack(alignment: .leading, spacing: controlsSpacing) {
				VStack(alignment: .leading, spacing: metricTitleSpacing) {
					Text(med.displayName)
						.font(.customFont(fontFamily, style: .title3, weight: .semibold))
						.foregroundStyle(.primary)
						.noTruncate()

					Text(viewModel.patternSummary)
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}


				TimelineView(.periodic(from: .now, by: 1)) { context in
					let availability = viewModel.doseAvailability(at: context.date)
					if let nextDate = availability.eligibleDate {
						if nextDate > context.date {
							insightBadge(text: "Next saved window \(nextDate.formatted(date: .abbreviated, time: .shortened))", tint: .orange)
						} else {
							insightBadge(text: "Saved limits met", tint: med.displayColor)
						}
					} else {
						insightBadge(text: availability.message, tint: .secondary)
					}
				}
			}

			if let refillProjection = viewModel.refillProjection {
				HStack(alignment: .top, spacing: controlsSpacing) {
					Image(systemSymbol: refillProjection.urgent ? .exclamationmarkTriangleFill : .shippingboxFill)
						.foregroundStyle(refillProjection.urgent ? .orange : med.displayColor)
						.accessibilityHidden(true)
					Text(refillProjection.statusMessage)
						.font(.customFont(fontFamily, style: .caption))
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
		.padding(clinicalCardPadding)
		.background(
			LinearGradient(
				colors: [med.displayColor.opacity(0.12), med.displayColor.opacity(0.04)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			),
			in: RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous)
		)
		.overlay(
			RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous)
				.strokeBorder(med.displayColor.opacity(0.12), lineWidth: 1)
		)
		.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private func metricsView(for med: ANMedicationConcept) -> some View {
		let unitAbbrev = viewModel.preferredUnit?.abbreviation
		let qtyText: String = {
			guard let qty = med.quantity, let unit = unitAbbrev else { return "—" }
			return "\(qty.formattedAmount) \(unit) left"
		}()
		let refillText: String = {
			guard let days = viewModel.daysUntilRefill else { return "—" }
			if days == 0 { return "Refill today" }
			return days > 0 ? "Refill in \(days) days" : "Refill \(-days) days ago"
		}()
		let avg7 = viewModel.averagePerDay(window: 7)
		let avgText: String = {
			guard avg7 > 0, let unit = unitAbbrev else { return "—" }
			return "\(avg7.formattedAmount) \(unit)/day"
		}()
		let etaText: String = {
			guard let days = viewModel.estimatedDaysRemaining else { return "—" }
			return "About \(days) days left"
		}()

		// Usage progress text (optional - only if initialQuantity is available)
		let usageText: String = viewModel.usageProgressText ?? "—"

		// Refill cycle status (optional)
		let cycleStatusText: String = viewModel.refillCycleStatusText

		VStack(alignment: .leading, spacing: controlsSpacing) {
			Text("Overview")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))

			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: controlsSpacing), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: controlsSpacing) {
				metricCard(title: "Daily Average (7 Days)", value: avgText, systemImage: .chartLineUptrendXyaxis)
				metricCard(title: "Quantity", value: qtyText, systemImage: .pill)

				if viewModel.usagePercentage != nil {
					metricCard(title: "Usage", value: usageText, systemImage: .chartPieFill)
						.accessibilityLabel("Medication usage progress: \(usageText)")
				}

				metricCard(title: "Until Refill", value: refillText, systemImage: .calendar)
				metricCard(title: "Estimated Supply", value: etaText, systemImage: .hourglass)

				if viewModel.refillCycleStatus != .unknown {
					metricCard(title: "Refill Status", value: cycleStatusText, systemImage: .arrowTrianglehead2ClockwiseRotate90)
						.accessibilityLabel("Refill cycle status: \(cycleStatusText)")
				}
			}
		}
	}

	private func metricCard(title: String, value: String, systemImage: SFSymbol) -> some View {
		VStack(alignment: .leading, spacing: metricTitleSpacing) {
			HStack(spacing: metricLabelSpacing) {
				Image(systemSymbol: systemImage)
					.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
				Text(title)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
			}
			Text(value)
				.font(.customFont(fontFamily, style: .headline))
				.noTruncate()
		}
		.padding(metricCardPadding)
		.frame(maxWidth: .infinity, minHeight: metricCardMinHeight, alignment: .leading)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: metricCardCornerRadius, style: .continuous))
		.accessibilityElement(children: .combine)
		.accessibilityLabel("\(title): \(value)")
	}

	private func insightBadge(text: String, tint: Color) -> some View {
		Text(text)
			.font(.customFont(fontFamily, style: .caption, weight: .medium))
			.foregroundStyle(tint)
			.noTruncate()
			.padding(.horizontal, insightBadgePaddingH)
			.padding(.vertical, insightBadgePaddingV)
			.background(
				RoundedRectangle(cornerRadius: metricCardCornerRadius, style: .continuous)
					.fill(tint.opacity(0.12))
			)
	}

	private var chartAxisStrideDays: Int {
		switch daysWindow {
		case ...7: return 2
		case ...14: return 3
		case ...30: return 5
		default: return 15
		}
	}

	private func visualizationHeader(_ title: String, medication: ANMedicationConcept) -> some View {
		VStack(alignment: .leading, spacing: metricTitleSpacing) {
			Text(medication.displayName)
				.font(.customFont(fontFamily, style: .title3, weight: .semibold))
				.noTruncate()
			Text("\(title) · \(daysWindow) days through \(viewModel.trendsWindowEnd.formatted(date: .abbreviated, time: .omitted))")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	@ViewBuilder
	private func usageChart(for med: ANMedicationConcept) -> some View {
		let data = viewModel.dailyTotals(last: daysWindow)
		if data.isEmpty {
			Text("No doses recorded in this range. Choose another range or open History to review your entries.")
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			VStack(alignment: .leading, spacing: controlsSpacing) {
				visualizationHeader("Daily Usage", medication: med)

				Chart(data, id: \.day) { item in
					// Area mark for visual appeal
					AreaMark(
						x: .value("Day", item.day, unit: .day),
						y: .value("Total", item.total)
					)
					.foregroundStyle(.linearGradient(
						colors: [med.displayColor.opacity(0.4), med.displayColor.opacity(0.1), .clear],
						startPoint: .top,
						endPoint: .bottom
					))

					// Line mark for clarity
					LineMark(
						x: .value("Day", item.day, unit: .day),
						y: .value("Total", item.total)
					)
					.interpolationMethod(.linear)
					.foregroundStyle(med.displayColor)
					.lineStyle(StrokeStyle(lineWidth: chartLineWidth))

					// Point marks for data points
					if item.total > 0 {
						PointMark(
							x: .value("Day", item.day, unit: .day),
							y: .value("Total", item.total)
						)
						.foregroundStyle(med.displayColor)
						.symbolSize(chartSymbolSize)
					}
				}
				.chartXAxis {
					AxisMarks(values: .stride(by: .day, count: chartAxisStrideDays)) { _ in
						AxisGridLine()
							.foregroundStyle(.secondary.opacity(0.3))
						AxisValueLabel(format: daysWindow <= 7 ? .dateTime.weekday(.abbreviated) : daysWindow <= 14 ? .dateTime.weekday(.abbreviated).day() : .dateTime.day().month(.abbreviated))
							.foregroundStyle(.secondary)
					}
				}
				.chartYAxis {
					AxisMarks(position: .leading) { _ in
						AxisGridLine()
							.foregroundStyle(.secondary.opacity(0.2))
						AxisValueLabel()
							.foregroundStyle(.secondary)
					}
				}
				.chartBackground { _ in
					Rectangle()
						.fill(.clear)
				}
				.frame(height: chartHeight)
				.padding(.horizontal, chartPaddingH)
				.accessibilityLabel("Daily usage chart for \(med.displayName)")
				.accessibilityHint("Tap to open history for this medication")
				.onTapGesture {
					// Navigate to history with the selected medication
					if let medicationID = viewModel.selectedMedicationID {
						navigationManager.navigateToHistory(medicationID: medicationID.uuidString)
					}
				}
				Button {
					if let medicationID = viewModel.selectedMedicationID {
						navigationManager.navigateToHistory(medicationID: medicationID.uuidString)
					}
				} label: {
					Label("View History", systemSymbol: .clock)
						.font(.customFont(fontFamily, style: .body))
						.frame(minHeight: 44)
				}
				.accessibilityLabel("View history for \(med.displayName)")
			}
			.padding(chartContainerPadding)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius))
		}
	}

	@ViewBuilder
	private func calendarHeatmap(for med: ANMedicationConcept) -> some View {
		let data = viewModel.calendarHeatmapData(last: daysWindow)
		if data.isEmpty {
			Text("No doses recorded in this range. Choose another range or open History to review your entries.")
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			VStack(alignment: .leading, spacing: controlsSpacing) {
				visualizationHeader("Usage Calendar", medication: med)

				CalendarHeatmapGrid(
					data: data,
					daysWindow: daysWindow,
					medicationColor: med.displayColor,
					medicationName: med.displayName,
					onDateTapped: { date in
						// Navigate to history with selected date and medication
						if let medicationID = viewModel.selectedMedicationID {
							navigationManager.navigateToHistory(date: date, medicationID: medicationID.uuidString)
						}
					}
				)
			}
			.padding(chartContainerPadding)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius))
		}
	}
}

struct CalendarHeatmapGrid: View {
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	let data: [CalendarDay]
	let daysWindow: Int
	let medicationColor: Color
	let medicationName: String
	let onDateTapped: (Date) -> Void
	private let calendar = Calendar.current

	@ScaledMetric private var heatmapSpacing: CGFloat = 8
	@ScaledMetric private var heatmapCellSpacing: CGFloat = 2
	@ScaledMetric private var heatmapCellHeight: CGFloat = 20
	@ScaledMetric private var heatmapCellCornerRadius: CGFloat = 3
	@ScaledMetric private var heatmapCellBorderWidth: CGFloat = 0.5
	@ScaledMetric private var legendSquareCornerRadius: CGFloat = 2
	@ScaledMetric private var legendSquareSize: CGFloat = 12

	// Calculate grid layout
	private var columns: Int { 7 } // Days of week
	private var rows: Int {
		let weeks = ceil(Double(daysWindow) / 7.0)
		return Int(weeks)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: heatmapSpacing) {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(spacing: heatmapSpacing) {
					ForEach(data, id: \.date) { day in
						Button {
							onDateTapped(day.date)
						} label: {
							VStack(alignment: .leading, spacing: heatmapCellSpacing) {
								Text(day.date.formatted(date: .abbreviated, time: .omitted))
									.font(.customFont(fontFamily, style: .body, weight: .medium))
								Text(day.total > 0 ? "\(day.total.formattedAmount) logged" : "No doses logged")
									.font(.customFont(fontFamily, style: .subheadline))
									.foregroundStyle(.secondary)
							}
							.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
							.padding(heatmapSpacing)
							.background(.regularMaterial, in: RoundedRectangle(cornerRadius: heatmapCellCornerRadius))
						}
						.buttonStyle(.plain)
						.accessibilityLabel(accessibilityLabel(for: day))
						.accessibilityHint("Open history for this date")
					}
				}
			} else {
				ScrollView(.horizontal) {
					VStack(spacing: heatmapCellSpacing) {
						HStack(spacing: heatmapCellSpacing) {
							ForEach(0 ..< 7, id: \.self) { index in
								Text(calendar.veryShortWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
									.font(.customFont(fontFamily, style: .caption2))
									.foregroundStyle(.secondary)
									.frame(maxWidth: .infinity, minHeight: 44)
							}
						}
						.accessibilityHidden(true)

						LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: heatmapCellSpacing), count: 7), spacing: heatmapCellSpacing) {
							ForEach(paddedData, id: \.date) { day in
								if day.intensity >= 0 {
									Button {
										onDateTapped(day.date)
									} label: {
										Text("\(calendar.component(.day, from: day.date))")
											.font(.customFont(fontFamily, style: .caption))
											.foregroundStyle(.primary)
											.padding(4)
											.background(.regularMaterial, in: Circle())
											.frame(maxWidth: .infinity, minHeight: 44)
											.background(colorForIntensity(day.intensity), in: RoundedRectangle(cornerRadius: heatmapCellCornerRadius))
									}
									.buttonStyle(.plain)
									.accessibilityLabel(accessibilityLabel(for: day))
									.accessibilityHint("Open history for this date")
								} else {
									Color.clear.frame(height: 44)
										.accessibilityHidden(true)
								}
							}
						}
					}
					.frame(minWidth: 7 * 44 + 6 * heatmapCellSpacing)
				}
			}

			// Legend
			HStack {
				Text("Less")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)

				HStack(spacing: heatmapCellSpacing) {
					ForEach(0 ..< 5) { level in
						RoundedRectangle(cornerRadius: legendSquareCornerRadius)
							.fill(colorForIntensity(Double(level) / 4.0))
							.frame(width: legendSquareSize, height: legendSquareSize)
							.overlay(
								RoundedRectangle(cornerRadius: legendSquareCornerRadius)
									.stroke(.secondary.opacity(0.2), lineWidth: heatmapCellBorderWidth)
							)
					}
				}

				Text("More")
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)

				Spacer()
			}
		}
		.accessibilityElement(children: .contain)
	}

	// Pad data to fill grid properly
	private var paddedData: [CalendarDay] {
		guard let firstDate = data.first?.date else { return data }

		let firstWeekday = calendar.component(.weekday, from: firstDate)
		let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7

		var paddedData = data

		// Add leading empty days
		if leadingEmptyDays > 0 {
			for i in (1 ... leadingEmptyDays).reversed() {
				if let emptyDate = calendar.date(byAdding: .day, value: -i, to: firstDate) {
					paddedData.insert(CalendarDay(date: emptyDate, total: -1, intensity: -1), at: 0)
				}
			}
		}

		return paddedData
	}

	private func colorForIntensity(_ intensity: Double) -> Color {
		if intensity < 0 {
			// Empty/placeholder days
			return .clear
		} else if intensity == 0 {
			// No usage days
			return medicationColor.opacity(0.1)
		} else {
			// Usage days with intensity scaling
			return medicationColor.opacity(0.2 + (intensity * 0.8))
		}
	}

	private func accessibilityLabel(for day: CalendarDay) -> String {
		let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
		guard day.intensity >= 0 else {
			return "Empty calendar cell"
		}

		if day.total > 0 {
			return "\(dateText), \(medicationName), \(day.total.formattedAmount) logged"
		}

		return "\(dateText), \(medicationName), no doses logged"
	}
}

#if DEBUG
	#Preview {
		MedicationTrendsView()
	}
#endif
