//
//  TrendAnalyzer.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/20/23.
//

import Foundation
import SwiftUI

/// **TrendAnalyzer**
///
/// This class provides functions to analyze the trend of a set of numbers using weighted linear regression.
/// It includes outlier handling and moving averages to improve the robustness of the trend detection.
///
/// ### Enhancements Implemented:
/// - **Weighted Regression:** Gives more weight to recent data points, under the assumption that they are more indicative of the current trend.
/// - **Moving Averages:** Applies a simple moving average to smooth out short-term fluctuations and highlight longer-term trends.
/// - **Outlier Handling:** Utilizes the Interquartile Range (IQR) method to detect and remove outliers from the dataset.
/// - **Time Series Consideration:** Takes into account the sequential order of data points.
/// - **Threshold Adjustment:** Introduces a threshold to define the sensitivity of trend detection.
/// - **Data Validation:** Ensures there are enough data points to perform trend analysis.
///
/// ### Usage Example:
/// ```swift
/// let numbers = [5.0, 4.5, 4.0, 3.5, 3.0, 2.5, 2.0]
/// let trend = TrendAnalyzer.trend(numbers: numbers)
/// print(trend.description) // Output: "Trending Down"
/// ```
class TrendAnalyzer {
    /// **Trend Enum**
    ///
    /// Represents the possible trends in the data.
    public enum Trend: String, CaseIterable {
        case stable
        case up
        case down
        
        /// Associated color for each trend.
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
        
        /// Description for each trend.
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
    
    /// **Trend Analysis Function**
    ///
    /// Analyzes the trend of a set of numbers and returns a `Trend` enum value.
    ///
    /// **Enhancements:**
    /// - **Moving Averages:** Applies a moving average to smooth the data.
    /// - **Outlier Handling:** Removes outliers using the Interquartile Range (IQR) method.
    /// - **Weighted Regression:** Performs weighted linear regression, giving more weight to recent data points.
    ///
    /// **Parameters:**
    /// - `numbers`: An array of `Double` values representing the data.
    /// - `movingAveragePeriod`: An `Int` specifying the period for the moving average. Default is `1` (no smoothing).
    ///
    /// **Returns:** A `Trend` indicating whether the data is trending up, down, or stable.
    public static func trend(numbers: [Double], movingAveragePeriod: Int = 1) -> Trend {
        // Check if there are enough data points
        guard numbers.count > 1 else {
            return .stable // Not enough data to determine a trend
        }
        
        // Apply moving average to smooth out short-term fluctuations
        let smoothedNumbers = movingAverage(numbers: numbers, period: movingAveragePeriod)
        
        // Handle outliers using the interquartile range (IQR) method
        let cleanedNumbers = removeOutliers(numbers: smoothedNumbers)
        
        // Re-check if we have enough data after outlier removal
        guard cleanedNumbers.count > 1 else {
            return .stable
        }
        
        // Perform weighted linear regression to calculate the slope
        let slope = calculateWeightedSlope(data: cleanedNumbers)
        
        // Define a small threshold to account for minor fluctuations
        let threshold = 0.01
        
        // Determine the trend based on the slope
        if slope > threshold {
            return .up
        } else if slope < -threshold {
            return .down
        } else {
            return .stable
        }
    }
    
    /// **Moving Average Function**
    ///
    /// Applies a simple moving average to the data to smooth out short-term fluctuations.
    ///
    /// **Parameters:**
    /// - `numbers`: An array of `Double` values representing the original data.
    /// - `period`: The number of data points to include in each average calculation.
    ///
    /// **Returns:** An array of `Double` values representing the smoothed data.
    private static func movingAverage(numbers: [Double], period: Int) -> [Double] {
        guard period > 1, numbers.count >= period else {
            return numbers // Not enough data to smooth
        }
        
        var smoothedNumbers = [Double]()
        for i in 0...(numbers.count - period) {
            let window = numbers[i..<(i + period)]
            let average = window.reduce(0, +) / Double(period)
            smoothedNumbers.append(average)
        }
        return smoothedNumbers
    }
    
    /// **Calculate Weighted Slope Function**
    ///
    /// Calculates the slope of the best-fit line using weighted linear regression.
    ///
    /// **Weighted Regression:**
    /// - Assigns weights to data points, giving more weight to recent data points.
    /// - Uses the weights in the regression calculations to emphasize recent trends.
    ///
    /// **Parameters:**
    /// - `data`: An array of `Double` values representing the cleaned and smoothed data.
    ///
    /// **Returns:** The weighted slope as a `Double`.
    private static func calculateWeightedSlope(data: [Double]) -> Double {
        let n = Double(data.count)
        let xValues = (0..<data.count).map { Double($0) }
        let yValues = data
        
        // Assign weights, giving more weight to recent data points
        let weights = (1...data.count).map { Double($0) } // Weights increase linearly
        
        let sumW = weights.reduce(0, +)
        let sumWX = zip(weights, xValues).map(*).reduce(0, +)
        let sumWY = zip(weights, yValues).map(*).reduce(0, +)
        let sumWXX = zip(weights, xValues.map { $0 * $0 }).map(*).reduce(0, +)
        let sumWXY = zip(weights, zip(xValues, yValues).map(*)).map(*).reduce(0, +)
        
        let numerator = sumW * sumWXY - sumWX * sumWY
        let denominator = sumW * sumWXX - sumWX * sumWX
        
        // Avoid division by zero
        guard denominator != 0 else {
            return 0
        }
        
        return numerator / denominator
    }
    
    /// **Remove Outliers Function**
    ///
    /// Removes outliers from the data using the interquartile range (IQR) method.
    ///
    /// **Outlier Handling:**
    /// - **Interquartile Range (IQR) Method:**
    ///   - Calculates the first (Q1) and third (Q3) quartiles.
    ///   - Computes the IQR as `IQR = Q3 - Q1`.
    ///   - Defines lower and upper bounds as `Q1 - 1.5 * IQR` and `Q3 + 1.5 * IQR`.
    ///   - Filters out data points outside these bounds.
    ///
    /// **Parameters:**
    /// - `numbers`: An array of `Double` values representing the data.
    ///
    /// **Returns:** An array of `Double` values with outliers removed.
    private static func removeOutliers(numbers: [Double]) -> [Double] {
        let sortedNumbers = numbers.sorted()
        let quartile1 = percentile(sortedNumbers, percentile: 25)
        let quartile3 = percentile(sortedNumbers, percentile: 75)
        let iqr = quartile3 - quartile1
        
        // Define outlier boundaries
        let lowerBound = quartile1 - 1.5 * iqr
        let upperBound = quartile3 + 1.5 * iqr
        
        // Filter out the outliers
        return numbers.filter { $0 >= lowerBound && $0 <= upperBound }
    }
    
    /// **Percentile Calculation Function**
    ///
    /// Calculates the percentile of a sorted array.
    ///
    /// **Parameters:**
    /// - `sortedNumbers`: An array of `Double` values sorted in ascending order.
    /// - `percentile`: The desired percentile (e.g., 25 for Q1, 75 for Q3).
    ///
    /// **Returns:** The value at the specified percentile.
    private static func percentile(_ sortedNumbers: [Double], percentile: Double) -> Double {
        let k = (Double(sortedNumbers.count - 1)) * percentile / 100.0
        let f = floor(k)
        let c = ceil(k)
        
        if f == c {
            return sortedNumbers[Int(k)]
        } else {
            let d0 = sortedNumbers[Int(f)] * (c - k)
            let d1 = sortedNumbers[Int(c)] * (k - f)
            return d0 + d1
        }
    }
}
