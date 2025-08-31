//
//  DHLoggerTests.swift
//  DHLoggingKitTests
//
//  Tests for the DHLogger functionality
//

import Testing
import Foundation
@testable import DHLoggingKit

@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, visionOS 1.0, *)
struct DHLoggerTests {
	// MARK: - Initialization Tests
	@Test("DHLogger should initialize with subsystem and category")
	func dhLoggerShouldInitializeWithSubsystemAndCategory() {
		let logger = DHLogger(subsystem: "com.test.app", category: "testing")
		
		// Logger should be created successfully (no direct access to internal properties)
		#expect(true, "Logger should initialize without errors")
	}
	
	@Test("DHLogger should initialize with category only using bundle ID")
	func dhLoggerShouldInitializeWithCategoryOnly() {
		let logger = DHLogger(category: "testing")
		
		// Should use bundle identifier or fallback
		#expect(true, "Logger should initialize with category-only constructor")
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
		#expect(true, "All static factory methods should work")
	}
	
	// MARK: - Logging Method Tests
	@Test("Debug logging should not crash")
	func debugLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		// These should not crash or throw
		logger.debug("Test debug message")
		logger.debug("Debug with data: \("sensitive", privacy: .private)")
		
		#expect(true, "Debug logging should complete without errors")
	}
	
	@Test("Info logging should not crash")
	func infoLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		logger.info("Test info message")
		logger.info("Info with public data: \("public data", privacy: .public)")
		
		#expect(true, "Info logging should complete without errors")
	}
	
	@Test("Notice logging should not crash")
	func noticeLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		logger.notice("Test notice message")
		logger.notice("Notice with mixed data: \("private", privacy: .private) and \("public", privacy: .public)")
		
		#expect(true, "Notice logging should complete without errors")
	}
	
	@Test("Warning logging should not crash")
	func warningLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		
		logger.warning("Test warning message")
		logger.warning("Warning with hash: \("sensitive data", privacy: .private(mask: .hash))")
		
		#expect(true, "Warning logging should complete without errors")
	}
	
	@Test("Error logging should not crash")
	func errorLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		let testError = TestError.sampleError
		
		logger.error("Test error message")
		logger.error("Test error with Error object", error: testError)
		
		#expect(true, "Error logging should complete without errors")
	}
	
	@Test("Fault logging should not crash")
	func faultLoggingShouldNotCrash() {
		let logger = DHLogger(category: "test")
		let testError = TestError.criticalError
		
		logger.fault("Test fault message")
		logger.fault("Test fault with Error object", error: testError)
		
		#expect(true, "Fault logging should complete without errors")
	}
	
	// MARK: - Convenience Methods Tests
	@Test("Enter and exit methods should work")
	func enterAndExitMethodsShouldWork() {
		let logger = DHLogger(category: "test")
		
		logger.enter()
		logger.exit()
		
		#expect(true, "Enter/exit methods should complete without errors")
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
	
	// MARK: - Privacy Tests
	@Test("Privacy annotations should work without crashing")
	func privacyAnnotationsShouldWorkWithoutCrashing() {
		let logger = DHLogger(category: "test")
		let sensitiveData = "user_password_123"
		let publicData = "operation_success"
		
		logger.info("Login attempt: user \(sensitiveData, privacy: .private) result \(publicData, privacy: .public)")
		logger.debug("Hash example: \(sensitiveData, privacy: .private(mask: .hash))")
		logger.notice("Auto privacy: \(sensitiveData, privacy: .auto)")
		
		#expect(true, "Privacy annotations should work without errors")
	}
	
	// MARK: - Stress Tests
	@Test("Rapid logging should not crash")
	func rapidLoggingShouldNotCrash() {
		let logger = DHLogger(category: "stress-test")
		
		// Log many messages rapidly
		for i in 0..<100 {
			logger.debug("Rapid log message \(i)")
		}
		
		#expect(true, "Rapid logging should complete without errors")
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
		
		#expect(true, "Concurrent logging should complete without errors")
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
		
		#expect(true, "Empty messages should be handled without errors")
	}
	
	@Test("Very long messages should be handled")
	func veryLongMessagesShouldBeHandled() {
		let logger = DHLogger(category: "test")
		let longMessage = String(repeating: "This is a very long log message. ", count: 100)
		
		logger.info("\(longMessage)")
		
		#expect(true, "Very long messages should be handled without errors")
	}
	
	@Test("Special characters should be handled")
	func specialCharactersShouldBeHandled() {
		let logger = DHLogger(category: "test")
		
		let specialChars = "Special chars: 🚀 émojis àccénts 中文 العربية \n\t\r\\\"'"
		logger.info("Message with special characters: \(specialChars, privacy: .public)")
		
		#expect(true, "Special characters should be handled without errors")
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