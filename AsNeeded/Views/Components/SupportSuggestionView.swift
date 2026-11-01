import ANModelKit
import SFSafeSymbols
import SwiftUI

struct SupportSuggestionView: View {
	@Environment(\.fontFamily) private var fontFamily
	@AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false
	@State private var isDismissed = false

	var message: String = String(localized: "Consider supporting continued development")
	let onSupportTapped: () -> Void

	var body: some View {
		Group {
		if !hideSupportBanners && !isDismissed {
			SupportBannerCard(
				message: message,
				onDismiss: { isDismissed = true },
				onHide: { hideSupportBanners = true }
			) { label in
				Button(action: onSupportTapped) {
					label
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 16)
			.padding(.top, 8)
		}
		}
		.modifier(EstablishedUseSupportModifier())
	}
}

/// Shared support presentation keeps dismissal separate from the support action.
struct SupportBannerCard<SupportAction: View>: View {
	@Environment(\.fontFamily) private var fontFamily

	let message: String
	let onDismiss: () -> Void
	let onHide: () -> Void
	@ViewBuilder let supportAction: (SupportBannerActionLabel) -> SupportAction

	var body: some View {
		VStack(spacing: 8) {
			ZStack(alignment: .topTrailing) {
				supportAction(SupportBannerActionLabel(content: .banner(message)))
					.buttonStyle(.plain)

				Button(action: onDismiss) {
					Image(systemSymbol: .xmark)
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.foregroundStyle(.accent)
						.frame(width: 44, height: 44)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Close support banner")
				.padding(16)
			}

			supportAction(SupportBannerActionLabel(content: .callToAction))
			.buttonStyle(.plain)
			.foregroundStyle(.accent)
			.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
			.overlay {
				RoundedRectangle(cornerRadius: 10)
					.strokeBorder(Color.accent, lineWidth: 1)
			}

			Button(action: onHide) {
				Text("Don't Show Again")
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.foregroundStyle(.secondary)
			.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
			.overlay {
				RoundedRectangle(cornerRadius: 10)
					.strokeBorder(Color.secondary, lineWidth: 1)
			}
		}
	}
}

struct SupportBannerActionLabel: View {
	@Environment(\.fontFamily) private var fontFamily

	enum Content {
		case banner(String)
		case callToAction
	}

	let content: Content

	var body: some View {
		switch content {
		case .banner(let message):
			SupportBannerLabel(message: message)
		case .callToAction:
			Text("Support As Needed")
				.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
				.frame(maxWidth: .infinity, minHeight: 44)
				.contentShape(Rectangle())
		}
	}
}


/// The whole outlined card is the support link; Close remains a separate control.
struct SupportBannerLabel: View {
	@Environment(\.fontFamily) private var fontFamily
	let message: String

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .top, spacing: 8) {
				Image(systemSymbol: .heart)
					.font(.customFont(fontFamily, style: .title3, weight: .semibold))
					.frame(minHeight: 44)
					.foregroundStyle(.accent)
					.accessibilityHidden(true)
				Text("Enjoying As Needed?")
					.font(.customFont(fontFamily, style: .headline, weight: .semibold))
					.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(.trailing, 52)

			Text(message)
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.foregroundStyle(.primary)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.strokeBorder(Color.accent, lineWidth: 1)
		}
		.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.accessibilityElement(children: .combine)
		.accessibilityHint("View ways to support As Needed")
	}
}

#if DEBUG
	#Preview {
		NavigationStack {
			List {
				SupportSuggestionView(onSupportTapped: {})
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
			}
		}
	}
#endif

/// Optional support prompts follow established use, independently of review requests.
enum SupportPromptPolicy {
	static func shouldShow(launchCount: Int, doseDates: [Date], at date: Date = .now, calendar: Calendar = .current) -> Bool {
		let recordedDates = doseDates.filter { $0 <= date }
		return launchCount >= 3 && recordedDates.count >= 3 &&
			Set(recordedDates.map { calendar.startOfDay(for: $0) }).count >= 2
	}
}

struct EstablishedUseSupportModifier: ViewModifier {
	@AppStorage(UserDefaultsKeys.appLaunchCount) private var launchCount = 0
	@State private var doseDates: [Date] = []

	func body(content: Content) -> some View {
		VStack(spacing: 0) {
			if SupportPromptPolicy.shouldShow(launchCount: launchCount, doseDates: doseDates) {
				content
			}
		}
		.task {
			let store = DataStore.shared
			let snapshots = store.committedSnapshots()
			do {
				let snapshot = try await store.prepareForAccess()
				doseDates = snapshot.events.filter { $0.eventType == .doseTaken }.map(\.date)
				for await snapshot in snapshots {
					guard !Task.isCancelled else { return }
					doseDates = snapshot.events.filter { $0.eventType == .doseTaken }.map(\.date)
				}
			} catch {
				doseDates = []
			}
		}
	}
}
