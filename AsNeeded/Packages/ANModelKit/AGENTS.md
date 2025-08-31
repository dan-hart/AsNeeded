# ANModelKit Repository Guidelines

## Project Structure & Modules
- `Sources/ANModelKit/`: Core data models for medication tracking applications
  - `ANModelKit.swift`: Package entry point (minimal, 1 line)
  - `ANMedicationConcept.swift`: Medication model with privacy features (~47 lines)
  - `ANDoseConcept.swift`: Dose amount and unit model (~23 lines)
  - `ANEventConcept.swift`: Event tracking model with types (~49 lines)
  - `ANUnitConcept.swift`: Comprehensive medication units system (~179 lines)
- `Tests/ANModelKitTests/`: Comprehensive Swift Testing suite (~268 lines, 22+ tests)
- `Package.swift`: Swift Package Manager configuration
- `README.md`: Comprehensive documentation with usage examples and integration guides
- `LICENSE`: GNU GPLv3 license
- `CHANGELOG.md`: Version history and feature additions

## Build, Test, Run
- **Build (CLI)**: `swift build`
- **Tests (CLI)**: `swift test` (runs 22+ comprehensive unit tests)
- **Package Validation**: `swift package resolve` to validate dependencies
- **Clean Build**: `swift package clean && swift build`
- **Test Coverage**: High coverage with comprehensive model, enum, and edge case testing

## Coding Style & Naming
- **Swift Version**: Swift 6.2+ with modern concurrency and Sendable conformance
- **Indentation**: Use tabs, wrap at ~120 columns
- **Model Design**: Pure Swift structs with comprehensive protocol conformance
- **Privacy First**: Built-in redaction methods for sensitive medical data
- **Identifiers**: UUID-based identifiers following Boutique best practices
- **Access Control**: Public API surface with internal implementation details
- **Naming**: Prefix all types with `AN` (AsNeeded), descriptive enum cases
- **Documentation**: Triple-slash comments with clinical context for medical units

## Architecture Overview
- **Domain Models**: Pure data structures with no business logic or dependencies
- **Privacy Architecture**: Built-in `redacted()` methods for sensitive data handling
- **Type Safety**: Strong typing for medication units, event types, and relationships
- **Protocol Conformance**: `Identifiable`, `Codable`, `Equatable`, `Hashable`, `Sendable`
- **Zero Dependencies**: Foundation-only, no external dependencies
- **Extensibility**: Enum-based designs allow future expansion while maintaining compatibility

## Data Model Design Patterns
- **Unique Identification**: UUID identifiers for all primary entities (Boutique compatible)
- **Optional Properties**: Flexible initialization with optional parameters
- **Relationship Modeling**: Composition-based relationships (Event contains Medication/Dose)
- **Privacy by Design**: Sensitive data can be redacted while preserving structure
- **Clinical Context**: Medical units include clinical descriptions and standardized abbreviations
- **Localization Ready**: Unit names support singular/plural forms with locale awareness

## Medical Data Models
### Core Entities
- **ANMedicationConcept**: Medication definitions with clinical names, nicknames, quantities, refill tracking
- **ANDoseConcept**: Dose amounts with standardized medical units
- **ANEventConcept**: Event tracking (dose taken, reconciliation, suspected side effects)
- **ANUnitConcept**: 30+ standardized medication units with clinical context

### Privacy Features
- **Redaction Methods**: Built-in methods to sanitize sensitive medical information
- **Structure Preservation**: Redacted data maintains object structure for analytics
- **Selective Privacy**: Only sensitive fields (names) are redacted, quantities preserved

## Testing Guidelines
- **Framework**: Swift Testing (`import Testing`, `@Test`, `#expect`)
- **Coverage**: 22+ tests covering initialization, relationships, privacy, serialization
- **Test Categories**:
  - Model initialization and property setting
  - Codable serialization/deserialization round-trips
  - Privacy redaction functionality
  - Unit system completeness and correctness
  - Enum case handling and edge cases
- **Test Structure**: Organized by model type, descriptive test names
- **Assertions**: Use `#expect` with clear test intentions

## Medical Unit System
- **Comprehensive Units**: 30+ standardized medication units covering all common forms
- **Clinical Context**: Each unit includes clinical descriptions for healthcare professionals
- **Standard Abbreviations**: Medical abbreviations following clinical conventions
- **Display Names**: User-friendly names with singular/plural support
- **Common Subsets**: Curated lists for UI pickers and common use cases
- **Extensibility**: New units can be added without breaking existing code

## Privacy & Data Protection
- **Sensitive Data**: Clinical names and user nicknames are considered sensitive
- **Redaction Strategy**: Replace sensitive text with `[REDACTED]` placeholder
- **Non-Sensitive Data**: Quantities, dates, units, and IDs are preserved
- **Analytics Safe**: Redacted data suitable for usage analytics and debugging
- **HIPAA Considerations**: Designed with healthcare privacy requirements in mind

## Package Distribution
- **License**: GNU GPLv3 (suitable for open source healthcare projects)
- **Dependencies**: Zero external dependencies (Foundation only)
- **Platform Support**: iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+
- **Swift Package Manager**: Primary distribution method
- **Versioning**: Semantic versioning with stable API design

## .gitignore Requirements for Swift Packages
- **Build artifacts**: Ignore `.build/` directory (Swift Package Manager build artifacts)
- **Xcode integration**: Ignore `.swiftpm/xcode/` directory and user data files
- **System files**: Ignore `.DS_Store` and macOS system files
- **Dependencies**: Ignore `/Packages` directory if using package dependencies
- **User data**: Ignore `xcuserdata/`, `*.xcuserstate`, and Xcode user-specific files
- Standard Swift package .gitignore should include: `.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`, `*.xcuserstate`

## Integration Patterns
- **Core Data**: Easy mapping to/from Core Data entities
- **SwiftUI**: Direct binding support with `Identifiable` conformance
- **Boutique**: Compatible UUID-based identifiers
- **JSON APIs**: Full `Codable` support for network serialization
- **Analytics**: Privacy-safe redacted data for usage tracking

## Agent-Specific Instructions
> You are an expert in Swift 6, healthcare data modeling, and privacy-focused design. You understand medical terminology, medication management workflows, and healthcare app requirements. You prioritize type safety, privacy protection, and comprehensive testing for medical applications.

### Critical Data Model Requirements
**ALWAYS maintain data integrity and privacy standards:**

1. **Privacy First**: Any new sensitive fields must have redaction support
2. **Type Safety**: Use strong typing for all medical concepts (units, event types)
3. **Medical Accuracy**: Ensure medical units and terminology are clinically accurate
4. **Comprehensive Testing**: All new models and enum cases must have full test coverage
5. **Backward Compatibility**: Maintain API stability for existing consumers

**Testing commands:**
- Full test suite: `swift test`
- Specific model tests: `swift test --filter "ANMedicationConcept"`
- Unit system tests: `swift test --filter "ANUnitConcept"`
- Privacy tests: `swift test --filter "redacted"`

### Medical Data Modeling Guidelines
- **Clinical Accuracy**: Verify medical units and terminology with healthcare standards
- **Privacy Protection**: New sensitive fields require redaction methods
- **Relationships**: Maintain clear entity relationships without tight coupling
- **Extensibility**: Design for future medical concepts and units
- **Documentation**: Include clinical context for medical professionals

### Healthcare App Integration
- **HIPAA Awareness**: Design with healthcare privacy requirements in mind
- **User Experience**: Support both clinical names and user-friendly nicknames
- **Workflow Support**: Model real medication management workflows
- **Analytics Safety**: Ensure redacted data is safe for usage analytics
- **Accessibility**: Consider healthcare accessibility requirements

**Never store or model actual patient health information - this is a medication tracking framework only.**