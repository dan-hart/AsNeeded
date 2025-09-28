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
	@State private var daysWindow: Int = 14
	@AppStorage("trendsVisualizationType") private var visualizationType: VisualizationType = .chart

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					// Picker + context
					VStack(spacing: 12) {
						HStack(alignment: .center) {
							Picker("Medication", selection: $viewModel.selectedMedicationID) {
								ForEach(viewModel.medications, id: \.id) { med in
									Text(med.displayName).tag(Optional(med.id))
								}
							}
							.pickerStyle(.menu)
							.accentColor(viewModel.selectedMedication?.displayColor ?? .accent)
							Spacer()
							Picker("Range", selection: $daysWindow) {
								Text("14d").tag(14)
								Text("30d").tag(30)
							}
							.pickerStyle(.segmented)
							.accentColor(viewModel.selectedMedication?.displayColor ?? .accent)
							.frame(maxWidth: 160)
						}
						
						HStack {
							Text("View:")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Picker("Visualization", selection: $visualizationType) {
								ForEach(VisualizationType.allCases, id: \.self) { type in
									Label(type.displayName, systemImage: type.systemImage)
										.tag(type)
								}
							}
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
					VStack(spacing: 16) {
						Divider()
							.padding(.top, 16)
						
						SupportSuggestionView()
					}
					.padding(.bottom, 16)
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

		LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
			metricCard(title: "Avg (7d)", value: avgText, systemImage: .chartLineUptrendXyaxis)
			metricCard(title: "Quantity", value: qtyText, systemImage: .pill)
			metricCard(title: "Until Refill", value: refillText, systemImage: .calendar)
			metricCard(title: "Run-out ETA", value: etaText, systemImage: .hourglass)
		}
	}

	private func metricCard(title: String, value: String, systemImage: SFSymbol) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 6) {
				Image(systemSymbol: systemImage)
					.foregroundStyle(viewModel.selectedMedication?.displayColor ?? .accent)
				Text(title)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Text(value)
				.font(.headline)
		}
		.padding(12)
		.frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
	}

	@ViewBuilder
	private func usageChart(for med: ANMedicationConcept) -> some View {
		let data = viewModel.dailyTotals(last: daysWindow)
		if data.isEmpty {
			Text("No recent dose data.")
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			VStack(alignment: .leading, spacing: 12) {
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
					.lineStyle(StrokeStyle(lineWidth: 2))

					// Point marks for data points
					if item.total > 0 {
						PointMark(
							x: .value("Day", item.day, unit: .day),
							y: .value("Total", item.total)
						)
						.foregroundStyle(med.displayColor)
						.symbolSize(30)
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
				.frame(height: 280)
				.padding(.horizontal, 4)
				.onTapGesture {
					// Navigate to history with the selected medication
					if let medicationID = viewModel.selectedMedicationID {
						navigationManager.navigateToHistory(medicationID: medicationID.uuidString)
					}
				}
			}
			.padding(16)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
			VStack(alignment: .leading, spacing: 12) {
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
			.padding(16)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
		}
	}
}

struct CalendarHeatmapGrid: View {
	let data: [CalendarDay]
	let daysWindow: Int
	let medicationColor: Color
	let onDateTapped: (Date) -> Void
	private let calendar = Calendar.current
	
	// Calculate grid layout
	private var columns: Int { 7 } // Days of week
	private var rows: Int { 
		let weeks = ceil(Double(daysWindow) / 7.0)
		return Int(weeks)
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			// Weekday headers
			HStack(spacing: 2) {
				ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
					Text(day)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity)
						.frame(height: 20)
				}
			}
			
			// Calendar grid
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
				ForEach(paddedData, id: \.date) { day in
					RoundedRectangle(cornerRadius: 3)
						.fill(colorForIntensity(day.intensity))
						.frame(height: 20)
						.overlay(
							RoundedRectangle(cornerRadius: 3)
								.stroke(.secondary.opacity(0.2), lineWidth: 0.5)
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
				
				HStack(spacing: 2) {
					ForEach(0..<5) { level in
						RoundedRectangle(cornerRadius: 2)
							.fill(colorForIntensity(Double(level) / 4.0))
							.frame(width: 12, height: 12)
							.overlay(
								RoundedRectangle(cornerRadius: 2)
									.stroke(.secondary.opacity(0.2), lineWidth: 0.5)
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
