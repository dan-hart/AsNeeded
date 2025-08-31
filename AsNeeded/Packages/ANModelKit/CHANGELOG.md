# Changelog

All notable changes to ANModelKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of ANModelKit
- `ANMedicationConcept` for medication tracking with privacy-focused redaction
- `ANDoseConcept` for dose amount and unit management
- `ANEventConcept` for medication event tracking (dose taken, reconciliation, side effects)
- `ANUnitConcept` enum with 30+ standardized medication units
- Comprehensive unit system with clinical descriptions, abbreviations, and display names
- Privacy-first design with built-in redaction capabilities
- Full Swift 6.2 support with modern concurrency
- Multi-platform support (iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+)
- Zero external dependencies (Foundation only)
- Comprehensive test coverage with 22+ unit tests
- Boutique-compatible UUID identifiers
- Complete Codable support for all models
- Localization-ready singular/plural unit names

### Technical Features
- Sendable conformance for all public types
- Type-safe medication unit system
- Privacy redaction methods for sensitive medical data
- Comprehensive API documentation
- Swift Testing framework integration
- Equatable, Hashable, and Identifiable conformance where appropriate

### Documentation
- Complete README with usage examples
- Medical disclaimers and privacy guidance  
- API reference documentation
- Integration examples for SwiftUI and Core Data
- Testing guidelines and coverage reports