import Foundation

public struct TimeLimitedOffer: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let offerType: OfferType
    public let originalPrice: Decimal
    public let discountedPrice: Decimal
    public let discountPercentage: Int
    public let startDate: Date
    public let expiresAt: Date
    public let items: [OfferItem]
    public let iapProductId: String?
    public let displayPriority: Int

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        offerType: OfferType,
        originalPrice: Decimal,
        discountedPrice: Decimal,
        startDate: Date = Date(),
        expiresAt: Date,
        items: [OfferItem],
        iapProductId: String? = nil,
        displayPriority: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.offerType = offerType
        self.originalPrice = originalPrice
        self.discountedPrice = discountedPrice
        self.discountPercentage = Int((1 - NSDecimalNumber(decimal: discountedPrice).doubleValue / NSDecimalNumber(decimal: originalPrice).doubleValue) * 100)
        self.startDate = startDate
        self.expiresAt = expiresAt
        self.items = items
        self.iapProductId = iapProductId
        self.displayPriority = displayPriority
    }

    public var isActive: Bool {
        let now = Date()
        return now >= startDate && now < expiresAt
    }

    public var timeRemaining: TimeInterval {
        return max(0, expiresAt.timeIntervalSinceNow)
    }

    public var formattedTimeRemaining: String {
        let seconds = Int(timeRemaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    public var savings: Decimal {
        return originalPrice - discountedPrice
    }
}

public enum OfferType: String, CaseIterable, Codable, Sendable {
    case starterPack
    case coinBundle
    case powerUpBundle
    case themeBundle
    case weeklyDeal
    case dailyDeal
    case flashSale
    case seasonalSale
}

public struct OfferItem: Codable, Sendable {
    public let itemType: OfferItemType
    public let quantity: Int
    public let displayName: String

    public init(itemType: OfferItemType, quantity: Int, displayName: String? = nil) {
        self.itemType = itemType
        self.quantity = quantity
        self.displayName = displayName ?? itemType.defaultDisplayName(quantity: quantity)
    }
}

public enum OfferItemType: Codable, Sendable {
    case coins
    case powerUp(PowerUpType)
    case theme(MusicTheme)
    case adFree
    case experience

    private enum CodingKeys: String, CodingKey {
        case type
        case powerUpType
        case theme
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
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown offer item type")
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
        }
    }

    func defaultDisplayName(quantity: Int) -> String {
        switch self {
        case .coins:
            return "\(quantity) Coins"
        case .powerUp(let type):
            return "\(quantity)x \(type.rawValue.capitalized)"
        case .theme(let theme):
            return "\(theme.displayName) Theme"
        case .adFree:
            return "Ad-Free Experience"
        case .experience:
            return "\(quantity) XP"
        }
    }
}

public struct OfferManager {
    public static func generateDailyOffer() -> TimeLimitedOffer {
        let tomorrow = Date().addingTimeInterval(86400)
        return TimeLimitedOffer(
            title: "Daily Deal",
            description: "Today's special offer!",
            offerType: .dailyDeal,
            originalPrice: 4.99,
            discountedPrice: 2.99,
            expiresAt: tomorrow,
            items: [
                OfferItem(itemType: .coins, quantity: 500),
                OfferItem(itemType: .powerUp(.hammer), quantity: 3),
                OfferItem(itemType: .powerUp(.swap), quantity: 2)
            ],
            iapProductId: "com.game2244.daily_deal"
        )
    }

    public static func generateWeeklyOffer() -> TimeLimitedOffer {
        let nextWeek = Date().addingTimeInterval(604800)
        return TimeLimitedOffer(
            title: "Weekly Bundle",
            description: "This week's mega bundle!",
            offerType: .weeklyDeal,
            originalPrice: 19.99,
            discountedPrice: 9.99,
            expiresAt: nextWeek,
            items: [
                OfferItem(itemType: .coins, quantity: 2500),
                OfferItem(itemType: .powerUp(.hammer), quantity: 10),
                OfferItem(itemType: .powerUp(.swap), quantity: 10),
                OfferItem(itemType: .powerUp(.undo), quantity: 20),
                OfferItem(itemType: .theme(.cyberpunk), quantity: 1)
            ],
            iapProductId: "com.game2244.weekly_bundle"
        )
    }
}