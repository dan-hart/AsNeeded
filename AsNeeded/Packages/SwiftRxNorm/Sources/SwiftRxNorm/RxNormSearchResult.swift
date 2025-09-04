import Foundation

/// Enhanced search result with metadata for better UX
public struct RxNormSearchResult: Codable, Hashable, Sendable {
	/// The drug information
	public let drug: RxNormDrug
	
	/// Relevance score (0.0 to 1.0, where 1.0 is most relevant)
	public let score: Double
	
	/// Source of the result
	public let source: SearchSource
	
	/// Whether this is an exact match
	public let isExactMatch: Bool
	
	/// Original search term that matched
	public let matchedTerm: String?
	
	/// Creates a new search result
	public init(
		drug: RxNormDrug,
		score: Double = 1.0,
		source: SearchSource = .direct,
		isExactMatch: Bool = false,
		matchedTerm: String? = nil
	) {
		self.drug = drug
		self.score = min(max(score, 0.0), 1.0) // Clamp between 0 and 1
		self.source = source
		self.isExactMatch = isExactMatch
		self.matchedTerm = matchedTerm
	}
}

/// Source of the search result
public enum SearchSource: String, Codable, Sendable {
	case direct = "direct"
	case approximate = "approximate"
	case spellingSuggestion = "spelling"
	case synonym = "synonym"
}

/// Options for configuring search behavior
public struct SearchOptions: Sendable {
	/// Maximum number of results to return
	public let maxResults: Int
	
	/// Whether to include approximate matches
	public let includeApproximate: Bool
	
	/// Whether to include spelling corrections
	public let includeSpellingCorrections: Bool
	
	/// Whether to include synonym matches
	public let includeSynonyms: Bool
	
	/// Minimum score threshold for results (0.0 to 1.0)
	public let minScore: Double
	
	/// Whether to sort results by score
	public let sortByRelevance: Bool
	
	/// Default options optimized for autocomplete
	public static let autocomplete = SearchOptions(
		maxResults: 10,
		includeApproximate: true,
		includeSpellingCorrections: false,
		includeSynonyms: false,
		minScore: 0.5,
		sortByRelevance: true
	)
	
	/// Default options optimized for comprehensive search
	public static let comprehensive = SearchOptions(
		maxResults: 50,
		includeApproximate: true,
		includeSpellingCorrections: true,
		includeSynonyms: true,
		minScore: 0.0,
		sortByRelevance: true
	)
	
	/// Default options optimized for exact search
	public static let exact = SearchOptions(
		maxResults: 25,
		includeApproximate: false,
		includeSpellingCorrections: false,
		includeSynonyms: false,
		minScore: 0.8,
		sortByRelevance: false
	)
	
	public init(
		maxResults: Int = 25,
		includeApproximate: Bool = true,
		includeSpellingCorrections: Bool = true,
		includeSynonyms: Bool = false,
		minScore: Double = 0.0,
		sortByRelevance: Bool = true
	) {
		self.maxResults = max(1, min(maxResults, 100)) // Clamp between 1 and 100
		self.includeApproximate = includeApproximate
		self.includeSpellingCorrections = includeSpellingCorrections
		self.includeSynonyms = includeSynonyms
		self.minScore = min(max(minScore, 0.0), 1.0) // Clamp between 0 and 1
		self.sortByRelevance = sortByRelevance
	}
}

/// Result of an autocomplete operation
public struct AutocompleteResult: Sendable {
	/// The suggested completions
	public let suggestions: [RxNormSearchResult]
	
	/// Whether more results are available
	public let hasMore: Bool
	
	/// The query that was searched
	public let query: String
	
	/// Time taken for the search (in seconds)
	public let searchTime: TimeInterval
	
	public init(
		suggestions: [RxNormSearchResult],
		hasMore: Bool = false,
		query: String,
		searchTime: TimeInterval = 0
	) {
		self.suggestions = suggestions
		self.hasMore = hasMore
		self.query = query
		self.searchTime = searchTime
	}
}