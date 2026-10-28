import SwiftUI

/// Shared tap/hold handling adapted from 8fab48f, retaining movement and disappearance cancellation.
struct DoseLogPressGestureModifier: ViewModifier {
	@Binding var isPressed: Bool
	@Binding var isLongPressing: Bool
	var holdProgress: Binding<Double> = .constant(0)
	var longPressDuration: TimeInterval = 0.5
	let onTap: () -> Void
	let onQuickLog: (() async -> Bool)?
	var onQuickLogSuccess: (() -> Void)?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var press = DoseLogPressState()
	@State private var holdTask: Task<Void, Never>?
	@State private var isSaving = false
	@State private var showSuccess = false

	func body(content: Content) -> some View {
		content
			.scaleEffect(reduceMotion ? 1 : (showSuccess ? 1.04 : 1))
			.contentShape(Rectangle())
			.highPriorityGesture(DragGesture(minimumDistance: 0)
				.onChanged { value in
					guard !isSaving else { return }
					if press.move(horizontal: value.translation.width, vertical: value.translation.height) {
						holdTask?.cancel()
						resetVisuals()
						return
					}
					guard press.begin() else { return }
					isPressed = true
					HapticsManager.shared.lightImpact()
					guard let onQuickLog else { return }
					if !reduceMotion {
						withAnimation(.linear(duration: longPressDuration)) {
							holdProgress.wrappedValue = 1
						}
					}
					let clock = ContinuousClock()
					let deadline = clock.now.advanced(by: .seconds(longPressDuration))
					holdTask = Task { @MainActor in
						do {
							try await clock.sleep(until: deadline.advanced(by: .seconds(-longPressDuration / 2)))
							guard !Task.isCancelled else { return }
							HapticsManager.shared.mediumImpact()
							try await clock.sleep(until: deadline)
						} catch { return }
						guard !Task.isCancelled, press.reachThreshold() else { return }
						isLongPressing = true
						isSaving = true
						// The ring and save share this deadline. No post-ring delay.
						var transaction = Transaction()
						transaction.disablesAnimations = true
						withTransaction(transaction) { holdProgress.wrappedValue = 1 }
						HapticsManager.shared.heavyImpact()
						// Detach the completed hold from cancellation before persistence starts.
						holdTask = nil
						let saved = await onQuickLog()
						isSaving = false
						if saved {
							withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { showSuccess = true }
							onQuickLogSuccess?()
							Task { @MainActor in
								try? await Task.sleep(for: .milliseconds(180))
								withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { showSuccess = false }
							}
						}
					}
				}
				.onEnded { _ in
					holdTask?.cancel()
					holdTask = nil
					let shouldOpen = press.release()
					resetVisuals()
					if shouldOpen {
						HapticsManager.shared.mediumImpact()
						onTap()
					}
				})
			.onDisappear {
				holdTask?.cancel()
				holdTask = nil
				press.cancel()
				resetVisuals()
			}
	}

	private func resetVisuals() {
		isPressed = false
		isLongPressing = false
		holdProgress.wrappedValue = 0
	}
}

extension View {
	func doseLogPressGesture(
		isPressed: Binding<Bool>, isLongPressing: Binding<Bool>,
		holdProgress: Binding<Double> = .constant(0), longPressDuration: TimeInterval = 0.5,
		onTap: @escaping () -> Void, onQuickLog: (() async -> Bool)? = nil,
		onQuickLogSuccess: (() -> Void)? = nil
	) -> some View {
		modifier(DoseLogPressGestureModifier(isPressed: isPressed, isLongPressing: isLongPressing,
			holdProgress: holdProgress, longPressDuration: longPressDuration,
			onTap: onTap, onQuickLog: onQuickLog, onQuickLogSuccess: onQuickLogSuccess))
	}
}
