import SwiftUI
import Charts
import ANModelKit

struct MedicationTrendsView: View {
    @StateObject private var viewModel = MedicationTrendsViewModel()
    @State private var daysWindow: Int = 14

    var body: some View {
        NavigationStack {
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
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Trends")
            .onAppear { if viewModel.selectedMedicationID == nil { viewModel.selectedMedicationID = viewModel.medications.first?.id } }
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
            metricCard(title: "Avg (7d)", value: avgText, systemImage: "chart.line.uptrend.xyaxis")
            metricCard(title: "Quantity", value: qtyText, systemImage: "pill")
            metricCard(title: "Until Refill", value: refillText, systemImage: "calendar")
            metricCard(title: "Run-out ETA", value: etaText, systemImage: "hourglass")
        }
    }

    private func metricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
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
            Chart(data, id: \.day) { item in
                LineMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Total", item.total)
                )
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 240)
        }
    }
}

#if DEBUG
#Preview {
    MedicationTrendsView()
}
#endif
