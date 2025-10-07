import SwiftUI

extension View {
	/// Prevents text truncation by allowing the view to grow vertically
	///
	/// This modifier ensures text content wraps to multiple lines and expands
	/// vertically as needed, while respecting horizontal constraints. The text
	/// will never be truncated with an ellipsis (...).
	///
	/// Critical for Dynamic Type support and accessibility - ensures content
	/// remains fully visible at all font sizes.
	///
	/// **Use Cases:**
	/// - Medication names (clinical names, nicknames)
	/// - Important labels that must never truncate
	/// - Any text where full content visibility is essential
	/// - Content that needs to adapt to larger accessibility font sizes
	///
	/// **When NOT to use:**
	/// - List rows where you want consistent height (use `.lineLimit(2)` instead)
	/// - Preview text that should show "..." (use `.lineLimit(3)` instead)
	/// - Performance-critical scrolling lists with many items
	///
	/// **Example:**
	/// ```swift
	/// Text(medication.clinicalName)
	///     .font(.customFont(fontFamily, style: .caption))
	///     .noTruncate()
	/// ```
	///
	/// - Returns: A view that grows vertically to fit its content without truncation
	func noTruncate() -> some View {
		fixedSize(horizontal: false, vertical: true)
	}
}
