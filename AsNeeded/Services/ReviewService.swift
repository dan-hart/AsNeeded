import Foundation
import StoreKit
import SwiftUI

@MainActor
final class ReviewService: ObservableObject {
	static let shared = ReviewService()

	private init() {}

	// MARK: - Public Methods

	/// Requests a manual review from the Support screen
	func requestReview() {
		Task {
			await AppReviewManager.shared.requestManualReview()
		}
	}

	/// Opens the App Store review page directly as a fallback
	func openAppStoreReviewPage() {
		AppReviewManager.shared.openAppStoreReviewPage()
	}

}