import Foundation
import SwiftUI
import GameCore

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Production AdMob-backed ad service.
///
/// **Setup checklist** (so this file actually serves real ads):
/// 1. Register the production app/ad units in AdMob and replace the test app/ad unit IDs.
/// 2. Keep `GADApplicationIdentifier` and `SKAdNetworkItems` current with AdMob's published list.
/// 3. Complete consent/ATT before the first ad load in regions where that is required.
/// 4. Set the three ad unit IDs below (or pass them via `init(...)`) — the defaults are
///    Google's public TEST IDs so you can validate wiring without burning real impressions.
@Observable
@MainActor
public final class LiveAdService: AdServiceProtocol {

    // MARK: - Test Ad Unit IDs (replace with production IDs from your AdMob console)
    public static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    public static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    public static let testRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    public var isBannerVisible: Bool = false
    private var adFree: Bool = false

    private let bannerUnitID: String
    private let interstitialUnitID: String
    private let rewardedUnitID: String

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var didStart: Bool = false
    #endif

    public init(
        bannerUnitID: String = LiveAdService.testBannerUnitID,
        interstitialUnitID: String = LiveAdService.testInterstitialUnitID,
        rewardedUnitID: String = LiveAdService.testRewardedUnitID
    ) {
        self.bannerUnitID = bannerUnitID
        self.interstitialUnitID = interstitialUnitID
        self.rewardedUnitID = rewardedUnitID
        adFree = UserDefaults.standard.bool(forKey: "isAdFreePurchased")
    }

    // MARK: - AdServiceProtocol

    public func showBanner() async {
        guard !adFree else { return }
        isBannerVisible = true
        #if canImport(GoogleMobileAds)
        await ensureStarted()
        // Banner UI is owned by the host (a SwiftUI representable would render
        // GADBannerView at the bottom). Keeping the flag here so the host can
        // observe and present its banner accordingly.
        #endif
    }

    public func hideBanner() async {
        isBannerVisible = false
    }

    public func showInterstitial() async -> Bool {
        guard !adFree else { return false }
        #if canImport(GoogleMobileAds)
        await ensureStarted()
        await loadInterstitialIfNeeded()
        guard let interstitial else { return false }
        guard let root = rootViewController() else { return false }
        interstitial.present(from: root)
        self.interstitial = nil
        Task { await loadInterstitialIfNeeded() }
        return true
        #else
        try? await Task.sleep(for: .seconds(0.5))
        return true
        #endif
    }

    public func showRewarded(onReward: @MainActor @Sendable () -> Void) async -> Bool {
        guard !adFree else { return false }
        #if canImport(GoogleMobileAds)
        await ensureStarted()
        await loadRewardedIfNeeded()
        guard let rewarded else { return false }
        guard let root = rootViewController() else { return false }
        // Avoid capturing the non-escaping `onReward` inside the continuation
        // closure; signal via the continuation, then call onReward after we resume.
        let didReward: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            rewarded.present(from: root) {
                cont.resume(returning: true)
            }
        }
        if didReward { onReward() }
        self.rewarded = nil
        Task { await loadRewardedIfNeeded() }
        return didReward
        #else
        try? await Task.sleep(for: .seconds(0.5))
        onReward()
        return true
        #endif
    }

    public func isAdFree() async -> Bool { adFree }

    public func setAdFree(_ value: Bool) {
        adFree = value
        if value { isBannerVisible = false }
    }

    // MARK: - GoogleMobileAds glue (compiled out until SDK is added)

    #if canImport(GoogleMobileAds)
    private func ensureStarted() async {
        guard !didStart else { return }
        didStart = true
        await requestTrackingAuthorizationIfNeeded()
        await MobileAds.shared.start()
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        guard #available(iOS 14.0, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in cont.resume() }
        }
        #endif
    }

    private func loadInterstitialIfNeeded() async {
        guard interstitial == nil else { return }
        let request = Request()
        do {
            interstitial = try await InterstitialAd.load(
                with: interstitialUnitID,
                request: request
            )
        } catch {
            #if DEBUG
            print("LiveAdService: interstitial load failed:", error)
            #endif
        }
    }

    private func loadRewardedIfNeeded() async {
        guard rewarded == nil else { return }
        let request = Request()
        do {
            rewarded = try await RewardedAd.load(
                with: rewardedUnitID,
                request: request
            )
        } catch {
            #if DEBUG
            print("LiveAdService: rewarded load failed:", error)
            #endif
        }
    }

    private func rootViewController() -> UIViewController? {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController
        #else
        nil
        #endif
    }
    #endif
}

public struct LiveBannerAdView: View {
    private let adUnitID: String

    public init(adUnitID: String = LiveAdService.testBannerUnitID) {
        self.adUnitID = adUnitID
    }

    public var body: some View {
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        let width = max(320, UIScreen.main.bounds.width)
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        BannerRepresentable(adUnitID: adUnitID, adSize: adSize)
            .frame(width: adSize.size.width, height: adSize.size.height)
            .background(Color.clear)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds) && canImport(UIKit)
private struct BannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        if banner.adUnitID != adUnitID {
            banner.adUnitID = adUnitID
            banner.load(Request())
        }
        banner.rootViewController = rootViewController()
        banner.adSize = adSize
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }?.rootViewController
    }
}
#endif
