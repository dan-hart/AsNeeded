# SwiftRxNorm Repository Guidelines

## Project Structure & Modules
- `Sources/SwiftRxNorm/`: Core API client implementation and models
  - `SwiftRxNorm.swift`: Main `RxNormClient` with comprehensive API endpoints (~277 lines)
  - `RxNormNetworking.swift`: Protocol for dependency-injected HTTP networking
  - `RxNormDrug.swift`, `RxNormInteraction.swift`: Core data models
  - `RxNormError.swift`: Error handling types
  - `DrugsResponse.swift`, `InteractionResponse.swift`: Internal JSON response models
- `Tests/SwiftRxNormTests/`: Swift Testing test suite with mock and live endpoint tests
- `Package.swift`: Swift Package Manager configuration
- `README.md`: Comprehensive documentation with usage examples
- `LICENSE`: GNU GPLv3 license
- `CHANGELOG.md`: Version history and changes

## Build, Test, Run
- **Build (CLI)**: `swift build`
- **Tests (CLI)**: `swift test` (runs mocked unit tests)
- **Live API Tests**: Enable by setting `enabled = true` in `SwiftRxNormLiveEndpointTests.swift`
- **Package Validation**: `swift package resolve` to validate dependencies
- **Clean Build**: `swift package clean && swift build`

## Coding Style & Naming
- **Swift Version**: Swift 6.0+ with modern concurrency (async/await)
- **Indentation**: Use tabs, wrap at ~120 columns
- **API Design**: Follow Swift API Design Guidelines
- **Networking**: Protocol-oriented with dependency injection (`RxNormNetworking`)
- **Error Handling**: Comprehensive error types with `LocalizedError` conformance
- **Concurrency**: All API methods are `async throws` with `@MainActor` where appropriate
- **Data Models**: Pure Swift structs with `Codable`, `Sendable`, `Hashable` conformance
- **Access Control**: Public API surface, internal implementation details
- **Documentation**: Triple-slash comments for all public APIs

## Architecture Overview
- **Client Architecture**: `RxNormClient` as main entry point with injected networking
- **Networking Layer**: Protocol-based (`RxNormNetworking`) with `URLSession` default implementation
- **Data Models**: Lightweight, focused structs (`RxNormDrug`, `RxNormInteraction`)
- **Response Handling**: Internal response models for JSON parsing, public models for API surface
- **Error Strategy**: Specific error types (`RxNormError`) with appropriate context
- **Search Capabilities**: Multiple search strategies (exact, fuzzy, spelling suggestions, comprehensive)
- **Rate Limiting**: Designed to respect NLM's 20 requests/second limit

## API Client Design Patterns
- **Dependency Injection**: All networking is protocol-based for testability
- **Comprehensive Search**: `comprehensiveSearch()` combines multiple strategies
- **URL Construction**: Centralized base URL with endpoint-specific building
- **JSON Decoding**: Separate internal models for parsing, clean public models for consumers
- **Async/Await**: Modern concurrency throughout, no callbacks or completion handlers
- **Error Propagation**: Structured error handling with meaningful error types

## Testing Guidelines
- **Framework**: Swift Testing (`import Testing`, `@Test`, `#expect`)
- **Mock Strategy**: `MockNetworking` protocol implementation for unit tests
- **Live Tests**: Optional live endpoint tests (disabled by default for CI safety)
- **Coverage Areas**: 
  - JSON decoding for all endpoints
  - Error handling scenarios
  - Search functionality variants
  - Network layer abstraction
- **Test Structure**: Mirror source structure, descriptive test names
- **Assertions**: Use `#expect` for clear test intentions

## RxNorm API Integration
- **Base URL**: `https://rxnav.nlm.nih.gov/REST/`
- **Supported Endpoints**:
  - Drug search (`drugs.json`, `approximateTerm.json`)
  - RxCUI lookup and properties
  - Drug interactions (`interaction.json`)
  - Spelling suggestions (`spellingsuggestions.json`)
  - Synonym resolution (`allProperties.json`)
- **Response Handling**: Robust JSON parsing with fallback to empty results
- **Rate Limiting**: Client designed for 20 req/sec limit compliance
- **Error Handling**: Network errors, HTTP status codes, JSON parsing failures

## Medical Data Considerations
- **No Medical Advice**: Library provides data access only, no clinical recommendations
- **Data Attribution**: Include required NLM attribution in consuming applications
- **Privacy**: No sensitive patient data handled, only drug name lookups
- **Disclaimers**: Medical disclaimers required in documentation and consuming apps

## Package Distribution
- **License**: GNU GPLv3 (suitable for open source projects)
- **Dependencies**: Zero external dependencies (Foundation only)
- **Platform Support**: iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+
- **Swift Package Manager**: Primary distribution method
- **Versioning**: Semantic versioning with stable 1.x API

## .gitignore Requirements for Swift Packages
- **Build artifacts**: Ignore `.build/` directory (Swift Package Manager build artifacts)
- **Xcode integration**: Ignore `.swiftpm/xcode/` directory and user data files
- **System files**: Ignore `.DS_Store` and macOS system files
- **Dependencies**: Ignore `/Packages` directory if using package dependencies
- **User data**: Ignore `xcuserdata/`, `*.xcuserstate`, and Xcode user-specific files
- Standard Swift package .gitignore should include: `.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`, `*.xcuserstate`

## Agent-Specific Instructions
> You are an expert in Swift 6, networking, and REST API design. You understand medical data handling best practices and have experience with healthcare APIs. You prioritize robust error handling, comprehensive testing, and clear documentation for medical/healthcare applications.

### Critical API Integration Requirements
**ALWAYS ensure RxNorm API compliance and proper error handling:**

1. **After API changes**: Test against live RxNorm endpoints to verify compatibility
2. **Error scenarios**: Handle all HTTP status codes, network failures, and malformed JSON
3. **Rate limiting**: Respect NLM's 20 requests/second limit in client design
4. **Medical disclaimers**: Include appropriate medical disclaimers in documentation
5. **Data attribution**: Ensure NLM attribution requirements are documented

**Testing commands:**
- Unit tests: `swift test --filter SwiftRxNormTests`
- Live API tests: Enable in code and run `swift test --filter SwiftRxNormLiveTests`
- Package validation: `swift package resolve`
- Build verification: `swift build --configuration release`

### Medical Data Handling Guidelines
- **No Clinical Advice**: Never add clinical decision support or medical advice
- **Data Only**: Focus on data access, search, and retrieval functionality
- **Privacy First**: No patient data, identifiers, or sensitive medical information
- **Attribution**: Document NLM data source requirements for consumers
- **Disclaimers**: Include medical disclaimers in all documentation

**Never add features that could be construed as providing medical advice or clinical decision support.**