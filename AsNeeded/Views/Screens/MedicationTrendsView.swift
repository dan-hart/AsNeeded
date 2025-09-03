import SwiftUI
import Charts
import ANModelKit
import SFSafeSymbols

struct MedicationTrendsView: View {
	@StateObject private var viewModel = MedicationTrendsViewModel()
	@State private var daysWindow: Int = 14

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					// Picker + context
					HStack(alignment: .center) {
						Picker("Medication", selection: $viewModel.selectedMedicationID) {
							ForEach(viewModel.medications, id: \.id) { med in
								Text(med.displayName).tag(Optional(med.id))
							}
						}
						.pickerStyle(.menu)
						Spacer()
						Picker("Range", selection: $daysWindow) {
							Text("14d").tag(14)
							Text("30d").tag(30)
						}
						.pickerStyle(.segmented)
						.frame(maxWidth: 160)
					}

					if let med = viewModel.selectedMedication {
						metricsView(for: med)
						usageChart()
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
				.padding()
			}
			.navigationTitle("Trends")
			.onAppear { 
				// If no medication is selected or the selected medication no longer exists
				if viewModel.selectedMedicationID == nil || viewModel.selectedMedication == nil {
					viewModel.selectedMedicationID = viewModel.medications.first?.id
				}
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
					.foregroundStyle(.accent)
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
	private func usageChart() -> some View {
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
						colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.1), .clear],
						startPoint: .top,
						endPoint: .bottom
					))
					
					// Line mark for clarity
					LineMark(
						x: .value("Day", item.day, unit: .day),
						y: .value("Total", item.total)
					)
					.interpolationMethod(.catmullRom)
					.foregroundStyle(Color.accentColor)
					.lineStyle(StrokeStyle(lineWidth: 2))
					
					// Point marks for data points
					if item.total > 0 {
						PointMark(
							x: .value("Day", item.day, unit: .day),
							y: .value("Total", item.total)
						)
						.foregroundStyle(Color.accentColor)
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
			}
			.padding(16)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
		}
	}
}

#if DEBUG
#Preview {
	MedicationTrendsView()
}
#endif
