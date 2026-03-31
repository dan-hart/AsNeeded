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
    @AppStorage(UserDefaultsKeys.trendsDaysWindow) private var daysWindow: Int = 14
    @AppStorage(UserDefaultsKeys.trendsVisualizationType) private var visualizationType: VisualizationType = .chart
    @State private var questionText = ""
    @State private var showingDisclaimer = false

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
    @ScaledMetric private var questionPromptSpacing: CGFloat = 8
    @ScaledMetric private var clinicalCardPadding: CGFloat = 18
    @ScaledMetric private var promptButtonPaddingH: CGFloat = 10
    @ScaledMetric private var promptButtonPaddingV: CGFloat = 8
    @ScaledMetric private var insightBadgePaddingH: CGFloat = 10
    @ScaledMetric private var insightBadgePaddingV: CGFloat = 6
    @ScaledMetric private var buttonVerticalPadding: CGFloat = 14
    @ScaledMetric private var buttonCornerRadius: CGFloat = 14
    @ScaledMetric private var smallSpacing: CGFloat = 4
    @ScaledMetric private var mediumSpacing: CGFloat = 8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    controlsSection

                    if let med = viewModel.selectedMedication {
                        summaryCard(for: med)

                        metricsView(for: med)

                        switch visualizationType {
                        case .chart:
                            usageChart(for: med)
                        case .heatmap:
                            calendarHeatmap(for: med)
                        }

                        questionsSection(for: med)
                    } else {
                        Text("Select a medication to see trends.")
                            .font(.customFont(fontFamily, style: .body))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SupportSuggestionView()
                        .padding(.bottom, chartContainerPadding)
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .customNavigationTitle("Trends")
            .onAppear {
                viewModel.ensureValidSelection()
            }
            .sheet(isPresented: $showingDisclaimer) {
                NavigationStack {
                    MedicalDisclaimerDetailView()
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: controlsSpacing) {
            Text("Review recent timing, refill pressure, and changes in your logging pattern.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: controlsSpacing) {
                Menu {
                    ForEach(viewModel.medications, id: \.id) { med in
                        Button {
                            viewModel.selectedMedicationID = med.id
                            viewModel.latestQuestionAnswer = nil
                            viewModel.questionErrorMessage = nil
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
                }

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
                .tint(viewModel.selectedMedication?.displayColor ?? .accent)
                .frame(maxWidth: pickerMaxWidth)
            }

            Picker("Visualization", selection: $visualizationType) {
                ForEach(VisualizationType.allCases, id: \.self) { type in
                    Text(type.displayName)
                        .font(.customFont(fontFamily, style: .body))
                        .tag(type)
                }
            }
            .font(.customFont(fontFamily, style: .body))
            .pickerStyle(.segmented)
            .tint(viewModel.selectedMedication?.displayColor ?? .accent)
        }
        .padding(clinicalCardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func summaryCard(for med: ANMedicationConcept) -> some View {
        VStack(alignment: .leading, spacing: controlsSpacing) {
            HStack(alignment: .top) {
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

                Spacer()

                if let nextEligibleDoseDate = viewModel.nextEligibleDoseDate, nextEligibleDoseDate > Date() {
                    insightBadge(
                        text: "Next window \(nextEligibleDoseDate.formatted(date: .omitted, time: .shortened))",
                        tint: .orange
                    )
                } else {
                    insightBadge(text: "Available now", tint: med.displayColor)
                }
            }

            if let refillProjection = viewModel.refillProjection {
                HStack(alignment: .top, spacing: controlsSpacing) {
                    Image(systemSymbol: refillProjection.urgent ? .exclamationmarkTriangleFill : .shippingboxFill)
                        .foregroundStyle(refillProjection.urgent ? .orange : med.displayColor)
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

        VStack(alignment: .leading, spacing: controlsSpacing) {
            Text("Overview")
                .font(.customFont(fontFamily, style: .headline, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: controlsSpacing), GridItem(.flexible(), spacing: controlsSpacing)], spacing: controlsSpacing) {
                metricCard(title: "Avg (7d)", value: avgText, systemImage: .chartLineUptrendXyaxis)
                metricCard(title: "Quantity", value: qtyText, systemImage: .pill)

                if viewModel.usagePercentage != nil {
                    metricCard(title: "Usage", value: usageText, systemImage: .chartPieFill)
                        .accessibilityLabel("Medication usage progress: \(usageText)")
                }

                metricCard(title: "Until Refill", value: refillText, systemImage: .calendar)
                metricCard(title: "Run-out ETA", value: etaText, systemImage: .hourglass)

                if viewModel.refillCycleStatus != .unknown {
                    metricCard(title: "Refill Status", value: cycleStatusText, systemImage: .arrowTrianglehead2ClockwiseRotate90)
                        .accessibilityLabel("Refill cycle status: \(cycleStatusText)")
                }
            }
        }
    }

    @ViewBuilder
    private func questionsSection(for med: ANMedicationConcept) -> some View {
        switch viewModel.questionAvailability {
        case .unavailable:
            EmptyView()
        case .disabled:
            VStack(alignment: .leading, spacing: controlsSpacing) {
                HStack {
                    Text("Private Questions")
                        .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    Spacer()
                    insightBadge(text: "Opt in", tint: med.displayColor)
                }

                Text("Turn this on in App Preferences to ask private questions about your trends. Questions stay on this device, and this medication data never leaves the device for processing.")
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink(destination: AppPreferencesView()) {
                    Label("Open App Preferences", systemSymbol: .gearshapeFill)
                        .font(.customFont(fontFamily, style: .body, weight: .medium))
                        .foregroundStyle(.accent)
                }

                disclaimerFooter
            }
            .padding(clinicalCardPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous))
        case .available:
            VStack(alignment: .leading, spacing: controlsSpacing) {
                HStack {
                    Text("Private Questions")
                        .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                    Spacer()
                    insightBadge(text: "On device", tint: med.displayColor)
                }

                Text("Ask about your logged history in plain language. Questions stay on this device, and your medication data never leaves the device for this feature.")
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Ask about timing, consistency, or changes in this medication's pattern", text: $questionText, axis: .vertical)
                    .font(.customFont(fontFamily, style: .body))
                    .lineLimit(2 ... 4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        let prompt = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !prompt.isEmpty else { return }
                        await viewModel.ask(question: prompt, windowDays: daysWindow)
                    }
                } label: {
                    HStack {
                        if viewModel.isAnsweringQuestion {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemSymbol: .bubbleLeftAndBubbleRightFill)
                        }
                        Text(viewModel.isAnsweringQuestion ? "Reviewing your history..." : "Ask About This Data")
                            .font(.customFont(fontFamily, style: .body, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, buttonVerticalPadding)
                    .background(med.displayColor, in: RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
                }
                .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnsweringQuestion)

                if !viewModel.examplePrompts.isEmpty {
                    VStack(alignment: .leading, spacing: questionPromptSpacing) {
                        Text("Try a prompt")
                            .font(.customFont(fontFamily, style: .caption, weight: .medium))
                            .foregroundStyle(.secondary)

                        ForEach(viewModel.examplePrompts, id: \.self) { prompt in
                            Button {
                                questionText = prompt
                                Task {
                                    await viewModel.ask(question: prompt, windowDays: daysWindow)
                                }
                            } label: {
                                HStack(alignment: .top, spacing: mediumSpacing) {
                                    Image(systemSymbol: .sparkles)
                                        .foregroundStyle(med.displayColor)
                                        .padding(.top, smallSpacing)

                                    Text(prompt)
                                        .font(.customFont(fontFamily, style: .subheadline))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                                .padding(.horizontal, promptButtonPaddingH)
                                .padding(.vertical, promptButtonPaddingV)
                                .background(
                                    RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous)
                                        .fill(Color(.tertiarySystemFill))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let errorMessage = viewModel.questionErrorMessage {
                    Text(errorMessage)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let answer = viewModel.latestQuestionAnswer {
                    VStack(alignment: .leading, spacing: controlsSpacing) {
                        Text(answer.answer)
                            .font(.customFont(fontFamily, style: .body))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !answer.highlights.isEmpty {
                            VStack(alignment: .leading, spacing: smallSpacing) {
                                Text("What stands out")
                                    .font(.customFont(fontFamily, style: .caption, weight: .medium))
                                    .foregroundStyle(.secondary)

                                ForEach(answer.highlights, id: \.self) { highlight in
                                    HStack(alignment: .top, spacing: smallSpacing) {
                                        Image(systemSymbol: .circleFill)
                                            .font(.customFont(fontFamily, style: .caption2))
                                            .foregroundStyle(med.displayColor)
                                            .padding(.top, smallSpacing)
                                        Text(highlight)
                                            .font(.customFont(fontFamily, style: .caption))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        if !answer.limitations.isEmpty {
                            VStack(alignment: .leading, spacing: smallSpacing) {
                                Text("Limitations")
                                    .font(.customFont(fontFamily, style: .caption, weight: .medium))
                                    .foregroundStyle(.secondary)

                                ForEach(answer.limitations, id: \.self) { limitation in
                                    Text(limitation)
                                        .font(.customFont(fontFamily, style: .caption))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(clinicalCardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous)
                            .fill(med.displayColor.opacity(0.06))
                    )
                }

                disclaimerFooter
            }
            .padding(clinicalCardPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: chartContainerCornerRadius, style: .continuous))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: metricCardCornerRadius, style: .continuous))
    }

    private func insightBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.customFont(fontFamily, style: .caption, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, insightBadgePaddingH)
            .padding(.vertical, insightBadgePaddingV)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private var disclaimerFooter: some View {
        HStack(alignment: .top, spacing: mediumSpacing) {
            Image(systemSymbol: .exclamationmarkTriangleFill)
                .foregroundStyle(.orange)
                .padding(.top, smallSpacing)

            VStack(alignment: .leading, spacing: smallSpacing) {
                Text("Responses may be incorrect or incomplete. Review your history directly before making decisions.")
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingDisclaimer = true
                } label: {
                    Text("Medical Disclaimer")
                        .font(.customFont(fontFamily, style: .caption, weight: .medium))
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, smallSpacing)
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
                        .symbolSize(chartSymbolSize)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: daysWindow <= 7 ? 2 : daysWindow <= 14 ? 3 : 5)) { _ in
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
}

#if DEBUG
    #Preview {
        MedicationTrendsView()
    }
#endif
