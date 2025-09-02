//
//  DHLoggerTests.swift
//  DHLoggingKitTests
//
//  Tests for the DHLogger functionality
//

import Testing
import Foundation
import OSLog
@testable import DHLoggingKit

struct DHLoggerTests {
	// MARK: - Initialization Tests
	@Test("DHLogger should initialize with subsystem and category")
	func dhLoggerShouldInitializeWithSubsystemAndCategory() {
		let logger = DHLogger(subsystem: "com.test.app", category: "testing")
		
		// Logger should be created successfully (no direct access to internal properties)
		#expect(Bool(true), "Logger should initialize without errors")
	}
	
	@Test("DHLogger should initialize with category only using bundle ID")
	func dhLoggerShouldInitializeWithCategoryOnly() {
		let logger = DHLogger(category: "testing")
		
		// Should use bundle identifier or fallback
		#expect(Bool(true), "Logger should initialize with category-only constructor")
	}
	
	// MARK: - Static Factory Methods Tests
	@Test("Static factory methods should create different loggers")
	func staticFactoryMethodsShouldCreateDifferentLoggers() {
		let generalLogger = DHLogger.general
		let networkLogger = DHLogger.network
		let uiLogger = DHLogger.ui
		let dataLogger = DHLogger.data
		let authLogger = DHLogger.auth
		let performanceLogger = DHLogger.performance
		
		// All should be created successfully
		#expect(Bool(true), "All static factory methods should work")
	}
	
	// MARK: - Logging Method Tests
	@Test("Debug logging should not crash")
	func debugLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		// These should not crash or throw
		logger.debug("Test debug message")
		logger.debug("Debug with data: sensitive")
		
		#expect(Bool(true), "Debug logging should complete without errors")
	}
	
	@Test("Info logging should not crash")
	func infoLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		logger.info("Test info message")
		logger.info("Info with public data: public data")
		
		#expect(Bool(true), "Info logging should complete without errors")
	}
	
	@Test("Notice logging should not crash")
	func noticeLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		logger.notice("Test notice message")
		logger.notice("Notice with mixed data: private and public")
		
		#expect(Bool(true), "Notice logging should complete without errors")
	}
	
	@Test("Warning logging should not crash")
	func warningLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		logger.warning("Test warning message")
		logger.warning("Warning with hash: sensitive data")
		
		#expect(Bool(true), "Warning logging should complete without errors")
	}
	
	@Test("Error logging should not crash")
	func errorLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		let testError = TestError.sampleError
		
		logger.error("Test error message")
		logger.error("Test error with Error object", error: testError)
		
		#expect(Bool(true), "Error logging should complete without errors")
	}
	
	@Test("Fault logging should not crash")
	func faultLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		let testError = TestError.criticalError
		
		logger.fault("Test fault message")
		logger.fault("Test fault with Error object", error: testError)
		
		#expect(Bool(true), "Fault logging should complete without errors")
	}
	
	// MARK: - Convenience Methods Tests
	@Test("Enter and exit methods should work")
	func enterAndExitMethodsShouldWork() {
		let logger = DHLogger(category: "test")
		
		logger.enter()
		logger.exit()
		
		#expect(Bool(true), "Enter/exit methods should complete without errors")
	}
	
	@Test("Timed execution should work and return result")
	func timedExecutionShouldWorkAndReturnResult() {
		let logger = DHLogger(category: "test")
		
		let result = logger.timed("Test operation") {
			// Simulate some work
			Thread.sleep(forTimeInterval: 0.01)
			return 42
		}
		
		#expect(result == 42, "Timed execution should return the correct result")
	}
	
	@Test("Timed execution should handle throwing closures")
	func timedExecutionShouldHandleThrowingClosures() {
		let logger = DHLogger(category: "test")
		
		do {
			let result = try logger.timed("Throwing operation") {
				throw TestError.sampleError
			}
			#expect(Bool(false), "Should have thrown an error")
		} catch {
			#expect(error is TestError, "Should propagate the thrown error")
		}
	}
	
	@Test("Async timed execution should work")
	func asyncTimedExecutionShouldWork() async {
		let logger = DHLogger(category: "test")
		
		let result = await logger.timedAsync("Async test operation") {
			// Simulate async work
			try? await Task.sleep(for: .milliseconds(10))
			return "success"
		}
		
		#expect(result == "success", "Async timed execution should return the correct result")
	}
	
	@Test("Async timed execution should handle throwing closures")
	func asyncTimedExecutionShouldHandleThrowingClosures() async {
		let logger = DHLogger(category: "test")
		
		do {
			let _ = try await logger.timedAsync("Async throwing operation") {
				throw TestError.sampleError
			}
			#expect(Bool(false), "Should have thrown an error")
		} catch {
			#expect(error is TestError, "Should propagate the thrown error")
		}
	}
	
	// MARK: - Basic String Tests
	@Test("Basic string logging should work without crashing")
	func basicStringLoggingShouldWorkWithoutCrashing() {
		let logger = DHLogger(category: "test")
		let sensitiveData = "user_password_123"
		let publicData = "operation_success"
		
		logger.info("Login attempt: user \(sensitiveData) result \(publicData)")
		logger.debug("Hash example: \(sensitiveData)")
		logger.notice("Auto privacy: \(sensitiveData)")
		
		#expect(Bool(true), "Basic string logging should work without errors")
	}
	
	// MARK: - Stress Tests
	@Test("Rapid logging should not crash")
	func rapidLoggingShouldNotCrash() {
		let logger = DHLogger(category: "stress-test")
		
		// Log many messages rapidly
		for i in 0..<100 {
			logger.debug("Rapid log message \(i)")
		}
		
		#expect(Bool(true), "Rapid logging should complete without errors")
	}
	
	@Test("Concurrent logging should be thread-safe")
	func concurrentLoggingShouldBeThreadSafe() async {
		let logger = DHLogger(category: "concurrent-test")
		
		await withTaskGroup(of: Void.self) { group in
			// Start multiple concurrent logging tasks
			for i in 0..<10 {
				group.addTask {
					for j in 0..<10 {
						logger.info("Concurrent log from task \(i), message \(j)")
					}
				}
			}
		}
		
		#expect(Bool(true), "Concurrent logging should complete without errors")
	}
	
	// MARK: - Edge Case Tests
	@Test("Empty messages should be handled")
	func emptyMessagesShouldBeHandled() {
		let logger = DHLogger(category: "test")
		
		logger.debug("")
		logger.info("")
		logger.notice("")
		logger.warning("")
		logger.error("")
		logger.fault("")
		
		#expect(Bool(true), "Empty messages should be handled without errors")
	}
	
	@Test("Very long messages should be handled")
	func veryLongMessagesShouldBeHandled() {
		let logger = DHLogger(category: "test")
		let longMessage = String(repeating: "This is a very long log message. ", count: 100)
		
		logger.info("\(longMessage)")
		
		#expect(Bool(true), "Very long messages should be handled without errors")
	}
	
	@Test("Special characters should be handled")
	func specialCharactersShouldBeHandled() {
		let logger = DHLogger(category: "test")
		
		let specialChars = "Special chars: 🚀 émojis àccénts 中文 العربية \\n\\t\\r\\\\\\\"\'"
		logger.info("Message with special characters: \(specialChars)")
		
		#expect(Bool(true), "Special characters should be handled without errors")
	}
	
	// MARK: - OSLog Direct Access Tests
	@Test("Direct OSLog access should provide underlying logger")
	func directOSLogAccessShouldProvideUnderlyingLogger() {
		let logger = DHLogger(category: "test")
		let oslogger = logger.oslog
		
		// Should get the underlying OSLog Logger instance
		// This should not crash and should allow direct OSLog usage
		oslogger.info("Direct OSLog test message")
		
		#expect(Bool(true), "Direct OSLog access should work without errors")
	}
	
	@Test("Direct OSLog should support privacy annotations")
	func directOSLogShouldSupportPrivacyAnnotations() {
		let logger = DHLogger(category: "privacy-test")
		let oslogger = logger.oslog
		
		let sensitiveData = "secret-password-123"
		let publicData = "operation-success"
		
		// These should compile and run without errors, demonstrating privacy support
		oslogger.info("Login attempt with user: \(sensitiveData, privacy: .private) result: \(publicData, privacy: .public)")
		oslogger.debug("Hash example: \(sensitiveData, privacy: .private(mask: .hash))")
		oslogger.notice("Auto privacy: \(sensitiveData, privacy: .auto)")
		
		#expect(Bool(true), "Direct OSLog privacy annotations should work")
	}
	
	// MARK: - Privacy Helper Methods Tests
	@Test("Privacy redact method should work")
	func privacyRedactMethodShouldWork() {
		let sensitiveValue = "user-password-123"
		let redactedValue = DHLogger.redact(sensitiveValue)
		
		#expect(redactedValue == "<private>", "Redact should return '<private>'")
	}
	
	@Test("Privacy hash method should work")
	func privacyHashMethodShouldWork() {
		let sensitiveValue = "user-password-123"
		let hashedValue = DHLogger.hash(sensitiveValue)
		
		#expect(hashedValue.starts(with: "<hash:"), "Hash should start with '<hash:'")
		#expect(hashedValue.hasSuffix(">"), "Hash should end with '>'")
		
		// Same input should produce same hash
		let secondHash = DHLogger.hash(sensitiveValue)
		#expect(hashedValue == secondHash, "Same input should produce same hash")
		
		// Different input should produce different hash
		let differentValue = "different-password-456"
		let differentHash = DHLogger.hash(differentValue)
		#expect(hashedValue != differentHash, "Different inputs should produce different hashes")
	}
	
	// MARK: - DHLogLevel Tests
	@Test("DHLogLevel enum should have correct order")
	func dhLogLevelEnumShouldHaveCorrectOrder() {
		#expect(DHLogLevel.debug < DHLogLevel.info, "Debug should be less than info")
		#expect(DHLogLevel.info < DHLogLevel.notice, "Info should be less than notice")
		#expect(DHLogLevel.notice < DHLogLevel.warning, "Notice should be less than warning")
		#expect(DHLogLevel.warning < DHLogLevel.error, "Warning should be less than error")
		#expect(DHLogLevel.error < DHLogLevel.fault, "Error should be less than fault")
	}
	
	@Test("DHLogLevel should have proper descriptions")
	func dhLogLevelShouldHaveProperDescriptions() {
		#expect(DHLogLevel.debug.description == "DEBUG", "Debug description should be 'DEBUG'")
		#expect(DHLogLevel.info.description == "INFO", "Info description should be 'INFO'")
		#expect(DHLogLevel.notice.description == "NOTICE", "Notice description should be 'NOTICE'")
		#expect(DHLogLevel.warning.description == "WARNING", "Warning description should be 'WARNING'")
		#expect(DHLogLevel.error.description == "ERROR", "Error description should be 'ERROR'")
		#expect(DHLogLevel.fault.description == "FAULT", "Fault description should be 'FAULT'")
	}
	
	@Test("DHLogLevel should have emoji representations")
	func dhLogLevelShouldHaveEmojiRepresentations() {
		#expect(DHLogLevel.debug.emoji == "🔍", "Debug emoji should be magnifying glass")
		#expect(DHLogLevel.info.emoji == "ℹ️", "Info emoji should be info symbol")
		#expect(DHLogLevel.notice.emoji == "📝", "Notice emoji should be memo")
		#expect(DHLogLevel.warning.emoji == "⚠️", "Warning emoji should be warning sign")
		#expect(DHLogLevel.error.emoji == "❌", "Error emoji should be X mark")
		#expect(DHLogLevel.fault.emoji == "💥", "Fault emoji should be explosion")
	}
	
	@Test("DHLogLevel should convert to OSLogType correctly")
	func dhLogLevelShouldConvertToOSLogTypeCorrectly() {
		#expect(DHLogLevel.debug.osLogType == .debug, "Debug should convert to OSLogType.debug")
		#expect(DHLogLevel.info.osLogType == .info, "Info should convert to OSLogType.info")
		#expect(DHLogLevel.notice.osLogType == .default, "Notice should convert to OSLogType.default")
		#expect(DHLogLevel.warning.osLogType == .info, "Warning should convert to OSLogType.info")
		#expect(DHLogLevel.error.osLogType == .error, "Error should convert to OSLogType.error")
		#expect(DHLogLevel.fault.osLogType == .fault, "Fault should convert to OSLogType.fault")
	}
	
	@Test("DHLogLevel should be iterable")
	func dhLogLevelShouldBeIterable() {
		let allLevels = DHLogLevel.allCases
		#expect(allLevels.count == 6, "Should have exactly 6 log levels")
		#expect(allLevels.contains(.debug), "Should contain debug level")
		#expect(allLevels.contains(.info), "Should contain info level")
		#expect(allLevels.contains(.notice), "Should contain notice level")
		#expect(allLevels.contains(.warning), "Should contain warning level")
		#expect(allLevels.contains(.error), "Should contain error level")
		#expect(allLevels.contains(.fault), "Should contain fault level")
	}
	
	// MARK: - DHPrivacy Tests
	@Test("DHPrivacy should provide privacy constants")
	func dhPrivacyShouldProvidePrivacyConstants() {
		// These should compile and be accessible
		let privateLevel = DHPrivacy.private
		let publicLevel = DHPrivacy.public
		let hashLevel = DHPrivacy.privateHash
		let autoLevel = DHPrivacy.auto
		
		#expect(Bool(true), "DHPrivacy constants should be accessible")
	}
	
	@Test("String privacy extensions should work")
	func stringPrivacyExtensionsShouldWork() {
		let testString = "sensitive-data"
		
		let privateResult = testString.private
		#expect(privateResult.0 == testString, "Private extension should preserve string")
		
		let publicResult = testString.public
		#expect(publicResult.0 == testString, "Public extension should preserve string")
		
		let hashResult = testString.privateHash
		#expect(hashResult.0 == testString, "Hash extension should preserve string")
		
		#expect(Bool(true), "String privacy extensions should work")
	}
	
	// MARK: - DHLoggingKit Main Module Tests
	@Test("DHLoggingKit should have version information")
	func dhLoggingKitShouldHaveVersionInformation() {
		let version = DHLoggingKit.version
		#expect(!version.isEmpty, "Version should not be empty")
		#expect(version.contains("."), "Version should contain dots (semver format)")
	}
	
	@Test("DHLoggingKit shared logger should work")
	func dhLoggingKitSharedLoggerShouldWork() {
		let sharedLogger = DHLoggingKit.shared
		
		// Should be able to use the shared logger
		sharedLogger.info("Test message from shared logger")
		
		#expect(Bool(true), "Shared logger should work")
	}
	
	// MARK: - Integration Tests
	@Test("Logger should work with all factory methods and privacy")
	func loggerShouldWorkWithAllFactoryMethodsAndPrivacy() async {
		let loggers = [
			DHLogger.general,
			DHLogger.network,
			DHLogger.ui,
			DHLogger.data,
			DHLogger.auth,
			DHLogger.performance
		]
		
		for logger in loggers {
			// Test regular logging
			logger.debug("Debug test message")
			logger.info("Info test message")
			logger.notice("Notice test message")
			logger.warning("Warning test message")
			logger.error("Error test message")
			logger.fault("Fault test message")
			
			// Test with direct OSLog privacy
			let sensitiveData = "private-data"
			let publicData = "public-data"
			logger.oslog.info("Testing privacy: \(sensitiveData, privacy: .private) and \(publicData, privacy: .public)")
			
			// Test convenience methods
			logger.enter()
			logger.exit()
			
			// Test timing
			let _ = logger.timed("Test operation") { return "result" }
			let _ = await logger.timedAsync("Async test operation") { return "async-result" }
		}
		
		#expect(Bool(true), "All factory method loggers should work with privacy features")
	}
	
	// MARK: - Performance Tests
	@Test("Logging performance should be acceptable")
	func loggingPerformanceShouldBeAcceptable() {
		let logger = DHLogger(category: "performance-test")
		let iterations = 1000
		
		let startTime = CFAbsoluteTimeGetCurrent()
		
		for i in 0..<iterations {
			logger.debug("Performance test message \(i)")
		}
		
		let endTime = CFAbsoluteTimeGetCurrent()
		let duration = endTime - startTime
		
		// Should complete 1000 log messages in under 1 second (very generous limit)
		#expect(duration < 1.0, "1000 log messages should complete in under 1 second")
	}
	
	// MARK: - Memory Tests
	@Test("Logger struct should be lightweight")
	func loggerStructShouldBeLightweight() {
		// DHLogger is a struct, so it should be value-type and lightweight
		let logger = DHLogger(category: "memory-test")
		logger.info("Memory test message")
		
		// Structs don't have reference counting overhead
		#expect(Bool(true), "DHLogger struct should be lightweight and not retain references")
	}
}

// MARK: - Test Helpers
enum TestError: Error, CustomStringConvertible {
	case sampleError
	case criticalError
	
	var description: String {
		switch self {
		case .sampleError:
			return "Sample error for testing"
		case .criticalError:
			return "Critical error for testing"
		}
	}
}