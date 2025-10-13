import SwiftUI
import SFSafeSymbols

/// A horizontal row of quick action buttons with consistent styling
///
/// Features:
/// - Three action buttons (Edit, History, Delete)
/// - Consistent button styling with system background colors
/// - Accent color for Edit/History, red for Delete
/// - Responsive button sizing with equal width distribution
/// - Integrated haptic feedback support
///
/// **Appearance:**
/// - Horizontal layout with 12pt spacing between buttons
/// - Rounded rectangle buttons with 10pt corner radius
/// - SF Symbol icons with descriptive labels
/// - System secondary background with appropriate foreground colors
/// - Full-width button distribution
///
/// **Use Cases:**
/// - Detail views requiring edit, history, and delete actions
/// - Management interfaces with common CRUD operations
/// - Any screen needing standardized action buttons
/// - Patient record management interfaces
/// - Item detail screens in productivity apps
/// - Settings or configuration screens with modify/remove options
struct QuickActionsComponent: View {
	let onEditTapped: () -> Void
	let onHistoryTapped: () -> Void
	let onDeleteTapped: () -> Void

	@ScaledMetric private var buttonSpacing: CGFloat = 12
	@ScaledMetric private var verticalPadding: CGFloat = 12
	@ScaledMetric private var cornerRadius: CGFloat = 10

	var body: some View {
		HStack(spacing: buttonSpacing) {
			// Edit button
			Button {
				onEditTapped()
			} label: {
				Label("Edit", systemSymbol: .pencil)
					.font(.subheadline)
					.fontWeight(.medium)
					.frame(maxWidth: .infinity)
					.padding(.vertical, verticalPadding)
					.background {
						RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
							.fill(.regularMaterial)
					}
					.foregroundStyle(.accent)
			}
			.accessibilityLabel("Edit")
			.accessibilityHint("Opens edit form for this item")

			// History button
			Button {
				onHistoryTapped()
			} label: {
				Label("History", systemSymbol: .clock)
					.font(.subheadline)
					.fontWeight(.medium)
					.frame(maxWidth: .infinity)
					.padding(.vertical, verticalPadding)
					.background {
						RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
							.fill(.regularMaterial)
					}
					.foregroundStyle(.accent)
			}
			.accessibilityLabel("History")
			.accessibilityHint("View history and activity for this item")

			// Delete button
			Button {
				onDeleteTapped()
			} label: {
				Label("Delete", systemSymbol: .trash)
					.font(.subheadline)
					.fontWeight(.medium)
					.frame(maxWidth: .infinity)
					.padding(.vertical, verticalPadding)
					.background {
						RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
							.fill(.regularMaterial)
					}
					.foregroundStyle(.red)
			}
			.accessibilityLabel("Delete")
			.accessibilityHint("Delete this item permanently")
		}
		.padding(.horizontal)
	}
}

#if DEBUG
#Preview {
	QuickActionsComponent(
		onEditTapped: { print("Edit tapped") },
		onHistoryTapped: { print("History tapped") },
		onDeleteTapped: { print("Delete tapped") }
	)
	.padding()
}

#Preview("Dark Mode") {
	QuickActionsComponent(
		onEditTapped: { print("Edit tapped") },
		onHistoryTapped: { print("History tapped") },
		onDeleteTapped: { print("Delete tapped") }
	)
	.padding()
	.preferredColorScheme(.dark)
}
#endif