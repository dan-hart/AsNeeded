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
					withAnimation(reduceMotion ? nil : .linear(duration: longPressDuration)) {
						holdProgress.wrappedValue = 1
					}
					holdTask = Task { @MainActor in
						do { try await Task.sleep(for: .seconds(longPressDuration)) }
						catch { return }
						guard !Task.isCancelled, press.reachThreshold() else { return }
						isLongPressing = true
						isSaving = true
						// Persistence completes even if the finger lifts or the view disappears.
						Task { @MainActor in
							let saved = await onQuickLog()
							isSaving = false
							if saved {
								HapticsManager.shared.heavyImpact()
								withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { showSuccess = true }
								onQuickLogSuccess?()
								Task { @MainActor in
									try? await Task.sleep(for: .milliseconds(180))
									withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { showSuccess = false }
								}
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
