import Foundation
import StoreKit
import SwiftUI

@MainActor
final class ReviewService: ObservableObject {
	static let shared = ReviewService()

	private init() {}

	// MARK: - Public Methods

	/// Requests a manual review from the Support screen - bypasses custom alert
	func requestReview() {
		Task {
			await AppReviewManager.shared.requestManualReview()
		}
	}

	/// Opens Apple's native review dialog directly (same as requestReview for manual requests)
	func openAppStoreReviewPage() {
		Task {
			await AppReviewManager.shared.requestManualReview()
		}
	}

	/// Checks if review requests are allowed (for UI visibility)
	var canShowReviewButtons: Bool {
		AppReviewManager.shared.canMakeReviewRequest()
	}

}