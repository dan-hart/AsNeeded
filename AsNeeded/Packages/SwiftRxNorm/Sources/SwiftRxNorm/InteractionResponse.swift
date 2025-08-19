import Foundation

/// Decodable model representing the full RxNorm interaction response.
struct InteractionResponse: Decodable {
    let interactionTypeGroup: [TypeGroup]?
    struct TypeGroup: Decodable {
        let interactionType: [InteractionType]?
        struct InteractionType: Decodable {
            let interactionPair: [InteractionPair]?
            struct InteractionPair: Decodable {
                let description: String
                let interactionConcept: [InteractionConcept]
                struct InteractionConcept: Decodable {
                    let minConceptItem: ConceptItem
                    struct ConceptItem: Decodable {
                        let name: String
                        let rxcui: String
                    }
                }
            }
        }
    }
}
