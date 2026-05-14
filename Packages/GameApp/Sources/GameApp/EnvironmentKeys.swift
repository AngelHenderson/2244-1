import SwiftUI
import GameCore

// Default implementations for environment values
private struct DefaultGameStore: Sendable {
    @MainActor
    static func make() -> GameStore {
        GameStore()
    }
}

private struct DefaultPurchaseService: Sendable {
    @MainActor
    static func make() -> PurchaseService {
        PurchaseService()
    }
}

private struct DefaultHapticsService: Sendable {
    @MainActor
    static func make() -> HapticsService {
        HapticsService()
    }
}

public struct GameStoreKey: EnvironmentKey {
    nonisolated public static var defaultValue: GameStore {
        MainActor.assumeIsolated {
            DefaultGameStore.make()
        }
    }
}

public struct AdServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: any AdServiceProtocol {
        MainActor.assumeIsolated {
            DummyAdService()
        }
    }
}

public struct PurchaseServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: PurchaseService {
        MainActor.assumeIsolated {
            DefaultPurchaseService.make()
        }
    }
}

public struct HapticsServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: HapticsService {
        MainActor.assumeIsolated {
            DefaultHapticsService.make()
        }
    }
}

public struct ReportServiceKey: EnvironmentKey {
    public typealias Value = any ReportServiceProtocol
    public static let defaultValue: any ReportServiceProtocol = NoopReportService()
}

/// Optional ledger reference. Views can use it to record reward grants;
/// when nil (e.g. in previews) callers fall back to direct mutation.
public struct RewardLedgerOptionalKey: EnvironmentKey {
    public static let defaultValue: RewardLedgerStore? = nil
}

public extension EnvironmentValues {
    var gameStore: GameStore {
        get { self[GameStoreKey.self] }
        set { self[GameStoreKey.self] = newValue }
    }
    
    var adService: any AdServiceProtocol {
        get { self[AdServiceKey.self] }
        set { self[AdServiceKey.self] = newValue }
    }
    
    var purchaseService: PurchaseService {
        get { self[PurchaseServiceKey.self] }
        set { self[PurchaseServiceKey.self] = newValue }
    }
    
    var hapticsService: HapticsService {
        get { self[HapticsServiceKey.self] }
        set { self[HapticsServiceKey.self] = newValue }
    }

    var reportService: any ReportServiceProtocol {
        get { self[ReportServiceKey.self] }
        set { self[ReportServiceKey.self] = newValue }
    }

    var rewardLedgerOptional: RewardLedgerStore? {
        get { self[RewardLedgerOptionalKey.self] }
        set { self[RewardLedgerOptionalKey.self] = newValue }
    }
    
    // Theme toggles can be extended to remote config injection in future
    var colorBlindMode: Bool {
        get { self[ColorBlindModeKey.self] }
        set { self[ColorBlindModeKey.self] = newValue }
    }

    var spinWheelState: SpinWheelState {
        get { self[SpinWheelStateKey.self] }
        set { self[SpinWheelStateKey.self] = newValue }
    }

    var seasonHistoryStore: SeasonHistoryStore {
        get { self[SeasonHistoryStoreKey.self] }
        set { self[SeasonHistoryStoreKey.self] = newValue }
    }
}


public struct ColorBlindModeKey: EnvironmentKey {
    public static var defaultValue: Bool {
        UserDefaults.standard.bool(forKey: "colorBlindMode")
    }
}

private struct DefaultSpinWheelState: Sendable {
    @MainActor
    static func make() -> SpinWheelState {
        SpinWheelState()
    }
}

public struct SpinWheelStateKey: EnvironmentKey {
    nonisolated public static var defaultValue: SpinWheelState {
        MainActor.assumeIsolated {
            DefaultSpinWheelState.make()
        }
    }
}

private struct DefaultSeasonHistoryStore: Sendable {
    @MainActor
    static func make() -> SeasonHistoryStore {
        SeasonHistoryStore()
    }
}

public struct SeasonHistoryStoreKey: EnvironmentKey {
    nonisolated public static var defaultValue: SeasonHistoryStore {
        MainActor.assumeIsolated {
            DefaultSeasonHistoryStore.make()
        }
    }
}

private struct DefaultSocialFeedPublisher: Sendable {
    @MainActor
    static func make() -> SocialFeedPublisher {
        SocialFeedPublisher(socialService: MockSocialService())
    }
}

public struct SocialFeedPublisherKey: EnvironmentKey {
    nonisolated public static var defaultValue: SocialFeedPublisher {
        MainActor.assumeIsolated {
            DefaultSocialFeedPublisher.make()
        }
    }
}

public extension EnvironmentValues {
    var socialFeedPublisher: SocialFeedPublisher {
        get { self[SocialFeedPublisherKey.self] }
        set { self[SocialFeedPublisherKey.self] = newValue }
    }
}
