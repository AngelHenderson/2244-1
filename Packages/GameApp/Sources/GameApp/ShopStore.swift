import Foundation
import SwiftUI
import Observation
import GameCore
import GameServices

// MARK: - Shop Models
public struct ShopBundle: Identifiable, Codable {
    public let id: String
    public let title: String
    public let price: Double
    public let tags: [String]?
    public let perks: Perks?
    public let items: Items?
    
    public struct Perks: Codable {
        public let noAds: Bool?
        public let allBeats: Bool?
        public let allLiveThemes: Bool?
    }
    
    public struct Items: Codable {
        public let gems: Int?
        public let hammers: Int?
        public let swaps: Int?
        public let magnets: Int?
        public let spins: Int?
        public let boost2x: Int?
        public let boost3x: Int?
        public let boost4x: Int?
        public let liveThemes: AnyDecodable?  // Can be Int or [String]
        public let tileBeats: AnyDecodable?  // Can be Int or [String]
        public let galaxyThemes: Int?
        public let colorWheelThemes: Int?
        public let gridThemes: Int?
    }
}

// Helper to handle heterogeneous JSON types
public struct AnyDecodable: Codable {
    public let value: Any
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let array = try? container.decode([String].self) {
            value = array
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        // Not needed for reading
    }
}

public struct GemBundle: Identifiable, Codable {
    public let id: String
    public let gems: Int
    public let price: Double
    public let tags: [String]?
}

public struct PerkBundle: Identifiable, Codable {
    public let id: String
    public let item: String
    public let quantity: Int
    public let price: Double
}

public struct ShopCatalog: Codable {
    public let catalogVersion: String
    public let lastUpdated: String
    public let currency: String
    public let pricingModel: String
    public let bundles: [ShopBundle]
    public let gemBundles: [GemBundle]
    public let perkBundles: [PerkBundle]
    public let freePerks: [PerkBundle]
}

// MARK: - Shop Store
@MainActor
@Observable
public final class ShopStore {
    public var catalog: ShopCatalog?
    public var isLoading = false
    public var error: String?
    
    // Purchase tracking
    public var purchasedBundles = Set<String>()
    public var isPurchasing = false
    
    // Journey tiles calculation using AlphaLabels
    public var availableJourneyTiles: [String] = []
    
    private let journeyStore: JourneyKit.Store
    private let purchaseService: PurchaseService?
    private weak var gemWallet: GemWallet?
    private weak var gameStore: GameStore?
    private weak var rewardLedger: RewardLedgerStore?
    private var grantedTransactionIDs: Set<String>
    private static let grantedTransactionIDsKey = "shopGrantedTransactionIDs"
    
    public init(
        journeyStore: JourneyKit.Store,
        purchaseService: PurchaseService? = nil,
        gemWallet: GemWallet? = nil,
        gameStore: GameStore? = nil,
        rewardLedger: RewardLedgerStore? = nil
    ) {
        self.journeyStore = journeyStore
        self.purchaseService = purchaseService
        self.gemWallet = gemWallet
        self.gameStore = gameStore
        self.rewardLedger = rewardLedger
        self.grantedTransactionIDs = Set(
            UserDefaults.standard.stringArray(forKey: Self.grantedTransactionIDsKey) ?? []
        )
        configurePurchaseDelivery()
        Task { await loadCatalog() }
        calculateJourneyTiles()
    }
    
    private func loadCatalog() async {
        isLoading = true
        error = nil
        
        do {
            // First try to load from bundle
            if let url = Bundle.main.url(forResource: "2244_shop_catalog", withExtension: "json") {
                print("📦 Loading shop catalog from: \(url)")
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                catalog = try decoder.decode(ShopCatalog.self, from: data)
                print("✅ Shop catalog loaded successfully with \(catalog?.bundles.count ?? 0) bundles")
            } else {
                // Fallback: Try to load from JSON folder in main bundle
                let bundle = Bundle.main
                let jsonPath = bundle.path(forResource: "2244_shop_catalog", ofType: "json", inDirectory: "JSON")
                    ?? bundle.path(forResource: "2244_shop_catalog", ofType: "json")
                
                if let jsonPath = jsonPath {
                    let url = URL(fileURLWithPath: jsonPath)
                    print("📦 Loading shop catalog from path: \(url)")
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    catalog = try decoder.decode(ShopCatalog.self, from: data)
                    print("✅ Shop catalog loaded successfully with \(catalog?.bundles.count ?? 0) bundles")
                } else {
                    // Use hardcoded catalog as last resort
                    print("⚠️ Using hardcoded catalog")
                    catalog = createDefaultCatalog()
                }
            }
        } catch {
            print("❌ Failed to decode shop catalog: \(error)")
            self.error = "Failed to load shop catalog: \(error.localizedDescription)"
            // Use hardcoded catalog as fallback
            catalog = createDefaultCatalog()
        }
        
        await purchaseService?.ensureProductsLoaded(for: IAPProduct.allProductIDs)
        
        isLoading = false
    }
    
    private func createDefaultCatalog() -> ShopCatalog {
        // Create a minimal catalog with sample data for testing
        return ShopCatalog(
            catalogVersion: "2025-09-04c",
            lastUpdated: "2025-09-04T23:33:37",
            currency: "USD",
            pricingModel: "one_time",
            bundles: [
                ShopBundle.canonical(IAPProduct.starterPackProduct, tags: ["Starter"]),
                ShopBundle.canonical(IAPProduct.powerUpBundleProduct, tags: ["Tools"]),
                ShopBundle.canonical(IAPProduct.megaBundleProduct, tags: ["Best Value"])
            ],
            gemBundles: [
                GemBundle(
                    id: IAPProduct.smallCoinsProduct.id,
                    gems: 500,
                    price: 0.99,
                    tags: nil
                ),
                GemBundle(
                    id: IAPProduct.mediumCoinsProduct.id,
                    gems: 2500,
                    price: 3.99,
                    tags: ["Popular"]
                ),
                GemBundle(
                    id: IAPProduct.largeCoinsProduct.id,
                    gems: 10000,
                    price: 9.99,
                    tags: ["Best Value"]
                )
            ],
            perkBundles: [],
            freePerks: []
        )
    }
    
    public func calculateJourneyTiles() {
        // Get milestones from journey store
        let milestones = journeyStore.milestones()
        
        // Show tiles up to current milestone + future ones (infinite progression)
        // Start from C and generate labels for each milestone
        do {
            // Generate labels for existing milestones + extra for "to infinity" feel
            let extraTiles = 10 // Show 10 tiles beyond current highest
            let totalTiles = milestones.count + extraTiles
            availableJourneyTiles = try AlphaLabels.generate(from: "C", count: totalTiles)
        } catch {
            // Fallback to simple array if AlphaLabels fails
            availableJourneyTiles = milestones.map { "Tile \($0)" }
        }
    }
    
    public func purchase(_ bundleId: String) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        error = nil
        defer { isPurchasing = false }
        
        guard let product = IAPProduct.product(for: bundleId) else {
            error = "Product unavailable"
            return
        }

        guard let purchaseService else {
            error = "Purchases are unavailable"
            return
        }

        guard let purchase = await purchaseService.purchaseVerified(productID: product.id) else {
            error = purchaseService.errorMessage ?? "Purchase failed. Please try again."
            return
        }

        applyVerifiedPurchase(purchase)
    }
    
    private func applyBundleRewards(_ bundle: ShopBundle) {
        // This would integrate with game state to apply rewards
        // For now, just track the purchase
        print("Applied rewards from bundle: \(bundle.title)")
    }
    
    private func gemBundle(for id: String) -> GemBundle? {
        catalog?.gemBundles.first { $0.id == id }
    }
    
    private func purchaseGemBundle(_ bundle: GemBundle) async {
        let success = await performPurchase(productID: bundle.id)
        if success {
            grantGems(bundle.gems)
            purchasedBundles.insert(bundle.id)
        } else {
            error = "Purchase failed. Please try again."
        }
    }
    
    private func performPurchase(productID: String) async -> Bool {
        guard let purchaseService else { return false }
        return await purchaseService.purchase(productID: productID)
    }

    private func configurePurchaseDelivery() {
        purchaseService?.onVerifiedPurchase = { [weak self] purchase in
            self?.applyVerifiedPurchase(purchase)
        }
        Task { [weak self] in
            await self?.purchaseService?.deliverPendingTransactions()
        }
    }

    private func applyVerifiedPurchase(_ purchase: VerifiedPurchase) {
        guard grantedTransactionIDs.insert(purchase.transactionID).inserted else { return }
        UserDefaults.standard.set(Array(grantedTransactionIDs), forKey: Self.grantedTransactionIDsKey)

        guard let product = IAPProduct.product(for: purchase.productID) else { return }
        grantProductRewards(product, transactionID: purchase.transactionID)
        purchasedBundles.insert(product.id)
    }

    /// Test-only seam exposing the verified-purchase apply path. Hidden from
    /// the public surface so production callers continue to flow through the
    /// `PurchaseService.onVerifiedPurchase` callback.
    internal func _applyVerifiedPurchaseForTesting(_ purchase: VerifiedPurchase) {
        applyVerifiedPurchase(purchase)
    }

    private func grantProductRewards(_ product: IAPProduct, transactionID: String) {
        for (index, item) in product.items.enumerated() {
            let key = "\(transactionID):\(product.id):\(index):\(item.ledgerItemType.rawValue)"
            switch item.type {
            case .coins:
                grantWithLedger(
                    source: .purchase,
                    itemType: .gems,
                    amount: item.quantity,
                    idempotencyKey: key
                ) {
                    grantGems(item.quantity)
                }
            case .powerUp(let type):
                grantWithLedger(
                    source: .purchase,
                    itemType: type.ledgerItemType,
                    amount: item.quantity,
                    idempotencyKey: key
                ) {
                    grantPowerUp(type.rawValue, count: item.quantity)
                }
            case .adFree:
                grantWithLedger(
                    source: .purchase,
                    itemType: .adFree,
                    amount: item.quantity,
                    idempotencyKey: key
                ) {
                    UserDefaults.standard.set(true, forKey: "isAdFreePurchased")
                }
            case .theme, .experience, .subscription:
                continue
            }
        }
    }

    private func grantWithLedger(
        source: RewardLedgerEntry.Source,
        itemType: RewardLedgerEntry.ItemType,
        amount: Int,
        idempotencyKey: String,
        apply: @MainActor () -> Void
    ) {
        guard let rewardLedger else {
            apply()
            return
        }

        rewardLedger.grant(
            source: source,
            itemType: itemType,
            amount: amount,
            idempotencyKey: idempotencyKey,
            apply: apply
        )
    }

    private func grantPowerUp(_ type: String, count: Int) {
        guard count > 0 else { return }
        if let gameStore {
            gameStore.addPowerUp(type, count: count)
            return
        }

        let defaults = UserDefaults.standard
        var inventory: [String: Int] = [:]
        if let data = defaults.data(forKey: "powerUpInventory"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            inventory = decoded
        }
        inventory[type, default: 0] += count
        if let data = try? JSONEncoder().encode(inventory) {
            defaults.set(data, forKey: "powerUpInventory")
        }
    }
    
    private func grantGems(_ amount: Int) {
        guard amount > 0 else { return }
        if let gemWallet {
            gemWallet.deposit(amount, source: .purchase)
            return
        }
        
        // Fallback: update UserDefaults directly if wallet is unavailable (e.g., previews)
        let defaults = UserDefaults.standard
        let newBalance = defaults.integer(forKey: "coins") + amount
        defaults.set(newBalance, forKey: "coins")
        NotificationCenter.default.post(
            name: Notification.Name("GemsDidChange"),
            object: nil,
            userInfo: ["newBalance": newBalance, "added": amount]
        )
    }
    
    public func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = catalog?.currency ?? "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    
    public func isPurchased(_ bundleId: String) -> Bool {
        purchasedBundles.contains(bundleId) || purchaseService?.isOwned(bundleId) == true
    }
}

private extension ShopBundle {
    static func canonical(_ product: IAPProduct, tags: [String]? = nil) -> ShopBundle {
        ShopBundle(
            id: product.id,
            title: product.displayName,
            price: Double(truncating: NSDecimalNumber(decimal: product.price)),
            tags: tags,
            perks: product.items.contains { item in
                if case .adFree = item.type { return true }
                return false
            } ? Perks(noAds: true, allBeats: nil, allLiveThemes: nil) : nil,
            items: Items(
                gems: product.items.firstQuantity(for: .coins),
                hammers: product.items.firstQuantity(for: .powerUp(.hammer)),
                swaps: product.items.firstQuantity(for: .powerUp(.swap)),
                magnets: product.items.firstQuantity(for: .powerUp(.magnet)),
                spins: nil,
                boost2x: nil,
                boost3x: nil,
                boost4x: nil,
                liveThemes: nil,
                tileBeats: nil,
                galaxyThemes: nil,
                colorWheelThemes: nil,
                gridThemes: nil
            )
        )
    }
}

private extension Array where Element == IAPProductItem {
    func firstQuantity(for type: IAPProductItem.ItemType) -> Int? {
        first { item in
            switch (item.type, type) {
            case (.coins, .coins), (.adFree, .adFree), (.experience, .experience):
                return true
            case (.powerUp(let lhs), .powerUp(let rhs)):
                return lhs == rhs
            case (.theme(let lhs), .theme(let rhs)):
                return lhs == rhs
            case (.subscription(let lhs), .subscription(let rhs)):
                return lhs == rhs
            default:
                return false
            }
        }?.quantity
    }
}

private extension IAPProductItem {
    var ledgerItemType: RewardLedgerEntry.ItemType {
        switch type {
        case .coins:
            return .gems
        case .powerUp(let powerUp):
            return powerUp.ledgerItemType
        case .theme:
            return .theme
        case .adFree:
            return .adFree
        case .experience:
            return .gems
        case .subscription:
            return .subscription
        }
    }
}

private extension PowerUpType {
    var ledgerItemType: RewardLedgerEntry.ItemType {
        switch self {
        case .hammer: return .hammer
        case .swap: return .swap
        case .magnet: return .magnet
        case .undo: return .undo
        case .shuffle: return .shuffle
        case .double: return .double
        }
    }
}

// MARK: - Environment Key
private struct ShopStoreKey: EnvironmentKey {
    nonisolated static var defaultValue: ShopStore {
        MainActor.assumeIsolated {
            // This should be properly initialized with journey store in the app
            ShopStore(journeyStore: JourneyKit.Store())
        }
    }
}

public extension EnvironmentValues {
    var shopStore: ShopStore {
        get { self[ShopStoreKey.self] }
        set { self[ShopStoreKey.self] = newValue }
    }
}

#if DEBUG
public extension ShopCatalog {
    @MainActor
    static let preview = ShopCatalog(
        catalogVersion: "preview",
        lastUpdated: "2026-05-04T00:00:00Z",
        currency: "USD",
        pricingModel: "one_time",
        bundles: [
            ShopBundle.canonical(IAPProduct.starterPackProduct, tags: ["Starter"]),
            ShopBundle.canonical(IAPProduct.powerUpBundleProduct, tags: ["Tools"]),
            ShopBundle.canonical(IAPProduct.megaBundleProduct, tags: ["Best Value"]),
        ],
        gemBundles: [
            GemBundle(id: IAPProduct.smallCoinsProduct.id, gems: 500, price: 0.99, tags: nil),
            GemBundle(id: IAPProduct.mediumCoinsProduct.id, gems: 2_500, price: 3.99, tags: ["Popular"]),
            GemBundle(id: IAPProduct.largeCoinsProduct.id, gems: 10_000, price: 9.99, tags: ["Best Value"]),
        ],
        perkBundles: [
            PerkBundle(id: "preview-hammer-3", item: "hammer", quantity: 3, price: 1.99),
            PerkBundle(id: "preview-swap-3", item: "swap", quantity: 3, price: 1.99),
            PerkBundle(id: "preview-magnet-2", item: "magnet", quantity: 2, price: 2.99),
        ],
        freePerks: [
            PerkBundle(id: "preview-free-hammer", item: "hammer", quantity: 1, price: 0),
            PerkBundle(id: "preview-free-swap", item: "swap", quantity: 1, price: 0),
        ]
    )
}
#endif
