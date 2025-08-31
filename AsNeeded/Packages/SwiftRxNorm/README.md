# SwiftRxNorm

[![Swift 6.0](https://img.shields.io/badge/swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS-lightgrey.svg)](https://github.com/apple/swift-package-manager)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://buymeacoffee.com/codedbydan)

A modern Swift client library for the **RxNorm API** from the U.S. National Library of Medicine (NLM). SwiftRxNorm provides type-safe, async/await access to RxNorm's comprehensive drug information database.

## ⚠️ Important Medical Disclaimer

> **This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health, Department of Health and Human Services. NLM is not responsible for the product and does not endorse or recommend this or any other product.**

> **It is not the intention of NLM to provide specific medical advice, but rather to provide users with information to better understand their health and their medications. Users are urged to consult with a qualified physician for advice about medications.**

> **This library is for informational purposes only and should not be used as a substitute for professional medical advice, diagnosis, or treatment.**

## Features

- ✅ **Modern Swift 6**: Built with modern Swift concurrency (async/await)
- ✅ **Comprehensive API Coverage**: Access to all major RxNorm endpoints
- ✅ **Type-Safe**: Strongly typed responses with proper error handling
- ✅ **Multi-Platform**: iOS, macOS, watchOS, tvOS, and visionOS support
- ✅ **Dependency Injectable**: Protocol-based networking for easy testing
- ✅ **Comprehensive Search**: Multiple search strategies with deduplication
- ✅ **Fuzzy Matching**: Spelling suggestions and approximate term matching
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

// Search for drugs by name
let drugs = try await client.fetchDrugsByName("aspirin")
print(drugs) // [RxNormDrug(rxCUI: "1191", name: "Aspirin")]

// Get comprehensive search results (combines multiple strategies)
let results = try await client.comprehensiveSearch("asprin") // Note: misspelled
print(results) // Returns results including spelling corrections

// Get drug interactions
if let rxcui = try await client.fetchRxcuiByName("warfarin") {
    let interactions = try await client.fetchInteractionsForRxcui(rxcui)
    print(interactions)
}

// Get spelling suggestions
let suggestions = try await client.getSpellingSuggestions("ibuprofn")
print(suggestions) // ["Ibuprofen", ...]
```

## API Reference

### Core Methods

#### Drug Search
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

### Required Attribution

When using SwiftRxNorm in your applications, you must include appropriate attribution to the National Library of Medicine as the data source. A suggested attribution notice:

> "Drug data provided by RxNorm from the U.S. National Library of Medicine."

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