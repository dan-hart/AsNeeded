import ANModelKit
import SFSafeSymbols
import SwiftUI

struct HistoryDoseWarningView: View {
	let warning: MedicationHistoryDoseWarningService.Warning
	let dose: MedicationHistoryDoseWarningService.Dose
	let rollingEntries: [MedicationHistoryDoseWarningService.Dose]
	let onEdit: (UUID) -> Void

	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		NavigationStack {
			Form {
				if let spacing = warning.spacing {
					Section {
						let minimum = spacing.minimumHours * 3_600
						let gap = duration(spacing.elapsed)
						let limit = duration(minimum)
						Text("These doses were logged \(gap == limit ? preciseDuration(spacing.elapsed) : gap) apart. Your current saved minimum is \(gap == limit ? preciseDuration(minimum) : limit).")
							.font(.customFont(fontFamily, style: .body))
						entryButton(spacing.previous)
						entryButton(dose)
					} header: {
						heading("Doses logged close together")
					}
				}

				if let single = warning.singleDose {
					Section {
						quantityFinding(single, maximum: warning.singleMaximum)
						if warning.spacing == nil { entryButton(dose) }
					} header: {
						heading("Amount per dose")
					}
				}

				if let rolling = warning.rolling {
					Section {
						quantityFinding(rolling, maximum: warning.rollingMaximum)
						let lowerBound = timestamp(dose.date.addingTimeInterval(-SavedDoseLimits.rollingWindow))
						let upperBound = timestamp(dose.date)
						Text("24-hour window after \(lowerBound) through \(upperBound).")
							.font(.customFont(fontFamily, style: .footnote))
							.foregroundStyle(.secondary)
					} header: {
						heading("Amount in 24 hours")
					}
					Section {
						ForEach(rollingEntries) { entry in
							entryButton(entry, comparingTo: warning.unit)
						}
					} header: {
						heading("Entries in this window")
					}
				}
			}
			.customNavigationTitle("Review Dose", displayMode: .inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button { dismiss() } label: {
						Label("Close", systemSymbol: .xmark)
					}
				}
			}
		}
		.tint(.accent)
	}

	private func heading(_ title: LocalizedStringKey) -> some View {
		Text(title)
			.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
	}

	private func entryButton(_ entry: MedicationHistoryDoseWarningService.Dose, comparingTo expectedUnit: ANUnitConcept? = nil) -> some View {
		let date = timestamp(entry.date)
		let quantity = entry.amount.flatMap { displayAmount($0, unit: entry.unit) }
		return Button { onEdit(entry.id) } label: {
			VStack(alignment: .leading, spacing: 4) {
				Text(date)
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
				Text(quantity ?? String(localized: "No usable amount recorded"))
					.font(.customFont(fontFamily, style: .footnote))
					.foregroundStyle(.secondary)
				if let expectedUnit, let unit = entry.unit, unit != expectedUnit {
					Text("Different unit from saved limit")
						.font(.customFont(fontFamily, style: .footnote))
						.foregroundStyle(.secondary)
				}
			}
		}
		.accessibilityHint("Edit this dose entry")
	}

	@ViewBuilder
	private func quantityFinding(_ finding: MedicationHistoryDoseWarningService.QuantityFinding, maximum: Double?) -> some View {
		let limit = maximum.flatMap { amount in
			amount.isFinite && amount > 0 ? displayAmount(amount, unit: warning.unit) : nil
		}
		VStack(alignment: .leading, spacing: 6) {
			switch finding {
			case let .exceeded(total):
				if let amount = displayAmount(total, unit: warning.unit) {
					Text("Logged amount exceeded the saved limit. Logged \(amount).")
				}
			case let .atLeast(total):
				if let amount = displayAmount(total, unit: warning.unit) {
					Text("Logged amount exceeded the saved limit. At least \(amount) was logged in matching units. Some entries couldn’t be counted.")
				}
			case .overflow:
				Text("Logged amount exceeded the saved limit. The total is too large to display.")
			case .unavailable:
				if limit != nil {
					Text("Couldn’t check the amount. Review missing or invalid amounts and entries with different units.")
				} else {
					Text("Couldn’t check the amount. Review the limit and unit in medication settings.")
				}
			}
			if let limit {
				Text("Current saved limit: \(limit)")
					.foregroundStyle(.secondary)
			}
		}
		.font(.customFont(fontFamily, style: .body))
	}

	private func timestamp(_ date: Date) -> String {
		date.formatted(date: .abbreviated, time: .shortened)
	}

	private func duration(_ seconds: TimeInterval) -> String {
		guard seconds < 365 * 24 * 3_600 else {
			let hours = number(seconds / 3_600)
			return String(localized: "\(hours) hours")
		}
		return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
	}

	private func preciseDuration(_ seconds: TimeInterval) -> String {
		String(localized: "\(number(seconds)) seconds")
	}

	private func displayAmount(_ amount: Double, unit: ANUnitConcept?) -> String? {
		guard let unit else { return nil }
		return String(localized: "\(number(amount)) \(unit.localizedAbbreviation)")
	}

	private func number(_ value: Double) -> String {
		if value != 0, abs(value) < 0.000_001 || abs(value) >= 1e12 {
			return value.formatted(.number.notation(.scientific).precision(.significantDigits(1...17)))
		}
		return DoseAmountInput.text(for: value)
	}
}
