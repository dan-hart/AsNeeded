import Foundation
import SwiftUI
import RevenueCat
import DHLoggingKit
import DHUtilityKit

@MainActor
class RevenueCatManager: NSObject, ObservableObject  {
	static let shared = RevenueCatManager()
	
	// Product identifiers - these should match your App Store Connect configuration
	enum ProductIdentifier: String, CaseIterable {
		// Tips (one-time purchases)
		case tipThanks = "com.codedbydan.asneeded.tip.thanks"
		case tipCheers = "com.codedbydan.asneeded.tip.cheers"
		case tipOvation = "com.codedbydan.asneeded.tip.ovation"
		
		// Subscriptions (monthly)
		case subscriptionSupporter = "com.codedbydan.asneeded.subscription.supporter"
		case subscriptionAdvocate = "com.codedbydan.asneeded.subscription.advocate"
		case subscriptionChampion = "com.codedbydan.asneeded.subscription.champion"
		
		var isTip: Bool {
			switch self {
			case .tipThanks, .tipCheers, .tipOvation:
				return true
			default:
				return false
			}
		}
	}
	
	@Published var offerings: Offerings?
	@Published var customerInfo: CustomerInfo?
	@Published var availableProducts: [StoreProduct] = []
	@Published var isLoadingProducts = false
	@Published var purchaseError: String?
	
	func configure() {
		// Configure RevenueCat with your API key
		// You'll need to add your RevenueCat API key here
		// Get it from https://app.revenuecat.com
		
        guard let rcPublicKey = try? SecretManager.shared.getSecret(.revenueCatAPIKey) else {
            DHLogger.data.error("RevenueCat API key not found in secrets manager")
            return
        }
		
		Purchases.logLevel = .debug
		Purchases.configure(withAPIKey: rcPublicKey)
		
		// Enable debug logs in debug builds
		#if DEBUG
		Purchases.logLevel = .verbose
		#endif
		
		// Listen for customer info updates
		Purchases.shared.delegate = self
		
		// Load initial data
		Task {
			await fetchProducts()
			await fetchCustomerInfo()
		}
		
		DHLogger.data.info("RevenueCat configured")
	}
	
	@MainActor
	func fetchProducts() async {
		isLoadingProducts = true
		defer { isLoadingProducts = false }
		
		// Get all product identifiers
		let productIdentifiers = ProductIdentifier.allCases.map { $0.rawValue }
		DHLogger.data.info("Fetching products: \(productIdentifiers)")
		
		// Fetch products directly from StoreKit via RevenueCat
		let products = await Purchases.shared.products(productIdentifiers)
		self.availableProducts = products
		
		DHLogger.data.info("Successfully fetched \(products.count) products")
		for product in products {
			DHLogger.data.info("Product: \(product.productIdentifier) - \(product.localizedTitle) - \(product.localizedPriceString)")
		}
		
		if products.count != productIdentifiers.count {
			let foundIds = products.map { $0.productIdentifier }
			let missingIds = productIdentifiers.filter { !foundIds.contains($0) }
			DHLogger.data.warning("Missing products: \(missingIds)")
		}
	}
	
	@MainActor
	func fetchOfferings() async {
		// Keep this for backwards compatibility, but we'll primarily use direct products
		do {
			let offerings = try await Purchases.shared.offerings()
			self.offerings = offerings
			DHLogger.data.debug("Fetched RevenueCat offerings: \(offerings.current?.identifier ?? "none")")
		} catch {
			DHLogger.data.error("Failed to fetch offerings", error: error)
		}
	}
	
	@MainActor
	func fetchCustomerInfo() async {
		do {
			let customerInfo = try await Purchases.shared.customerInfo()
			self.customerInfo = customerInfo
			DHLogger.data.debug("Fetched customer info")
		} catch {
			DHLogger.data.error("Failed to fetch customer info", error: error)
		}
	}
	
	@MainActor
	func purchaseTip(_ productId: ProductIdentifier) async -> Bool {
		guard productId.isTip else {
			DHLogger.data.error("Attempted to purchase non-tip product as tip: \(productId.rawValue)")
			return false
		}
		
		return await purchase(productId)
	}
	
	@MainActor
	func purchaseSubscription(_ productId: ProductIdentifier) async -> Bool {
		guard !productId.isTip else {
			DHLogger.data.error("Attempted to purchase tip product as subscription: \(productId.rawValue)")
			return false
		}
		
		return await purchase(productId)
	}
	
	@MainActor
	private func purchase(_ productId: ProductIdentifier) async -> Bool {
		purchaseError = nil
		
		// First, ensure products are loaded
		if availableProducts.isEmpty {
			DHLogger.data.info("Products not loaded, fetching now...")
			await fetchProducts()
		}
		
		// Find the product directly
		guard let product = availableProducts.first(where: { $0.productIdentifier == productId.rawValue }) else {
			DHLogger.data.error("Product not found: \(productId.rawValue)")
			DHLogger.data.error("Available products: \(availableProducts.map { $0.productIdentifier })")
			purchaseError = "Product not available. Please check your App Store Connect configuration."
			return false
		}
		
		do {
			DHLogger.ui.info("Starting purchase for: \(productId.rawValue)")
			
			// Purchase directly using the StoreProduct
			let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(product: product)
			
			if userCancelled {
				DHLogger.ui.info("User cancelled purchase")
				return false
			}
			
			self.customerInfo = customerInfo
			
			DHLogger.ui.info("Purchase successful: \(productId.rawValue)")
			
			// Show success feedback
			await showSuccessFeedback(for: productId)
			
			return true
		} catch let error as ErrorCode {
			handlePurchaseError(error)
			return false
		} catch {
			DHLogger.data.error("Purchase failed", error: error)
			purchaseError = "Purchase failed. Please try again."
			return false
		}
	}
	
	private func handlePurchaseError(_ error: ErrorCode) {
		switch error {
		case .purchaseCancelledError:
			DHLogger.ui.info("Purchase cancelled by user")
			// Don't show error for user cancellation
		case .productNotAvailableForPurchaseError:
			purchaseError = "This product is not available for purchase."
		case .purchaseNotAllowedError:
			purchaseError = "Purchases are not allowed on this device."
		case .networkError:
			purchaseError = "Network error. Please check your connection and try again."
		case .paymentPendingError:
			purchaseError = "Payment is pending. Please check back later."
		default:
			purchaseError = "Purchase failed. Please try again."
		}
		
		if let errorMessage = purchaseError {
			DHLogger.data.error("Purchase error: \(errorMessage)")
		}
	}
	
	@MainActor
	private func showSuccessFeedback(for productId: ProductIdentifier) async {
		// This could trigger a success animation or thank you message
		// For now, we'll just log it
		DHLogger.ui.info("Thank you for your support with: \(productId.rawValue)")
	}
	
	func restorePurchases() async -> Bool {
		do {
			let customerInfo = try await Purchases.shared.restorePurchases()
			self.customerInfo = customerInfo
			DHLogger.ui.info("Purchases restored successfully")
			return true
		} catch {
			DHLogger.data.error("Failed to restore purchases", error: error)
			purchaseError = "Failed to restore purchases. Please try again."
			return false
		}
	}
	
	@MainActor
	func reloadProducts() async {
		DHLogger.data.info("Manually reloading products...")
		await fetchProducts()
	}
	
	// Check if user has active subscription
	var hasActiveSubscription: Bool {
		guard let customerInfo = customerInfo else { return false }
		return !customerInfo.activeSubscriptions.isEmpty
	}
	
	// Get active subscription tier
	var activeSubscriptionTier: ProductIdentifier? {
		guard let customerInfo = customerInfo else { return nil }
		
		for subscription in customerInfo.activeSubscriptions {
			if let tier = ProductIdentifier(rawValue: subscription) {
				return tier
			}
		}
		
		return nil
	}
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
	nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
		Task { @MainActor in
			self.customerInfo = customerInfo
			DHLogger.data.debug("Customer info updated")
		}
	}
	
	nonisolated func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase makeDeferredPurchase: @escaping StartPurchaseBlock) {
		// Handle promoted purchases from the App Store
		Task { @MainActor in
			DHLogger.ui.info("Ready for promoted product: \(product.productIdentifier)")
		}
		// Call makeDeferredPurchase outside of MainActor context to avoid race condition
		makeDeferredPurchase { _, _, _, _ in }
	}
}
