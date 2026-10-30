@testable import AsNeeded
import Testing

@Suite("RevenueCat missing configuration")
@MainActor
struct RevenueCatConfigurationTests {
	@Test("Unconfigured product loading does not access the SDK")
	func productLoadingWithoutConfiguration() async {
		let manager = RevenueCatManager()
		await manager.fetchProducts()
		await manager.fetchOfferings()
		await manager.fetchCustomerInfo()
		await manager.reloadProducts()
		#expect(!manager.isConfigured)
		#expect(!manager.isLoadingProducts)
		#expect(manager.availableProducts.isEmpty)
		#expect(manager.offerings == nil)
		#expect(manager.customerInfo == nil)
	}

	@Test("Purchases explain missing configuration")
	func purchaseWithoutConfiguration() async {
		let manager = RevenueCatManager()
		#expect(await manager.purchaseTip(.tipThanks) == false)
		#expect(manager.purchaseError == RevenueCatManager.unavailableMessage)
		#expect(await manager.purchaseSubscription(.subscriptionSupporter) == false)
		#expect(manager.purchaseError == RevenueCatManager.unavailableMessage)
	}

	@Test("Restore explains missing configuration")
	func restoreWithoutConfiguration() async {
		let manager = RevenueCatManager()
		#expect(await manager.restorePurchases() == false)
		#expect(manager.purchaseError == RevenueCatManager.unavailableMessage)
		#expect(!manager.hasActiveSubscription)
		#expect(manager.activeSubscriptionTier == nil)
	}
}
