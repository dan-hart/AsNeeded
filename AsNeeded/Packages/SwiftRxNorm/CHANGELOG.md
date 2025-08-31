# Changelog

All notable changes to SwiftRxNorm will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of SwiftRxNorm
- Support for all major RxNorm API endpoints
- Type-safe Swift models for RxNorm data
- Comprehensive error handling
- Modern Swift 6 async/await support
- Multi-platform support (iOS, macOS, watchOS, tvOS, visionOS)
- Dependency injection for networking (testability)
- Comprehensive test coverage (27+ tests)
- Fuzzy search capabilities with `suggestDrugs()`
- Spelling suggestions with `getSpellingSuggestions()`
- Comprehensive search combining multiple strategies
- Support for drug interactions, synonyms, and properties
- Proper medical disclaimers and NLM attribution
- Rate limiting guidelines and best practices documentation

### Core Features
- `fetchDrugsByName()` - Search drugs by name
- `fetchRxcuiByName()` - Get RxCUI for drug names  
- `fetchDrugSynonyms()` - Get synonyms for RxCUI
- `fetchInteractionsForRxcui()` - Get drug interactions
- `fetchPropertiesForRxcui()` - Get drug properties
- `suggestDrugs()` - Fuzzy/approximate search
- `getSpellingSuggestions()` - Spelling corrections
- `comprehensiveSearch()` - Multi-strategy search with deduplication

### Documentation
- Comprehensive README with examples
- Medical disclaimers and legal requirements
- API reference documentation  
- Installation and usage guides
- Best practices for rate limiting
- Testing and dependency injection examples