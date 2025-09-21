import Foundation
import StoreKit
import SwiftUI

@MainActor
final class ReviewService: ObservableObject {
	static let shared = ReviewService()

	private let appStoreID = "6714469235"

	private init() {}

	// MARK: - Public Methods

	/// Requests a review - tries native StoreKit prompt first, then opens App Store if needed
	func requestReview() {
		// Try the native review prompt first (this may or may not show based on Apple's algorithm)
		SKStoreReviewController.requestReview()

		// Add a small delay, then open App Store review page as backup
		// This ensures users can always leave a review when they want to
		Task {
			try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
			openAppStoreReviewPage()
		}
	}

	/// Opens the App Store review page directly as a fallback
	func openAppStoreReviewPage() {
		guard let url = URL(string: "https://itunes.apple.com/app/id\(appStoreID)?action=write-review") else {
			return
		}

		if UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url)
		}
	}

}