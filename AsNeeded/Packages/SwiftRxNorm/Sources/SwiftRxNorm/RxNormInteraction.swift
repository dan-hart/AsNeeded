import Foundation

/// A representation of a drug-drug interaction result from RxNorm API.
public struct RxNormInteraction: Codable, Hashable, Sendable {
    public let description: String
    public let drugs: [RxNormDrug]
}
