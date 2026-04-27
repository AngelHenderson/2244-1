import Testing
@testable import GameCore

@Suite("IAP Contract Tests")
struct IAPContractTests {

    @Test("IAP catalog uses launch product IDs")
    func iapProductsDefined() {
        let ids = Set(IAPProduct.allProducts.map(\.id))

        #expect(ids == Set([
            "com.game2244.adfree",
            "com.game2244.coins.small",
            "com.game2244.coins.medium",
            "com.game2244.coins.large",
            "com.game2244.powerup.bundle",
            "com.game2244.theme.cyberpunk",
            "com.game2244.theme.lofi",
            "com.game2244.theme.orchestral",
            "com.game2244.starter.pack",
            "com.game2244.mega.bundle",
            "com.game2244.boosts.autoclaim.monthly",
            "com.game2244.pro.monthly",
            "com.game2244.pro.yearly"
        ]))
    }

    @Test("Consumable and non-consumable product types are explicit")
    func consumableFlags() {
        #expect(IAPProduct.adFreeProduct.isConsumable == false)
        #expect(IAPProduct.cyberpunkThemeProduct.isConsumable == false)
        #expect(IAPProduct.lofiThemeProduct.isConsumable == false)
        #expect(IAPProduct.orchestralThemeProduct.isConsumable == false)
        #expect(IAPProduct.starterPackProduct.isConsumable == false)
        #expect(IAPProduct.megaBundleProduct.isConsumable == false)
        #expect(IAPProduct.autoClaimBoostsMonthlyProduct.isConsumable == false)
        #expect(IAPProduct.proMonthlyProduct.isConsumable == false)
        #expect(IAPProduct.proYearlyProduct.isConsumable == false)

        #expect(IAPProduct.smallCoinsProduct.isConsumable)
        #expect(IAPProduct.mediumCoinsProduct.isConsumable)
        #expect(IAPProduct.largeCoinsProduct.isConsumable)
        #expect(IAPProduct.powerUpBundleProduct.isConsumable)
    }

    @Test("Coin packages award canonical amounts")
    func coinPackages() {
        #expect(IAPProduct.smallCoinsProduct.items.coinQuantity == 500)
        #expect(IAPProduct.mediumCoinsProduct.items.coinQuantity == 2500)
        #expect(IAPProduct.largeCoinsProduct.items.coinQuantity == 10000)
    }

    @Test("Power-up bundle contains correct items")
    func powerUpBundle() {
        let bundle = IAPProduct.powerUpBundleProduct.items.powerUps

        #expect(bundle[.hammer] == 10)
        #expect(bundle[.swap] == 10)
        #expect(bundle[.undo] == 20)
        #expect(bundle[.shuffle] == 5)
        #expect(bundle[.magnet] == 5)
        #expect(bundle[.double] == 5)
    }

    @Test("Bundles expose permanent entitlements")
    func bundledEntitlements() {
        #expect(IAPProduct.adFreeProduct.permanentEntitlementProductIDs == Set(["com.game2244.adfree"]))
        #expect(IAPProduct.starterPackProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.starter.pack",
            "com.game2244.adfree"
        ]))
        #expect(IAPProduct.megaBundleProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.mega.bundle",
            "com.game2244.theme.cyberpunk",
            "com.game2244.theme.lofi",
            "com.game2244.theme.orchestral",
            "com.game2244.adfree"
        ]))
    }

    @Test("Theme products map back to StoreKit IDs")
    func themeProductIDs() {
        #expect(IAPProduct.productID(for: .cyberpunk) == "com.game2244.theme.cyberpunk")
        #expect(IAPProduct.productID(for: .lofi) == "com.game2244.theme.lofi")
        #expect(IAPProduct.productID(for: .orchestral) == "com.game2244.theme.orchestral")
    }

    @Test("Subscription products expose active entitlements")
    func subscriptionProducts() {
        #expect(IAPProduct.subscriptionProductIDs == Set([
            "com.game2244.boosts.autoclaim.monthly",
            "com.game2244.pro.monthly",
            "com.game2244.pro.yearly"
        ]))
        #expect(IAPProduct.proSubscriptionProductIDs == Set([
            "com.game2244.pro.monthly",
            "com.game2244.pro.yearly"
        ]))
        #expect(IAPProduct.autoClaimBoostsMonthlyProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.boosts.autoclaim.monthly"
        ]))
        #expect(IAPProduct.proMonthlyProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.pro.monthly"
        ]))
        #expect(IAPProduct.proYearlyProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.pro.yearly"
        ]))
    }
}

private extension Array where Element == IAPProductItem {
    var coinQuantity: Int {
        first {
            if case .coins = $0.type { return true }
            return false
        }?.quantity ?? 0
    }

    var powerUps: [PowerUpType: Int] {
        reduce(into: [:]) { result, item in
            if case .powerUp(let type) = item.type {
                result[type] = item.quantity
            }
        }
    }
}
