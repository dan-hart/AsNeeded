import SwiftUI
import Charts
import ANModelKit
import SFSafeSymbols

enum VisualizationType: String, CaseIterable {
	case chart = "chart"
	case heatmap = "heatmap"
	
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

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					// Picker + context
					VStack(spacing: controlsSpacing) {
						HStack(alignment: .center) {
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
									Text(viewModel.selectedMedication?.displayName ?? "Select")
										.font(.customFont(fontFamily, style: .body))
										.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
									Image(systemSymbol: .chevronUpChevronDown)
										.font(.customFont(fontFamily, style: .caption2))
										.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
								}
							}
							Spacer()
							Picker("Range", selection: $daysWindow) {
								Text("14d")
									.font(.customFont(fontFamily, style: .body))
									.tag(14)
								Text("30d")
									.font(.customFont(fontFamily, style: .body))
									.tag(30)
							}
							.font(.customFont(fontFamily, style: .body))
							.pickerStyle(.segmented)
							.accentColor(viewModel.selectedMedication?.displayColor ?? .accent)
							.frame(maxWidth: pickerMaxWidth)
						}

						HStack {
							Text("View:")
								.font(.customFont(fontFamily, style: .subheadline))
								.foregroundStyle(.secondary)
							Picker("Visualization", selection: $visualizationType) {
								ForEach(VisualizationType.allCases, id: \.self) { type in
									Label {
										Text(type.displayName)
											.font(.customFont(fontFamily, style: .body))
									} icon: {
										Image(systemName: type.systemImage)
									}
									.tag(type)
								}
							}
							.font(.customFont(fontFamily, style: .body))
							.pickerStyle(.segmented)
							.accentColor(viewModel.selectedMedication?.displayColor ?? .accent)
							Spacer()
						}
					}

					if let med = viewModel.selectedMedication {
						metricsView(for: med)
						
						switch visualizationType {
						case .chart:
							usageChart(for: med)
						case .heatmap:
							calendarHeatmap(for: med)
						}
					} else {
						Text("Select a medication to see trends.")
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					
					// Support link at bottom
					VStack(spacing: sectionSpacing) {
						Divider()
							.padding(.top, chartContainerPadding)

						SupportSuggestionView()
					}
					.padding(.bottom, chartContainerPadding)
				}
				.padding(.horizontal)
				.padding(.vertical)
			}
			.navigationTitle("Trends")
			.onAppear {
				// Ensure we have a valid medication selected
				viewModel.ensureValidSelection()
			}
		}
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
			return days > 0 ? "Refill in \(days)d" : "Refill \(-days)d ago"
		}()
		let avg7 = viewModel.averagePerDay(window: 7)
		let avgText: String = {
			guard avg7 > 0, let unit = unitAbbrev else { return "—" }
			return "\(avg7.formattedAmount) \(unit)/day"
		}()
		let etaText: String = {
			guard let days = viewModel.estimatedDaysRemaining else { return "—" }
			return "~\(days)d remaining"
		}()

		// Usage progress text (optional - only if initialQuantity is available)
		let usageText: String = viewModel.usageProgressText ?? "—"

		// Refill cycle status (optional)
		let cycleStatusText: String = viewModel.refillCycleStatusText

		LazyVGrid(columns: [GridItem(.flexible(), spacing: controlsSpacing), GridItem(.flexible(), spacing: controlsSpacing)], spacing: controlsSpacing) {
			metricCard(title: "Avg (7d)", value: avgText, systemImage: .chartLineUptrendXyaxis)
			metricCard(title: "Quantity", value: qtyText, systemImage: .pill)

			// Show usage progress card ONLY if initialQuantity is available
			if viewModel.usagePercentage != nil {
				metricCard(title: "Usage", value: usageText, systemImage: .chartPieFill)
					.accessibilityLabel("Medication usage progress: \(usageText)")
			}

			metricCard(title: "Until Refill", value: refillText, systemImage: .calendar)
			metricCard(title: "Run-out ETA", value: etaText, systemImage: .hourglass)

			// Show refill status card ONLY if we have the needed data
			if viewModel.refillCycleStatus != .unknown {
				metricCard(title: "Refill Status", value: cycleStatusText, systemImage: .arrowTrianglehead2ClockwiseRotate90)
					.accessibilityLabel("Refill cycle status: \(cycleStatusText)")
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
		}
		.padding(metricCardPadding)
		.frame(maxWidth: .infinity, minHeight: metricCardMinHeight, alignment: .leading)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: metricCardCornerRadius, style: .continuous))
	}

	@ViewBuilder
	private func usageChart(for med: ANMedicationConcept) -> some View {
		let data = viewModel.dailyTotals(last: daysWindow)
		if data.isEmpty {
			Text("No recent dose data.")
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			VStack(alignment: .leading, spacing: controlsSpacing) {
				Text("Daily Usage")
					.font(.headline)
					.fontWeight(.semibold)

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
					.interpolationMethod(.catmullRom)
					.foregroundStyle(med.displayColor)
					.lineStyle(StrokeStyle(lineWidth: chartLineWidth))

					// Point marks for data points
					if item.total > 0 {
						PointMark(
							x: .value("Day", item.day, unit: .day),
							y: .value("Total", item.total)
						)
						.foregroundStyle(med.displayColor)
						.chartSymbolSize(chartSymbolSize)
					}
				}
				.chartXAxis {
					AxisMarks(values: .stride(by: .day, count: daysWindow <= 7 ? 2 : daysWindow <= 14 ? 3 : 5)) { value in
						AxisGridLine()
							.foregroundStyle(.secondary.opacity(0.3))
						AxisValueLabel(format: daysWindow <= 7 ? .dateTime.weekday(.abbreviated) : daysWindow <= 14 ? .dateTime.weekday(.abbreviated).day() : .dateTime.day().month(.abbreviated))
							.foregroundStyle(.secondary)
					}
				}
				.chartYAxis {
					AxisMarks(position: .leading) { value in
						AxisGridLine()
							.foregroundStyle(.secondary.opacity(0.2))
						AxisValueLabel()
							.foregroundStyle(.secondary)
					}
				}
				.chartBackground { chartProxy in
					Rectangle()
						.fill(.clear)
				}
				.frame(height: chartHeight)
				.padding(.horizontal, chartPaddingH)
				.onTapGesture {
					// Navigate to history with the selected medication
					if let medicationID = viewModel.selectedMedicationID {
						navigationManager.navigateToHistory(medicationID: medicationID.uuidString)
					}
				}
			}
			.padding(chartContainerPadding)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius))
		}
	}
	
	@ViewBuilder
	private func calendarHeatmap(for med: ANMedicationConcept) -> some View {
		let data = viewModel.calendarHeatmapData(last: daysWindow)
		if data.isEmpty {
			Text("No recent dose data.")
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			VStack(alignment: .leading, spacing: controlsSpacing) {
				Text("Usage Calendar")
					.font(.headline)
					.fontWeight(.semibold)

				CalendarHeatmapGrid(
					data: data,
					daysWindow: daysWindow,
					medicationColor: med.displayColor,
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
	let data: [CalendarDay]
	let daysWindow: Int
	let medicationColor: Color
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
			// Weekday headers
			HStack(spacing: heatmapCellSpacing) {
				ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
					Text(day)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity)
						.frame(height: heatmapCellHeight)
				}
			}

			// Calendar grid
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: heatmapCellSpacing), count: 7), spacing: heatmapCellSpacing) {
				ForEach(paddedData, id: \.date) { day in
					RoundedRectangle(cornerRadius: heatmapCellCornerRadius)
						.fill(colorForIntensity(day.intensity))
						.frame(height: heatmapCellHeight)
						.overlay(
							RoundedRectangle(cornerRadius: heatmapCellCornerRadius)
								.stroke(.secondary.opacity(0.2), lineWidth: heatmapCellBorderWidth)
						)
						.onTapGesture {
							// Only navigate for actual dates, not padding
							if day.intensity >= 0 {
								onDateTapped(day.date)
							}
						}
						.help(day.total > 0 ?
							  "\(calendar.component(.day, from: day.date)): \(day.total.formattedAmount)" :
							  "\(calendar.component(.day, from: day.date)): No doses")
				}
			}

			// Legend
			HStack {
				Text("Less")
					.font(.caption)
					.foregroundStyle(.secondary)

				HStack(spacing: heatmapCellSpacing) {
					ForEach(0..<5) { level in
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
					.font(.caption)
					.foregroundStyle(.secondary)

				Spacer()
			}
		}
	}
	
	// Pad data to fill grid properly
	private var paddedData: [CalendarDay] {
		guard let firstDate = data.first?.date else { return data }
		
		let firstWeekday = calendar.component(.weekday, from: firstDate)
		let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
		
		var paddedData = data
		
		// Add leading empty days
		if leadingEmptyDays > 0 {
			for i in (1...leadingEmptyDays).reversed() {
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
}

#if DEBUG
#Preview {
	MedicationTrendsView()
}
#endif
