// DoseLogPressGestureModifier.swift
// Tap-to-open / hold-to-quick-log press handling shared by dose logging controls.

import SFSafeSymbols
import SwiftUI

/// Adds the press handling used by dose logging controls: a short press opens the Log Dose sheet and
/// holding for `longPressDuration` quick logs the default dose.
///
/// **Features:**
/// - `DragGesture(minimumDistance: 0)` as a high-priority gesture so the press starts immediately
/// - Long press fires at the exact threshold via a `DispatchWorkItem`, cancelled on release
/// - Light impact haptic when the press begins, heavy impact when the quick log triggers, medium impact on a short tap
/// - Reports `isPressed` / `isLongPressing` through bindings so the caller can scale or shade its label
/// - Drives `holdProgress` from 0 to 1 over `longPressDuration` while the finger is down, so the caller
///   can draw a fill or ring that shows the hold building up and makes the gesture discoverable
///
/// **Use Cases:**
/// - Floating Log Dose button on the History tab
/// - Mirrors the row button on the Medication tab (`MedicationRowComponent`)
struct DoseLogPressGestureModifier: ViewModifier {
    // MARK: - Properties
    @Binding var isPressed: Bool
    @Binding var isLongPressing: Bool
    /// 0 when idle, animating to 1 over `longPressDuration` while pressed. Resets on release.
    var holdProgress: Binding<Double> = .constant(0)
    var longPressDuration: TimeInterval = 0.5
    let onTap: () -> Void
    let onQuickLog: (() async -> Bool)?
    var onQuickLogSuccess: (() -> Void)? = nil

    @State private var longPressWorkItem: DispatchWorkItem?
    @State private var hasTriggeredQuickLog = false
    private let hapticsManager = HapticsManager.shared

    // MARK: - Body
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // Only set up the timer on first change event
                        guard longPressWorkItem == nil else { return }

                        // Visual feedback - press started
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                        // A small tick on touch-down tells the user the hold has started counting.
                        hapticsManager.lightImpact()
                        withAnimation(.linear(duration: longPressDuration)) {
                            holdProgress.wrappedValue = 1
                        }

                        // Schedule long press action to fire at exact threshold
                        let workItem = DispatchWorkItem { [self] in
                            guard !hasTriggeredQuickLog else { return }

                            hasTriggeredQuickLog = true
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isLongPressing = true
                            }
                            hapticsManager.heavyImpact()

                            if let onQuickLog {
                                Task {
                                    let success = await onQuickLog()
                                    if success {
                                        await MainActor.run {
                                            onQuickLogSuccess?()
                                        }
                                    }
                                }
                            }
                        }

                        longPressWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration, execute: workItem)
                    }
                    .onEnded { _ in
                        // Cancel scheduled long press if it hasn't fired yet
                        longPressWorkItem?.cancel()
                        longPressWorkItem = nil

                        // Reset visual states
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = false
                            isLongPressing = false
                        }
                        withAnimation(.easeOut(duration: 0.15)) {
                            holdProgress.wrappedValue = 0
                        }

                        // Only trigger tap action if it was a short press (long press wasn't triggered)
                        if !hasTriggeredQuickLog {
                            hapticsManager.mediumImpact()
                            onTap()
                        }

                        // Reset for next interaction
                        hasTriggeredQuickLog = false
                    }
            )
    }
}

extension View {
    /// Applies tap-to-open / hold-to-quick-log press handling. See `DoseLogPressGestureModifier`.
    func doseLogPressGesture(
        isPressed: Binding<Bool>,
        isLongPressing: Binding<Bool>,
        holdProgress: Binding<Double> = .constant(0),
        longPressDuration: TimeInterval = 0.5,
        onTap: @escaping () -> Void,
        onQuickLog: (() async -> Bool)? = nil,
        onQuickLogSuccess: (() -> Void)? = nil
    ) -> some View {
        modifier(
            DoseLogPressGestureModifier(
                isPressed: isPressed,
                isLongPressing: isLongPressing,
                holdProgress: holdProgress,
                longPressDuration: longPressDuration,
                onTap: onTap,
                onQuickLog: onQuickLog,
                onQuickLogSuccess: onQuickLogSuccess
            )
        )
    }
}

#if DEBUG
    #Preview {
        struct PreviewHost: View {
            @State private var isPressed = false
            @State private var isLongPressing = false
            @State private var holdProgress: Double = 0
            @State private var lastAction = "None"

            var body: some View {
                VStack(spacing: 24) {
                    Text("Last action: \(lastAction)")
                    Label("Log Dose", systemSymbol: .plus)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(.accent))
                        .overlay(
                            Capsule()
                                .trim(from: 0, to: holdProgress)
                                .stroke(.white, lineWidth: 3)
                        )
                        .scaleEffect(isPressed || isLongPressing ? 0.95 : 1.0)
                        .doseLogPressGesture(
                            isPressed: $isPressed,
                            isLongPressing: $isLongPressing,
                            holdProgress: $holdProgress,
                            onTap: { lastAction = "Tap" },
                            onQuickLog: {
                                lastAction = "Quick log"
                                return true
                            }
                        )
                }
                .padding()
            }
        }

        return PreviewHost()
    }
#endif
