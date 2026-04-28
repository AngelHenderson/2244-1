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
    private var interstitialDelegate: LiveFullScreenAdDelegate?
    private var rewardedDelegate: LiveFullScreenAdDelegate?
    private var rewardedInterstitialDelegate: LiveFullScreenAdDelegate?
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
        let delegate = LiveFullScreenAdDelegate(
            onDismiss: { [weak self] in
                self?.interstitial = nil
                self?.interstitialDelegate = nil
                Task { await self?.loadInterstitialIfNeeded() }
            },
            onFailToPresent: { [weak self] in
                self?.interstitial = nil
                self?.interstitialDelegate = nil
                Task { await self?.loadInterstitialIfNeeded() }
            }
        )
        interstitial.fullScreenContentDelegate = delegate
        interstitialDelegate = delegate
        interstitial.present(from: root)
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
        let didReward: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let resolver = LiveRewardResolver(continuation: cont)
            let delegate = LiveFullScreenAdDelegate(
                onDismiss: { [weak self, resolver] in
                    self?.rewarded = nil
                    self?.rewardedDelegate = nil
                    resolver.finishOnDismiss()
                    Task { await self?.loadRewardedIfNeeded() }
                },
                onFailToPresent: { [weak self, resolver] in
                    self?.rewarded = nil
                    self?.rewardedDelegate = nil
                    resolver.finishFailed()
                    Task { await self?.loadRewardedIfNeeded() }
                }
            )
            rewarded.fullScreenContentDelegate = delegate
            rewardedDelegate = delegate
            rewarded.present(from: root) {
                Task { @MainActor in
                    resolver.markEarned()
                }
            }
        }
        if didReward { onReward() }
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
            let resolver = LiveRewardResolver(continuation: cont)
            let delegate = LiveFullScreenAdDelegate(
                onDismiss: { [weak self, resolver] in
                    self?.rewardedInterstitial = nil
                    self?.rewardedInterstitialDelegate = nil
                    resolver.finishOnDismiss()
                    Task { await self?.loadRewardedInterstitialIfNeeded() }
                },
                onFailToPresent: { [weak self, resolver] in
                    self?.rewardedInterstitial = nil
                    self?.rewardedInterstitialDelegate = nil
                    resolver.finishFailed()
                    Task { await self?.loadRewardedInterstitialIfNeeded() }
                }
            )
            rewardedInterstitial.fullScreenContentDelegate = delegate
            rewardedInterstitialDelegate = delegate
            rewardedInterstitial.present(from: root) {
                Task { @MainActor in
                    resolver.markEarned()
                }
            }
        }
        if didReward { onReward() }
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
@MainActor
private final class LiveRewardResolver {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var didEarnReward = false

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func markEarned() {
        didEarnReward = true
    }

    func finishOnDismiss() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: didEarnReward)
    }

    func finishFailed() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: false)
    }
}

@MainActor
private final class LiveFullScreenAdDelegate: NSObject, FullScreenContentDelegate {
    private let onDismiss: @MainActor @Sendable () -> Void
    private let onFailToPresent: @MainActor @Sendable () -> Void

    init(
        onDismiss: @escaping @MainActor @Sendable () -> Void,
        onFailToPresent: @escaping @MainActor @Sendable () -> Void
    ) {
        self.onDismiss = onDismiss
        self.onFailToPresent = onFailToPresent
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        onDismiss()
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        onFailToPresent()
    }
}

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
