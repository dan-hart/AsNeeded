import SwiftUI

/// Preference key to propagate content size from child views to parent via SwiftUI's preference system
///
/// This key is used internally by the `DynamicDetentModifier` to measure the actual content height
/// of a sheet's contents before determining which presentation detents to offer.
private struct ContentSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    /// Intelligently selects sheet presentation detents based on measured content size
    ///
    /// This modifier automatically determines whether a sheet should offer `.medium`, `.large`, or both
    /// detent options by measuring the actual content height and comparing it against available screen space.
    /// This creates an adaptive user experience where sheets with minimal content default to medium height,
    /// while sheets with extensive content skip directly to large height.
    ///
    /// ## How It Works
    ///
    /// 1. **Measurement Phase**: Uses GeometryReader + PreferenceKey to measure content height
    /// 2. **Screen Detection**: Captures screen height from the current window scene on appear
    /// 3. **Calculation Phase**: Estimates usable medium detent space (~35% of screen height)
    /// 4. **Decision Logic**:
    ///    - If content > 130% of medium space → Show only `.large` (content won't fit comfortably)
    ///    - If content ≤ 130% of medium space → Show both `.medium` and `.large` (user choice)
    ///
    /// ## Medium Detent Space Calculation
    ///
    /// The modifier estimates realistic usable space in a medium detent:
    /// - iPhone screens: ~850-950pt tall
    /// - Medium detent: ~50% of screen = 425-475pt
    /// - Minus safe areas (~100pt) and navigation (~50pt)
    /// - **Result**: ~275-325pt usable space = 35% of screen height
    ///
    /// The 1.3x multiplier (130%) provides comfortable padding to avoid cramped layouts.
    ///
    /// ## Visual Appearance
    ///
    /// - Always shows a visible drag indicator for discoverability
    /// - Sheets with only `.large` detent still allow dismiss-by-drag
    /// - Medium detent sheets can be expanded to large by dragging up
    ///
    /// ## Use Cases in AsNeeded
    ///
    /// 1. **Quick Actions**: Short sheets (dose logging, simple forms) default to medium
    /// 2. **Detail Views**: Content-heavy sheets (medication details, history) skip to large
    /// 3. **Adaptive Forms**: Forms that grow based on user input adjust detents dynamically
    /// 4. **Settings Panels**: Moderate content can offer both options for user preference
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// .sheet(isPresented: $showingSheet) {
    ///     VStack(spacing: 16) {
    ///         Text("Sheet Title")
    ///             .font(.headline)
    ///         // ... sheet content ...
    ///     }
    ///     .padding()
    ///     .dynamicDetent()  // Automatically selects appropriate detents
    /// }
    /// ```
    ///
    /// ## Performance Considerations
    ///
    /// - Measurement happens once on sheet appearance, not continuously
    /// - GeometryReader is confined to a hidden background, avoiding layout interference
    /// - Screen height is cached in state after first measurement
    /// - No performance impact on main content rendering
    ///
    /// ## Fallback Behavior
    ///
    /// If measurements aren't ready (e.g., during initial layout pass), defaults to offering
    /// both `.medium` and `.large` to ensure sheets are always accessible.
    ///
    /// - Returns: A view with intelligent presentation detents and visible drag indicator
    func dynamicDetent() -> some View {
        modifier(DynamicDetentModifier())
    }
}

private struct DynamicDetentModifier: ViewModifier {
    @State private var contentHeight: CGFloat = 0
    @State private var screenHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ContentSizePreferenceKey.self, value: geometry.size)
                }
            )
            .onPreferenceChange(ContentSizePreferenceKey.self) { size in
                contentHeight = size.height
            }
            .onAppear {
                // Get actual screen height from current window
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first
                {
                    screenHeight = window.bounds.height
                }
            }
            .presentationDetents(dynamicDetents)
            .presentationDragIndicator(.visible)
    }

    private var dynamicDetents: Set<PresentationDetent> {
        guard screenHeight > 0, contentHeight > 0 else {
            // Default fallback when measurements aren't ready
            return [.medium, .large]
        }

        // Calculate realistic medium detent space
        // iPhone screens: ~850-950pt tall, medium detent ~50% = 425-475pt
        // Minus safe areas (~100pt) and navigation (~50pt) = ~275-325pt usable
        let estimatedMediumSpace: CGFloat = screenHeight * 0.35

        // If content is significantly larger than medium space, default to large
        // Otherwise provide both options
        if contentHeight > estimatedMediumSpace * 1.3 {
            return [.large] // Content too large for comfortable medium detent
        } else {
            return [.medium, .large] // Content fits reasonably in medium
        }
    }
}
