import Foundation

/// Advanced fuzzy matching for drug names
struct FuzzyMatcher {
	
	/// Calculate similarity score between two strings using multiple algorithms
	static func score(_ query: String, _ target: String) -> Double {
		let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		let t = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Exact match
		if q == t {
			return 1.0
		}
		
		// Calculate multiple similarity metrics
		let prefixScore = prefixSimilarity(q, t)
		let containsScore = containsSimilarity(q, t)
		let levenshteinScore = 1.0 - (Double(levenshteinDistance(q, t)) / Double(max(q.count, t.count)))
		let phoneticsScore = phoneticSimilarity(q, t)
		let tokenScore = tokenSimilarity(q, t)
		
		// Weight the scores (optimized for drug names)
		let weights: [Double] = [
			prefixScore * 0.35,      // High weight for prefix matches (users often type beginning)
			containsScore * 0.20,     // Medium weight for contains
			levenshteinScore * 0.20,  // Medium weight for edit distance
			phoneticsScore * 0.15,    // Lower weight for phonetic similarity
			tokenScore * 0.10         // Lower weight for token matching
		]
		
		return min(weights.reduce(0, +), 1.0)
	}
	
	/// Check if query is a prefix of target (important for autocomplete)
	private static func prefixSimilarity(_ query: String, _ target: String) -> Double {
		if target.hasPrefix(query) {
			// Give higher score for shorter targets (more exact)
			let lengthRatio = Double(query.count) / Double(target.count)
			return 0.8 + (lengthRatio * 0.2)
		}
		
		// Check if any word in target starts with query
		let targetWords = target.split(separator: " ")
		for word in targetWords {
			if word.lowercased().hasPrefix(query) {
				return 0.7
			}
		}
		
		return 0.0
	}
	
	/// Check if target contains query
	private static func containsSimilarity(_ query: String, _ target: String) -> Double {
		if target.contains(query) {
			// Position matters - earlier is better
			if let range = target.range(of: query) {
				let position = target.distance(from: target.startIndex, to: range.lowerBound)
				let ratio = 1.0 - (Double(position) / Double(target.count))
				return 0.5 + (ratio * 0.5)
			}
		}
		return 0.0
	}
	
	/// Calculate Levenshtein distance for typo tolerance
	private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
		let s1Array = Array(s1)
		let s2Array = Array(s2)
		
		if s1Array.isEmpty { return s2Array.count }
		if s2Array.isEmpty { return s1Array.count }
		
		var matrix = [[Int]]()
		for i in 0...s1Array.count {
			matrix.append([Int](repeating: 0, count: s2Array.count + 1))
			matrix[i][0] = i
		}
		for j in 0...s2Array.count {
			matrix[0][j] = j
		}
		
		for i in 1...s1Array.count {
			for j in 1...s2Array.count {
				if s1Array[i-1] == s2Array[j-1] {
					matrix[i][j] = matrix[i-1][j-1]
				} else {
					matrix[i][j] = min(
						matrix[i-1][j] + 1,     // deletion
						matrix[i][j-1] + 1,     // insertion
						matrix[i-1][j-1] + 1    // substitution
					)
				}
			}
		}
		
		return matrix[s1Array.count][s2Array.count]
	}
	
	/// Phonetic similarity using Soundex-like algorithm optimized for drug names
	private static func phoneticSimilarity(_ query: String, _ target: String) -> Double {
		let q = phoneticKey(query)
		let t = phoneticKey(target)
		
		if q == t {
			return 1.0
		}
		
		// Check prefix match in phonetic form
		if t.hasPrefix(q) || q.hasPrefix(t) {
			return 0.7
		}
		
		// Calculate similarity of phonetic keys
		let distance = levenshteinDistance(q, t)
		return max(0, 1.0 - (Double(distance) / Double(max(q.count, t.count))))
	}
	
	/// Generate phonetic key for a drug name
	private static func phoneticKey(_ text: String) -> String {
		var result = text.lowercased()
		
		// Common drug name transformations
		let replacements: [(String, String)] = [
			// Common medical prefixes/suffixes
			("ph", "f"),
			("ck", "k"),
			("x", "ks"),
			("qu", "kw"),
			("c", "k"),
			("z", "s"),
			("ough", "of"),
			("igh", "i"),
			
			// Remove common drug suffixes for matching
			("ine$", ""),
			("in$", ""),
			("ol$", ""),
			("ide$", ""),
			("ate$", ""),
			
			// Normalize vowels (simplified)
			("ae", "e"),
			("oe", "e"),
			("ou", "u"),
			("ei", "i"),
			("ie", "i"),
			
			// Remove silent letters common in drug names
			("mb", "m"),
			("wr", "r"),
			("kn", "n"),
			("gn", "n"),
			("ps", "s")
		]
		
		for (pattern, replacement) in replacements {
			if pattern.hasSuffix("$") {
				// End of string replacement
				let p = String(pattern.dropLast())
				if result.hasSuffix(p) {
					result = String(result.dropLast(p.count)) + replacement
				}
			} else {
				result = result.replacingOccurrences(of: pattern, with: replacement)
			}
		}
		
		// Remove duplicate characters
		var previous: Character? = nil
		var cleaned = ""
		for char in result {
			if char != previous {
				cleaned.append(char)
				previous = char
			}
		}
		
		return cleaned
	}
	
	/// Token-based similarity (for multi-word drug names)
	private static func tokenSimilarity(_ query: String, _ target: String) -> Double {
		let queryTokens = Set(query.split(separator: " ").map { $0.lowercased() })
		let targetTokens = Set(target.split(separator: " ").map { $0.lowercased() })
		
		if queryTokens.isEmpty || targetTokens.isEmpty {
			return 0.0
		}
		
		let intersection = queryTokens.intersection(targetTokens)
		let union = queryTokens.union(targetTokens)
		
		return Double(intersection.count) / Double(union.count)
	}
	
	/// Special handling for common drug name misspellings
	static func applyCommonCorrections(_ query: String) -> [String] {
		var suggestions: [String] = []
		let q = query.lowercased()
		
		// Common misspelling patterns in drug names
		let corrections: [(String, String)] = [
			// Common typos
			("asprin", "aspirin"),
			("ibuprofin", "ibuprofen"),
			("acetominophen", "acetaminophen"),
			("tylenol", "acetaminophen"),
			("advil", "ibuprofen"),
			("motrin", "ibuprofen"),
			
			// Missing letters
			("penicilin", "penicillin"),
			("amoxicilin", "amoxicillin"),
			("metformin", "metformin"),
			
			// Extra letters
			("aspirine", "aspirin"),
			("ibuprofene", "ibuprofen"),
			
			// Wrong vowels
			("insulen", "insulin"),
			("insulan", "insulin"),
			("dioxin", "digoxin"),
			
			// Common brand/generic confusion
			("xanax", "alprazolam"),
			("valium", "diazepam"),
			("prozac", "fluoxetine"),
			("zoloft", "sertraline"),
			("lipitor", "atorvastatin"),
			("norco", "hydrocodone"),
			("vicodin", "hydrocodone"),
			("percocet", "oxycodone"),
			("neurontin", "gabapentin"),
			("prilosec", "omeprazole"),
			("nexium", "esomeprazole"),
			("synthroid", "levothyroxine"),
			("glucophage", "metformin"),
			("zestril", "lisinopril"),
			("prinivil", "lisinopril"),
			("lopressor", "metoprolol"),
			("toprol", "metoprolol"),
			("tenormin", "atenolol"),
			("norvasc", "amlodipine"),
			("lasix", "furosemide"),
			("coumadin", "warfarin"),
			("plavix", "clopidogrel"),
			("singulair", "montelukast"),
			("ambien", "zolpidem"),
			("ativan", "lorazepam"),
			("klonopin", "clonazepam"),
			("flexeril", "cyclobenzaprine"),
			("ultram", "tramadol"),
			("dilaudid", "hydromorphone")
		]
		
		// Check for exact correction matches
		for (misspelling, correct) in corrections {
			if q == misspelling {
				suggestions.append(correct)
			} else if q == correct {
				// If searching for generic, also suggest brand name
				for (brand, generic) in corrections where generic == correct {
					suggestions.append(brand)
				}
			}
		}
		
		// Check for partial matches
		if suggestions.isEmpty {
			for (pattern, correct) in corrections {
				if q.contains(pattern) || pattern.contains(q) {
					suggestions.append(correct)
				}
			}
		}
		
		return suggestions
	}
}