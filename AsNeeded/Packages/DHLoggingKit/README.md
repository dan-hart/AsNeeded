# DHLoggingKit

[![Swift 6.0](https://img.shields.io/badge/swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS-lightgrey.svg)](https://github.com/apple/swift-package-manager)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://buymeacoffee.com/codedbydan)

A modern Swift logging framework that provides a unified, easy-to-use interface to **Apple's OSLog** with enhanced developer experience across all Apple platforms. DHLoggingKit wraps Apple's unified logging system with convenient APIs while preserving all the performance, privacy, and debugging benefits of OSLog.

## Features

- ✅ **Modern Swift 6**: Built with Swift 6.0 and modern concurrency support
- ✅ **Zero-Overhead Wrapper**: Direct pass-through to Apple's optimized OSLog system
- ✅ **Full Privacy Control**: Complete support for OSLog's privacy annotations
- ✅ **Multi-Platform**: iOS 14+, macOS 11+, watchOS 7+, tvOS 14+, visionOS 1+
- ✅ **Convenient Factory Methods**: Pre-configured loggers for common use cases
- ✅ **Developer-Friendly**: Enhanced convenience methods for debugging and performance
- ✅ **Thread-Safe**: Sendable conformance for safe concurrent usage
- ✅ **Console.app Integration**: Full compatibility with Apple's debugging tools
- ✅ **Zero Dependencies**: Pure Foundation + OSLog implementation

## Installation

### Swift Package Manager

Add DHLoggingKit to your project via Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/DHLoggingKit.git", from: "1.0.0")
]
```

## Quick Start

```swift
import DHLoggingKit

// Use pre-configured loggers for common categories
let networkLogger = DHLogger.network
let uiLogger = DHLogger.ui

// Log with full OSLog privacy control support
networkLogger.info("Starting API request to \(endpoint, privacy: .public)")
networkLogger.debug("Request headers: \(headers, privacy: .private)")

// Handle errors with automatic context
networkLogger.error("Network request failed", error: networkError)

// Use convenience methods for development
networkLogger.enter() // Logs function entry
defer { networkLogger.exit() } // Logs function exit

// Time operations
let result = networkLogger.timed("Database query") {
    return database.fetchUsers()
}

// Async timing
let data = await networkLogger.timedAsync("API call") {
    return await apiService.fetchData()
}
```

## Core Concepts

### Logger Categories

DHLoggingKit provides factory methods for common logging categories:

```swift
let generalLogger = DHLogger.general      // General app events
let networkLogger = DHLogger.network      // Network operations
let uiLogger = DHLogger.ui                // User interface events
let dataLogger = DHLogger.data            // Data persistence
let authLogger = DHLogger.auth            // Authentication events
let performanceLogger = DHLogger.performance // Performance monitoring
```

### Custom Loggers

Create custom loggers for specific subsystems:

```swift
// Uses your app's bundle identifier as subsystem
let customLogger = DHLogger(category: "payment-processing")

// Or specify both subsystem and category
let specificLogger = DHLogger(
    subsystem: "com.myapp.analytics", 
    category: "user-tracking"
)
```

### Log Levels

DHLoggingKit supports all OSLog levels with appropriate use cases:

```swift
// Debug: Development and troubleshooting (filtered in release builds)
logger.debug("Entering function with parameter: \(param, privacy: .private)")

// Info: General informational events
logger.info("User logged in successfully")

// Notice: Significant events (default level)
logger.notice("Payment processing completed for order \(orderId, privacy: .public)")

// Warning: Potential issues that are recoverable
logger.warning("API rate limit approaching: \(currentCount)/\(maxCount, privacy: .public)")

// Error: Error conditions that don't crash the app
logger.error("Failed to save user preferences", error: saveError)

// Fault: Critical errors that may cause crashes
logger.fault("Database connection lost", error: criticalError)
```

## Privacy Controls

DHLoggingKit provides full access to OSLog's privacy system:

```swift
let userLogger = DHLogger.auth

// Mark sensitive data as private (redacted in logs)
userLogger.info("Login attempt for user: \(username, privacy: .private)")

// Public data is visible in logs
userLogger.info("Login successful from IP: \(clientIP, privacy: .public)")

// Private data with hash (shows <mask.hash> in logs)
userLogger.debug("Processing token: \(authToken, privacy: .private(mask: .hash))")

// Auto privacy (respects system settings)
userLogger.notice("Session created: \(sessionId, privacy: .auto)")
```

### Using DHPrivacy Convenience

For easier privacy control, use the `DHPrivacy` utilities:

```swift
import DHLoggingKit

// Access common privacy levels easily
let publicLevel = DHPrivacy.public
let privateLevel = DHPrivacy.private
let hashedLevel = DHPrivacy.privateHash

// Or use string extensions
let email = "user@example.com"
logger.info("Email sent to: \(email.private)")
logger.info("Email domain: \(emailDomain.public)")
```

## Convenience Methods

### Function Tracking

```swift
func processPayment() {
    let logger = DHLogger.general
    
    logger.enter() // Logs: "→ Entering processPayment()"
    defer { logger.exit() } // Logs: "← Exiting processPayment()"
    
    // Your implementation here
}
```

### Performance Timing

```swift
let logger = DHLogger.performance

// Synchronous operations
let result = logger.timed("Database query") {
    return database.performComplexQuery()
}
// Logs: "⏱ Database query took 0.234s"

// Asynchronous operations
let apiResult = await logger.timedAsync("API request") {
    return await networkService.fetchUserData()
}
// Logs: "⏱ API request took 1.456s"
```

## Error Handling

DHLoggingKit integrates seamlessly with Swift's error handling:

```swift
let logger = DHLogger.network

do {
    let data = try await apiService.fetchData()
    logger.info("API request successful")
} catch {
    // Automatically includes error details
    logger.error("API request failed", error: error)
    
    // Or with custom context
    logger.fault("Critical API failure - retrying", error: error)
}
```

## Advanced Usage

### Custom Log Categories

```swift
// Create loggers for specific app modules
struct PaymentService {
    private let logger = DHLogger(category: "payments")
    
    func processPayment() {
        logger.notice("Processing payment for amount: \(amount, privacy: .public)")
        
        // Implementation
    }
}

struct AnalyticsService {
    private let logger = DHLogger(
        subsystem: "com.myapp.analytics",
        category: "events"
    )
    
    func trackEvent() {
        logger.info("Event tracked: \(eventName, privacy: .public)")
    }
}
```

### Integration with SwiftUI

```swift
struct ContentView: View {
    private let logger = DHLogger.ui
    
    var body: some View {
        VStack {
            Button("Tap me") {
                logger.debug("Button tapped")
                handleButtonTap()
            }
        }
        .onAppear {
            logger.info("ContentView appeared")
        }
    }
}
```

### Testing Considerations

DHLoggingKit is designed for production use and integrates with Apple's logging system. For testing:

```swift
import XCTest
@testable import MyApp

class MyServiceTests: XCTestCase {
    func testServiceLogging() {
        // DHLoggingKit logs will appear in test output
        let service = MyService()
        service.performOperation() // This will log through DHLoggingKit
        
        // Use Console.app to verify log output during development
    }
}
```

## Console.app Integration

DHLoggingKit logs are fully compatible with Apple's Console.app:

1. **Open Console.app** on macOS or use the Console in Xcode
2. **Filter by subsystem**: Use your app's bundle identifier
3. **Filter by category**: Use the category names you've defined
4. **View log levels**: All DHLoggingKit levels appear correctly
5. **Privacy redaction**: Private data is properly redacted

Example Console.app filter:
```
subsystem:com.myapp.example category:network
```

## Performance Considerations

DHLoggingKit is designed for zero performance overhead:

- **Pass-through design**: Direct calls to OSLog with no interception
- **Lazy evaluation**: Uses `@autoclosure` for optimal performance
- **System integration**: Leverages OSLog's optimized performance
- **Debug filtering**: Debug messages are automatically filtered in release builds

```swift
// This debug message has zero cost in release builds
logger.debug("Expensive debug info: \(expensiveComputation(), privacy: .private)")
```

## Requirements

- **Swift**: 6.0+
- **Platforms**: iOS 14.0+ / macOS 11.0+ / watchOS 7.0+ / tvOS 14.0+ / visionOS 1.0+
- **Dependencies**: None (Foundation + OSLog only)

## Comparison with Other Logging Frameworks

| Feature | DHLoggingKit | OSLog (direct) | Other Frameworks |
|---------|-------------|----------------|-----------------|
| Performance | ✅ Zero overhead | ✅ Native | ❌ Overhead |
| Privacy Controls | ✅ Full support | ✅ Native | ❌ Limited |
| Console Integration | ✅ Perfect | ✅ Native | ❌ Requires export |
| Apple Platform Integration | ✅ Native | ✅ Native | ❌ Third-party |
| Developer Experience | ✅ Enhanced | ❌ Verbose | ✅ Varies |
| Dependencies | ✅ Zero | ✅ None | ❌ Many |

## Best Practices

### Do's ✅
```swift
// Use appropriate log levels
logger.info("User action completed")  // For important events
logger.debug("Internal state: \(state, privacy: .private)")  // For development

// Use privacy annotations
logger.notice("Processing order: \(orderId, privacy: .public)")
logger.debug("User data: \(userData, privacy: .private)")

// Use factory methods for common categories
let networkLogger = DHLogger.network
let uiLogger = DHLogger.ui
```

### Don'ts ❌
```swift
// Don't log sensitive data without privacy controls
logger.info("Password: \(password)")  // ❌ Exposes sensitive data

// Don't use high-frequency debug logging without consideration
for item in largeArray {
    logger.debug("Processing item: \(item)")  // ❌ Too verbose
}

// Don't create excessive logger instances
class MyClass {
    let logger1 = DHLogger(category: "a")  // ❌ Create one per logical
    let logger2 = DHLogger(category: "b")  // component, not per class
}
```

## Migration from Other Frameworks

### From print() statements:
```swift
// Before
print("User logged in: \(username)")

// After
logger.info("User logged in: \(username, privacy: .private)")
```

### From os_log:
```swift
// Before
os_log("Network request completed", log: OSLog.default, type: .info)

// After
DHLogger.network.info("Network request completed")
```

### From third-party frameworks:
```swift
// Before (example with CocoaLumberjack)
DDLogInfo("API response received")

// After
DHLogger.network.info("API response received")
```

## Troubleshooting

### Logs not appearing in Console.app?
- Verify your app's bundle identifier matches the subsystem
- Check Console.app filters
- Ensure you're looking at the correct device/simulator

### Performance issues?
- DHLoggingKit should have zero performance impact
- Verify you're not doing expensive work in log message closures
- Use privacy annotations to reduce string processing

### Privacy not working?
- Ensure you're using the correct privacy annotations
- Check that sensitive data is marked with `.private`
- Verify Console.app is showing the correct privacy redaction

## Examples Repository

For more comprehensive examples, see the [DHLoggingKit Examples](https://github.com/yourusername/DHLoggingKit-Examples) repository which includes:

- SwiftUI integration examples
- NetworkKit integration
- Core Data logging patterns
- Testing strategies
- Performance benchmarks

## License

DHLoggingKit is released under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

When contributing:
- Follow Swift API Design Guidelines
- Maintain zero-overhead design principles
- Preserve full OSLog functionality
- Add comprehensive tests for new features
- Update documentation as needed

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/DHLoggingKit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/DHLoggingKit/discussions)
- **Apple Documentation**: [OSLog Documentation](https://developer.apple.com/documentation/oslog)
- **Console.app Guide**: [Apple Console User Guide](https://support.apple.com/guide/console/welcome/mac)

---

**Built with ❤️ for the Swift and Apple developer community**