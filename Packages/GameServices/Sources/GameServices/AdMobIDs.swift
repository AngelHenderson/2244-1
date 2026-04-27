import Foundation

public typealias AdMobIDs = Game2244AdMobIDs

public struct Game2244AdMobIDs: Equatable, Sendable {
    public let appID: String
    public let banner: String
    public let interstitial: String
    public let rewarded: String
    public let rewardedInterstitial: String

    public init(
        appID: String,
        banner: String,
        interstitial: String,
        rewarded: String,
        rewardedInterstitial: String
    ) {
        self.appID = appID
        self.banner = banner
        self.interstitial = interstitial
        self.rewarded = rewarded
        self.rewardedInterstitial = rewardedInterstitial
    }

    public static let debug = Game2244AdMobIDs(
        appID: "ca-app-pub-3940256099942544~1458002511",
        banner: "ca-app-pub-3940256099942544/2435281174",
        interstitial: "ca-app-pub-3940256099942544/4411468910",
        rewarded: "ca-app-pub-3940256099942544/1712485313",
        rewardedInterstitial: "ca-app-pub-3940256099942544/6978759866"
    )

    public static let production = Game2244AdMobIDs(
        appID: "ca-app-pub-7853395118626839~7726164547",
        banner: "ca-app-pub-7853395118626839/5881765682",
        interstitial: "ca-app-pub-7853395118626839/8723551443",
        rewarded: "ca-app-pub-7853395118626839/5100001208",
        rewardedInterstitial: "ca-app-pub-7853395118626839/6221511185"
    )

    public static var current: Game2244AdMobIDs {
        #if DEBUG
        debug
        #else
        production
        #endif
    }

    public static func resolved(from bundle: Bundle = .main) -> Game2244AdMobIDs {
        let fallback = current

        return Game2244AdMobIDs(
            appID: string(for: Keys.appID, in: bundle) ?? fallback.appID,
            banner: string(for: Keys.banner, in: bundle) ?? fallback.banner,
            interstitial: string(for: Keys.interstitial, in: bundle) ?? fallback.interstitial,
            rewarded: string(for: Keys.rewarded, in: bundle) ?? fallback.rewarded,
            rewardedInterstitial: string(for: Keys.rewardedInterstitial, in: bundle)
                ?? fallback.rewardedInterstitial
        )
    }

    private static func string(for key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum Keys {
        static let appID = "GADApplicationIdentifier"
        static let banner = "GADBannerAdUnitID"
        static let interstitial = "GADInterstitialAdUnitID"
        static let rewarded = "GADRewardedAdUnitID"
        static let rewardedInterstitial = "GADRewardedInterstitialAdUnitID"
    }
}
