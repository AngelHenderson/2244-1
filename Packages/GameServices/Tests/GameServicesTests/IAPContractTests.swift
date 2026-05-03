import Foundation
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
            "com.game2244.pro.yearly",
            "com.game2244.pro.family.monthly",
            "com.game2244.pro.family.yearly"
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
        #expect(IAPProduct.proFamilyMonthlyProduct.isConsumable == false)
        #expect(IAPProduct.proFamilyYearlyProduct.isConsumable == false)

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
            "com.game2244.pro.yearly",
            "com.game2244.pro.family.monthly",
            "com.game2244.pro.family.yearly"
        ]))
        #expect(IAPProduct.proSubscriptionProductIDs == Set([
            "com.game2244.pro.monthly",
            "com.game2244.pro.yearly",
            "com.game2244.pro.family.monthly",
            "com.game2244.pro.family.yearly"
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
        #expect(IAPProduct.proFamilyMonthlyProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.pro.family.monthly"
        ]))
        #expect(IAPProduct.proFamilyYearlyProduct.permanentEntitlementProductIDs == Set([
            "com.game2244.pro.family.yearly"
        ]))
    }

    @Test("Local StoreKit configuration contains every canonical product")
    func localStoreKitConfigurationMatchesCatalog() throws {
        let configURL = try repositoryFileURL("2244/game2244/Configuration.storekit")
        let data = try Data(contentsOf: configURL)
        let json = try JSONSerialization.jsonObject(with: data)
        let configuredIDs = collectProductIDs(from: json)

        #expect(configuredIDs == Set(IAPProduct.allProductIDs))
    }

    @Test("Family subscriptions are marked family-shareable locally")
    func familySubscriptionsAreShareable() throws {
        let configURL = try repositoryFileURL("2244/game2244/Configuration.storekit")
        let data = try Data(contentsOf: configURL)
        let json = try JSONSerialization.jsonObject(with: data)
        let products = collectProductObjects(from: json)

        #expect(products[IAPProduct.proFamilyMonthlyProduct.id]?["familyShareable"] as? Bool == true)
        #expect(products[IAPProduct.proFamilyYearlyProduct.id]?["familyShareable"] as? Bool == true)
    }

    @Test("Xcode scheme enables the local StoreKit configuration")
    func xcodeSchemeUsesLocalStoreKitConfiguration() throws {
        let schemeURL = try repositoryFileURL("2244/game2244.xcodeproj/xcshareddata/xcschemes/game2244.xcscheme")
        let scheme = try String(contentsOf: schemeURL, encoding: .utf8)
        #expect(!scheme.contains("storeKitConfigurationFileReference ="))

        let match = try #require(scheme.firstMatch(of: /<StoreKitConfigurationFileReference\s+identifier = "([^"]+)"/))
        let projectURL = try repositoryFileURL("2244/game2244.xcodeproj")
        let resolvedURL = URL(fileURLWithPath: String(match.1), relativeTo: projectURL)
            .standardizedFileURL
        let expectedURL = try repositoryFileURL("2244/game2244/Configuration.storekit")
            .standardizedFileURL
        #expect(resolvedURL.path == expectedURL.path)
        #expect(FileManager.default.fileExists(atPath: resolvedURL.path))
    }

    @Test("IAP docs and shop JSON stay aligned with the canonical catalog")
    func docsAndShopCatalogMatchCode() throws {
        let docsURL = try repositoryFileURL("Docs/IAP_CATALOG.md")
        let docs = try String(contentsOf: docsURL, encoding: .utf8)
        let documentedIDs = Set(
            docs.matches(of: /`(com\.game2244\.[^`]+)`/)
                .map { String($0.1) }
        )
        #expect(documentedIDs == Set(IAPProduct.allProductIDs))

        let shopURL = try repositoryFileURL("2244/game2244/JSON/2244_shop_catalog.json")
        let data = try Data(contentsOf: shopURL)
        let json = try JSONSerialization.jsonObject(with: data)
        let shopIDs = collectIDs(fromShopCatalog: json)
        #expect(shopIDs.isSubset(of: Set(IAPProduct.allProductIDs)))
        #expect(shopIDs == Set([
            IAPProduct.starterPackProduct.id,
            IAPProduct.powerUpBundleProduct.id,
            IAPProduct.megaBundleProduct.id,
            IAPProduct.smallCoinsProduct.id,
            IAPProduct.mediumCoinsProduct.id,
            IAPProduct.largeCoinsProduct.id
        ]))
    }
}

private func repositoryFileURL(_ relativePath: String) throws -> URL {
    var cursor = URL(fileURLWithPath: #filePath)
    while cursor.path != "/" {
        let candidate = relativePath
            .split(separator: "/")
            .reduce(cursor) { url, component in
                url.appendingPathComponent(String(component))
            }
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        cursor.deleteLastPathComponent()
    }

    throw CocoaError(.fileNoSuchFile)
}

private func collectIDs(fromShopCatalog value: Any) -> Set<String> {
    guard let dictionary = value as? [String: Any] else { return [] }
    var ids = Set<String>()
    for key in ["bundles", "gemBundles", "perkBundles", "freePerks"] {
        guard let entries = dictionary[key] as? [[String: Any]] else { continue }
        ids.formUnion(entries.compactMap { $0["id"] as? String })
    }
    return ids
}

private func collectProductIDs(from value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        var ids = Set<String>()
        if let productID = dictionary["productID"] as? String {
            ids.insert(productID)
        }
        for child in dictionary.values {
            ids.formUnion(collectProductIDs(from: child))
        }
        return ids
    }

    if let array = value as? [Any] {
        return array.reduce(into: Set<String>()) { result, child in
            result.formUnion(collectProductIDs(from: child))
        }
    }

    return []
}

private func collectProductObjects(from value: Any) -> [String: [String: Any]] {
    if let dictionary = value as? [String: Any] {
        var result: [String: [String: Any]] = [:]
        if let productID = dictionary["productID"] as? String {
            result[productID] = dictionary
        }
        for child in dictionary.values {
            result.merge(collectProductObjects(from: child)) { current, _ in current }
        }
        return result
    }

    if let array = value as? [Any] {
        return array.reduce(into: [:]) { result, child in
            result.merge(collectProductObjects(from: child)) { current, _ in current }
        }
    }

    return [:]
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
