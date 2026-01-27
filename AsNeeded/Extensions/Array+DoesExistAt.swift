//
//  Array+SafeAccess.swift
//  AsNeeded
//
//  Safe array subscript access to prevent index out of range crashes
//

import Foundation

extension Array {
    // MARK: - Safe Subscript

    /// Returns the element at the specified index if it exists, otherwise nil
    subscript(doesExistAt index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    // MARK: - Safe Range Subscript

    /// Returns the slice within `bounds`, clamped to this collection’s indices.
    /// If the clamped lower bound is not less than the clamped upper bound,
    /// an empty slice is returned instead of trapping.
    subscript<R: RangeExpression>(doesExistAt bounds: R) -> SubSequence where R.Bound == Index {
        // Convert any RangeExpression (e.g. `..<`, `...`) to a concrete Range
        let requested = bounds.relative(to: self)

        // Clamp each bound individually to [startIndex, endIndex]
        let lower = requested.lowerBound < startIndex ? startIndex :
            (requested.lowerBound > endIndex ? endIndex : requested.lowerBound)
        let upper = requested.upperBound < startIndex ? startIndex :
            (requested.upperBound > endIndex ? endIndex : requested.upperBound)

        // If inverted or empty after clamping, return an empty slice safely
        guard lower < upper else { return self[endIndex ..< endIndex] }

        return self[lower ..< upper]
    }

    // MARK: - Safe Closed Range Subscript

    /// Returns the elements in the specified closed range, safely bounded to array indices
    subscript(doesExistAt range: ClosedRange<Index>) -> ArraySlice<Element> {
        guard !isEmpty else {
            return ArraySlice<Element>()
        }
        let clampedLower = Swift.max(0, range.lowerBound)
        let clampedUpper = Swift.min(count - 1, range.upperBound)
        guard clampedLower <= clampedUpper else {
            return ArraySlice<Element>()
        }
        return self[clampedLower ... clampedUpper]
    }
}

extension Collection {
    // MARK: - Safe Get

    /// Returns the element at the specified index if it exists, otherwise nil
    func safeElement(at index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
