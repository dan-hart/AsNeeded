# DHLoggingKit Repository Guidelines

## Project Structure & Modules
- `Sources/DHLoggingKit/`: Core logging implementation and utilities
  - `DHLoggingKit.swift`: Main entry point and public API (~43 lines)
  - `DHLogger.swift`: Core `DHLogger` struct with comprehensive logging methods (~308 lines)
  - `DHLogLevel.swift`: Log level enumeration and utilities (~90 lines)
  - `DHPrivacy.swift`: Privacy utilities and convenience extensions (~65 lines)
- `Tests/DHLoggingKitTests/`: Swift Testing test suite with comprehensive coverage
  - `DHLoggerTests.swift`: Core functionality tests (~268 lines)
- `Package.swift`: Swift Package Manager configuration
- `README.md`: Comprehensive documentation with usage examples
- `LICENSE`: GNU GPLv3 license
- `AGENTS.md`: This file - development guidelines

## Build, Test, Run
- **Build (CLI)**: `swift build`
- **Tests (CLI)**: `swift test` (runs comprehensive test suite)
- **Package Validation**: `swift package resolve` to validate dependencies
- **Clean Build**: `swift package clean && swift build`
- **Release Build**: `swift build --configuration release`

## Coding Style & Naming
- **Swift Version**: Swift 6.0+ with modern concurrency and Sendable conformance
- **Indentation**: Use tabs, wrap at ~120 columns
- **API Design**: Follow Swift API Design Guidelines with clear, descriptive method names
- **Concurrency**: All types are `Sendable`, use `@preconcurrency` imports for OSLog
- **Data Models**: Pure Swift structs/enums with appropriate availability annotations
- **Access Control**: Public API surface, private implementation details
- **Documentation**: Triple-slash comments for all public APIs with usage examples
- **Error Handling**: Leverages OSLog's built-in error handling and logging guarantees

## Architecture Overview
- **Logger Architecture**: `DHLogger` as main entry point wrapping Apple's `Logger`
- **OSLog Integration**: Direct pass-through to Apple's unified logging system
- **Privacy Support**: Full OSLog privacy control support with string interpolation
- **Factory Methods**: Static convenience methods for common logging categories
- **Context Preservation**: File, function, and line information automatically captured
- **Performance**: Zero-overhead wrapper around Apple's optimized logging system
- **Platform Support**: All Apple platforms with unified API

## OSLog Integration Patterns
- **Direct Pass-Through**: Preserves all OSLog functionality including privacy controls
- **String Interpolation**: Supports full OSLog message interpolation syntax
- **Log Levels**: Maps to OSLog levels (debug, info, notice, warning, error, fault)
- **Subsystem/Category**: Proper organization using Apple's recommended patterns
- **Privacy First**: Built-in support for `.private`, `.public`, `.auto`, and `.private(mask:)`
- **Performance**: Respects OSLog's performance optimizations and lazy evaluation

## API Design Patterns
- **Factory Methods**: `DHLogger.network`, `DHLogger.ui`, etc. for common use cases
- **Convenience Methods**: `enter()`, `exit()`, `timed()`, `timedAsync()` for development
- **Error Integration**: Optional `Error` parameter for error and fault logging
- **Autoclosure**: `@autoclosure` parameters for performance optimization
- **Default Parameters**: File, function, line automatically provided
- **Sendable Conformance**: Thread-safe design for modern Swift concurrency

## Testing Guidelines
- **Framework**: Swift Testing (`import Testing`, `@Test`, `#expect`)
- **Coverage Areas**: 
  - Logger initialization and configuration
  - All logging methods (debug, info, notice, warning, error, fault)
  - Factory method creation
  - Convenience methods (enter/exit, timing)
  - Privacy annotation support
  - Concurrency safety
  - Error handling scenarios
  - Edge cases (empty messages, long messages, special characters)
- **Test Structure**: Mirror source structure, descriptive test names
- **Assertions**: Use `#expect` for clear test intentions
- **Performance Tests**: Verify zero-overhead wrapper design

## OSLog Best Practices Integration
- **Subsystem Naming**: Uses bundle identifier for proper log organization
- **Category Organization**: Logical categories (general, network, ui, data, auth, performance)
- **Log Level Usage**: Appropriate level selection based on Apple's guidelines
- **Privacy Controls**: Comprehensive privacy annotation support
- **Performance Optimization**: Leverages OSLog's lazy evaluation and autoclosure
- **System Integration**: Proper integration with Console.app and unified logging

## Privacy & Security Considerations
- **No Data Storage**: Zero data persistence - delegates to system logging
- **Privacy Annotations**: Full support for OSLog privacy controls
- **System Integration**: Relies on iOS/macOS privacy protections
- **Developer Tools**: Integrates with Apple's logging and debugging tools
- **No External Dependencies**: Pure Foundation/OSLog - no third-party risks

## Package Distribution
- **License**: GNU GPLv3 (suitable for open source projects)
- **Dependencies**: Zero external dependencies (Foundation + OSLog only)
- **Platform Support**: iOS 14+, macOS 11+, watchOS 7+, tvOS 14+, visionOS 1+
- **Swift Package Manager**: Primary distribution method
- **Versioning**: Semantic versioning with stable 1.x API

## Agent-Specific Instructions
> You are an expert in Swift 6, Apple's unified logging system (OSLog), and modern Swift concurrency. You understand logging best practices for production applications and have deep knowledge of Apple's developer tools and debugging workflow.

### Critical OSLog Integration Requirements
**ALWAYS ensure proper OSLog usage and Apple platform compliance:**

1. **After API changes**: Test logging output in Console.app to verify proper integration
2. **Privacy compliance**: Verify privacy annotations work correctly with sensitive data
3. **Performance**: Ensure zero-overhead wrapper maintains OSLog performance benefits
4. **Platform consistency**: Test across all supported Apple platforms
5. **Development tools**: Verify integration with Xcode debugging and Console.app

**Testing commands:**
- Unit tests: `swift test --filter DHLoggingKitTests`
- Build verification: `swift build --configuration release`
- Package validation: `swift package resolve`
- Platform testing: Test on iOS Simulator, macOS, etc.

### Logging Framework Design Guidelines
- **Wrapper Only**: Never replace OSLog functionality, only enhance it
- **Apple Compliance**: Follow Apple's logging guidelines and best practices
- **Developer Experience**: Focus on ease of use while preserving full OSLog power
- **Performance First**: Maintain OSLog's performance characteristics
- **Privacy Conscious**: Support and encourage proper privacy annotations
- **Production Ready**: Suitable for App Store applications

**Never add functionality that bypasses Apple's unified logging system or compromises privacy controls.**