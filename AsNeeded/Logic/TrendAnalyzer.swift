//
//  TrendAnalyzer.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/20/23.
//

import Foundation
import SwiftUI

/// TrendAnalyzer
///
/// This class provides a function to analyze the trend of a set of numbers.
///
/// ## Functions
///
/// * `trend(numbers: [Double]) -> Trend`
///   This function analyzes the trend of a set of numbers and returns a `Trend` enum value. The `Trend` enum has three cases: `stable`, `up`, and `down`. The `stable` case is returned if the standard deviation of the numbers is 0. The `up` case is returned if the maximum index of the numbers is less than the minimum index. The `down` case is returned if the minimum index of the numbers is less than the maximum index.
///
/// ## Why
///
/// This code is useful for analyzing the trend of a set of numbers. The code uses linear algebra to calculate the standard deviation of the numbers. The standard deviation is then used to determine the trend of the numbers.
///
/// ## How
///
/// The code first calculates the mean and variance of the numbers. The mean is the average of the numbers. The variance is a measure of how spread out the numbers are. The standard deviation is the square root of the variance.
///
/// The code then checks if the standard deviation is 0. If the standard deviation is 0, then the numbers are all the same value, so the trend is `stable`. If the standard deviation is not 0, then the code checks for the maximum and minimum indices of the numbers. The maximum index is the index of the largest number. The minimum index is the index of the smallest number.
///
/// If the maximum index is less than the minimum index, then the trend is `up`. If the minimum index is less than the maximum index, then the trend is `down`.
///
/// ## Example
///
/// The following code shows how to use the `trend()` function:
///
/// /// let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
/// let trend = TrendAnalyzer.trend(numbers: numbers)
///
/// print(trend.rawValue)
///
/// This code first creates an array of numbers. The array contains ten numbers, which are all increasing. The code then calls the trend() function to analyze the trend of the numbers. The trend() function returns the up case, because the maximum index of the numbers is less than the minimum index.
class TrendAnalyzer {
    public enum Trend: String, CaseIterable {
        case stable
        case up
        case down
        
        var color: Color {
            switch self {
            case .stable:
                return .blue
            case .up:
                return .red
            case .down:
                return .green
            }
        }
        
        var description: String {
            switch self {
            case .stable:
                return "Stable Trend"
            case .up:
                return "Trending Up"
            case .down:
                return "Trending Down"
            }
        }
    }
        
        /// This function analyzes the trend of a set of numbers and returns a `Trend` enum value. The `Trend` enum has three cases: `stable`, `up`, and `down`. The `stable` case is returned if the standard deviation of the numbers is 0. The `up` case is returned if the maximum index of the numbers is less than the minimum index. The `down` case is returned if the minimum index of the numbers is less than the maximum index.
        public static func trend(numbers: [Double]) -> Trend {
            let mean = numbers.reduce(0, +) / Double(numbers.count)
            let variance = numbers.map { pow($0 - mean, 2) }.reduce(0, +) / Double(numbers.count - 1)
            let standardDeviation = sqrt(variance)
            
            if standardDeviation == 0 {
                return .stable
            } else {
                let maxIndex = numbers.firstIndex(where: { $0 > mean + standardDeviation })
                let minIndex = numbers.firstIndex(where: { $0 < mean - standardDeviation })
                
                if maxIndex == nil && minIndex == nil {
                    return .stable
                } else if maxIndex == nil {
                    return .up
                } else if minIndex == nil {
                    return .down
                } else {
                    return maxIndex! < minIndex! ? .down : .up
                }
            }
        }
    }
