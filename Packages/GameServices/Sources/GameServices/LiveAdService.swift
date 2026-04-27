import Foundation
import SwiftUI
import GameCore

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Production AdMob-backed ad service.
///
/// Production and debug ad unit IDs are resolved from the app bundle's Info.plist,
/// with package-test fallbacks supplied by `AdMobIDs`.
@Observable
@MainActor
public final class LiveAdService: AdServiceProtocol {

    public var isBannerVisible: Bool = false
    private var adFree: Bool = false

    private let bannerUnitID: String
    private let interstitialUnitID: String
    private let rewardedUnitID: String
    private let rewardedInterstitialUnitID: String

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var rewardedInterstitial: RewardedInterstitialAd?
    #endif

    public init(adMobIDs: AdMobIDs = .resolved()) {
        self.bannerUnitID = adMobIDs.banner
        self.interstitialUnitID = adMobIDs.interstitial
        self.rewardedUnitID = adMobIDs.rewarded
        self.rewardedInterstitialUnitID = adMobIDs.rewardedInterstitial
        adFree = UserDefaults.standard.bool(forKey: "isAdFreePurchased")
    }

    // MARK: - AdServiceProtocol

    public func prepareForAdRequests() async -> Bool {
        guard !adFree else { return false }
        #if canImport(GoogleMobileAds)
        return await AdConsentManager.shared.prepareAndStartMobileAds()
        #else
        return true
        #endif
    }

    public func showBanner() async {
        guard !adFree else { return }
        isBannerVisible = true
        #if canImport(GoogleMobileAds)
        guard await AdConsentManager.shared.prepareAndStartMobileAds() else {
            isBannerVisible = false
            return
        }
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
        guard await AdConsentManager.shared.prepareAndStartMobileAds() else { return false }
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
        guard await AdConsentManager.shared.prepareAndStartMobileAds() else { return false }
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

    public func showRewardedInterstitial(onReward: @MainActor @Sendable () -> Void) async -> Bool {
        guard !adFree else { return false }
        #if canImport(GoogleMobileAds)
        guard await AdConsentManager.shared.prepareAndStartMobileAds() else { return false }
        await loadRewardedInterstitialIfNeeded()
        guard let rewardedInterstitial else { return false }
        guard let root = rootViewController() else { return false }
        let didReward: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            rewardedInterstitial.present(from: root) {
                cont.resume(returning: true)
            }
        }
        if didReward { onReward() }
        self.rewardedInterstitial = nil
        Task { await loadRewardedInterstitialIfNeeded() }
        return didReward
        #else
        try? await Task.sleep(for: .seconds(0.5))
        onReward()
        return true
        #endif
    }

    public func isPrivacyOptionsRequired() async -> Bool {
        #if canImport(GoogleMobileAds)
        _ = await AdConsentManager.shared.prepareForAdRequests()
        return AdConsentManager.shared.isPrivacyOptionsRequired
        #else
        return false
        #endif
    }

    public func showPrivacyOptions() async -> Bool {
        #if canImport(GoogleMobileAds)
        return await AdConsentManager.shared.presentPrivacyOptions()
        #else
        return false
        #endif
    }

    public func isAdFree() async -> Bool { adFree }

    public func setAdFree(_ value: Bool) {
        adFree = value
        if value { isBannerVisible = false }
    }

    // MARK: - GoogleMobileAds glue (compiled out until SDK is added)

    #if canImport(GoogleMobileAds)
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

    private func loadRewardedInterstitialIfNeeded() async {
        guard rewardedInterstitial == nil else { return }
        let request = Request()
        do {
            rewardedInterstitial = try await RewardedInterstitialAd.load(
                with: rewardedInterstitialUnitID,
                request: request
            )
        } catch {
            #if DEBUG
            print("LiveAdService: rewarded interstitial load failed:", error)
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

    public init(adUnitID: String = AdMobIDs.resolved().banner) {
        self.adUnitID = adUnitID
    }

    public var body: some View {
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        BannerContent(adUnitID: adUnitID)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds) && canImport(UIKit)
private struct BannerContent: View {
    let adUnitID: String
    @State private var canLoadBanner = false

    var body: some View {
        Group {
            if canLoadBanner {
                GeometryReader { proxy in
                    let width = max(320, proxy.size.width)
                    let adSize = largeAnchoredAdaptiveBanner(width: width)
                    HStack {
                        Spacer(minLength: 0)
                        BannerRepresentable(adUnitID: adUnitID, adSize: adSize)
                            .frame(width: adSize.size.width, height: adSize.size.height)
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 90)
                .background(Color.clear)
            } else {
                EmptyView()
            }
        }
        .task(id: adUnitID) {
            canLoadBanner = await AdConsentManager.shared.prepareAndStartMobileAds()
        }
    }
}

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
