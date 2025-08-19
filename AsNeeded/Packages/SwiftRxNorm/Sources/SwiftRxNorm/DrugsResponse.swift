import Foundation

// Internal endpoint response model for drug lookup (used by RxNormClient)
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
