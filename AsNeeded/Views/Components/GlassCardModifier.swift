import SFSafeSymbols
import SwiftUI

/// A quiet, opaque content card. The legacy name is retained for existing form call sites.
/// Liquid Glass belongs to the controls/navigation layer, which the system renders.
struct GlassCardModifier: ViewModifier {

    let cornerRadius: CGFloat
    let padding: CGFloat

    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 20
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.background(
				Color(.secondarySystemGroupedBackground),
				in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
			)
	}

}

extension View {
    /// Groups readable form content on an opaque system surface.
    func glassCard(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 20
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            padding: padding
        ))
    }
}

#if DEBUG
    #Preview {
        @Previewable @Environment(\.fontFamily) var fontFamily

        VStack(spacing: 20) {
            Text("Default Glass Card")
                .font(.customFont(fontFamily, style: .headline))
                .glassCard()

            VStack {
                Text("Custom Glass Card")
                    .font(.customFont(fontFamily, style: .headline))
                Text("With custom parameters")
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundStyle(.secondary)
            }
            .glassCard(cornerRadius: 12, padding: 16)

            HStack {
                Image(systemSymbol: .starFill)
                    .foregroundStyle(.yellow)
                Text("Compact Card")
                    .font(.customFont(fontFamily, style: .body))
            }
            .glassCard(cornerRadius: 8, padding: 12)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
#endif
