import UIKit
import SwiftUI

/// Centralized haptics manager following iOS best practices
@MainActor
public final class HapticsManager: ObservableObject {
	public static let shared = HapticsManager()
	
	@AppStorage("hapticsEnabled") public var hapticsEnabled: Bool = true
	
	// Haptic generators for different feedback types
	private let impactLight = UIImpactFeedbackGenerator(style: .light)
	private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
	private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
	private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
	private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
	private let selection = UISelectionFeedbackGenerator()
	private let notification = UINotificationFeedbackGenerator()
	
	private init() {
		// Prepare generators for immediate use
		impactLight.prepare()
		impactMedium.prepare()
		impactHeavy.prepare()
		impactSoft.prepare()
		impactRigid.prepare()
		selection.prepare()
		notification.prepare()
	}
	
	// MARK: - Selection Feedback
	
	/// Light tap feedback for UI selections (tabs, toggles, pickers)
	public func selectionChanged() {
		guard hapticsEnabled else { return }
		selection.selectionChanged()
		selection.prepare() // Re-prepare for next use
	}
	
	// MARK: - Impact Feedback
	
	/// Light impact for subtle interactions (stepper changes, small buttons)
	public func lightImpact() {
		guard hapticsEnabled else { return }
		impactLight.impactOccurred()
		impactLight.prepare()
	}
	
	/// Medium impact for standard button taps
	public func mediumImpact() {
		guard hapticsEnabled else { return }
		impactMedium.impactOccurred()
		impactMedium.prepare()
	}
	
	/// Heavy impact for significant actions (delete, important confirmations)
	public func heavyImpact() {
		guard hapticsEnabled else { return }
		impactHeavy.impactOccurred()
		impactHeavy.prepare()
	}
	
	/// Soft impact for gentle feedback (floating buttons, cards)
	public func softImpact() {
		guard hapticsEnabled else { return }
		impactSoft.impactOccurred()
		impactSoft.prepare()
	}
	
	/// Rigid impact for precise, mechanical feedback
	public func rigidImpact() {
		guard hapticsEnabled else { return }
		impactRigid.impactOccurred()
		impactRigid.prepare()
	}
	
	// MARK: - Notification Feedback
	
	/// Success feedback for completed actions
	public func notificationSuccess() {
		guard hapticsEnabled else { return }
		notification.notificationOccurred(.success)
		notification.prepare()
	}
	
	/// Warning feedback for attention-needed states
	public func notificationWarning() {
		guard hapticsEnabled else { return }
		notification.notificationOccurred(.warning)
		notification.prepare()
	}
	
	/// Error feedback for failed actions
	public func notificationError() {
		guard hapticsEnabled else { return }
		notification.notificationOccurred(.error)
		notification.prepare()
	}
	
	// MARK: - Specialized Feedback Patterns
	
	/// Feedback for dose logging action
	public func doseLogged() {
		guard hapticsEnabled else { return }
		mediumImpact()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			self?.notificationSuccess()
		}
	}
	
	/// Feedback for medication added
	public func medicationAdded() {
		guard hapticsEnabled else { return }
		softImpact()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			self?.notificationSuccess()
		}
	}
	
	/// Feedback for deletion action
	public func itemDeleted() {
		guard hapticsEnabled else { return }
		heavyImpact()
	}
	
	/// Feedback for pull to refresh
	public func pullToRefresh() {
		guard hapticsEnabled else { return }
		rigidImpact()
	}
	
	/// Feedback for date/time picker changes
	public func datePickerChanged() {
		guard hapticsEnabled else { return }
		selectionChanged()
	}
	
	/// Feedback for swipe actions
	public func swipeAction() {
		guard hapticsEnabled else { return }
		lightImpact()
	}
}

// MARK: - SwiftUI View Modifier

struct HapticFeedbackModifier: ViewModifier {
	let style: HapticFeedbackStyle
	let trigger: Bool
	
	func body(content: Content) -> some View {
		content
			.onChange(of: trigger) { _, _ in
				HapticsManager.shared.performFeedback(style: style)
			}
	}
}

enum HapticFeedbackStyle {
	case selection
	case lightImpact
	case mediumImpact
	case heavyImpact
	case softImpact
	case rigidImpact
	case success
	case warning
	case error
	case doseLogged
	case medicationAdded
	case itemDeleted
}

extension HapticsManager {
	func performFeedback(style: HapticFeedbackStyle) {
		switch style {
		case .selection:
			selectionChanged()
		case .lightImpact:
			lightImpact()
		case .mediumImpact:
			mediumImpact()
		case .heavyImpact:
			heavyImpact()
		case .softImpact:
			softImpact()
		case .rigidImpact:
			rigidImpact()
		case .success:
			notificationSuccess()
		case .warning:
			notificationWarning()
		case .error:
			notificationError()
		case .doseLogged:
			doseLogged()
		case .medicationAdded:
			medicationAdded()
		case .itemDeleted:
			itemDeleted()
		}
	}
}

extension View {
	/// Adds haptic feedback to a view when a trigger value changes
	func hapticFeedback(style: HapticFeedbackStyle, trigger: Bool) -> some View {
		modifier(HapticFeedbackModifier(style: style, trigger: trigger))
	}
}