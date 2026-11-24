import ANModelKit
import SFSafeSymbols
import SwiftUI

struct HistoryDoseWarningView: View {
	struct Review {
		let warning: MedicationHistoryDoseWarningService.Warning
		let dose: MedicationHistoryDoseWarningService.Dose
		let medicationName: String?
		let rollingEntries: [MedicationHistoryDoseWarningService.Dose]

		var relatedEntries: [MedicationHistoryDoseWarningService.Dose] {
			var entries = rollingEntries
			if !entries.contains(where: { $0.id == dose.id }) { entries.append(dose) }
			if let previous = warning.spacing?.previous, !entries.contains(where: { $0.id == previous.id }) {
				entries.append(previous)
			}
			return entries.sorted(by: MedicationHistoryDoseWarningService.Dose.ordered)
		}
	}

	let review: Review?
	let onEdit: (UUID) -> Void

	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	static func warningTitles(for warning: MedicationHistoryDoseWarningService.Warning) -> [LocalizedStringKey] {
		var titles: [LocalizedStringKey] = []
		if warning.spacing != nil {
			titles.append("Doses logged close together")
		}
		if let single = warning.singleDose, single != .unavailable {
			titles.append("Per-dose limit exceeded")
		}
		if let rolling = warning.rolling, rolling != .unavailable {
			titles.append("24-hour limit exceeded")
		}
		return titles
	}

	var body: some View {
		NavigationStack {
			Group {
				if let review {
					reviewList(review)
				} else {
					ContentUnavailableView {
						Label("Dose warning no longer applies", systemSymbol: .infoCircle)
							.font(.customFont(fontFamily, style: .headline))
					}
				}
			}
			.customNavigationTitle("Review Dose", displayMode: .inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button { dismiss() } label: {
						Label("Close", systemSymbol: .xmark)
					}
					.keyboardShortcut(.cancelAction)
				}
			}
		}
		.tint(.accent)
	}

	private func reviewList(_ review: Review) -> some View {
		let entries = review.relatedEntries
		let lowerBound = SavedDoseLimits.windowStart(endingAt: review.dose.date)
		let timeZone = TimeZone.autoupdatingCurrent
		let reviewedOffset = timeZone.secondsFromGMT(for: review.dose.date)
		let showOffset = entries.contains { timeZone.secondsFromGMT(for: $0.date) != reviewedOffset } ||
			(review.warning.rolling != nil && timeZone.secondsFromGMT(for: lowerBound) != reviewedOffset)
		return List {
			VStack(alignment: .leading, spacing: 4) {
				if let name = review.medicationName {
					Text(name)
						.demoNameRedacted()
						.font(.customFont(fontFamily, style: .headline))
						.noTruncate()
						.accessibilityAddTraits(.isHeader)
				}
				Text("Compared with current dose limits.")
					.font(.customFont(fontFamily, style: .footnote))
					.foregroundStyle(.secondary)
			}
			.listRowBackground(Color.clear)

			if let spacing = review.warning.spacing {
				Section {
					let minimum = spacing.minimumHours * 3_600
					let gap = duration(spacing.elapsed)
					let limit = minimum.isFinite ? duration(minimum) : hours(spacing.minimumHours)
					reviewNote("The gap between these two logged doses is shorter than the saved wait time.")
					comparison("Time between doses", value: gap == limit ? preciseDuration(spacing.elapsed) : gap)
					comparison("Saved minimum", value: gap == limit ? preciseDuration(minimum) : limit)
				} header: {
					heading("Doses logged close together")
				}
			}

			if let single = review.warning.singleDose {
				Section {
					quantityFinding(single, maximum: review.warning.singleMaximum, unit: review.warning.unit, rolling: false)
				} header: {
					heading(single == .unavailable ? "Amount per dose" : "Per-dose limit exceeded")
				}
			}

			if let rolling = review.warning.rolling {
				Section {
					quantityFinding(rolling, maximum: review.warning.rollingMaximum, unit: review.warning.unit, rolling: true)
				} header: {
					heading(rolling == .unavailable ? "Amount in 24 hours" : "24-hour limit exceeded")
				} footer: {
					let start = timestamp(lowerBound, showOffset: showOffset)
					let end = timestamp(review.dose.date, showOffset: showOffset)
					Text("24-hour window after \(start) through \(end).")
						.font(.customFont(fontFamily, style: .footnote))
				}
			}

			Section {
				ForEach(entries) { entry in
					entryButton(entry, review: review, showOffset: showOffset)
				}
			} header: {
				heading("Related dose entries")
			}
		}
		.listStyle(.insetGrouped)
	}

	private func comparison(_ title: LocalizedStringKey, value: String) -> some View {
		ViewThatFits(in: .horizontal) {
			if !dynamicTypeSize.isAccessibilitySize {
				HStack(alignment: .firstTextBaseline, spacing: 12) {
					Text(title).fixedSize()
					Spacer(minLength: 0)
					Text(value).fontWeight(.semibold).fixedSize()
				}
			}
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
				Text(value).fontWeight(.semibold)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.fixedSize(horizontal: false, vertical: true)
		}
		.font(.customFont(fontFamily, style: .body))
		.accessibilityElement(children: .combine)
	}

	private func heading(_ title: LocalizedStringKey) -> some View {
		Text(title)
			.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
	}

	private func entryButton(_ entry: MedicationHistoryDoseWarningService.Dose, review: Review, showOffset: Bool) -> some View {
		let quantity = entry.amount.flatMap { displayAmount($0, unit: entry.unit) }
		// The preceding dose can be outside the rolling window when the saved interval exceeds 24 hours.
		let inWindow = entry.date > SavedDoseLimits.windowStart(endingAt: review.dose.date)
		let checksUnit = entry.id == review.dose.id && review.warning.singleDose != nil ||
			review.warning.rolling != nil && inWindow
		return Button { onEdit(entry.id) } label: {
			HStack(alignment: .center, spacing: 12) {
				VStack(alignment: .leading, spacing: 3) {
					if entry.id == review.dose.id {
						Text("Reviewed dose")
							.font(.customFont(fontFamily, style: .footnote))
							.foregroundStyle(Color.secondary)
					} else if entry.id == review.warning.spacing?.previous.id {
						Text("Previous dose")
							.font(.customFont(fontFamily, style: .footnote))
							.foregroundStyle(Color.secondary)
					}
					Text(timestamp(entry.date, showOffset: showOffset))
						.font(.customFont(fontFamily, style: .body))
					Text(quantity ?? String(localized: "No usable amount recorded"))
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(Color.secondary)
					if checksUnit, let expectedUnit = review.warning.unit, let unit = entry.unit, unit != expectedUnit {
						Text("Different unit from saved limit")
							.font(.customFont(fontFamily, style: .footnote))
							.foregroundStyle(Color.secondary)
					}
				}
				.foregroundStyle(Color.primary)
				.fixedSize(horizontal: false, vertical: true)
				Spacer(minLength: 0)
				Image(systemSymbol: .pencil)
					.foregroundStyle(Color.accent)
					.accessibilityHidden(true)
			}
			.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityHint("Edit this dose entry")
	}

	@ViewBuilder
	private func quantityFinding(_ finding: MedicationHistoryDoseWarningService.QuantityFinding, maximum: Double?, unit: ANUnitConcept?, rolling: Bool) -> some View {
		let limit = maximum.flatMap { amount in
			amount.isFinite && amount > 0 ? displayAmount(amount, unit: unit) : nil
		}
		if finding != .unavailable {
			reviewNote(rolling
				? "The doses logged in the 24 hours ending with this dose add up to more than the saved limit."
				: "The amount logged for this dose is over the saved limit for one dose.")
		}
		switch finding {
		case let .exceeded(total):
			if let amount = displayAmount(total, unit: unit) {
				comparison(rolling ? "Logged total" : "Logged amount", value: amount)
			}
		case let .atLeast(total):
			if let amount = displayAmount(total, unit: unit) {
				comparison("Known total", value: String(localized: "At least \(amount)"))
			}
			reviewNote("Some entries couldn’t be counted.")
		case .overflow:
			reviewNote("The total is too large to display.")
		case .unavailable:
			if limit == nil {
				reviewNote("Couldn’t check the amount. Review the limit and unit in medication settings.")
			} else if rolling {
				reviewNote("Couldn’t check the total. Review entries with missing amounts or different units.")
			} else {
				reviewNote("Couldn’t check this dose. Review its recorded amount and unit.")
			}
		}
		if let limit {
			comparison("Saved limit", value: limit)
		}
	}

	private func reviewNote(_ message: LocalizedStringKey) -> some View {
		Text(message)
			.font(.customFont(fontFamily, style: .body))
	}

	private func timestamp(_ date: Date, showOffset: Bool) -> String {
		guard showOffset else { return date.formatted(date: .abbreviated, time: .standard) }
		return date.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().second().timeZone(.localizedGMT(.long)))
	}

	private func duration(_ seconds: TimeInterval) -> String {
		guard seconds < 365 * 24 * 3_600 else {
			return hours(seconds / 3_600)
		}
		return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
	}

	private func preciseDuration(_ seconds: TimeInterval) -> String {
		String(localized: "\(number(seconds)) seconds")
	}

	private func hours(_ value: Double) -> String {
		String(localized: "\(number(value)) hours")
	}

	private func displayAmount(_ amount: Double, unit: ANUnitConcept?) -> String? {
		guard let unit else { return nil }
		// Reuse the localized full unit where the ordinary display preserves the evidence.
		if amount >= 0.01, amount < 1e12, (amount * 100).rounded() / 100 == amount {
			return unit.localizedAmount(for: amount)
		}
		return String(localized: "\(number(amount)) \(unit.localizedAbbreviation)")
	}

	private func number(_ value: Double) -> String {
		if value != 0, abs(value) < 0.000_001 || abs(value) >= 1e12 {
			return value.formatted(.number.notation(.scientific).precision(.significantDigits(1...17)))
		}
		return DoseAmountInput.text(for: value)
	}
}

struct HistoryDoseWarningLabel: View {
	let titles: [LocalizedStringKey]
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Image(systemSymbol: .exclamationmarkTriangleFill)
				.foregroundStyle(.yellow)
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 4) {
				if titles.count > 1 {
					Text("\(titles.count) dose warnings")
						.fontWeight(.semibold)
				}
				ForEach(titles.indices, id: \.self) { index in
					HStack(alignment: .firstTextBaseline, spacing: 6) {
						if titles.count > 1 {
							Text(verbatim: "•")
								.accessibilityHidden(true)
						}
						Text(titles[index])
					}
				}
			}
			.font(.customFont(fontFamily, style: .subheadline, weight: titles.count == 1 ? .semibold : .regular))
			.foregroundStyle(.primary)
			.frame(maxWidth: .infinity, alignment: .leading)

			Image(systemSymbol: .chevronForward)
				.font(.customFont(fontFamily, style: .footnote, weight: .semibold))
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
		}
		.fixedSize(horizontal: false, vertical: true)
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.frame(minHeight: 44)
		.background(.yellow.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
		.contentShape(Rectangle())
		.accessibilityElement(children: .combine)
	}
}
