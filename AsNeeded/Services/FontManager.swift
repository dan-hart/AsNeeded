import CoreText
import Foundation
import OSLog
import UIKit

/// Service responsible for registering and managing custom fonts in the app
/// Ensures accessibility fonts are available throughout the application
final class FontManager {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AsNeeded", category: "FontManager")

	/// Register all custom fonts at app launch
	/// Should be called early in the app lifecycle (e.g., App.init())
	static func registerCustomFonts() {
		logger.info("Starting custom font registration")

		// Register Atkinson Hyperlegible fonts
		registerAtkinsonHyperlegibleFonts()

		// Register OpenDyslexic fonts
		registerOpenDyslexicFonts()

		logger.info("Custom font registration completed")
	}

	// MARK: - Private Registration Methods
	private static func registerAtkinsonHyperlegibleFonts() {
		let fontFiles = [
			"AtkinsonHyperlegible-Regular.ttf",
			"AtkinsonHyperlegible-Bold.ttf",
			"AtkinsonHyperlegible-Italic.ttf",
			"AtkinsonHyperlegible-BoldItalic.ttf"
		]

		for fontFile in fontFiles {
			registerFont(fileName: fontFile, fontFamily: "Atkinson Hyperlegible")
		}
	}

	private static func registerOpenDyslexicFonts() {
		let fontFiles = [
			"OpenDyslexic-Regular.ttf",
			"OpenDyslexic-Bold.ttf"
		]

		for fontFile in fontFiles {
			registerFont(fileName: fontFile, fontFamily: "OpenDyslexic")
		}
	}

	private static func registerFont(fileName: String, fontFamily: String) {
		// Try to find font in the main bundle first (in Resources/Fonts subdirectory or main bundle)
		guard let fontURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf", subdirectory: "Resources/Fonts") ??
			  Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") else {
			logger.error("Failed to find font file: \(fileName)")
			return
		}

		// For iOS 18+, use the newer API if available
		if #available(iOS 18.0, *) {
			var error: Unmanaged<CFError>?
			if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
				logger.info("Successfully registered font: \(fileName)")
			} else {
				if let error = error?.takeRetainedValue() {
					let errorDescription = CFErrorCopyDescription(error)
					logger.error("Failed to register font \(fileName): \(String(describing: errorDescription))")
				} else {
					logger.error("Failed to register font \(fileName): Unknown error")
				}
			}
		} else {
			// Fallback to older API for iOS 17 and below
			guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
				logger.error("Failed to create data provider for font: \(fileName)")
				return
			}

			guard let font = CGFont(fontDataProvider) else {
				logger.error("Failed to create CGFont from data provider: \(fileName)")
				return
			}

			var error: Unmanaged<CFError>?
			if CTFontManagerRegisterGraphicsFont(font, &error) {
				logger.info("Successfully registered font: \(fileName)")
			} else {
				if let error = error?.takeRetainedValue() {
					let errorDescription = CFErrorCopyDescription(error)
					logger.error("Failed to register font \(fileName): \(String(describing: errorDescription))")
				} else {
					logger.error("Failed to register font \(fileName): Unknown error")
				}
			}
		}
	}

	// MARK: - Font Availability Checking
	/// Check if a custom font family is available for use
	/// - Parameter fontFamily: The FontFamily enum case to check
	/// - Returns: True if the font is available, false otherwise
	static func isFontAvailable(_ fontFamily: FontFamily) -> Bool {
		switch fontFamily {
		case .system:
			return true // System font is always available
		case .atkinsonHyperlegible:
			return isFontRegistered("AtkinsonHyperlegible-Regular")
		case .openDyslexic:
			return isFontRegistered("OpenDyslexicThree-Regular")
		}
	}

	private static func isFontRegistered(_ fontName: String) -> Bool {
		// Check if the specific font name is available
		return UIFont(name: fontName, size: 12) != nil
	}

	// MARK: - Font Information
	/// Get detailed information about all available custom fonts
	/// Useful for debugging and testing
	static func getAvailableFontInfo() -> [String: [String]] {
		var fontInfo: [String: [String]] = [:]

		// Check Atkinson Hyperlegible
		let atkinsonFonts = ["AtkinsonHyperlegible-Regular", "AtkinsonHyperlegible-Bold", "AtkinsonHyperlegible-Italic", "AtkinsonHyperlegible-BoldItalic"]
		fontInfo["Atkinson Hyperlegible"] = atkinsonFonts.filter { isFontRegistered($0) }

		// Check OpenDyslexic
		let openDyslexicFonts = ["OpenDyslexicThree-Regular", "OpenDyslexicThree-Bold"]
		fontInfo["OpenDyslexic"] = openDyslexicFonts.filter { isFontRegistered($0) }

		return fontInfo
	}
}