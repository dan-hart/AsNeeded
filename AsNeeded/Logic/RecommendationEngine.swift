//
//  RecommendationEngine.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/24/24.
//

import Foundation

/// **RecommendationEngine**
///
/// This class provides personalized recommendations to help reduce a habit gradually.
/// It analyzes the input data (an array of integers representing daily counts) and suggests
/// the next day's intake, aiming to ease the user off the habit over time.
///
/// ### Improvements:
/// - **Dynamic Thresholds:** Automatically sets trend thresholds based on the data's variability.
/// - **Adaptive Reduction:** Calculates the reduction amount based on the trend and user's progress.
/// - **Insightful Feedback:** Provides encouragement messages that reflect the user's trend.
///
/// ### Usage Example:
/// ```swift
/// let counts = [12, 13, 14, 15, 16, 17, 18]
/// let recommendation = RecommendationEngine.recommendNextIntake(numbers: counts)
/// print(recommendation.encouragementMessage) // e.g., "Let's turn things around! You can do it!"
/// print("Try aiming for \(recommendation.recommendedIntake) tomorrow.") // e.g., "Try aiming for 16 tomorrow."
/// ```
class RecommendationEngine {
    
    /// **Recommendation Struct**
    ///
    /// Encapsulates the recommendation details, including the recommended intake
    /// and the encouragement message.
    struct Recommendation {
        /// The recommended intake for the next day.
        let recommendedIntake: Int
        
        /// A positive encouragement message.
        let encouragementMessage: String
    }
    
    /// **Recommendation Function**
    ///
    /// Analyzes the input data and provides a recommendation for the next day's intake.
    /// The recommendation includes the recommended intake and an encouragement message.
    ///
    /// **Improvements:**
    /// - Incorporates trend analysis with dynamic thresholds.
    /// - Adapts the reduction amount based on the user's intake trend.
    ///
    /// **Parameters:**
    /// - `numbers`: An array of `Int` values representing daily counts of the habit.
    ///
    /// **Returns:** A `Recommendation` containing the recommended intake and encouragement message.
    public static func recommendNextIntake(numbers: [Int]) -> Recommendation {
        // Check if there is enough data
        guard numbers.count > 1, let lastIntake = numbers.last else {
            return Recommendation(recommendedIntake: 1, encouragementMessage: "Start tracking your habit to receive personalized recommendations!")
        }
        
        // Calculate the trend using linear regression
        let trend = calculateTrend(data: numbers.map { Double($0) })
        
        // Calculate the standard deviation of the intake data
        let stdDev = calculateStandardDeviation(data: numbers.map { Double($0) })
        
        // Define dynamic thresholds based on standard deviation
        let thresholds = determineDynamicThresholds(stdDev: stdDev)
        
        // Determine the target reduction based on the trend and thresholds
        let reductionAmount = determineReductionAmount(trend: trend, lastIntake: lastIntake, thresholds: thresholds)
        
        // Calculate the recommended intake for the next day
        var recommendedIntake = lastIntake - reductionAmount
        
        // Ensure the recommended intake is not less than 1
        if recommendedIntake < 1 {
            recommendedIntake = 1
        }
        
        // Generate an encouragement message based on the trend
        let encouragement = generateEncouragementMessage(trend: trend, thresholds: thresholds)
        
        // Create and return the Recommendation
        return Recommendation(recommendedIntake: recommendedIntake, encouragementMessage: encouragement)
    }
    
    /// **Calculate Trend Function**
    ///
    /// Calculates the trend (slope) of the intake data using linear regression.
    ///
    /// **Parameters:**
    /// - `data`: An array of `Double` values representing daily counts.
    ///
    /// **Returns:** A `Double` representing the slope of the trend.
    private static func calculateTrend(data: [Double]) -> Double {
        let n = Double(data.count)
        let xValues = (0..<data.count).map { Double($0) }
        let yValues = data
        
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = n * sumX2 - sumX * sumX
        
        // Avoid division by zero
        guard denominator != 0 else {
            return 0
        }
        
        let slope = numerator / denominator
        return slope
    }
    
    /// **Calculate Standard Deviation Function**
    ///
    /// Calculates the standard deviation of the intake data.
    ///
    /// **Parameters:**
    /// - `data`: An array of `Double` values representing daily counts.
    ///
    /// **Returns:** A `Double` representing the standard deviation.
    private static func calculateStandardDeviation(data: [Double]) -> Double {
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count)
        let stdDev = sqrt(variance)
        return stdDev
    }
    
    /// **Determine Dynamic Thresholds Function**
    ///
    /// Defines thresholds for trend categorization based on the standard deviation.
    ///
    /// **Parameters:**
    /// - `stdDev`: A `Double` representing the standard deviation of the data.
    ///
    /// **Returns:** A tuple containing positive and negative thresholds.
    private static func determineDynamicThresholds(stdDev: Double) -> (positive: Double, negative: Double) {
        // Factor to adjust sensitivity (can be tuned)
        let factor = 0.1
        
        // Thresholds are a function of standard deviation and factor
        let positiveThreshold = stdDev * factor
        let negativeThreshold = -stdDev * factor
        
        return (positive: positiveThreshold, negative: negativeThreshold)
    }
    
    /// **Determine Reduction Amount Function**
    ///
    /// Calculates the amount to reduce for the next day's intake based on the trend and thresholds.
    ///
    /// **Logic:**
    /// - **Strong Increasing Trend:** Suggest a more significant reduction.
    /// - **Slight Increasing Trend:** Suggest a moderate reduction.
    /// - **Stable Trend:** Suggest a minimal reduction to initiate progress.
    /// - **Slight Decreasing Trend:** Maintain or slightly reduce to keep momentum.
    /// - **Strong Decreasing Trend:** Suggest maintaining current reduction rate.
    ///
    /// **Parameters:**
    /// - `trend`: A `Double` representing the slope of the intake trend.
    /// - `lastIntake`: The intake value from the last day.
    /// - `thresholds`: A tuple containing positive and negative thresholds.
    ///
    /// **Returns:** An `Int` representing the reduction amount.
    private static func determineReductionAmount(trend: Double, lastIntake: Int, thresholds: (positive: Double, negative: Double)) -> Int {
        // Define base reduction amount
        var reductionAmount: Int
        
        if trend > thresholds.positive * 2 {
            // Strong increasing trend
            reductionAmount = Int(Double(lastIntake) * 0.15) // Reduce by 15% of last intake
        } else if trend > thresholds.positive {
            // Slight increasing trend
            reductionAmount = Int(Double(lastIntake) * 0.10) // Reduce by 10% of last intake
        } else if trend < thresholds.negative * 2 {
            // Strong decreasing trend
            reductionAmount = Int(Double(lastIntake) * 0.05) // Reduce by 5% of last intake
        } else if trend < thresholds.negative {
            // Slight decreasing trend
            reductionAmount = Int(Double(lastIntake) * 0.03) // Reduce by 3% of last intake
        } else {
            // Stable trend
            reductionAmount = Int(Double(lastIntake) * 0.08) // Reduce by 8% of last intake
        }
        
        // Ensure at least a reduction of 1
        if reductionAmount < 1 {
            reductionAmount = 1
        }
        
        return reductionAmount
    }
    
    /// **Generate Encouragement Message Function**
    ///
    /// Provides a positive and generic encouragement message based on the trend and thresholds.
    ///
    /// **Parameters:**
    /// - `trend`: A `Double` representing the slope of the intake trend.
    /// - `thresholds`: A tuple containing positive and negative thresholds.
    ///
    /// **Returns:** A `String` containing the encouragement message.
    private static func generateEncouragementMessage(trend: Double, thresholds: (positive: Double, negative: Double)) -> String {
        let positiveMessages = [
            "Great job on taking steps to reduce!",
            "Keep up the good work!",
            "You're making fantastic progress!",
            "Every step counts!",
            "You're on the right track!",
            "Positive changes are happening!",
            "Small steps lead to big results!",
            "Your effort is paying off!",
            "You're doing an amazing job!",
            "Keep striving for your goals!",
            "Every reduction is a step forward!",
            "Believe in yourself, you've got this!",
            "Progress, not perfection!",
            "Stay strong, you're making a difference!",
            "Your dedication is inspiring!",
            "One day at a time!",
            "Success is on the horizon!",
            "Small changes lead to big outcomes!",
            "You're capable of great things!",
            "Keep moving forward!",
            "Your efforts are commendable!",
            "You're making healthy choices!",
            "Stay focused and keep pushing!",
            "Your hard work is noticeable!",
            "You're making positive changes!",
            "Keep up the momentum!",
            "You're a role model for others!",
            "Each day is a new opportunity!",
            "Don't give up, you're doing great!",
            "Your progress is remarkable!",
            "You're making a real difference!",
            "Stay committed to your goals!",
            "You're on the path to success!",
            "Every effort counts!",
            "You're stronger than you think!",
            "Believe in your progress!",
            "Your determination is admirable!",
            "You're making wise choices!",
            "Stay positive and keep going!",
            "Your journey is inspiring!",
            "You're building healthy habits!",
            "Keep challenging yourself!",
            "You're achieving great things!",
            "Your progress is motivating!",
            "Stay dedicated and keep improving!",
            "You're reaching new heights!",
            "Keep setting and smashing goals!",
            "Your hard work is paying off!",
            "You're making excellent strides!",
            "Stay focused on your journey!",
            "You're an inspiration!",
            // Additional positive messages
            "Your commitment is leading to success!",
            "You're transforming your habits positively!",
            "Keep embracing the change!",
            "Your positive attitude is contagious!",
            "You're on a winning streak!",
            "Keep investing in yourself!",
            "Your progress is a testament to your effort!",
            "You're paving the way for success!",
            "Stay the course, greatness awaits!",
            "You're setting yourself up for success!",
            "Your actions today are shaping a better tomorrow!",
            "You're unlocking new achievements!",
            "Keep nurturing your growth!",
            "Your perseverance is paying dividends!",
            "You're making impactful changes!",
            "Stay confident, you're doing wonderfully!",
            "Your dedication is making a difference!",
            "You're cultivating success!",
            "Keep up the splendid work!",
            "Your journey is commendable!",
            "You're elevating your standards!",
            "Stay motivated, amazing things are happening!",
            "You're conquering your goals one by one!",
            "Keep building on your successes!",
            "Your efforts are yielding great results!",
            "You're on an upward trajectory!",
            "Stay enthusiastic, you're thriving!",
            "Your progress is exceptional!",
            "You're a beacon of positive change!",
            "Keep flourishing and growing!",
            "Your determination is leading the way!",
            "You're mastering positive habits!",
            "Stay inspired, you're achieving greatness!",
            "Your hard work is setting you apart!",
            "You're creating a legacy of success!",
            "Keep shining brightly!",
            "Your achievements are remarkable!",
            "You're surpassing your goals!",
            "Stay driven, the sky's the limit!",
            "You're making strides towards excellence!",
            "Keep making a positive impact!",
            "Your success story is unfolding!",
            "You're an example of perseverance!",
            "Stay passionate, you're making it happen!",
            "Your progress is extraordinary!",
            "You're a force for positive change!",
            "Keep reaching for new heights!",
            "Your dedication is truly admirable!",
            "You're achieving outstanding results!",
            "Stay focused, you're excelling!",
            "Your journey is a success!",
            "You're realizing your potential!",
            "Keep up the extraordinary effort!",
            "Your commitment shines through!",
            "You're accomplishing remarkable feats!",
            "Stay relentless, you're unstoppable!",
            "Your progress is a source of inspiration!"
        ]
        
        let neutralMessages = [
            "Let's take the next step together!",
            "Stay focused, you can do it!",
            "Every journey begins with a single step!",
            "Keep moving forward!",
            "Consistency is key!",
            "Believe in yourself!",
            "Stay determined!",
            "You're capable of making a change!",
            "Let's work towards your goals!",
            "Keep your eyes on the prize!",
            "One step at a time!",
            "Stay motivated!",
            "You're on a journey of growth!",
            "Keep pushing forward!",
            "Your goals are within reach!",
            "Stay positive!",
            "Every day is a new opportunity!",
            "Keep striving!",
            "Believe in your abilities!",
            "Stay committed!",
            "You're making progress!",
            "Keep your momentum going!",
            "Stay focused on your path!",
            "You have the power to change!",
            "Let's keep going!",
            "Your efforts matter!",
            "Keep building good habits!",
            "Stay proactive!",
            "You're moving in the right direction!",
            "Let's continue to improve!",
            "Your journey is important!",
            "Keep up the steady pace!",
            "Stay engaged!",
            "You're capable of great things!",
            "Keep your goals in sight!",
            "Stay on track!",
            "You're making steady progress!",
            "Keep working towards your goals!",
            "Stay consistent!",
            "You're developing positive habits!",
            "Keep aiming high!",
            "Stay on your path to success!",
            "You're building a better future!",
            "Keep focusing on your growth!",
            "Stay resilient!",
            "You're moving forward!",
            "Keep your spirits up!",
            "Stay committed to your journey!",
            "You're capable of achieving your goals!",
            "Keep up the effort!",
            "Your dedication will pay off!",
            // Additional neutral messages
            "Let's keep making progress together!",
            "Stay attentive to your goals!",
            "You're laying the foundation for success!",
            "Keep your determination strong!",
            "Stay mindful of your journey!",
            "You're on the road to improvement!",
            "Keep your energy focused!",
            "Stay persistent!",
            "You're cultivating positive change!",
            "Keep moving towards your aspirations!",
            "Stay true to your objectives!",
            "You're building momentum!",
            "Keep your motivation high!",
            "Stay committed to your path!",
            "You're on a journey of betterment!",
            "Keep your focus sharp!",
            "Stay engaged with your goals!",
            "You're taking meaningful steps!",
            "Keep progressing steadily!",
            "Stay dedicated to your improvement!",
            "You're crafting your success story!",
            "Keep aligning with your goals!",
            "Stay proactive in your journey!",
            "You're advancing towards your targets!",
            "Keep up the consistent effort!",
            "Stay determined to succeed!",
            "You're paving your way forward!",
            "Keep your goals front and center!",
            "Stay encouraged!",
            "You're working towards positive outcomes!",
            "Keep your progress in motion!",
            "Stay dedicated to your success!",
            "You're fostering growth!",
            "Keep pursuing your objectives!",
            "Stay committed to your mission!",
            "You're enhancing your journey!",
            "Keep your dedication strong!",
            "Stay focused on your advancement!",
            "You're shaping your future!",
            "Keep striving for improvement!",
            "Stay invested in your goals!",
            "You're on a path of progress!",
            "Keep your efforts consistent!",
            "Stay centered on your aspirations!",
            "You're building towards success!",
            "Keep moving ahead!",
            "Stay dedicated to your purpose!",
            "You're forging ahead!",
            "Keep your commitment unwavering!",
            "Stay focused on your vision!",
            "You're creating positive momentum!",
            "Keep your determination alive!",
            "Stay connected to your goals!"
        ]
        
        let encouragingMessages = [
            "Let's turn things around! You can do it!",
            "Don't be discouraged; every day is a new opportunity!",
            "Stay strong; you have the power to change!",
            "Keep pushing; progress is within reach!",
            "Believe in your ability to improve!",
            "You can overcome any challenge!",
            "Stay positive; change is possible!",
            "Keep striving; you've got this!",
            "Every effort brings you closer to your goal!",
            "Believe in yourself!",
            "Let's make tomorrow better!",
            "Stay determined; you can make a difference!",
            "Keep your head up; progress takes time!",
            "You have the strength to change!",
            "Don't give up; keep trying!",
            "Stay focused; improvement is ahead!",
            "Your potential is limitless!",
            "Keep working towards your goal!",
            "Believe in the power of change!",
            "Let's focus on making progress!",
            "Stay hopeful; you can achieve your goals!",
            "Keep moving forward!",
            "You have what it takes!",
            "Stay committed; you can do this!",
            "Every step forward counts!",
            "Let's turn challenges into opportunities!",
            "Stay encouraged; better days are ahead!",
            "You are capable of great things!",
            "Keep believing in yourself!",
            "Stay resilient; you can succeed!",
            "Your journey starts now!",
            "Keep aiming for improvement!",
            "Stay strong; progress is possible!",
            "You can make a positive change!",
            "Keep your goals in sight!",
            "Believe in your journey!",
            "Let's work towards a better tomorrow!",
            "Stay motivated; you can achieve anything!",
            "You have the power to transform!",
            "Keep pushing forward!",
            "Stay focused on your goals!",
            "Your efforts can make a difference!",
            "Keep striving for success!",
            "Stay determined; change is within reach!",
            "You can create the future you want!",
            "Keep your spirits high!",
            "Stay positive; progress awaits!",
            "You are stronger than any challenge!",
            "Keep moving towards your goals!",
            "Stay inspired; you can do it!",
            "Your journey is just beginning!",
            // Additional encouraging messages
            "Let's embrace the opportunity to improve!",
            "Stay confident; you're capable of change!",
            "You have the courage to start anew!",
            "Keep working towards better outcomes!",
            "Believe in the possibility of success!",
            "Stay focused; your efforts matter!",
            "You can rise above any obstacle!",
            "Keep your determination strong!",
            "Stay hopeful; progress is on the horizon!",
            "You have the ability to make a difference!",
            "Keep striving; every effort counts!",
            "Stay committed; you're on the path to success!",
            "Your persistence will pay off!",
            "Keep moving; brighter days are ahead!",
            "Believe in the power of your actions!",
            "Stay encouraged; you can achieve your goals!",
            "You can turn things around!",
            "Keep your eyes on the prize!",
            "Stay dedicated; progress is possible!",
            "Your journey towards improvement starts now!",
            "Keep pushing; you have the strength!",
            "Stay motivated; change is attainable!",
            "You can make it happen!",
            "Keep your focus sharp!",
            "Believe in yourself; you are capable!",
            "Stay inspired; your goals are within reach!",
            "You have the potential to succeed!",
            "Keep working; every step matters!",
            "Stay positive; you can overcome challenges!",
            "Your determination can lead to success!",
            "Keep moving forward; progress is near!",
            "Stay resilient; you can achieve greatness!",
            "You have the power to change your path!",
            "Keep striving; better days await!",
            "Stay focused; your efforts are valuable!",
            "You can make a significant change!",
            "Keep your motivation high!",
            "Believe in the journey ahead!",
            "Stay dedicated; you can reach your goals!",
            "Your actions today shape your tomorrow!",
            "Keep pushing; success is possible!",
            "Stay hopeful; you can do it!",
            "You have the strength to make a difference!",
            "Keep moving; progress is within sight!",
            "Stay inspired; your goals are achievable!",
            "You can create positive change!",
            "Keep your commitment strong!",
            "Believe in your ability to succeed!",
            "Stay encouraged; you're on your way!",
            "Your journey is filled with potential!",
            "Keep striving; you can make it happen!",
            "Stay focused; progress is attainable!",
            "You have the power to achieve your goals!",
            "Keep pushing forward; success awaits!"
        ]
        
        // Select messages based on the trend and dynamic thresholds
        let messages: [String]
        
        if trend < thresholds.negative * 2 {
            // Strong decreasing trend
            messages = positiveMessages
        } else if trend < thresholds.negative {
            // Slight decreasing trend
            messages = positiveMessages
        } else if trend > thresholds.positive * 2 {
            // Strong increasing trend
            messages = encouragingMessages
        } else if trend > thresholds.positive {
            // Slight increasing trend
            messages = encouragingMessages
        } else {
            // Stable trend
            messages = neutralMessages
        }
        
        // Randomly select a message
        let message = messages.randomElement() ?? "Keep going!"
        
        return message
    }
}
