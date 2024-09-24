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
/// The `TrendAnalyzer` class provides comprehensive tools for analyzing trends in numerical data, particularly consumption patterns. It offers functions for trend analysis, outlier handling, moving averages, consumption forecasting, non-linear trend modeling, and seasonal adjustments.
///
/// ### Key Features:
/// - **Trend Analysis:** Determines the trend direction using linear regression and exponential smoothing.
/// - **Consumption Forecasting:** Analyzes historical consumption data against a limited supply, incorporating consumption trends and seasonal patterns.
/// - **Outlier Handling:** Removes outliers to improve analysis accuracy.
/// - **Moving Averages:** Smooths data to highlight longer-term trends.
/// - **Non-Linear Trend Modeling:** Uses exponential smoothing to capture non-linear trends.
/// - **Seasonal Adjustments:** Incorporates seasonal patterns (e.g., weekly cycles) into projections.
///
/// ### Usage Example:
/// ```swift
/// let dailyConsumption = [5, 6, 7, 6, 5, 6, 7, 8, 7, 6, 5]
/// let totalSupply = 150
/// let periodLength = 30
///
/// let status = TrendAnalyzer.consumptionStatus(numbers: dailyConsumption, totalSupply: totalSupply, periodLength: periodLength, seasonLength: 7)
///
/// print(status.rawValue) // e.g., "On Track"
/// print(status.description) // e.g., "You are on track with your consumption."
/// ```
class TrendAnalyzer {
    
    // MARK: - Enumerations
    
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
    
    /// **Consumption Status Enum**
    ///
    /// Represents the consumption status based on historical intake and limited supply.
    public enum ConsumptionStatus: String, CaseIterable {
        case ahead = "Ahead"
        case onTrack = "On Track"
        case slowDown = "Slow Down"
        case behind = "Behind"
        case danger = "Danger"
        
        /// Description for each status.
        var description: String {
            switch self {
            case .ahead:
                return "You are ahead of schedule. You may have surplus supply."
            case .onTrack:
                return "You are on track with your consumption."
            case .slowDown:
                return "Slow down your consumption to avoid running out of supply."
            case .behind:
                return "You are behind schedule. Consider slowing down your consumption."
            case .danger:
                return "Danger of running out! Significantly reduce your consumption."
            }
        }
    }
    
    // MARK: - Trend Analysis Functions
    
    /// **Trend Analysis Function**
    ///
    /// Analyzes the trend of a set of numbers and returns a `Trend` enum value.
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
        
        // Perform exponential smoothing to calculate the trend
        let trendSlope = calculateExponentialSmoothingSlope(data: cleanedNumbers)
        
        // Define a small threshold to account for minor fluctuations
        let threshold = 0.01
        
        // Determine the trend based on the slope
        if trendSlope > threshold {
            return .up
        } else if trendSlope < -threshold {
            return .down
        } else {
            return .stable
        }
    }
    
    // MARK: - Consumption Forecasting Function
    
    /// **Consumption Status Function**
    ///
    /// Analyzes historical consumption data against a limited supply to determine consumption status.
    /// Incorporates the consumption trend and seasonal patterns for a more accurate forecast.
    ///
    /// **Parameters:**
    /// - `numbers`: An array of `Int` values representing daily consumption.
    /// - `totalSupply`: An `Int` representing the total supply available (e.g., total apples per period).
    /// - `periodLength`: An `Int` representing the total number of days in the period (e.g., days in a month).
    /// - `seasonLength`: An `Int` representing the length of the season (e.g., 7 for weekly patterns). Default is `0` (no seasonality).
    ///
    /// **Returns:** A `ConsumptionStatus` indicating whether you need to adjust your consumption rate.
    public static func consumptionStatus(numbers: [Int], totalSupply: Int, periodLength: Int, seasonLength: Int = 0) -> ConsumptionStatus {
        guard !numbers.isEmpty else {
            return .onTrack // Default status when no data is available
        }
        
        // Calculate total consumption so far
        let totalConsumed = numbers.reduce(0, +)
        
        // Calculate the number of days passed
        let daysPassed = numbers.count
        
        // Adjust projected consumption based on trend and seasonality
        let projectedTotalConsumption = projectedConsumption(numbers: numbers.map { Double($0) }, totalSupply: totalSupply, periodLength: periodLength, seasonLength: seasonLength)
        
        // Determine the status based on projected consumption and supply
        let status: ConsumptionStatus
        
        // Define thresholds for statuses
        let surplusThreshold = Double(totalSupply) * 0.9 // 90% or more of supply remains
        let deficitThreshold = Double(totalSupply) * 1.1 // Consumption projected to exceed supply by 10% or more
        
        if projectedTotalConsumption < Double(totalSupply) * 0.75 {
            status = .behind
        } else if projectedTotalConsumption < surplusThreshold {
            status = .ahead
        } else if projectedTotalConsumption <= Double(totalSupply) {
            status = .onTrack
        } else if projectedTotalConsumption <= deficitThreshold {
            status = .slowDown
        } else {
            status = .danger
        }
        
        return status
    }
    
    // MARK: - Non-Linear Trend Modeling and Seasonal Adjustments
    
    /// **Projected Consumption Function**
    ///
    /// Projects total consumption for the period by incorporating consumption trend and seasonal adjustments.
    ///
    /// **Parameters:**
    /// - `numbers`: An array of `Double` values representing daily consumption.
    /// - `totalSupply`: Total supply available for the period.
    /// - `periodLength`: Total number of days in the period.
    /// - `seasonLength`: Length of the season (e.g., 7 for weekly patterns). Default is `0` (no seasonality).
    ///
    /// **Returns:** A `Double` representing the projected total consumption.
    private static func projectedConsumption(numbers: [Double], totalSupply: Int, periodLength: Int, seasonLength: Int) -> Double {
        let daysPassed = numbers.count
        let totalConsumed = numbers.reduce(0, +)
        
        // Calculate the consumption trend using exponential smoothing
        let consumptionTrend = calculateExponentialSmoothingSlope(data: numbers)
        
        // Calculate seasonal indices if seasonality is considered
        var seasonalIndices: [Double] = []
        if seasonLength > 0 {
            seasonalIndices = calculateSeasonalIndices(data: numbers, seasonLength: seasonLength)
        }
        
        var projectedConsumption = totalConsumed
        
        // Project future consumption
        for day in daysPassed..<periodLength {
            var projectedValue = numbers.last ?? 0.0
            // Adjust for trend
            projectedValue += consumptionTrend * Double(day - daysPassed + 1)
            // Adjust for seasonality
            if seasonLength > 0 && !seasonalIndices.isEmpty {
                let seasonIndex = day % seasonLength
                projectedValue *= seasonalIndices[seasonIndex]
            }
            projectedConsumption += projectedValue
        }
        
        return projectedConsumption
    }
    
    /// **Calculate Exponential Smoothing Slope Function**
    ///
    /// Calculates the trend slope using exponential smoothing to capture non-linear trends.
    ///
    /// **Parameters:**
    /// - `data`: An array of `Double` values representing the data.
    /// - `alpha`: The smoothing factor between 0 and 1. Default is `0.3`.
    ///
    /// **Returns:** A `Double` representing the smoothed trend slope.
    private static func calculateExponentialSmoothingSlope(data: [Double], alpha: Double = 0.3) -> Double {
        guard data.count > 1 else { return 0.0 }
        
        var smoothedData = [data[0]]
        
        // Apply exponential smoothing
        for i in 1..<data.count {
            let smoothedValue = alpha * data[i] + (1 - alpha) * smoothedData[i - 1]
            smoothedData.append(smoothedValue)
        }
        
        // Calculate the slope of the smoothed data
        let n = Double(smoothedData.count)
        let xValues = (0..<smoothedData.count).map { Double($0) }
        let yValues = smoothedData
        
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = n * sumX2 - sumX * sumX
        
        guard denominator != 0 else { return 0.0 }
        
        let slope = numerator / denominator
        return slope
    }
    
    /// **Calculate Seasonal Indices Function**
    ///
    /// Calculates seasonal indices for the data to adjust projections based on seasonal patterns.
    ///
    /// **Parameters:**
    /// - `data`: An array of `Double` values representing the data.
    /// - `seasonLength`: An `Int` representing the length of the season (e.g., 7 for weekly patterns).
    ///
    /// **Returns:** An array of `Double` values representing the seasonal indices.
    private static func calculateSeasonalIndices(data: [Double], seasonLength: Int) -> [Double] {
        guard data.count >= seasonLength else {
            return Array(repeating: 1.0, count: seasonLength)
        }
        
        var seasonAverages = [Double]()
        var seasonalIndices = [Double](repeating: 0.0, count: seasonLength)
        
        // Calculate average for each season
        let seasons = data.count / seasonLength
        for season in 0..<seasons {
            let startIndex = season * seasonLength
            let endIndex = startIndex + seasonLength
            let seasonData = data[startIndex..<endIndex]
            let average = seasonData.reduce(0, +) / Double(seasonLength)
            seasonAverages.append(average)
        }
        
        // Calculate seasonal indices
        for i in 0..<seasonLength {
            var indexSum = 0.0
            for season in 0..<seasons {
                let dataIndex = season * seasonLength + i
                indexSum += data[dataIndex] / seasonAverages[season]
            }
            seasonalIndices[i] = indexSum / Double(seasons)
        }
        
        return seasonalIndices
    }
    
    // MARK: - Helper Functions
    
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
