import SwiftUI

struct MedicationDateRangeSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@State private var start: Date
	@State private var end: Date
	private let earliestDate: Date
	private let includingToday: Bool
	let onApply: (TrendsDateRange) -> Void

	init(initialRange: TrendsDateRange?, earliestEvent: Date?, includingToday: Bool = false, onApply: @escaping (TrendsDateRange) -> Void) {
		let fallback = Calendar.current.date(byAdding: .day, value: includingToday ? 0 : -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
		_start = State(initialValue: initialRange?.start ?? fallback)
		_end = State(initialValue: initialRange?.end ?? fallback)
		self.earliestDate = Calendar.current.startOfDay(for: min(earliestEvent ?? initialRange?.start ?? fallback, initialRange?.start ?? fallback))
		self.includingToday = includingToday
		self.onApply = onApply
	}

	private var latestDate: Date {
		Calendar.current.date(byAdding: .day, value: includingToday ? 0 : -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
	}

	private var range: TrendsDateRange? {
		TrendsDateRange(start: start, end: end, calendar: .current, now: .now, includingToday: includingToday)
	}

	var body: some View {
		NavigationStack {
			Form {
				DatePicker("Start Date", selection: $start, in: earliestDate...max(earliestDate, min(end, latestDate)), displayedComponents: .date)
				DatePicker("End Date", selection: $end, in: min(start, latestDate)...latestDate, displayedComponents: .date)
				if !includingToday {
					Text("Showing complete days through yesterday. Today’s doses appear after the day is complete.")
						.foregroundStyle(.secondary)
				}
			}
			.font(.customFont(fontFamily, style: .body))
			.customNavigationTitle("Custom Range", displayMode: .inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Apply") {
						guard let range else { return }
						onApply(range)
						dismiss()
					}
					.disabled(range == nil)
				}
			}
			.tint(.accent)
		}
		.font(.customFont(fontFamily, style: .body))
		.presentationDetents([.medium, .large])
	}
}
