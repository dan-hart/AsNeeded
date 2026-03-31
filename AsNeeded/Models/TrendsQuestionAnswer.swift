import Foundation

struct TrendsQuestionAnswer: Equatable, Sendable {
	let answer: String
	let highlights: [String]
	let limitations: [String]
}

struct TrendsQuestionDailyTotal: Equatable, Sendable {
	let dayLabel: String
	let total: Double
}

struct TrendsQuestionContext: Equatable, Sendable {
	let medicationName: String
	let unitName: String
	let windowDays: Int
	let dailyTotals: [TrendsQuestionDailyTotal]
	let patternSummary: String
	let refillSummary: String
	let quantitySummary: String
}
