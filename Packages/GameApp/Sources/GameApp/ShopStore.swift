import Foundation
import SwiftUI
import Observation
import GameCore

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
    public let specialOffers: [ShopBundle]
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
    
    public init(journeyStore: JourneyKit.Store) {
        self.journeyStore = journeyStore
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
                ShopBundle(
                    id: "starter_pack",
                    title: "Starter Pack",
                    price: 2.99,
                    tags: ["Starter"],
                    perks: nil,
                    items: ShopBundle.Items(
                        gems: 1500,
                        hammers: 5,
                        swaps: 3,
                        magnets: 2,
                        liveThemes: nil,
                        tileBeats: nil,
                        galaxyThemes: nil,
                        colorWheelThemes: nil,
                        gridThemes: nil
                    )
                ),
                ShopBundle(
                    id: "value_crate",
                    title: "Value Crate",
                    price: 4.99,
                    tags: ["Best Value"],
                    perks: nil,
                    items: ShopBundle.Items(
                        gems: 4000,
                        hammers: 10,
                        swaps: 5,
                        magnets: 5,
                        liveThemes: nil,
                        tileBeats: nil,
                        galaxyThemes: nil,
                        colorWheelThemes: nil,
                        gridThemes: nil
                    )
                ),
                ShopBundle(
                    id: "mega_offer",
                    title: "Mega Offer",
                    price: 9.99,
                    tags: ["50% Off"],
                    perks: ShopBundle.Perks(noAds: true, allBeats: nil, allLiveThemes: nil),
                    items: ShopBundle.Items(
                        gems: 5000,
                        hammers: 30,
                        swaps: 15,
                        magnets: 10,
                        liveThemes: nil,
                        tileBeats: nil,
                        galaxyThemes: 4,
                        colorWheelThemes: 5,
                        gridThemes: 4
                    )
                )
            ],
            gemBundles: [
                GemBundle(id: "gems_300", gems: 300, price: 0.99, tags: ["Micro"]),
                GemBundle(id: "gems_1000", gems: 1000, price: 1.99, tags: nil),
                GemBundle(id: "gems_2500", gems: 2500, price: 3.99, tags: nil),
                GemBundle(id: "gems_5000", gems: 5000, price: 6.99, tags: nil),
                GemBundle(id: "gems_25000", gems: 25000, price: 19.99, tags: ["Popular"])
            ],
            specialOffers: [
                ShopBundle(
                    id: "no_ads_lifetime",
                    title: "No Ads (Lifetime)",
                    price: 7.99,
                    tags: nil,
                    perks: ShopBundle.Perks(noAds: true, allBeats: nil, allLiveThemes: nil),
                    items: nil
                )
            ],
            perkBundles: [
                PerkBundle(id: "hammers_5", item: "hammer", quantity: 5, price: 0.99),
                PerkBundle(id: "hammers_15", item: "hammer", quantity: 15, price: 1.99),
                PerkBundle(id: "swaps_5", item: "swap", quantity: 5, price: 1.29),
                PerkBundle(id: "magnets_5", item: "magnet", quantity: 5, price: 1.49)
            ],
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
        isPurchasing = true
        
        // Simulate purchase for now
        // In real app, this would integrate with StoreKit
        try? await Task.sleep(for: .seconds(1))
        
        purchasedBundles.insert(bundleId)
        isPurchasing = false
        
        // Handle rewards
        if let bundle = catalog?.bundles.first(where: { $0.id == bundleId }) {
            applyBundleRewards(bundle)
        }
    }
    
    private func applyBundleRewards(_ bundle: ShopBundle) {
        // This would integrate with game state to apply rewards
        // For now, just track the purchase
        print("Applied rewards from bundle: \(bundle.title)")
    }
    
    public func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = catalog?.currency ?? "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    
    public func isPurchased(_ bundleId: String) -> Bool {
        purchasedBundles.contains(bundleId)
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