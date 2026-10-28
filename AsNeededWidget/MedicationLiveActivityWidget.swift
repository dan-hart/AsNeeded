import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
	import ActivityKit
#endif

#if canImport(AppIntents)
	import AppIntents
#endif

private let widgetAccent = Color("AccentColor")

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.2, *)
struct MedicationLiveActivityWidget: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: MedicationLiveActivityAttributes.self) { context in
			LiveActivityLockScreenView(state: context.state)
				.activityBackgroundTint(Color(.systemBackground))
				.activitySystemActionForegroundColor(widgetAccent)
		} dynamicIsland: { context in
			DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					Image(systemName: context.state.symbolName)
						.font(.title3.weight(.semibold))
						.foregroundStyle(widgetAccent)
							.accessibilityLabel(context.state.medicationName)
				}

				DynamicIslandExpandedRegion(.trailing) {
					liveStatusBadge(for: context.state)
				}

				DynamicIslandExpandedRegion(.bottom) {
					LiveActivityExpandedView(state: context.state)
				}
			} compactLeading: {
				Image(systemName: context.state.symbolName)
					.foregroundStyle(widgetAccent)
					.accessibilityLabel("\(context.state.medicationName). \(context.state.statusText)")
			} compactTrailing: {
				if context.state.canTakeNow {
						Text("Log")
						.font(.caption2.weight(.semibold))
				} else if let nextDoseDate = context.state.nextDoseDate {
					Text(nextDoseDate, style: .timer)
						.font(.caption2.weight(.semibold))
						.monospacedDigit()
				}
			} minimal: {
				Image(systemName: context.state.symbolName)
					.foregroundStyle(widgetAccent)
						.accessibilityLabel("\(context.state.medicationName). \(context.state.statusText)")
			}
		}
	}

	@ViewBuilder
	private func liveStatusBadge(for state: MedicationLiveActivityAttributes.ContentState) -> some View {
			Text(state.lowStock ? "Low stock" : state.canTakeNow ? "Log dose" : "Saved interval")
			.font(.caption2.weight(.semibold))
			.foregroundStyle(state.lowStock ? .orange : widgetAccent)
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(
				Capsule()
					.fill((state.lowStock ? Color.orange : widgetAccent).opacity(0.12))
			)
	}
}

@available(iOSApplicationExtension 16.2, *)
private struct LiveActivityLockScreenView: View {
	let state: MedicationLiveActivityAttributes.ContentState

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .top, spacing: 12) {
				Image(systemName: state.symbolName)
					.font(.title2.weight(.semibold))
					.foregroundStyle(widgetAccent)
					.frame(width: 36, height: 36)
					.background(
						RoundedRectangle(cornerRadius: 10, style: .continuous)
							.fill(widgetAccent.opacity(0.12))
					)

				VStack(alignment: .leading, spacing: 4) {
					Text("Medication")
						.font(.caption.weight(.medium))
						.foregroundStyle(.secondary)

					Text(state.medicationName)
						.font(.headline.weight(.semibold))
						.fixedSize(horizontal: false, vertical: true)

					Text(state.detailText)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}

				Spacer(minLength: 12)

				VStack(alignment: .trailing, spacing: 4) {
					Text(state.statusText)
						.font(.subheadline.weight(.semibold))
						.multilineTextAlignment(.trailing)

					if !state.canTakeNow, let nextDoseDate = state.nextDoseDate {
						Text(nextDoseDate, style: .timer)
							.font(.caption.weight(.medium))
							.monospacedDigit()
							.foregroundStyle(.secondary)
					}
				}
			}

			if #available(iOSApplicationExtension 17.0, *), state.canTakeNow {
				let intent = logIntent(for: state.medicationID)

				Button(intent: intent) {
					Label("Log Dose", systemImage: "plus.circle.fill")
						.font(.subheadline.weight(.semibold))
						.frame(maxWidth: .infinity)
						.padding(.vertical, 12)
				}
				.buttonStyle(.borderedProminent)
				.tint(widgetAccent)
					.accessibilityLabel("Log a dose of \(state.medicationName)")
			}
		}
		.padding(.vertical, 8)
	}

	private func logIntent(for medicationID: String) -> LogDoseWidgetIntent {
		var intent = LogDoseWidgetIntent()
		intent.medicationID = medicationID
		return intent
	}
}

@available(iOSApplicationExtension 16.2, *)
private struct LiveActivityExpandedView: View {
	let state: MedicationLiveActivityAttributes.ContentState

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(state.medicationName)
				.font(.headline)
				.fixedSize(horizontal: false, vertical: true)
			Text(state.statusText)
				.font(.subheadline.weight(.semibold))

			Text(state.detailText)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(2)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
#endif
