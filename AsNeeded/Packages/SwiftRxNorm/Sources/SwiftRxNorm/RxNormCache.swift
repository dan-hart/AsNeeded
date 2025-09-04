import Foundation

/// Simple in-memory cache for RxNorm search results
final class RxNormCache {
	private struct CacheEntry {
		let results: [RxNormSearchResult]
		let timestamp: Date
	}
	
	private var cache: [String: CacheEntry] = [:]
	private let maxAge: TimeInterval
	private let maxEntries: Int
	
	init(maxAge: TimeInterval = 3600, maxEntries: Int = 100) {
		self.maxAge = maxAge
		self.maxEntries = maxEntries
	}
	
	/// Get cached results if available and not expired
	func get(_ key: String) -> [RxNormSearchResult]? {
		guard let entry = cache[key] else { return nil }
		
		if Date().timeIntervalSince(entry.timestamp) > maxAge {
			cache.removeValue(forKey: key)
			return nil
		}
		
		return entry.results
	}
	
	/// Store results in cache
	func set(_ key: String, results: [RxNormSearchResult]) {
		// Remove oldest entries if cache is full
		if cache.count >= maxEntries {
			let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
			if let oldestKey = oldestKey {
				cache.removeValue(forKey: oldestKey)
			}
		}
		
		cache[key] = CacheEntry(results: results, timestamp: Date())
	}
	
	/// Clear all cached entries
	func clear() {
		cache.removeAll()
	}
	
	/// Generate cache key for a query with options
	static func key(for query: String, options: SearchOptions) -> String {
		let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		let optionsString = "\(options.maxResults)-\(options.includeApproximate)-\(options.includeSpellingCorrections)-\(options.includeSynonyms)-\(options.minScore)"
		return "\(normalizedQuery):\(optionsString)"
	}
}