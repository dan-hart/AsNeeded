import SwiftUI

struct TrendsCustomRangeSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.fontFamily) private var fontFamily
	@State private var start: Date
	@State private var end: Date
	private let earliestDate: Date
	let onApply: (TrendsDateRange) -> Void

	init(initialRange: TrendsDateRange?, earliestEvent: Date?, onApply: @escaping (TrendsDateRange) -> Void) {
		let fallback = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
		_start = State(initialValue: initialRange?.start ?? fallback)
		_end = State(initialValue: initialRange?.end ?? fallback)
		self.earliestDate = Calendar.current.startOfDay(for: min(earliestEvent ?? initialRange?.start ?? fallback, initialRange?.start ?? fallback))
		self.onApply = onApply
	}

	private var yesterday: Date {
		Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
	}

	private var range: TrendsDateRange? {
		TrendsDateRange(start: start, end: end, calendar: .current, now: .now)
	}

	var body: some View {
		NavigationStack {
			Form {
				DatePicker("Start Date", selection: $start, in: earliestDate...max(earliestDate, min(end, yesterday)), displayedComponents: .date)
				DatePicker("End Date", selection: $end, in: min(start, yesterday)...yesterday, displayedComponents: .date)
				Text("Showing complete days through yesterday. Today’s doses appear after the day is complete.")
					.foregroundStyle(.secondary)
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
		.presentationDetents([.medium, .large])
	}
}
