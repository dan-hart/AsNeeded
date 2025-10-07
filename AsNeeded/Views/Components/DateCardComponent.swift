import SwiftUI
import SFSafeSymbols

/// A interactive date selection card component with optional remove functionality
///
/// Features:
/// - Customizable icon and color theming
/// - Date display with formatted presentation
/// - Optional remove button when date is set
/// - "Add Date" state for empty dates
/// - Comprehensive accessibility support
/// - Smooth animations and visual feedback
///
/// **Appearance:**
/// - Colored circular icon with themed background
/// - Title and formatted date display
/// - Context-sensitive background (filled vs. bordered)
/// - Optional remove button with smooth transitions
/// - Rounded card design with consistent styling
///
/// **Use Cases:**
/// - Medication refill date tracking
/// - Event scheduling interfaces
/// - Deadline and reminder management
/// - Form date input sections
/// - Calendar integration components
/// - Any interface requiring date selection with visual feedback
struct DateCardComponent: View {
	@Environment(\.fontFamily) private var fontFamily
	let title: String
	let icon: SFSymbol
	let date: Date?
	let color: Color
	let onTap: () -> Void
	let onRemove: (() -> Void)?
	@ScaledMetric private var iconContentSpacing: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 36
	@ScaledMetric private var labelSpacing: CGFloat = 4
	@ScaledMetric private var addIconSpacing: CGFloat = 4
	@ScaledMetric private var cardPadding: CGFloat = 14
	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var borderWidth: CGFloat = 1

	init(
		title: String,
		icon: SFSymbol,
		date: Date?,
		color: Color,
		onTap: @escaping () -> Void,
		onRemove: (() -> Void)? = nil
	) {
		self.title = title
		self.icon = icon
		self.date = date
		self.color = color
		self.onTap = onTap
		self.onRemove = onRemove
	}

	var body: some View {
		Button(action: onTap) {
			HStack(spacing: iconContentSpacing) {
				// Icon with colored background
				ZStack {
					Circle()
						.fill(color.opacity(0.15))
						.frame(width: iconSize, height: iconSize)

					Image(systemSymbol: icon)
						.font(.customFont(fontFamily, style: .body, weight: .semibold))
						.foregroundStyle(color)
				}

				// Date info
				VStack(alignment: .leading, spacing: labelSpacing) {
					Text(title)
						.font(.customFont(fontFamily, style: .caption, weight: .medium))
						.foregroundStyle(.secondary)

					if let date = date {
						Text(date.formatted(date: .abbreviated, time: .omitted))
							.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
							.foregroundStyle(.primary)
					} else {
						HStack(spacing: addIconSpacing) {
							Image(systemSymbol: .plusCircle)
								.font(.customFont(fontFamily, style: .caption2))
							Text("Add Date")
								.font(.customFont(fontFamily, style: .subheadline))
						}
						.foregroundStyle(color)
					}
				}

				Spacer()

				// Remove button (only show if date is set and onRemove is provided)
				if date != nil, let onRemove = onRemove {
					Button(action: onRemove) {
						Image(systemSymbol: .xmarkCircleFill)
							.font(.customFont(fontFamily, style: .title3))
							.foregroundStyle(.tertiary)
							.symbolRenderingMode(.hierarchical)
					}
					.buttonStyle(.plain)
					.transition(.scale.combined(with: .opacity))
					.accessibilityLabel("Remove \(title.lowercased())")
				}
			}
			.padding(cardPadding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(date != nil ?
						Color(.tertiarySystemGroupedBackground) :
						color.opacity(0.05)
					)
					.overlay(
						RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
							.strokeBorder(
								date != nil ?
									color.opacity(0.15) :
									color.opacity(0.2),
								lineWidth: borderWidth
							)
					)
			)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(
			date.map { "\(title): \($0.formatted(date: .abbreviated, time: .omitted))" }
			?? "Add \(title.lowercased())"
		)
		.accessibilityHint(date != nil ? "Tap to edit \(title.lowercased())" : "Tap to add \(title.lowercased())")
	}
}

#if DEBUG
#Preview {
	VStack(spacing: 16) {
		DateCardComponent(
			title: "Last Refill",
			icon: .clockArrowTriangleheadCounterclockwiseRotate90,
			date: Date(),
			color: .blue,
			onTap: { print("Last refill tapped") },
			onRemove: { print("Remove last refill") }
		)

		DateCardComponent(
			title: "Next Refill",
			icon: .calendarBadgePlus,
			date: nil,
			color: .green,
			onTap: { print("Next refill tapped") }
		)
	}
	.padding()
}
#endif