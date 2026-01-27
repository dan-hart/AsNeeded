// Color+Hex.swift
// Extension to convert between SwiftUI Color and hex strings for medication color customization

import ANModelKit
import SwiftUI

extension Color {
    /// Initializes a Color from a hex string
    /// - Parameter hex: Hex string in format "#RRGGBB" or "RRGGBB"
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove # if present
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        // Ensure we have exactly 6 characters
        guard hexString.count == 6 else { return nil }

        // Convert to integer
        guard let hexValue = Int(hexString, radix: 16) else { return nil }

        let red = Double((hexValue >> 16) & 0xFF) / 255.0
        let green = Double((hexValue >> 8) & 0xFF) / 255.0
        let blue = Double(hexValue & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    /// Converts a Color to a hex string representation
    /// - Returns: Hex string in format "#RRGGBB" or nil if conversion fails
    func toHex() -> String? {
        // Extract RGB components using UIColor
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let redInt = Int(red * 255)
        let greenInt = Int(green * 255)
        let blueInt = Int(blue * 255)

        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
    }
}

extension ANMedicationConcept {
    /// Returns the display color for this medication, falling back to accent color if none set
    var displayColor: Color {
        if let hexColor = displayColorHex {
            return Color(hex: hexColor) ?? .accent
        }
        return .accent
    }

    /// Validates if a hex string is valid for displayColorHex
    /// - Parameter hex: Hex string to validate
    /// - Returns: True if valid, false otherwise
    static func isValidHex(_ hex: String) -> Bool {
        Color(hex: hex) != nil
    }
}
