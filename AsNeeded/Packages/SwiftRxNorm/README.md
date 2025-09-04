# SwiftRxNorm

[![Swift 6.0](https://img.shields.io/badge/swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS-lightgrey.svg)](https://github.com/apple/swift-package-manager)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://buymeacoffee.com/codedbydan)

A modern Swift client library for the **RxNorm API** from the U.S. National Library of Medicine (NLM). SwiftRxNorm provides type-safe, async/await access to RxNorm's comprehensive drug information database.

## ⚠️ Required NIH Disclaimer

> **This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health, Department of Health and Human Services; NLM is not responsible for the product and does not endorse or recommend this or any other product.**

## ⚠️ Important Medical Disclaimer

> **It is not the intention of NLM to provide specific medical advice, but rather to provide users with information to better understand their health and their medications. Users are urged to consult with a qualified physician for advice about medications.**

> **This library is for informational purposes only and should not be used as a substitute for professional medical advice, diagnosis, or treatment.**

## Features

- ✅ **Modern Swift 6**: Built with modern Swift concurrency (async/await)
- ✅ **Comprehensive API Coverage**: Access to all major RxNorm endpoints
- ✅ **Type-Safe**: Strongly typed responses with proper error handling
- ✅ **Multi-Platform**: iOS, macOS, watchOS, tvOS, and visionOS support
- ✅ **Dependency Injectable**: Protocol-based networking for easy testing
- ✅ **Advanced Fuzzy Matching**: Robust algorithm handling typos, phonetic variations, and common misspellings
- ✅ **Smart Autocomplete**: Optimized for real-time suggestions with caching
- ✅ **Intelligent Search**: Multiple strategies with relevance scoring and deduplication
- ✅ **Built-in Caching**: Automatic result caching for improved performance
- ✅ **Common Corrections**: Handles brand/generic name confusion and common misspellings
- ✅ **Rate Limit Friendly**: Designed to work within NLM's 20 requests/second limit

## Installation

### Swift Package Manager

Add SwiftRxNorm to your project via Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftRxNorm.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SwiftRxNorm

let client = RxNormClient()

// NEW: Optimized autocomplete for real-time suggestions
let autocomplete = try await client.autocomplete("asp")
for suggestion in autocomplete.suggestions {
    print("\(suggestion.drug.name) - Score: \(suggestion.score)")
}

// NEW: Enhanced search with fuzzy matching and scoring
let results = try await client.enhancedSearch("asprin") // Handles typos!
for result in results {
    print("\(result.drug.name) - Match: \(result.score * 100)%")
}

// Search with custom options
let exactResults = try await client.enhancedSearch("aspirin", options: .exact)
let autoResults = try await client.autocomplete("ibu", options: .autocomplete)

// Legacy methods still available
let drugs = try await client.fetchDrugsByName("aspirin")
let interactions = try await client.fetchInteractionsForRxcui("1191")
```

## API Reference

### Core Methods

#### Enhanced Search & Autocomplete (NEW)
```swift
// Optimized autocomplete with caching and scoring
func autocomplete(_ query: String, options: SearchOptions = .autocomplete) async throws -> AutocompleteResult

// Advanced search with fuzzy matching and relevance scoring
func enhancedSearch(_ query: String, options: SearchOptions = .comprehensive) async throws -> [RxNormSearchResult]
```

#### Legacy Search Methods
```swift
// Basic drug search
func fetchDrugsByName(_ name: String) async throws -> [RxNormDrug]

// Fuzzy/approximate search
func suggestDrugs(_ term: String, max: Int = 25) async throws -> [RxNormDrug]

// Comprehensive search (combines multiple strategies)
func comprehensiveSearch(_ term: String) async throws -> [RxNormDrug]

// Spelling suggestions
func getSpellingSuggestions(_ term: String) async throws -> [String]
```

#### Drug Information
```swift
// Get RxCUI for a drug name
func fetchRxcuiByName(_ name: String) async throws -> String?

// Get synonyms for an RxCUI
func fetchDrugSynonyms(for rxCui: String) async throws -> [String]

// Get properties for an RxCUI
func fetchPropertiesForRxcui(_ rxCui: String) async throws -> [String: String]
```

#### Drug Interactions
```swift
// Get all interactions for an RxCUI
func fetchInteractionsForRxcui(_ rxCui: String) async throws -> [RxNormInteraction]
```

### Data Models

#### RxNormDrug
```swift
public struct RxNormDrug: Codable, Hashable, Sendable {
    public let rxCUI: String    // RxNorm Concept Unique Identifier
    public let name: String     // Normalized drug name
}
```

#### RxNormSearchResult (NEW)
```swift
public struct RxNormSearchResult: Codable, Hashable, Sendable {
    public let drug: RxNormDrug
    public let score: Double            // Relevance score (0.0-1.0)
    public let source: SearchSource     // Where the result came from
    public let isExactMatch: Bool       // Whether this is an exact match
    public let matchedTerm: String?     // The term that matched
}
```

#### AutocompleteResult (NEW)
```swift
public struct AutocompleteResult: Sendable {
    public let suggestions: [RxNormSearchResult]
    public let hasMore: Bool
    public let query: String
    public let searchTime: TimeInterval
}
```

#### SearchOptions (NEW)
```swift
public struct SearchOptions: Sendable {
    public let maxResults: Int
    public let includeApproximate: Bool
    public let includeSpellingCorrections: Bool
    public let includeSynonyms: Bool
    public let minScore: Double
    public let sortByRelevance: Bool
    
    // Preset configurations
    public static let autocomplete     // Optimized for real-time autocomplete
    public static let comprehensive    // Maximum coverage search
    public static let exact            // Exact matches only
}
```

#### RxNormInteraction
```swift
public struct RxNormInteraction: Codable, Hashable, Sendable {
    public let description: String
    public let drugs: [RxNormDrug]
}
```

### Error Handling

SwiftRxNorm provides comprehensive error handling through the `RxNormError` enum:

```swift
public enum RxNormError: Error, LocalizedError {
    case invalidRequest     // Malformed URL or request
    case invalidResponse    // Non-200 HTTP status
    case decodingFailed     // JSON parsing error
}
```

All methods properly propagate network errors and decoding errors, making error handling straightforward:

```swift
do {
    let drugs = try await client.fetchDrugsByName("aspirin")
    // Handle success
} catch RxNormError.invalidRequest {
    // Handle invalid request
} catch RxNormError.invalidResponse {
    // Handle server error
} catch RxNormError.decodingFailed {
    // Handle parsing error
} catch {
    // Handle other errors (network, etc.)
}
```

## Testing

SwiftRxNorm includes comprehensive test coverage with both unit tests and optional live endpoint tests:

```bash
# Run unit tests (mocked responses)
swift test

# Run live endpoint tests (requires network)
# Enable by setting `enabled = true` in SwiftRxNormLiveTests
swift test
```

### Dependency Injection for Testing

SwiftRxNorm uses protocol-based networking, making it easy to inject mock responses for testing:

```swift
struct MockNetworking: RxNormNetworking {
    let mockData: Data
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (mockData, response)
    }
}

let client = RxNormClient(network: MockNetworking(mockData: mockJSON))
```

## Rate Limiting & Best Practices

The NLM RxNorm API has the following guidelines:

- **Rate Limit**: 20 requests per second per IP address
- **Caching**: Results should be cached for 12-24 hours when possible
- **High Volume**: Consider using "RxNav-in-a-Box" for applications requiring high-volume access

SwiftRxNorm is designed to work efficiently within these constraints:

```swift
// Good: Use comprehensive search for better results with fewer requests
let results = try await client.comprehensiveSearch("aspirin")

// Good: Cache RxCUI lookups and reuse them
let rxcui = try await client.fetchRxcuiByName("warfarin")
// Store rxcui for later use instead of repeated lookups
```

## Displaying Required Disclaimers

**IMPORTANT**: The NIH requires that applications using RxNorm data display their disclaimer to users. SwiftRxNorm provides constants to make this easy:

```swift
import SwiftRxNorm
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.title)
            
            // Display the required NIH disclaimer
            Text(RxNormConstants.requiredDisclaimer)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Or use the full disclaimer with medical warnings
            Text(RxNormConstants.fullDisclaimer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// For UIKit apps
class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let disclaimerLabel = UILabel()
        disclaimerLabel.text = RxNormConstants.requiredDisclaimer
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.font = .preferredFont(forTextStyle: .caption1)
        disclaimerLabel.textColor = .secondaryLabel
        // Add to your view hierarchy
    }
}
```

Available disclaimer constants:
- `RxNormConstants.requiredDisclaimer` - The required NIH disclaimer
- `RxNormConstants.shortDisclaimer` - A shorter version for space-constrained UIs
- `RxNormConstants.medicalDisclaimer` - Medical advice disclaimer
- `RxNormConstants.fullDisclaimer` - Combined NIH and medical disclaimers

## Examples

### Search with Error Handling
```swift
import SwiftRxNorm

func searchMedication(_ query: String) async {
    let client = RxNormClient()
    
    do {
        let results = try await client.comprehensiveSearch(query)
        
        if results.isEmpty {
            // Try spelling suggestions
            let suggestions = try await client.getSpellingSuggestions(query)
            print("No results found. Did you mean: \(suggestions.joined(separator: ", "))?")
        } else {
            print("Found \(results.count) results:")
            for drug in results {
                print("- \(drug.name) (RxCUI: \(drug.rxCUI))")
            }
        }
    } catch RxNormError.invalidRequest {
        print("Invalid search query")
    } catch RxNormError.invalidResponse {
        print("RxNorm service unavailable")
    } catch {
        print("Network error: \(error.localizedDescription)")
    }
}
```

### Drug Interaction Checker
```swift
import SwiftRxNorm

func checkInteractions(drugName: String) async {
    let client = RxNormClient()
    
    do {
        guard let rxcui = try await client.fetchRxcuiByName(drugName) else {
            print("Drug not found")
            return
        }
        
        let interactions = try await client.fetchInteractionsForRxcui(rxcui)
        
        if interactions.isEmpty {
            print("No known interactions for \(drugName)")
        } else {
            print("Found \(interactions.count) interactions for \(drugName):")
            for interaction in interactions {
                print("- \(interaction.description)")
                let drugNames = interaction.drugs.map(\.name).joined(separator: " + ")
                print("  Drugs: \(drugNames)")
            }
        }
    } catch {
        print("Error checking interactions: \(error.localizedDescription)")
    }
}
```

## Requirements

- **Swift**: 6.0+
- **Platforms**: iOS 15.0+ / macOS 12.0+ / watchOS 8.0+ / tvOS 15.0+ / visionOS 1.0+
- **Dependencies**: None (uses Foundation only)

## Data Source & Attribution

This library provides access to **RxNorm**, a standardized nomenclature for clinical drugs developed by the National Library of Medicine (NLM). RxNorm:

- Links drug names from various vocabularies
- Provides normalized names for clinical drugs
- Is updated monthly by the NLM
- Is freely available and non-proprietary

### ⚠️ Required Attribution

**IMPORTANT**: The NIH requires that all applications using RxNorm data display the following disclaimer:

> "This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health, Department of Health and Human Services; NLM is not responsible for the product and does not endorse or recommend this or any other product."

You can easily display this in your app using:
```swift
Text(RxNormConstants.requiredDisclaimer)
```

## License

SwiftRxNorm is released under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.

The RxNorm data itself is in the public domain and is provided by the U.S. National Library of Medicine.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/SwiftRxNorm/issues)
- **RxNorm Documentation**: [RxNorm API Documentation](https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html)
- **Terms of Service**: [NLM Terms of Service](https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html)

---

**Disclaimer**: This software is provided "as is" without warranty of any kind. The authors and contributors are not responsible for any consequences of using this software. Always consult with healthcare professionals for medical advice.