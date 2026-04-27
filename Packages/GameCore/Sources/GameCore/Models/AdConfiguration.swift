import Foundation

public struct AdConfiguration: Codable, Sendable {
    public let bannerId: String
    public let interstitialId: String
    public let rewardedId: String
    public let rewardedInterstitialId: String?
    public let nativeId: String?
    public let testMode: Bool
    public let adFrequency: AdFrequency
    public let rewardedAdReward: AdReward
    public let placementRules: [AdPlacementRule]

    public init(
        bannerId: String = "ca-app-pub-3940256099942544/2435281174",
        interstitialId: String = "ca-app-pub-3940256099942544/4411468910",
        rewardedId: String = "ca-app-pub-3940256099942544/1712485313",
        rewardedInterstitialId: String? = "ca-app-pub-3940256099942544/6978759866",
        nativeId: String? = nil,
        testMode: Bool = true,
        adFrequency: AdFrequency = .normal,
        rewardedAdReward: AdReward = .default,
        placementRules: [AdPlacementRule] = AdPlacementRule.defaultRules
    ) {
        self.bannerId = bannerId
        self.interstitialId = interstitialId
        self.rewardedId = rewardedId
        self.rewardedInterstitialId = rewardedInterstitialId
        self.nativeId = nativeId
        self.testMode = testMode
        self.adFrequency = adFrequency
        self.rewardedAdReward = rewardedAdReward
        self.placementRules = placementRules
    }

    public static var production: AdConfiguration {
        return AdConfiguration(
            bannerId: "ca-app-pub-7853395118626839/5881765682",
            interstitialId: "ca-app-pub-7853395118626839/8723551443",
            rewardedId: "ca-app-pub-7853395118626839/5100001208",
            rewardedInterstitialId: "ca-app-pub-7853395118626839/6221511185",
            nativeId: nil,
            testMode: false
        )
    }

    public static var test: AdConfiguration {
        return AdConfiguration(testMode: true)
    }
}

public enum AdFrequency: String, Codable, Sendable {
    case low
    case normal
    case high
    case aggressive

    public var interstitialInterval: Int {
        switch self {
        case .low: return 5
        case .normal: return 3
        case .high: return 2
        case .aggressive: return 1
        }
    }

    public var bannerDelay: TimeInterval {
        switch self {
        case .low: return 30
        case .normal: return 15
        case .high: return 5
        case .aggressive: return 0
        }
    }
}

public struct AdReward: Codable, Sendable {
    public let coins: Int
    public let powerUps: [PowerUpType: Int]
    public let experience: Int

    public init(coins: Int = 50, powerUps: [PowerUpType: Int] = [:], experience: Int = 25) {
        self.coins = coins
        self.powerUps = powerUps
        self.experience = experience
    }

    public static var `default`: AdReward {
        return AdReward(coins: 50, powerUps: [.hammer: 1], experience: 25)
    }

    public static var doubleReward: AdReward {
        return AdReward(coins: 100, powerUps: [.hammer: 2, .swap: 1], experience: 50)
    }

    public static var tripleReward: AdReward {
        return AdReward(coins: 150, powerUps: [.hammer: 3, .swap: 2, .undo: 1], experience: 75)
    }
}

public struct AdPlacementRule: Codable, Sendable {
    public let placement: AdPlacement
    public let adType: AdType
    public let condition: AdCondition

    public init(placement: AdPlacement, adType: AdType, condition: AdCondition) {
        self.placement = placement
        self.adType = adType
        self.condition = condition
    }

    public static var defaultRules: [AdPlacementRule] {
        return [
            AdPlacementRule(placement: .homeScreen, adType: .banner, condition: .always),
            AdPlacementRule(placement: .gameOver, adType: .interstitial, condition: .everyNthTime(3)),
            AdPlacementRule(placement: .levelComplete, adType: .rewarded, condition: .optional),
            AdPlacementRule(placement: .shopScreen, adType: .native, condition: .always),
            AdPlacementRule(placement: .pauseMenu, adType: .banner, condition: .afterDelay(5))
        ]
    }
}

public enum AdPlacement: String, Codable, Sendable {
    case homeScreen
    case gameOver
    case levelComplete
    case pauseMenu
    case shopScreen
    case leaderboard
    case spinWheel
    case dailyReward
}

public enum AdType: String, Codable, Sendable {
    case banner
    case interstitial
    case rewarded
    case native
}

public enum AdCondition: Codable, Sendable {
    case always
    case everyNthTime(Int)
    case afterDelay(TimeInterval)
    case optional
    case never

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "always":
            self = .always
        case "everyNthTime":
            let value = try container.decode(Int.self, forKey: .value)
            self = .everyNthTime(value)
        case "afterDelay":
            let value = try container.decode(TimeInterval.self, forKey: .value)
            self = .afterDelay(value)
        case "optional":
            self = .optional
        case "never":
            self = .never
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown ad condition")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .always:
            try container.encode("always", forKey: .type)
        case .everyNthTime(let value):
            try container.encode("everyNthTime", forKey: .type)
            try container.encode(value, forKey: .value)
        case .afterDelay(let value):
            try container.encode("afterDelay", forKey: .type)
            try container.encode(value, forKey: .value)
        case .optional:
            try container.encode("optional", forKey: .type)
        case .never:
            try container.encode("never", forKey: .type)
        }
    }
}
