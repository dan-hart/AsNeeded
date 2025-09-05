# DHLoggingKit Repository Guidelines

## Project Structure & Modules
- `Sources/DHLoggingKit/`: Core logging implementation and utilities
  - `DHLoggingKit.swift`: Main entry point and public API (~48 lines)
  - `DHLogger.swift`: Core `DHLogger` struct with comprehensive logging methods and direct OSLog access (~435 lines)
  - `DHLogLevel.swift`: Log level enumeration and utilities with Sendable conformance (~90 lines)
  - `DHPrivacy.swift`: Privacy utilities and convenience extensions with improved Swift 6 compatibility (~65 lines)
- `Tests/DHLoggingKitTests/`: Swift Testing test suite with comprehensive coverage (36 tests)
  - `DHLoggerTests.swift`: Comprehensive functionality tests including privacy, performance, and integration tests (~490 lines)
- `Package.swift`: Swift Package Manager configuration with full Apple platform support
- `README.md`: Updated comprehensive documentation with accurate usage examples
- `LICENSE`: GNU GPLv3 license
- `CLAUDE.md`: This file - development guidelines

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
- **Direct OSLog Access**: `.oslog` property provides full access to underlying OSLog Logger
- **Dual API Surface**: String-based methods with context + direct OSLog access for privacy
- **OSLog Integration**: Direct pass-through to Apple's unified logging system
- **Privacy Support**: Full OSLog privacy control support via direct access and helper methods
- **Factory Methods**: Static convenience methods for common logging categories
- **Context Preservation**: File, function, and line information automatically captured
- **Performance**: Zero-overhead wrapper around Apple's optimized logging system
- **Platform Support**: All Apple platforms with unified API (iOS 14+, macOS 11+, watchOS 7+, tvOS 14+, visionOS 1+)

## OSLog Integration Patterns
- **Direct Pass-Through**: Preserves all OSLog functionality including privacy controls via `.oslog` access
- **Dual Approach**: String-based logging with context + direct OSLog access for full features
- **String Interpolation**: Full OSLog message interpolation syntax via `.oslog` property
- **Log Levels**: Maps to OSLog levels (debug, info, notice, warning, error, fault)
- **Subsystem/Category**: Proper organization using Apple's recommended patterns
- **Privacy First**: Built-in support for `.private`, `.public`, `.auto`, and `.private(mask:)` via direct access
- **Privacy Helpers**: `DHLogger.redact()` and `DHLogger.hash()` for string-based logging
- **Performance**: Respects OSLog's performance optimizations and lazy evaluation

## API Design Patterns
- **Factory Methods**: `DHLogger.network`, `DHLogger.ui`, etc. for common use cases
- **Direct OSLog Access**: `.oslog` property for full OSLog features including privacy
- **Convenience Methods**: `enter()`, `exit()`, `timed()`, `timedAsync()` for development
- **Privacy Helpers**: Static `redact()` and `hash()` methods for safe string-based logging
- **Error Integration**: Optional `Error` parameter for error and fault logging
- **Autoclosure**: `@autoclosure` parameters for performance optimization where applicable
- **Default Parameters**: File, function, line automatically provided for context
- **Sendable Conformance**: Thread-safe design for modern Swift concurrency

## Testing Guidelines
- **Framework**: Swift Testing (`import Testing`, `@Test`, `#expect`)
- **Current Coverage**: 36 comprehensive tests covering all functionality
- **Coverage Areas**: 
  - Logger initialization and configuration
  - All logging methods (debug, info, notice, warning, error, fault)
  - Direct OSLog access functionality and privacy features
  - Factory method creation and usage
  - Convenience methods (enter/exit, timing)
  - Privacy annotation support via `.oslog` access
  - Privacy helper methods (`redact()`, `hash()`)
  - DHLogLevel enum functionality and OSLogType conversion
  - DHPrivacy utilities and string extensions
  - Concurrency safety and thread-safe operations
  - Error handling scenarios
  - Performance benchmarking
  - Integration tests with all factory methods
  - Edge cases (empty messages, long messages, special characters)
- **Test Structure**: Mirror source structure, descriptive test names with clear intent
- **Assertions**: Use `#expect` for clear test intentions and readable failures
- **Performance Tests**: Verify zero-overhead wrapper design and OSLog performance characteristics

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

## .gitignore Requirements for Swift Packages
- **Build artifacts**: Ignore `.build/` directory (Swift Package Manager build artifacts)
- **Xcode integration**: Ignore `.swiftpm/xcode/` directory and user data files
- **System files**: Ignore `.DS_Store` and macOS system files
- **Dependencies**: Ignore `/Packages` directory if using package dependencies
- **User data**: Ignore `xcuserdata/`, `*.xcuserstate`, and Xcode user-specific files
- Standard Swift package .gitignore should include: `.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`, `*.xcuserstate`

## Agent-Specific Instructions
> You are an expert in Swift 6, Apple's unified logging system (OSLog), and modern Swift concurrency. You understand logging best practices for production applications and have deep knowledge of Apple's developer tools and debugging workflow.

### Critical OSLog Integration Requirements
**ALWAYS ensure proper OSLog usage and Apple platform compliance:**

1. **Direct OSLog Access**: Test that `.oslog` property provides full OSLog functionality
2. **Privacy compliance**: Verify privacy annotations work correctly via direct access and helper methods
3. **Performance**: Ensure zero-overhead wrapper maintains OSLog performance benefits
4. **Platform consistency**: Test across all supported Apple platforms (iOS 14+, macOS 11+, watchOS 7+, tvOS 14+, visionOS 1+)
5. **Development tools**: Verify integration with Xcode debugging and Console.app
6. **Context preservation**: Ensure file/function/line information is properly captured
7. **Swift 6 compatibility**: Verify Sendable conformance and concurrency safety

**Testing commands:**
- Full test suite: `swift test` (runs all 36 tests)
- Parallel testing: `swift test --parallel`
- Build verification: `swift build --configuration release`
- Package validation: `swift package resolve`
- Platform testing: Test on iOS Simulator, macOS, etc.

### Logging Framework Design Guidelines
- **Wrapper Only**: Never replace OSLog functionality, only enhance it with convenience
- **Direct Access**: Always preserve full OSLog access via `.oslog` property
- **Apple Compliance**: Follow Apple's logging guidelines and best practices
- **Developer Experience**: Focus on ease of use while preserving full OSLog power
- **Performance First**: Maintain OSLog's performance characteristics and zero overhead
- **Privacy Conscious**: Support and encourage proper privacy annotations via direct access
- **Context Enhancement**: Automatically provide file/function/line context for debugging
- **Swift 6 Ready**: Full compatibility with modern Swift concurrency and Sendable types
- **Production Ready**: Suitable for App Store applications with comprehensive testing

**Key Principles:**
- Never add functionality that bypasses Apple's unified logging system
- Never compromise privacy controls - always provide full OSLog privacy features
- Always maintain backward compatibility with existing OSLog workflows
- Always provide comprehensive test coverage for all functionality**