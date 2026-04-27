import Foundation

public struct AdMobIDs: Equatable, Sendable {
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

    public static let debug = AdMobIDs(
        appID: "ca-app-pub-3940256099942544~1458002511",
        banner: "ca-app-pub-3940256099942544/6300978111",
        interstitial: "ca-app-pub-3940256099942544/1033173712",
        rewarded: "ca-app-pub-3940256099942544/5224354917",
        rewardedInterstitial: "ca-app-pub-3940256099942544/5354046379"
    )

    public static let production = AdMobIDs(
        appID: "ca-app-pub-7853395118626839~7726164547",
        banner: "ca-app-pub-7853395118626839/5881765682",
        interstitial: "ca-app-pub-7853395118626839/8723551443",
        rewarded: "ca-app-pub-7853395118626839/5100001208",
        rewardedInterstitial: "ca-app-pub-7853395118626839/6221511185"
    )

    public static func resolved(from bundle: Bundle = .main) -> AdMobIDs {
        let fallback: AdMobIDs
        #if DEBUG
        fallback = .debug
        #else
        fallback = .production
        #endif

        return AdMobIDs(
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
