import Foundation

// MARK: - Protocol
public protocol MonetizationService: Sendable {
    func currentGems() async -> Int
    func buySmallPack() async throws -> Int // returns added gems
    func buyMediumPack() async throws -> Int
    func buyLargePack() async throws -> Int
    func watchAd() async throws -> Int
    func isAdFree() async -> Bool
    func setAdFree(_ value: Bool) async
}

// MARK: - Mock Implementation
public actor MonetizationServiceMock: MonetizationService {
    private var gems: Int
    private var adFree: Bool
    
    public init(initialGems: Int = 305, adFree: Bool = false) {
        self.gems = initialGems
        self.adFree = adFree
    }
    
    public func currentGems() async -> Int {
        return gems
    }
    
    public func buySmallPack() async throws -> Int {
        // Simulate purchase delay
        try await Task.sleep(nanoseconds: 500_000_000)
        let added = 120
        gems += added
        return added
    }
    
    public func buyMediumPack() async throws -> Int {
        try await Task.sleep(nanoseconds: 500_000_000)
        let added = 500
        gems += added
        return added
    }
    
    public func buyLargePack() async throws -> Int {
        try await Task.sleep(nanoseconds: 500_000_000)
        let added = 1200
        gems += added
        return added
    }
    
    public func watchAd() async throws -> Int {
        guard !adFree else {
            throw MonetizationError.adFreeUser
        }
        // Simulate ad viewing time
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let reward = Int.random(in: 50...100)
        gems += reward
        return reward
    }
    
    public func isAdFree() async -> Bool {
        return adFree
    }
    
    public func setAdFree(_ value: Bool) async {
        adFree = value
    }
}

public enum MonetizationError: Error {
    case purchaseFailed
    case adFreeUser
    case networkError
}

// MARK: - Live Implementation (Stub)
public actor LiveMonetizationService: MonetizationService {
    private let defaults = UserDefaults.standard
    
    public init() {}
    
    public func currentGems() async -> Int {
        return defaults.integer(forKey: "coins")
    }
    
    public func buySmallPack() async throws -> Int {
        // TODO: Implement with StoreKit 2
        // For now, just add gems locally
        let current = defaults.integer(forKey: "coins")
        let added = 120
        defaults.set(current + added, forKey: "coins")
        return added
    }
    
    public func buyMediumPack() async throws -> Int {
        let current = defaults.integer(forKey: "coins")
        let added = 500
        defaults.set(current + added, forKey: "coins")
        return added
    }
    
    public func buyLargePack() async throws -> Int {
        let current = defaults.integer(forKey: "coins")
        let added = 1200
        defaults.set(current + added, forKey: "coins")
        return added
    }
    
    public func watchAd() async throws -> Int {
        guard !defaults.bool(forKey: "isAdFreePurchased") else {
            throw MonetizationError.adFreeUser
        }
        // TODO: Implement with AdMob or similar
        // For now, simulate
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let current = defaults.integer(forKey: "coins")
        let reward = 68
        defaults.set(current + reward, forKey: "coins")
        return reward
    }
    
    public func isAdFree() async -> Bool {
        return defaults.bool(forKey: "isAdFreePurchased")
    }
    
    public func setAdFree(_ value: Bool) async {
        defaults.set(value, forKey: "isAdFreePurchased")
    }
}
