import UIKit

/// Manages the appearance of navigation bars throughout the app to support custom fonts
/// This provides a global, performant solution for applying custom fonts to navigation titles
enum NavigationBarAppearanceManager {
    // MARK: - Font Cache

    private nonisolated(unsafe) static var fontCache: [String: UIFont] = [:]

    /// Configure navigation bar appearance with the specified font family
    /// Call this when the app launches or when the font family changes
    /// - Parameter fontFamily: The font family to apply to navigation bars
    @MainActor
    static func configureAppearance(for fontFamily: FontFamily) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // For system font, use iOS native navigation title styling
        // Only apply custom fonts for accessibility fonts (Atkinson Hyperlegible, OpenDyslexic)
        if fontFamily != .system {
            // Configure large title font
            if let largeTitleFont = cachedFont(for: fontFamily, style: .largeTitle) {
                appearance.largeTitleTextAttributes = [
                    .font: largeTitleFont,
                ]
            }

            // Configure inline title font
            if let titleFont = cachedFont(for: fontFamily, style: .headline) {
                appearance.titleTextAttributes = [
                    .font: titleFont,
                ]
            }
        }

        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Configure segmented control fonts
        if fontFamily != .system, let segmentFont = cachedFont(for: fontFamily, style: .body) {
            UISegmentedControl.appearance().setTitleTextAttributes([.font: segmentFont], for: .normal)
        } else if fontFamily == .system {
            // Reset segmented control to system default
            UISegmentedControl.appearance().setTitleTextAttributes(nil, for: .normal)
        }
    }

    // MARK: - Font Caching

    /// Get or create a cached UIFont for the specified font family and style
    /// This avoids repeatedly creating the same fonts, improving performance
    private static func cachedFont(for fontFamily: FontFamily, style: UIFont.TextStyle) -> UIFont? {
        let cacheKey = "\(fontFamily.rawValue)-\(style.rawValue)"

        if let cached = fontCache[cacheKey] {
            return cached
        }

        let font: UIFont

        switch fontFamily {
        case .system:
            font = UIFont.preferredFont(forTextStyle: style)

        case .atkinsonHyperlegible, .openDyslexic:
            let baseSize = UIFont.preferredFont(forTextStyle: style).pointSize
            let fontName = style.isBoldStyle ? fontFamily.boldFontName : fontFamily.fontName

            if let customFont = UIFont(name: fontName, size: baseSize) {
                // Scale the font to maintain dynamic type
                let metrics = UIFontMetrics(forTextStyle: style)
                font = metrics.scaledFont(for: customFont)
            } else {
                // Fallback to system font if custom font not available
                font = UIFont.preferredFont(forTextStyle: style)
            }
        }

        fontCache[cacheKey] = font
        return font
    }

    /// Clear the font cache (call when memory warning occurs)
    static func clearCache() {
        fontCache.removeAll()
    }
}

// MARK: - UIFont.TextStyle Extensions

private extension UIFont.TextStyle {
    /// Determine if this text style typically uses bold weight
    var isBoldStyle: Bool {
        switch self {
        case .largeTitle, .title1, .title2, .title3, .headline:
            return true
        default:
            return false
        }
    }
}
