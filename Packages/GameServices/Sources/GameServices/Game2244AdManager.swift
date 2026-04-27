import Foundation
import Observation
import SwiftUI

#if canImport(GoogleMobileAds) && canImport(UIKit)
@preconcurrency import GoogleMobileAds
import UIKit
#endif

public enum Game2244Screen: Sendable, Hashable {
    case home
    case board
    case pause
    case results
    case shop
    case stats
    case settings
    case dailyChallenge
    case premiumUpsell

    public var allowsBanner: Bool {
        switch self {
        case .home, .shop, .stats, .settings, .premiumUpsell:
            true
        case .board, .pause, .results, .dailyChallenge:
            false
        }
    }
}

public enum Game2244AdKind: String, Sendable {
    case banner
    case interstitial
    case rewarded
    case rewardedInterstitial
}

public enum Game2244AdBlockReason: Sendable, Equatable {
    case premium
    case consentUnavailable
    case activeGame
    case alreadyPresentingFullScreenAd
    case frequencyCapped
}

public enum Game2244AdShowResult: Sendable, Equatable {
    case shown
    case unavailable
    case blocked(Game2244AdBlockReason)
}

public enum Game2244RewardPlacement: Sendable, Hashable {
    case doubleCoins(baseCoins: Int)
    case freeUndo
    case extraUndo(count: Int)
    case hint
    case shuffle
    case revive
    case continueRun
    case dailyStreakRepair
    case bonusChest
    case extraChallengeAttempt

    public var title: String {
        switch self {
        case .doubleCoins(let baseCoins):
            "Double \(baseCoins) coins"
        case .freeUndo:
            "Claim a free undo"
        case .extraUndo(let count):
            "Claim \(count) undos"
        case .hint:
            "Reveal a smart move"
        case .shuffle:
            "Shuffle the board"
        case .revive:
            "Revive this run"
        case .continueRun:
            "Continue your run"
        case .dailyStreakRepair:
            "Repair your streak"
        case .bonusChest:
            "Open a bonus chest"
        case .extraChallengeAttempt:
            "Get another challenge attempt"
        }
    }

    public var analyticsName: String {
        switch self {
        case .doubleCoins:
            "double_coins"
        case .freeUndo:
            "free_undo"
        case .extraUndo:
            "extra_undo"
        case .hint:
            "hint"
        case .shuffle:
            "shuffle"
        case .revive:
            "revive"
        case .continueRun:
            "continue_run"
        case .dailyStreakRepair:
            "daily_streak_repair"
        case .bonusChest:
            "bonus_chest"
        case .extraChallengeAttempt:
            "extra_challenge_attempt"
        }
    }
}

public struct Game2244EarnedAdReward: Sendable, Equatable {
    public let placement: Game2244RewardPlacement
    public let currency: String
    public let amount: Int

    public init(placement: Game2244RewardPlacement, currency: String, amount: Int) {
        self.placement = placement
        self.currency = currency
        self.amount = amount
    }
}

public enum Game2244RewardedAdResult: Sendable, Equatable {
    case earned(Game2244EarnedAdReward)
    case skipped
    case unavailable
    case failed(String)
    case blocked(Game2244AdBlockReason)
}

public enum Game2244AdEvent: Sendable, Equatable {
    case initialized
    case loadStarted(Game2244AdKind)
    case loaded(Game2244AdKind)
    case failedToLoad(Game2244AdKind, message: String)
    case willPresent(Game2244AdKind)
    case dismissed(Game2244AdKind)
    case failedToPresent(Game2244AdKind, message: String)
    case rewardEarned(Game2244AdKind, Game2244EarnedAdReward)
}

@MainActor
@Observable
public final class Game2244AdManager {
    public var isPremium = false
    public var canRequestAds = true
    public var isGameActive = false
    public var isFullScreenAdPresenting = false
    public var isInterstitialReady = false
    public var isRewardedReady = false
    public var isRewardedInterstitialReady = false
    public var lastErrorMessage: String?

    public var bannerAdUnitID: String { ids.banner }
    public var adsEnabled: Bool { !isPremium && canRequestAds }

    private let ids: Game2244AdMobIDs
    private let minimumSecondsBetweenInterstitials: TimeInterval
    private let completedRoundsBetweenInterstitials: Int
    private let onEvent: @MainActor @Sendable (Game2244AdEvent) -> Void

    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var completedRoundsSinceInterstitial = 0
    @ObservationIgnored private var lastInterstitialDate: Date?
    @ObservationIgnored private var isLoadingInterstitial = false
    @ObservationIgnored private var isLoadingRewarded = false
    @ObservationIgnored private var isLoadingRewardedInterstitial = false

    #if canImport(GoogleMobileAds) && canImport(UIKit)
    @ObservationIgnored private var interstitialAd: InterstitialAd?
    @ObservationIgnored private var rewardedAd: RewardedAd?
    @ObservationIgnored private var rewardedInterstitialAd: RewardedInterstitialAd?
    @ObservationIgnored private var interstitialDelegate: Game2244FullScreenAdDelegate?
    @ObservationIgnored private var rewardedDelegate: Game2244FullScreenAdDelegate?
    @ObservationIgnored private var rewardedInterstitialDelegate: Game2244FullScreenAdDelegate?
    #endif

    public init(
        ids: Game2244AdMobIDs = .resolved(),
        minimumSecondsBetweenInterstitials: TimeInterval = 180,
        completedRoundsBetweenInterstitials: Int = 3,
        onEvent: @escaping @MainActor @Sendable (Game2244AdEvent) -> Void = { _ in }
    ) {
        self.ids = ids
        self.minimumSecondsBetweenInterstitials = minimumSecondsBetweenInterstitials
        self.completedRoundsBetweenInterstitials = completedRoundsBetweenInterstitials
        self.onEvent = onEvent
    }

    public func startAndPreload(isPremium: Bool, canRequestAds: Bool = true) async {
        self.isPremium = isPremium
        self.canRequestAds = canRequestAds
        guard adsEnabled else {
            clearLoadedAds()
            return
        }
        await startSDKIfNeeded()
        await preloadAll()
    }

    public func updatePremiumStatus(_ isPremium: Bool) async {
        self.isPremium = isPremium
        guard adsEnabled else {
            clearLoadedAds()
            return
        }
        await preloadAll()
    }

    public func updateConsentStatus(canRequestAds: Bool) async {
        self.canRequestAds = canRequestAds
        guard adsEnabled else {
            clearLoadedAds()
            return
        }
        await startSDKIfNeeded()
        await preloadAll()
    }

    public func beginGame() {
        isGameActive = true
    }

    public func endGame() {
        isGameActive = false
    }

    public func shouldShowBanner(on screen: Game2244Screen) -> Bool {
        adsEnabled && screen.allowsBanner && !isGameActive && !isFullScreenAdPresenting
    }

    public func preloadAll() async {
        guard adsEnabled else { return }
        await preloadInterstitial()
        await preloadRewarded()
        await preloadRewardedInterstitial()
    }

    public func preloadInterstitial() async {
        guard adsEnabled, !isLoadingInterstitial else { return }
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        guard interstitialAd == nil else { return }
        isLoadingInterstitial = true
        emit(.loadStarted(.interstitial))
        defer { isLoadingInterstitial = false }
        do {
            let ad = try await InterstitialAd.load(with: ids.interstitial, request: Request())
            let delegate = Game2244FullScreenAdDelegate(
                onWillPresent: { [weak self] in
                    self?.emit(.willPresent(.interstitial))
                },
                onDismiss: { [weak self] in
                    self?.isFullScreenAdPresenting = false
                    self?.interstitialAd = nil
                    self?.interstitialDelegate = nil
                    self?.isInterstitialReady = false
                    self?.emit(.dismissed(.interstitial))
                    Task { await self?.preloadInterstitial() }
                },
                onFailToPresent: { [weak self] message in
                    self?.isFullScreenAdPresenting = false
                    self?.interstitialAd = nil
                    self?.interstitialDelegate = nil
                    self?.isInterstitialReady = false
                    self?.lastErrorMessage = message
                    self?.emit(.failedToPresent(.interstitial, message: message))
                    Task { await self?.preloadInterstitial() }
                }
            )
            ad.fullScreenContentDelegate = delegate
            interstitialAd = ad
            interstitialDelegate = delegate
            isInterstitialReady = true
            emit(.loaded(.interstitial))
        } catch {
            let message = error.localizedDescription
            lastErrorMessage = message
            emit(.failedToLoad(.interstitial, message: message))
        }
        #else
        lastErrorMessage = "Google Mobile Ads is unavailable on this platform."
        emit(.failedToLoad(.interstitial, message: lastErrorMessage ?? "Unavailable"))
        #endif
    }

    public func preloadRewarded() async {
        guard adsEnabled, !isLoadingRewarded else { return }
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        guard rewardedAd == nil else { return }
        isLoadingRewarded = true
        emit(.loadStarted(.rewarded))
        defer { isLoadingRewarded = false }
        do {
            let ad = try await RewardedAd.load(with: ids.rewarded, request: Request())
            rewardedAd = ad
            isRewardedReady = true
            emit(.loaded(.rewarded))
        } catch {
            let message = error.localizedDescription
            lastErrorMessage = message
            emit(.failedToLoad(.rewarded, message: message))
        }
        #else
        lastErrorMessage = "Google Mobile Ads is unavailable on this platform."
        emit(.failedToLoad(.rewarded, message: lastErrorMessage ?? "Unavailable"))
        #endif
    }

    public func preloadRewardedInterstitial() async {
        guard adsEnabled, !isLoadingRewardedInterstitial else { return }
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        guard rewardedInterstitialAd == nil else { return }
        isLoadingRewardedInterstitial = true
        emit(.loadStarted(.rewardedInterstitial))
        defer { isLoadingRewardedInterstitial = false }
        do {
            let ad = try await RewardedInterstitialAd.load(
                with: ids.rewardedInterstitial,
                request: Request()
            )
            rewardedInterstitialAd = ad
            isRewardedInterstitialReady = true
            emit(.loaded(.rewardedInterstitial))
        } catch {
            let message = error.localizedDescription
            lastErrorMessage = message
            emit(.failedToLoad(.rewardedInterstitial, message: message))
        }
        #else
        lastErrorMessage = "Google Mobile Ads is unavailable on this platform."
        emit(.failedToLoad(.rewardedInterstitial, message: lastErrorMessage ?? "Unavailable"))
        #endif
    }

    public func showInterstitialAfterRoundEnd() async -> Game2244AdShowResult {
        completedRoundsSinceInterstitial += 1
        guard !isPremium else { return .blocked(.premium) }
        guard canRequestAds else { return .blocked(.consentUnavailable) }
        guard !isGameActive else { return .blocked(.activeGame) }
        guard !isFullScreenAdPresenting else { return .blocked(.alreadyPresentingFullScreenAd) }
        guard completedRoundsSinceInterstitial >= completedRoundsBetweenInterstitials else {
            return .blocked(.frequencyCapped)
        }
        if let lastInterstitialDate {
            let secondsSinceLastInterstitial = Date().timeIntervalSince(lastInterstitialDate)
            guard secondsSinceLastInterstitial >= minimumSecondsBetweenInterstitials else {
                return .blocked(.frequencyCapped)
            }
        }

        #if canImport(GoogleMobileAds) && canImport(UIKit)
        guard let interstitialAd else {
            await preloadInterstitial()
            return .unavailable
        }
        isFullScreenAdPresenting = true
        isInterstitialReady = false
        lastInterstitialDate = Date()
        completedRoundsSinceInterstitial = 0
        interstitialAd.present(from: nil)
        return .shown
        #else
        return .unavailable
        #endif
    }

    public func showRewarded(for placement: Game2244RewardPlacement) async -> Game2244RewardedAdResult {
        guard !isPremium else { return .blocked(.premium) }
        guard canRequestAds else { return .blocked(.consentUnavailable) }
        guard !isGameActive else { return .blocked(.activeGame) }
        guard !isFullScreenAdPresenting else { return .blocked(.alreadyPresentingFullScreenAd) }

        #if canImport(GoogleMobileAds) && canImport(UIKit)
        guard let rewardedAd else {
            await preloadRewarded()
            return .unavailable
        }
        isFullScreenAdPresenting = true
        isRewardedReady = false
        return await withCheckedContinuation { continuation in
            let resolver = Game2244RewardResolver(continuation: continuation)
            let delegate = Game2244FullScreenAdDelegate(
                onWillPresent: { [weak self] in
                    self?.emit(.willPresent(.rewarded))
                },
                onDismiss: { [weak self, resolver] in
                    self?.isFullScreenAdPresenting = false
                    self?.rewardedAd = nil
                    self?.rewardedDelegate = nil
                    self?.isRewardedReady = false
                    self?.emit(.dismissed(.rewarded))
                    resolver.finishOnDismiss()
                    Task { await self?.preloadRewarded() }
                },
                onFailToPresent: { [weak self, resolver] message in
                    self?.isFullScreenAdPresenting = false
                    self?.rewardedAd = nil
                    self?.rewardedDelegate = nil
                    self?.isRewardedReady = false
                    self?.lastErrorMessage = message
                    self?.emit(.failedToPresent(.rewarded, message: message))
                    resolver.finishFailed(message)
                    Task { await self?.preloadRewarded() }
                }
            )
            rewardedDelegate = delegate
            rewardedAd.fullScreenContentDelegate = delegate
            rewardedAd.present(from: nil) { [weak self, resolver] in
                let adReward = rewardedAd.adReward
                let reward = Game2244EarnedAdReward(
                    placement: placement,
                    currency: adReward.type,
                    amount: adReward.amount.intValue
                )
                Task { @MainActor in
                    resolver.markEarned(reward)
                    self?.emit(.rewardEarned(.rewarded, reward))
                }
            }
        }
        #else
        return .unavailable
        #endif
    }

    public func showRewardedInterstitialAfterIntro(
        for placement: Game2244RewardPlacement
    ) async -> Game2244RewardedAdResult {
        guard !isPremium else { return .blocked(.premium) }
        guard canRequestAds else { return .blocked(.consentUnavailable) }
        guard !isGameActive else { return .blocked(.activeGame) }
        guard !isFullScreenAdPresenting else { return .blocked(.alreadyPresentingFullScreenAd) }

        #if canImport(GoogleMobileAds) && canImport(UIKit)
        guard let rewardedInterstitialAd else {
            await preloadRewardedInterstitial()
            return .unavailable
        }
        isFullScreenAdPresenting = true
        isRewardedInterstitialReady = false
        return await withCheckedContinuation { continuation in
            let resolver = Game2244RewardResolver(continuation: continuation)
            let delegate = Game2244FullScreenAdDelegate(
                onWillPresent: { [weak self] in
                    self?.emit(.willPresent(.rewardedInterstitial))
                },
                onDismiss: { [weak self, resolver] in
                    self?.isFullScreenAdPresenting = false
                    self?.rewardedInterstitialAd = nil
                    self?.rewardedInterstitialDelegate = nil
                    self?.isRewardedInterstitialReady = false
                    self?.emit(.dismissed(.rewardedInterstitial))
                    resolver.finishOnDismiss()
                    Task { await self?.preloadRewardedInterstitial() }
                },
                onFailToPresent: { [weak self, resolver] message in
                    self?.isFullScreenAdPresenting = false
                    self?.rewardedInterstitialAd = nil
                    self?.rewardedInterstitialDelegate = nil
                    self?.isRewardedInterstitialReady = false
                    self?.lastErrorMessage = message
                    self?.emit(.failedToPresent(.rewardedInterstitial, message: message))
                    resolver.finishFailed(message)
                    Task { await self?.preloadRewardedInterstitial() }
                }
            )
            rewardedInterstitialDelegate = delegate
            rewardedInterstitialAd.fullScreenContentDelegate = delegate
            rewardedInterstitialAd.present(from: nil) { [weak self, resolver] in
                let adReward = rewardedInterstitialAd.adReward
                let reward = Game2244EarnedAdReward(
                    placement: placement,
                    currency: adReward.type,
                    amount: adReward.amount.intValue
                )
                Task { @MainActor in
                    resolver.markEarned(reward)
                    self?.emit(.rewardEarned(.rewardedInterstitial, reward))
                }
            }
        }
        #else
        return .unavailable
        #endif
    }

    private func startSDKIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        await MobileAds.shared.start()
        #endif
        emit(.initialized)
    }

    private func clearLoadedAds() {
        #if canImport(GoogleMobileAds) && canImport(UIKit)
        interstitialAd = nil
        rewardedAd = nil
        rewardedInterstitialAd = nil
        interstitialDelegate = nil
        rewardedDelegate = nil
        rewardedInterstitialDelegate = nil
        #endif
        isInterstitialReady = false
        isRewardedReady = false
        isRewardedInterstitialReady = false
        isFullScreenAdPresenting = false
    }

    private func emit(_ event: Game2244AdEvent) {
        onEvent(event)
    }
}

#if canImport(GoogleMobileAds) && canImport(UIKit)
public struct Game2244BannerSlot: View {
    @Environment(Game2244AdManager.self) private var adManager
    private let screen: Game2244Screen

    public init(screen: Game2244Screen) {
        self.screen = screen
    }

    public var body: some View {
        if adManager.shouldShowBanner(on: screen) {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 320)
                let adSize = largeAnchoredAdaptiveBanner(width: width)
                HStack {
                    Spacer(minLength: 0)
                    Game2244BannerRepresentable(
                        adUnitID: adManager.bannerAdUnitID,
                        adSize: adSize
                    )
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 90)
        }
    }
}

private struct Game2244BannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.load(Request())
        context.coordinator.lastLoadKey = loadKey
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adUnitID = adUnitID
        banner.adSize = adSize
        guard context.coordinator.lastLoadKey != loadKey else { return }
        context.coordinator.lastLoadKey = loadKey
        banner.load(Request())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var loadKey: String {
        "\(adUnitID)-\(Int(adSize.size.width))x\(Int(adSize.size.height))"
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var lastLoadKey = ""

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            print("2244 banner loaded.")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("2244 banner failed:", error.localizedDescription)
            #endif
        }
    }
}
#endif

public struct Game2244RewardedInterstitialIntroSheet: View {
    @Environment(Game2244AdManager.self) private var adManager
    private let placement: Game2244RewardPlacement
    private let onResult: @MainActor @Sendable (Game2244RewardedAdResult) -> Void

    public init(
        placement: Game2244RewardPlacement,
        onResult: @escaping @MainActor @Sendable (Game2244RewardedAdResult) -> Void
    ) {
        self.placement = placement
        self.onResult = onResult
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text("Bonus Reward")
                .font(.title.bold())
            Text(placement.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Watch a short ad to claim this reward, or skip and keep playing without it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { @MainActor in
                    let result = await adManager.showRewardedInterstitialAfterIntro(for: placement)
                    onResult(result)
                }
            } label: {
                Text(adManager.isRewardedInterstitialReady ? "Claim Reward" : "Preparing Reward...")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!adManager.isRewardedInterstitialReady)
            Button(role: .cancel) {
                onResult(.skipped)
            } label: {
                Text("Skip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }
}

@MainActor
private final class Game2244RewardResolver {
    private var continuation: CheckedContinuation<Game2244RewardedAdResult, Never>?
    private var earnedReward: Game2244EarnedAdReward?

    init(continuation: CheckedContinuation<Game2244RewardedAdResult, Never>) {
        self.continuation = continuation
    }

    func markEarned(_ reward: Game2244EarnedAdReward) {
        earnedReward = reward
    }

    func finishOnDismiss() {
        guard let continuation else { return }
        self.continuation = nil
        if let earnedReward {
            continuation.resume(returning: .earned(earnedReward))
        } else {
            continuation.resume(returning: .skipped)
        }
    }

    func finishFailed(_ message: String) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: .failed(message))
    }
}

#if canImport(GoogleMobileAds) && canImport(UIKit)
@MainActor
private final class Game2244FullScreenAdDelegate: NSObject, FullScreenContentDelegate {
    private let onWillPresent: @MainActor @Sendable () -> Void
    private let onDismiss: @MainActor @Sendable () -> Void
    private let onFailToPresent: @MainActor @Sendable (String) -> Void

    init(
        onWillPresent: @escaping @MainActor @Sendable () -> Void,
        onDismiss: @escaping @MainActor @Sendable () -> Void,
        onFailToPresent: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.onWillPresent = onWillPresent
        self.onDismiss = onDismiss
        self.onFailToPresent = onFailToPresent
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        onWillPresent()
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        onDismiss()
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        onFailToPresent(error.localizedDescription)
    }
}
#endif
