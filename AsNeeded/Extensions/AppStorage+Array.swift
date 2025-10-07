import SwiftUI
import Foundation

/// Extension to enable AppStorage support for String arrays through retroactive RawRepresentable conformance
///
/// This extension uses Swift's retroactive conformance feature to make `[String]` conform to `RawRepresentable`,
/// which is required for types to be stored in UserDefaults via the `@AppStorage` property wrapper.
///
/// ## Implementation Details
///
/// The extension serializes arrays to/from JSON strings for storage in UserDefaults:
/// - **Encoding**: Array → JSON Data → UTF-8 String → UserDefaults
/// - **Decoding**: UserDefaults → UTF-8 String → JSON Data → Array
///
/// ## Fallback Behavior
///
/// - **Initialization**: Returns `nil` if the raw string cannot be decoded (invalid JSON, wrong format, etc.)
///   When `@AppStorage` receives `nil`, it uses the default value provided in the property wrapper
/// - **Encoding**: Returns `"[]"` (empty array JSON) if encoding fails, preventing data loss
///
/// ## Use Cases
///
/// This extension enables several features in AsNeeded:
/// 1. **Quick Phrases**: Store user's frequently used note phrases for medication logging
///    ```swift
///    @AppStorage(UserDefaultsKeys.quickPhrases) private var quickPhrases: [String] = []
///    ```
/// 2. **Search History**: Persist recent medication searches across app launches
/// 3. **Custom Lists**: Store any user-defined string lists that need to survive app restarts
///
/// ## Example Usage
///
/// ```swift
/// struct SettingsView: View {
///     @AppStorage(UserDefaultsKeys.quickPhrases) private var quickPhrases: [String] = ["Took with food", "Before bed"]
///
///     var body: some View {
///         List {
///             ForEach(quickPhrases, id: \.self) { phrase in
///                 Text(phrase)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Performance Considerations
///
/// - JSON encoding/decoding is performed on each get/set, so this is best suited for small-to-medium arrays
/// - For large datasets or complex types, consider using Boutique stores instead
/// - Changes trigger SwiftUI view updates automatically via `@AppStorage`'s observation mechanism
///
/// ## Thread Safety
///
/// UserDefaults is thread-safe, so this extension can be safely used from any thread. However, SwiftUI
/// property wrappers like `@AppStorage` must be accessed from the main thread as they trigger view updates.
extension Array: @retroactive RawRepresentable where Element == String {
	public init?(rawValue: String) {
		guard let data = rawValue.data(using: .utf8),
			  let result = try? JSONDecoder().decode([String].self, from: data)
		else { return nil }
		self = result
	}

	public var rawValue: String {
		guard let data = try? JSONEncoder().encode(self),
			  let result = String(data: data, encoding: .utf8)
		else { return "[]" }
		return result
	}
}