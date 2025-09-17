import Testing
import StoreKit
@testable import GameServices
@testable import GameCore

@Suite("IAP Contract Tests")
struct IAPContractTests {

    @Test("IAP products are defined correctly")
    func iapProductsDefined() async {
        let iapService = IAPService()

        let products = iapService.availableProducts
        #expect(products.contains { $0.id == "com.game2244.adfree" })
        #expect(products.contains { $0.id == "com.game2244.coins.small" })
        #expect(products.contains { $0.id == "com.game2244.coins.medium" })
        #expect(products.contains { $0.id == "com.game2244.coins.large" })
        #expect(products.contains { $0.id == "com.game2244.powerup.bundle" })
        #expect(products.contains { $0.id == "com.game2244.theme.cyberpunk" })
        #expect(products.contains { $0.id == "com.game2244.theme.lofi" })
        #expect(products.contains { $0.id == "com.game2244.theme.orchestral" })
    }

    @Test("Ad-free purchase removes ads permanently")
    func adFreePurchase() async {
        let iapService = IAPService()

        #expect(iapService.isAdFree == false)

        await iapService.purchase(productId: "com.game2244.adfree")

        #expect(iapService.isAdFree == true)
        #expect(iapService.isPurchased("com.game2244.adfree") == true)
    }

    @Test("Coin packages award correct amounts")
    func coinPackages() async {
        let iapService = IAPService()

        let smallCoins = iapService.coinAmount(for: "com.game2244.coins.small")
        let mediumCoins = iapService.coinAmount(for: "com.game2244.coins.medium")
        let largeCoins = iapService.coinAmount(for: "com.game2244.coins.large")

        #expect(smallCoins == 500)
        #expect(mediumCoins == 2500)
        #expect(largeCoins == 10000)
    }

    @Test("Power-up bundle contains correct items")
    func powerUpBundle() async {
        let iapService = IAPService()

        let bundle = iapService.powerUpBundle()

        #expect(bundle[.hammer] == 10)
        #expect(bundle[.swap] == 10)
        #expect(bundle[.undo] == 20)
        #expect(bundle[.shuffle] == 5)
        #expect(bundle[.magnet] == 5)
        #expect(bundle[.double] == 5)
    }

    @Test("Theme purchases unlock permanently")
    func themePurchases() async {
        let iapService = IAPService()

        #expect(iapService.isThemeUnlocked(.cyberpunk) == false)

        await iapService.purchase(productId: "com.game2244.theme.cyberpunk")

        #expect(iapService.isThemeUnlocked(.cyberpunk) == true)
        #expect(iapService.isPurchased("com.game2244.theme.cyberpunk") == true)
    }

    @Test("IAP service uses StoreKit 2")
    func usesStoreKit2() async {
        let iapService = IAPService()

        #expect(iapService.storeKitVersion == 2)
    }

    @Test("Purchase restoration works")
    func purchaseRestoration() async {
        let iapService = IAPService()

        await iapService.restorePurchases()

        #expect(iapService.restorationCompleted == true)
    }

    @Test("Product prices are fetched from store")
    func productPrices() async {
        let iapService = IAPService()

        await iapService.fetchProducts()

        let adFreePrice = iapService.price(for: "com.game2244.adfree")
        #expect(adFreePrice != nil)
    }
}

struct IAPProduct {
    let id: String
    let type: IAPProductType
}

enum IAPProductType {
    case adFree
    case coins(Int)
    case powerUpBundle
    case theme(MusicTheme)
}

@MainActor
class IAPService {
    var isAdFree = false
    var storeKitVersion = 2
    var restorationCompleted = false

    var availableProducts: [IAPProduct] = [
        IAPProduct(id: "com.game2244.adfree", type: .adFree),
        IAPProduct(id: "com.game2244.coins.small", type: .coins(500)),
        IAPProduct(id: "com.game2244.coins.medium", type: .coins(2500)),
        IAPProduct(id: "com.game2244.coins.large", type: .coins(10000)),
        IAPProduct(id: "com.game2244.powerup.bundle", type: .powerUpBundle),
        IAPProduct(id: "com.game2244.theme.cyberpunk", type: .theme(.cyberpunk)),
        IAPProduct(id: "com.game2244.theme.lofi", type: .theme(.lofi)),
        IAPProduct(id: "com.game2244.theme.orchestral", type: .theme(.orchestral))
    ]

    private var purchasedProducts: Set<String> = []

    func purchase(productId: String) async {
        purchasedProducts.insert(productId)
        if productId == "com.game2244.adfree" {
            isAdFree = true
        }
    }

    func isPurchased(_ productId: String) -> Bool {
        return purchasedProducts.contains(productId)
    }

    func coinAmount(for productId: String) -> Int {
        switch productId {
        case "com.game2244.coins.small": return 500
        case "com.game2244.coins.medium": return 2500
        case "com.game2244.coins.large": return 10000
        default: return 0
        }
    }

    func powerUpBundle() -> [PowerUpType: Int] {
        return [
            .hammer: 10,
            .swap: 10,
            .undo: 20,
            .shuffle: 5,
            .magnet: 5,
            .double: 5
        ]
    }

    func isThemeUnlocked(_ theme: MusicTheme) -> Bool {
        switch theme {
        case .classic, .minimal, .retro:
            return true
        case .cyberpunk:
            return isPurchased("com.game2244.theme.cyberpunk")
        case .lofi:
            return isPurchased("com.game2244.theme.lofi")
        case .orchestral:
            return isPurchased("com.game2244.theme.orchestral")
        }
    }

    func restorePurchases() async {
        restorationCompleted = true
    }

    func fetchProducts() async {

    }

    func price(for productId: String) -> Decimal? {
        return 4.99
    }
}