import Foundation

public struct IAPProduct: Identifiable, Codable, Sendable {
    public let id: String
    public let type: IAPProductType
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let localizedPrice: String?
    public let items: [IAPProductItem]
    public let isConsumable: Bool
    public let displayPriority: Int

    public init(
        id: String,
        type: IAPProductType,
        displayName: String,
        description: String,
        price: Decimal,
        localizedPrice: String? = nil,
        items: [IAPProductItem],
        isConsumable: Bool = true,
        displayPriority: Int = 0
    ) {
        self.id = id
        self.type = type
        self.displayName = displayName
        self.description = description
        self.price = price
        self.localizedPrice = localizedPrice
        self.items = items
        self.isConsumable = isConsumable
        self.displayPriority = displayPriority
    }

    public var formattedPrice: String {
        if let localizedPrice = localizedPrice {
            return localizedPrice
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "$\(price)"
    }

    public static var allProducts: [IAPProduct] {
        return [
            adFreeProduct,
            smallCoinsProduct,
            mediumCoinsProduct,
            largeCoinsProduct,
            powerUpBundleProduct,
            cyberpunkThemeProduct,
            lofiThemeProduct,
            orchestralThemeProduct,
            starterPackProduct,
            megaBundleProduct,
            autoClaimBoostsMonthlyProduct,
            proMonthlyProduct,
            proYearlyProduct,
            proFamilyMonthlyProduct,
            proFamilyYearlyProduct
        ]
    }

    public static var allProductIDs: [String] {
        allProducts.map(\.id)
    }

    public static func product(for id: String) -> IAPProduct? {
        allProducts.first { $0.id == id }
    }

    public static func productID(for theme: MusicTheme) -> String? {
        allProducts.first {
            if case .theme(let productTheme) = $0.type {
                return productTheme == theme
            }
            return false
        }?.id
    }

    public static var subscriptionProductIDs: Set<String> {
        Set(allProducts.compactMap { product in
            if case .subscription = product.type {
                return product.id
            }
            return nil
        })
    }

    public static var proSubscriptionProductIDs: Set<String> {
        Set(allProducts.compactMap { product in
            guard case .subscription(let kind) = product.type, kind.grantsPro else {
                return nil
            }
            return product.id
        })
    }

    public var permanentEntitlementProductIDs: Set<String> {
        var ids: Set<String> = isConsumable ? [] : [id]
        for item in items {
            switch item.type {
            case .adFree:
                ids.insert(Self.adFreeProduct.id)
            case .theme(let theme):
                if let themeProductID = Self.productID(for: theme) {
                    ids.insert(themeProductID)
                }
            case .coins, .powerUp, .experience, .subscription:
                continue
            }
        }
        return ids
    }

    public static let adFreeProduct = IAPProduct(
        id: "com.game2244.adfree",
        type: .adFree,
        displayName: "Remove Ads",
        description: "Enjoy Ultimate2244 without any advertisements",
        price: 4.99,
        items: [IAPProductItem(type: .adFree, quantity: 1)],
        isConsumable: false,
        displayPriority: 1
    )

    public static let smallCoinsProduct = IAPProduct(
        id: "com.game2244.coins.small",
        type: .coins(500),
        displayName: "Coin Pouch",
        description: "500 coins to spend on power-ups",
        price: 0.99,
        items: [IAPProductItem(type: .coins, quantity: 500)],
        displayPriority: 10
    )

    public static let mediumCoinsProduct = IAPProduct(
        id: "com.game2244.coins.medium",
        type: .coins(2500),
        displayName: "Coin Bag",
        description: "2500 coins with 25% bonus",
        price: 3.99,
        items: [IAPProductItem(type: .coins, quantity: 2500)],
        displayPriority: 11
    )

    public static let largeCoinsProduct = IAPProduct(
        id: "com.game2244.coins.large",
        type: .coins(10000),
        displayName: "Coin Chest",
        description: "10000 coins with 50% bonus",
        price: 9.99,
        items: [IAPProductItem(type: .coins, quantity: 10000)],
        displayPriority: 12
    )

    public static let powerUpBundleProduct = IAPProduct(
        id: "com.game2244.powerup.bundle",
        type: .powerUpBundle,
        displayName: "Power-Up Pack",
        description: "Essential power-ups to boost your game",
        price: 2.99,
        items: [
            IAPProductItem(type: .powerUp(.hammer), quantity: 10),
            IAPProductItem(type: .powerUp(.swap), quantity: 10),
            IAPProductItem(type: .powerUp(.undo), quantity: 20),
            IAPProductItem(type: .powerUp(.shuffle), quantity: 5),
            IAPProductItem(type: .powerUp(.magnet), quantity: 5),
            IAPProductItem(type: .powerUp(.double), quantity: 5)
        ],
        displayPriority: 20
    )

    public static let cyberpunkThemeProduct = IAPProduct(
        id: "com.game2244.theme.cyberpunk",
        type: .theme(.cyberpunk),
        displayName: "Cyberpunk Theme",
        description: "Futuristic electronic beats",
        price: 1.99,
        items: [IAPProductItem(type: .theme(.cyberpunk), quantity: 1)],
        isConsumable: false,
        displayPriority: 30
    )

    public static let lofiThemeProduct = IAPProduct(
        id: "com.game2244.theme.lofi",
        type: .theme(.lofi),
        displayName: "Lo-Fi Theme",
        description: "Relaxing lo-fi hip hop",
        price: 1.99,
        items: [IAPProductItem(type: .theme(.lofi), quantity: 1)],
        isConsumable: false,
        displayPriority: 31
    )

    public static let orchestralThemeProduct = IAPProduct(
        id: "com.game2244.theme.orchestral",
        type: .theme(.orchestral),
        displayName: "Orchestral Theme",
        description: "Epic cinematic experience",
        price: 1.99,
        items: [IAPProductItem(type: .theme(.orchestral), quantity: 1)],
        isConsumable: false,
        displayPriority: 32
    )

    public static let starterPackProduct = IAPProduct(
        id: "com.game2244.starter.pack",
        type: .bundle,
        displayName: "Starter Pack",
        description: "Perfect for new players!",
        price: 4.99,
        items: [
            IAPProductItem(type: .coins, quantity: 1000),
            IAPProductItem(type: .powerUp(.hammer), quantity: 5),
            IAPProductItem(type: .powerUp(.swap), quantity: 5),
            IAPProductItem(type: .powerUp(.undo), quantity: 10),
            IAPProductItem(type: .adFree, quantity: 1)
        ],
        isConsumable: false,
        displayPriority: 2
    )

    public static let megaBundleProduct = IAPProduct(
        id: "com.game2244.mega.bundle",
        type: .bundle,
        displayName: "Mega Bundle",
        description: "Ultimate value pack!",
        price: 19.99,
        items: [
            IAPProductItem(type: .coins, quantity: 5000),
            IAPProductItem(type: .powerUp(.hammer), quantity: 20),
            IAPProductItem(type: .powerUp(.swap), quantity: 20),
            IAPProductItem(type: .powerUp(.undo), quantity: 40),
            IAPProductItem(type: .powerUp(.shuffle), quantity: 10),
            IAPProductItem(type: .powerUp(.magnet), quantity: 10),
            IAPProductItem(type: .powerUp(.double), quantity: 10),
            IAPProductItem(type: .theme(.cyberpunk), quantity: 1),
            IAPProductItem(type: .theme(.lofi), quantity: 1),
            IAPProductItem(type: .theme(.orchestral), quantity: 1),
            IAPProductItem(type: .adFree, quantity: 1)
        ],
        isConsumable: false,
        displayPriority: 3
    )

    public static let autoClaimBoostsMonthlyProduct = IAPProduct(
        id: "com.game2244.boosts.autoclaim.monthly",
        type: .subscription(.autoClaimBoostsMonthly),
        displayName: "Auto-Claim Boosts Monthly",
        description: "Monthly auto-claim boosts for Ultimate2244",
        price: 1.99,
        items: [IAPProductItem(type: .subscription(.autoClaimBoosts), quantity: 1)],
        isConsumable: false,
        displayPriority: 40
    )

    public static let proMonthlyProduct = IAPProduct(
        id: "com.game2244.pro.monthly",
        type: .subscription(.proMonthly),
        displayName: "Ultimate2244 Pro Monthly",
        description: "Monthly Ultimate2244 Pro access with premium benefits",
        price: 4.99,
        items: [IAPProductItem(type: .subscription(.pro), quantity: 1)],
        isConsumable: false,
        displayPriority: 41
    )

    public static let proYearlyProduct = IAPProduct(
        id: "com.game2244.pro.yearly",
        type: .subscription(.proYearly),
        displayName: "Ultimate2244 Pro Yearly",
        description: "Yearly Ultimate2244 Pro access with premium benefits",
        price: 39.99,
        items: [IAPProductItem(type: .subscription(.pro), quantity: 1)],
        isConsumable: false,
        displayPriority: 42
    )

    public static let proFamilyMonthlyProduct = IAPProduct(
        id: "com.game2244.pro.family.monthly",
        type: .subscription(.proFamilyMonthly),
        displayName: "Ultimate2244 Pro Family Monthly",
        description: "Monthly Ultimate2244 Pro Family access with premium benefits",
        price: 9.99,
        items: [IAPProductItem(type: .subscription(.pro), quantity: 1)],
        isConsumable: false,
        displayPriority: 43
    )

    public static let proFamilyYearlyProduct = IAPProduct(
        id: "com.game2244.pro.family.yearly",
        type: .subscription(.proFamilyYearly),
        displayName: "Ultimate2244 Pro Family Yearly",
        description: "Yearly Ultimate2244 Pro Family access with premium benefits",
        price: 79.99,
        items: [IAPProductItem(type: .subscription(.pro), quantity: 1)],
        isConsumable: false,
        displayPriority: 44
    )
}

public enum IAPSubscriptionKind: String, Codable, Sendable {
    case autoClaimBoostsMonthly
    case proMonthly
    case proYearly
    case proFamilyMonthly
    case proFamilyYearly

    public var grantsPro: Bool {
        switch self {
        case .autoClaimBoostsMonthly:
            return false
        case .proMonthly, .proYearly, .proFamilyMonthly, .proFamilyYearly:
            return true
        }
    }
}

public enum IAPSubscriptionEntitlement: String, Codable, Sendable {
    case autoClaimBoosts
    case pro
}

public enum IAPProductType: Codable, Sendable {
    case adFree
    case coins(Int)
    case powerUpBundle
    case theme(MusicTheme)
    case bundle
    case subscription(IAPSubscriptionKind)

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case theme
        case subscriptionKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "adFree":
            self = .adFree
        case "coins":
            let value = try container.decode(Int.self, forKey: .value)
            self = .coins(value)
        case "powerUpBundle":
            self = .powerUpBundle
        case "theme":
            let theme = try container.decode(MusicTheme.self, forKey: .theme)
            self = .theme(theme)
        case "bundle":
            self = .bundle
        case "subscription":
            let subscriptionKind = try container.decode(IAPSubscriptionKind.self, forKey: .subscriptionKind)
            self = .subscription(subscriptionKind)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown IAP product type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .adFree:
            try container.encode("adFree", forKey: .type)
        case .coins(let value):
            try container.encode("coins", forKey: .type)
            try container.encode(value, forKey: .value)
        case .powerUpBundle:
            try container.encode("powerUpBundle", forKey: .type)
        case .theme(let theme):
            try container.encode("theme", forKey: .type)
            try container.encode(theme, forKey: .theme)
        case .bundle:
            try container.encode("bundle", forKey: .type)
        case .subscription(let subscriptionKind):
            try container.encode("subscription", forKey: .type)
            try container.encode(subscriptionKind, forKey: .subscriptionKind)
        }
    }
}

public struct IAPProductItem: Codable, Sendable {
    public enum ItemType: Codable, Sendable {
        case coins
        case powerUp(PowerUpType)
        case theme(MusicTheme)
        case adFree
        case experience
        case subscription(IAPSubscriptionEntitlement)
    }

    public let type: ItemType
    public let quantity: Int

    public init(type: ItemType, quantity: Int) {
        self.type = type
        self.quantity = quantity
    }
}

extension IAPProductItem.ItemType {
    private enum CodingKeys: String, CodingKey {
        case type
        case powerUpType
        case theme
        case subscriptionEntitlement
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "coins":
            self = .coins
        case "powerUp":
            let powerUpType = try container.decode(PowerUpType.self, forKey: .powerUpType)
            self = .powerUp(powerUpType)
        case "theme":
            let theme = try container.decode(MusicTheme.self, forKey: .theme)
            self = .theme(theme)
        case "adFree":
            self = .adFree
        case "experience":
            self = .experience
        case "subscription":
            let entitlement = try container.decode(IAPSubscriptionEntitlement.self, forKey: .subscriptionEntitlement)
            self = .subscription(entitlement)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown item type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .coins:
            try container.encode("coins", forKey: .type)
        case .powerUp(let powerUpType):
            try container.encode("powerUp", forKey: .type)
            try container.encode(powerUpType, forKey: .powerUpType)
        case .theme(let theme):
            try container.encode("theme", forKey: .type)
            try container.encode(theme, forKey: .theme)
        case .adFree:
            try container.encode("adFree", forKey: .type)
        case .experience:
            try container.encode("experience", forKey: .type)
        case .subscription(let entitlement):
            try container.encode("subscription", forKey: .type)
            try container.encode(entitlement, forKey: .subscriptionEntitlement)
        }
    }
}
