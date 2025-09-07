//
//  ArraySafeAccessTests.swift
//  AsNeededTests
//
//  Tests for Array+SafeAccess extension
//

import Testing
@testable import AsNeeded

struct ArraySafeAccessTests {
	// MARK: - Single Index Subscript Tests
	
	@Test("Safe subscript returns element at valid index")
	func testSafeSubscriptValidIndex() {
		let array = [1, 2, 3, 4, 5]
		
		#expect(array[doesExistAt: 0] == 1)
		#expect(array[doesExistAt: 2] == 3)
		#expect(array[doesExistAt: 4] == 5)
	}
	
	@Test("Safe subscript returns nil for negative index")
	func testSafeSubscriptNegativeIndex() {
		let array = ["a", "b", "c"]
		
		#expect(array[doesExistAt: -1] == nil)
		#expect(array[doesExistAt: -100] == nil)
	}
	
	@Test("Safe subscript returns nil for out of bounds index")
	func testSafeSubscriptOutOfBounds() {
		let array = [10, 20, 30]
		
		#expect(array[doesExistAt: 3] == nil)
		#expect(array[doesExistAt: 100] == nil)
	}
	
	@Test("Safe subscript works with empty array")
	func testSafeSubscriptEmptyArray() {
		let array: [String] = []
		
		#expect(array[doesExistAt: 0] == nil)
		#expect(array[doesExistAt: -1] == nil)
		#expect(array[doesExistAt: 1] == nil)
	}
	
	@Test("Safe subscript works with single element array")
	func testSafeSubscriptSingleElement() {
		let array = [42]
		
		#expect(array[doesExistAt: 0] == 42)
		#expect(array[doesExistAt: 1] == nil)
		#expect(array[doesExistAt: -1] == nil)
	}
	
	// MARK: - Range Subscript Tests
	
	@Test("Safe range subscript returns valid slice")
	func testSafeRangeSubscriptValid() {
		let array = [1, 2, 3, 4, 5]
		
		let slice1 = array[doesExistAt: 1..<3]
		#expect(Array(slice1) == [2, 3])
		
		let slice2 = array[doesExistAt: 0..<5]
		#expect(Array(slice2) == [1, 2, 3, 4, 5])
	}
	
	@Test("Safe range subscript clamps out of bounds range")
	func testSafeRangeSubscriptOutOfBounds() {
		let array = [10, 20, 30]
		
		let slice1 = array[doesExistAt: -2..<5]
		#expect(Array(slice1) == [10, 20, 30])
		
		let slice2 = array[doesExistAt: 1..<10]
		#expect(Array(slice2) == [20, 30])
		
		let slice3 = array[doesExistAt: 5..<10]
		#expect(Array(slice3).isEmpty)
	}
	
	@Test("Safe range subscript with empty range")
	func testSafeRangeSubscriptEmptyRange() {
		let array = [1, 2, 3]
		
		let slice = array[doesExistAt: 2..<2]
		#expect(Array(slice).isEmpty)
	}
	
	@Test("Safe range subscript with empty array")
	func testSafeRangeSubscriptEmptyArray() {
		let array: [Int] = []
		
		let slice = array[doesExistAt: 0..<5]
		#expect(Array(slice).isEmpty)
	}
	
	// MARK: - Closed Range Subscript Tests
	
	@Test("Safe closed range subscript returns valid slice")
	func testSafeClosedRangeSubscriptValid() {
		let array = ["a", "b", "c", "d", "e"]
		
		let slice1 = array[doesExistAt: 1...3]
		#expect(Array(slice1) == ["b", "c", "d"])
		
		let slice2 = array[doesExistAt: 0...4]
		#expect(Array(slice2) == ["a", "b", "c", "d", "e"])
	}
	
	@Test("Safe closed range subscript clamps out of bounds")
	func testSafeClosedRangeSubscriptOutOfBounds() {
		let array = [100, 200, 300]
		
		let slice1 = array[doesExistAt: -2...5]
		#expect(Array(slice1) == [100, 200, 300])
		
		let slice2 = array[doesExistAt: 1...10]
		#expect(Array(slice2) == [200, 300])
		
		let slice3 = array[doesExistAt: 5...10]
		#expect(Array(slice3).isEmpty)
	}
	
	@Test("Safe closed range subscript with single element")
	func testSafeClosedRangeSubscriptSingleElement() {
		let array = [1, 2, 3, 4, 5]
		
		let slice = array[doesExistAt: 2...2]
		#expect(Array(slice) == [3])
	}
	
	@Test("Safe closed range subscript with empty array")
	func testSafeClosedRangeSubscriptEmptyArray() {
		let array: [Double] = []
		
		let slice = array[doesExistAt: 0...5]
		#expect(Array(slice).isEmpty)
	}
	
	// MARK: - Collection Extension Tests
	
	@Test("safeElement returns element at valid index")
	func testSafeElementValidIndex() {
		let array = ["first", "second", "third"]
		let set: Set = [1, 2, 3]
		let dict = ["a": 10, "b": 20, "c": 30]
		
		#expect(array.safeElement(at: 0) == "first")
		#expect(array.safeElement(at: 2) == "third")
		
		// For unordered collections, we just verify it doesn't crash
		let setIndex = set.startIndex
		#expect(set.safeElement(at: setIndex) != nil)
		
		let dictIndex = dict.startIndex
		#expect(dict.safeElement(at: dictIndex) != nil)
	}
	
	@Test("safeElement returns nil for out of bounds")
	func testSafeElementOutOfBounds() {
		let array = [1.5, 2.5, 3.5]
		
		#expect(array.safeElement(at: 3) == nil)
		#expect(array.safeElement(at: -1) == nil)
		#expect(array.safeElement(at: 100) == nil)
	}
	
	@Test("safeElement with empty collection")
	func testSafeElementEmptyCollection() {
		let array: [Int] = []
		let set: Set<String> = []
		
		#expect(array.safeElement(at: 0) == nil)
		
		// For empty set, endIndex equals startIndex
		#expect(set.safeElement(at: set.startIndex) == nil)
	}
	
	// MARK: - Edge Case Tests
	
	@Test("Safe access with different types")
	func testSafeAccessDifferentTypes() {
		// Strings
		let strings = ["hello", "world"]
		#expect(strings[doesExistAt: 0] == "hello")
		#expect(strings[doesExistAt: 5] == nil)
		
		// Custom structs
		struct Person {
			let name: String
		}
		let people = [Person(name: "Alice"), Person(name: "Bob")]
		#expect(people[doesExistAt: 0]?.name == "Alice")
		#expect(people[doesExistAt: 2] == nil)
		
		// Optionals
		let optionals: [Int?] = [1, nil, 3]
		#expect(optionals[doesExistAt: 0] == 1)
		#expect(optionals[doesExistAt: 3] == nil) // Out of bounds
	}
	
	@Test("Safe access preserves array behavior")
	func testSafeAccessPreservesArrayBehavior() {
		var array = [1, 2, 3]
		
		// Modification through safe subscript should not be possible
		// This is expected behavior - safe subscript is read-only
		if let value = array[doesExistAt: 0] {
			#expect(value == 1)
		}
		
		// Regular subscript still works for modification
		array[0] = 10
		#expect(array[0] == 10)
		#expect(array[doesExistAt: 0] == 10)
	}
	
	@Test("Performance - safe subscript doesn't cause issues with large arrays")
	func testSafeSubscriptPerformance() {
		let largeArray = Array(0..<10000)
		
		// Access various indices
		#expect(largeArray[doesExistAt: 0] == 0)
		#expect(largeArray[doesExistAt: 5000] == 5000)
		#expect(largeArray[doesExistAt: 9999] == 9999)
		#expect(largeArray[doesExistAt: 10000] == nil)
		
		// Range access
		let slice = largeArray[doesExistAt: 100..<200]
		#expect(Array(slice).count == 100)
	}
}
