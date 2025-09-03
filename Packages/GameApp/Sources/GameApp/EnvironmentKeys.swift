import SwiftUI
import GameServices

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
    
    // Theme toggles can be extended to remote config injection in future
    var colorBlindMode: Bool {
        get { self[ColorBlindModeKey.self] }
        set { self[ColorBlindModeKey.self] = newValue }
    }
}


public struct ColorBlindModeKey: EnvironmentKey {
    public static var defaultValue: Bool {
        UserDefaults.standard.bool(forKey: "colorBlindMode")
    }
}

