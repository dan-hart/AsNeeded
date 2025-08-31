import Foundation
struct DrugsResponse: Decodable {
	let drugGroup: DrugGroup
	struct DrugGroup: Decodable {
		let conceptGroup: [ConceptGroup]?
		struct ConceptGroup: Decodable {
			let conceptProperties: [ConceptProperty]?
			struct ConceptProperty: Decodable {
				let rxcui: String
				let name: String
			}
		}
	}
}
