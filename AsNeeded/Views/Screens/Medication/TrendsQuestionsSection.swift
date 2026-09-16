import ANModelKit
import SFSafeSymbols
import SwiftUI

/// The "Private Questions" card on the Trends screen.
///
/// Shows one of four states driven by `MedicationTrendsViewModel.questionPhase`:
/// - idle: a composer plus example prompt chips
/// - working: the asked question, a live status line, the answer streaming in, and a Cancel button
/// - answered: the question and the structured answer, with an "Ask another" action
/// - failed: the error and a Retry action
///
/// Unavailable and opted-out states explain what the user can do instead of showing the composer.
struct TrendsQuestionsSection: View {
	@ObservedObject var viewModel: MedicationTrendsViewModel
	let medication: ANMedicationConcept
	let daysWindow: Int
	@Binding var questionText: String
	@FocusState.Binding var isFieldFocused: Bool
	@Binding var showingDisclaimer: Bool

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@ScaledMetric private var cardPadding: CGFloat = 18
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var smallSpacing: CGFloat = 4
	@ScaledMetric private var mediumSpacing: CGFloat = 8
	@ScaledMetric private var badgePaddingH: CGFloat = 10
	@ScaledMetric private var badgePaddingV: CGFloat = 6
	@ScaledMetric private var chipPaddingH: CGFloat = 12
	@ScaledMetric private var chipPaddingV: CGFloat = 8
	@ScaledMetric private var composerPadding: CGFloat = 10
	@ScaledMetric private var sendButtonSize: CGFloat = 34
	@ScaledMetric private var placeholderLineHeight: CGFloat = 12
	@State private var placeholderPulse = false

	// MARK: - Body

	var body: some View {
		switch viewModel.questionAvailability {
		case .unavailable:
			unavailableCard
		case .disabled:
			optInCard
		case .available:
			availableCard
		}
	}

	// MARK: - Unavailable / Opt-in

	@ViewBuilder
	private var unavailableCard: some View {
		// Only explain when the user can do something about it. Ineligible hardware stays quiet.
		if let reason = viewModel.questionUnavailableReason, reason != .deviceNotEligible {
			card {
				header(badgeText: reason == .modelNotReady ? "Getting ready" : "Off", badgeSymbol: .lockShield)
				Text(reason.userGuidance)
					.font(.customFont(fontFamily, style: .subheadline))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		} else {
			EmptyView()
		}
	}

	private var optInCard: some View {
		card {
			header(badgeText: "Opt in", badgeSymbol: .lockShield)

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
	}

	// MARK: - Available

	private var availableCard: some View {
		card {
			header(badgeText: statusBadgeText, badgeSymbol: statusBadgeSymbol)

			Text("Ask about your logged history in plain language. Everything stays on this device.")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			switch viewModel.questionPhase {
			case .idle:
				composer
				promptChips
			case .preparing:
				workingCard(stage: String(localized: "Reading \(daysWindow) days of \(medication.displayName) logs…"), partial: nil)
			case let .generating(partial):
				workingCard(
					stage: partial.answer.isEmpty ? String(localized: "Thinking…") : String(localized: "Writing the answer…"),
					partial: partial
				)
			case let .answered(answer):
				answerCard(answer)
				askAnotherButton
			case let .failed(message):
				failureCard(message)
			}

			disclaimerFooter
		}
		.animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.questionPhase)
	}

	// MARK: - Composer

	private var composer: some View {
		HStack(alignment: .bottom, spacing: mediumSpacing) {
			TextField(
				"Ask about timing, consistency, or changes",
				text: $questionText,
				axis: .vertical
			)
			.font(.customFont(fontFamily, style: .body))
			.lineLimit(1 ... 4)
			.focused($isFieldFocused)
			.accessibilityLabel("Question about \(medication.displayName)")

			Button {
				submitCurrentQuestion()
			} label: {
				Image(systemSymbol: .arrowUpCircleFill)
					.font(.system(size: sendButtonSize))
					.symbolRenderingMode(.hierarchical)
					.foregroundStyle(canSend ? medication.displayColor : Color.secondary)
			}
			.buttonStyle(.plain)
			.disabled(!canSend)
			.accessibilityLabel("Ask")
			.accessibilityHint("Sends your question to the on-device model")
		}
		.padding(composerPadding)
		.background(
			RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
				.fill(Color(.secondarySystemGroupedBackground))
		)
		.overlay(
			RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
				.strokeBorder(isFieldFocused ? medication.displayColor.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1)
		)
	}

	private var canSend: Bool {
		!questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.questionPhase.isWorking
	}

	private func submitCurrentQuestion() {
		let prompt = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !prompt.isEmpty else { return }
		isFieldFocused = false
		Task {
			await viewModel.ask(question: prompt, windowDays: daysWindow)
		}
	}

	// MARK: - Prompt chips

	@ViewBuilder
	private var promptChips: some View {
		if !viewModel.examplePrompts.isEmpty {
			VStack(alignment: .leading, spacing: mediumSpacing) {
				Text("Try asking")
					.font(.customFont(fontFamily, style: .caption, weight: .medium))
					.foregroundStyle(.secondary)

				if dynamicTypeSize.isAccessibilitySize {
					VStack(alignment: .leading, spacing: mediumSpacing) {
						ForEach(viewModel.examplePrompts, id: \.self) { prompt in
							promptChip(prompt)
						}
					}
				} else {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: mediumSpacing) {
							ForEach(viewModel.examplePrompts, id: \.self) { prompt in
								promptChip(prompt)
							}
						}
					}
					.scrollClipDisabled()
				}
			}
		}
	}

	private func promptChip(_ prompt: String) -> some View {
		Button {
			questionText = prompt
			isFieldFocused = false
			Task {
				await viewModel.ask(question: prompt, windowDays: daysWindow)
			}
		} label: {
			HStack(spacing: smallSpacing) {
				Image(systemSymbol: .sparkles)
					.font(.customFont(fontFamily, style: .caption))
				Text(prompt)
					.font(.customFont(fontFamily, style: .subheadline))
					.multilineTextAlignment(.leading)
					.fixedSize(horizontal: false, vertical: true)
			}
			.foregroundStyle(medication.displayColor)
			.padding(.horizontal, chipPaddingH)
			.padding(.vertical, chipPaddingV)
			.background(
				Capsule()
					.fill(medication.displayColor.opacity(0.12))
			)
		}
		.buttonStyle(.plain)
		.accessibilityHint("Asks this question")
	}

	// MARK: - Working

	private func workingCard(stage: String, partial: TrendsQuestionAnswer?) -> some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			questionEcho

			HStack(spacing: mediumSpacing) {
				ProgressView()
					.controlSize(.small)
					.tint(medication.displayColor)
				Text(stage)
					.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
					.foregroundStyle(.secondary)
					.contentTransition(.opacity)
				Spacer()
				Button("Cancel") {
					viewModel.cancelQuestion()
				}
				.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
				.buttonStyle(.bordered)
				.tint(medication.displayColor)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel("Working. \(stage)")

			if let partial, !partial.answer.isEmpty {
				Text(partial.answer)
					.font(.customFont(fontFamily, style: .body))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityLabel("Answer so far: \(partial.answer)")
			} else {
				placeholderLines
			}
		}
		.padding(cardPadding)
		.background(
			RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
				.fill(medication.displayColor.opacity(0.06))
		)
	}

	/// Three soft bars that stand in for the answer until the first words arrive.
	private var placeholderLines: some View {
		VStack(alignment: .leading, spacing: mediumSpacing) {
			ForEach([1.0, 0.85, 0.6], id: \.self) { fraction in
				GeometryReader { proxy in
					RoundedRectangle(cornerRadius: placeholderLineHeight / 2, style: .continuous)
						.fill(medication.displayColor.opacity(placeholderPulse ? 0.22 : 0.10))
						.frame(width: proxy.size.width * fraction)
				}
				.frame(height: placeholderLineHeight)
			}
		}
		.accessibilityHidden(true)
		.onAppear {
			guard !reduceMotion else { return }
			withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
				placeholderPulse = true
			}
		}
		.onDisappear {
			placeholderPulse = false
		}
	}

	// MARK: - Answer

	private func answerCard(_ answer: TrendsQuestionAnswer) -> some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			questionEcho

			Text(answer.answer)
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(.primary)
				.fixedSize(horizontal: false, vertical: true)
				.textSelection(.enabled)

			if !answer.highlights.isEmpty {
				VStack(alignment: .leading, spacing: smallSpacing) {
					Text("What stands out")
						.font(.customFont(fontFamily, style: .caption, weight: .medium))
						.foregroundStyle(.secondary)

					ForEach(answer.highlights, id: \.self) { highlight in
						HStack(alignment: .top, spacing: smallSpacing) {
							Image(systemSymbol: .circleFill)
								.font(.customFont(fontFamily, style: .caption2))
								.foregroundStyle(medication.displayColor)
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

			HStack(spacing: smallSpacing) {
				Image(systemSymbol: .lockShield)
				Text("Answered on this device")
			}
			.font(.customFont(fontFamily, style: .caption2))
			.foregroundStyle(.secondary)
		}
		.padding(cardPadding)
		.background(
			RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
				.fill(medication.displayColor.opacity(0.06))
		)
	}

	private var askAnotherButton: some View {
		Button {
			viewModel.resetQuestion()
			questionText = ""
			// The composer is added by this same update; focus it on the next one so the field exists.
			Task { @MainActor in
				isFieldFocused = true
			}
		} label: {
			Label("Ask another question", systemSymbol: .plusBubble)
				.font(.customFont(fontFamily, style: .body, weight: .medium))
				.foregroundStyle(medication.displayColor)
		}
		.buttonStyle(.plain)
	}

	// MARK: - Failure

	private func failureCard(_ message: String) -> some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			questionEcho

			HStack(alignment: .top, spacing: mediumSpacing) {
				Image(systemSymbol: .exclamationmarkCircleFill)
					.foregroundStyle(.orange)
				Text(message)
					.font(.customFont(fontFamily, style: .subheadline))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
			}

			HStack(spacing: rowSpacing) {
				if let question = viewModel.askedQuestion, !question.isEmpty {
					Button {
						Task {
							await viewModel.ask(question: question, windowDays: daysWindow)
						}
					} label: {
						Label("Try again", systemSymbol: .arrowClockwise)
							.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
					}
					.buttonStyle(.bordered)
					.tint(medication.displayColor)
				}

				Button {
					viewModel.resetQuestion()
					Task { @MainActor in
						isFieldFocused = true
					}
				} label: {
					Text("Edit question")
						.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
				}
				.buttonStyle(.plain)
				.foregroundStyle(medication.displayColor)
			}
		}
		.padding(cardPadding)
		.background(
			RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
				.fill(Color.orange.opacity(0.08))
		)
	}

	// MARK: - Shared pieces

	@ViewBuilder
	private var questionEcho: some View {
		if let question = viewModel.askedQuestion, !question.isEmpty {
			HStack(alignment: .top, spacing: mediumSpacing) {
				Image(systemSymbol: .quoteOpening)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(medication.displayColor)
					.padding(.top, smallSpacing)
				Text(question)
					.font(.customFont(fontFamily, style: .subheadline, weight: .medium))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel("Your question: \(question)")
		}
	}

	private func header(badgeText: String, badgeSymbol: SFSymbol) -> some View {
		HStack {
			Text("Private Questions")
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
			Spacer()
			HStack(spacing: smallSpacing) {
				Image(systemSymbol: badgeSymbol)
					.symbolEffect(.variableColor.iterative, options: .repeating, isActive: viewModel.questionPhase.isWorking && !reduceMotion)
				Text(badgeText)
			}
			.font(.customFont(fontFamily, style: .caption, weight: .medium))
			.foregroundStyle(medication.displayColor)
			.padding(.horizontal, badgePaddingH)
			.padding(.vertical, badgePaddingV)
			.background(
				Capsule()
					.fill(medication.displayColor.opacity(0.12))
			)
			.accessibilityLabel("Status: \(badgeText)")
		}
	}

	private var statusBadgeText: String {
		switch viewModel.questionPhase {
		case .idle:
			return String(localized: "On device")
		case .preparing, .generating:
			return String(localized: "Working…")
		case .answered:
			return String(localized: "Answered")
		case .failed:
			return String(localized: "Couldn't answer")
		}
	}

	private var statusBadgeSymbol: SFSymbol {
		switch viewModel.questionPhase {
		case .idle:
			return .lockShield
		case .preparing, .generating:
			return .sparkles
		case .answered:
			return .checkmarkCircleFill
		case .failed:
			return .exclamationmarkCircle
		}
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

	private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: rowSpacing, content: content)
			.padding(cardPadding)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
	}
}
