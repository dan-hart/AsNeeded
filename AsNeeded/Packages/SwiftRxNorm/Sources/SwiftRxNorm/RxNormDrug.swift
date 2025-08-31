import Foundation

/// A representation of a drug returned by the RxNorm API.
public struct RxNormDrug: Codable, Hashable, Sendable {
	/// The RxNorm concept unique identifier for the drug.
	public let rxCUI: String
	/// The normalized name of the drug.
	public let name: String
	
	/// Creates a new RxNormDrug instance.
	public init(rxCUI: String, name: String) {
		self.rxCUI = rxCUI
		self.name = name
	}
}
