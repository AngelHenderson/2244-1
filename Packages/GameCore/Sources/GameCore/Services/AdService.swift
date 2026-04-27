import Foundation
import SwiftUI

public protocol AdServiceProtocol: Sendable {
    func prepareForAdRequests() async -> Bool
    func showBanner() async
    func hideBanner() async
    func showInterstitial() async -> Bool
    func showRewarded(onReward: @MainActor @Sendable () -> Void) async -> Bool
    func showRewardedInterstitial(onReward: @MainActor @Sendable () -> Void) async -> Bool
    func isPrivacyOptionsRequired() async -> Bool
    func showPrivacyOptions() async -> Bool
    func isAdFree() async -> Bool
    // Allow app to update ad-free state after purchases
    @MainActor func setAdFree(_ value: Bool)
}

public extension AdServiceProtocol {
    func prepareForAdRequests() async -> Bool { true }
    func showRewardedInterstitial(onReward: @MainActor @Sendable () -> Void) async -> Bool { false }
    func isPrivacyOptionsRequired() async -> Bool { false }
    func showPrivacyOptions() async -> Bool { false }

    @MainActor func setAdFree(_ value: Bool) {}
}

@Observable
@MainActor
public final class DummyAdService: AdServiceProtocol {
    public var isBannerVisible = false
    private var adFree = false
    
    public init() {}

    public func prepareForAdRequests() async -> Bool {
        !adFree
    }
    
    public func showBanner() async {
        guard !adFree else { return }
        isBannerVisible = true
    }
    
    public func hideBanner() async {
        isBannerVisible = false
    }
    
    public func showInterstitial() async -> Bool {
        guard !adFree else { return false }
        try? await Task.sleep(for: .seconds(0.5))
        return true
    }
    
    public func showRewarded(onReward: @MainActor @Sendable () -> Void) async -> Bool {
        guard !adFree else { return false }
        try? await Task.sleep(for: .seconds(0.5))
        onReward()
        return true
    }

    public func showRewardedInterstitial(onReward: @MainActor @Sendable () -> Void) async -> Bool {
        guard !adFree else { return false }
        try? await Task.sleep(for: .seconds(0.5))
        onReward()
        return true
    }
    
    public func isAdFree() async -> Bool {
        adFree
    }
    
    public func setAdFree(_ value: Bool) {
        adFree = value
        if value {
            isBannerVisible = false
        }
    }
}
