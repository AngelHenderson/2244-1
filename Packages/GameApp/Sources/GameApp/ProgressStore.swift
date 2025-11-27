import Foundation

// MARK: - Protocol
public protocol ProgressStore: Sendable {
    func load() async throws -> GameProgress?
    func save(_ progress: GameProgress) async throws
    func clear() async throws
}

// MARK: - UserDefaults Store
public final class UserDefaultsProgressStore: ProgressStore, @unchecked Sendable {
    private let key = "com.yourco.game.progress.v4"
    private let legacyV3Key = "com.yourco.game.progress.v3"
    private let legacyV2Key = "com.yourco.game.progress.v2"
    private let legacyKeys = [
        "bestTile", "bestScore", "coins", "gamesPlayed",
        "theme", "rank", "lastPlayedAt", "highestTile"
    ]
    private let ud: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.game2244.progressStore", qos: .userInitiated)

    public init(suiteName: String? = nil) {
        self.ud = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Synchronous load for initialization (used by GameStore.init)
    public func loadSync() -> GameProgress? {
        return queue.sync {
            return _load()
        }
    }
    
    /// Synchronous save for immediate persistence
    public func saveSync(_ progress: GameProgress) throws {
        try queue.sync {
            try _save(progress)
        }
    }

    // Internal implementation (not thread-safe, must be called within queue)
    private func _load() -> GameProgress? {
        // Try to load v3 format first
        if let data = ud.data(forKey: key),
           let decoded = try? decoder.decode(GameProgress.self, from: data) {
            return decoded
        }
        
        // Try to load legacy v3 payload and migrate to v4
        if let data = ud.data(forKey: legacyV3Key),
           let decoded = try? decoder.decode(GameProgress.self, from: data) {
            try? _save(decoded)
            ud.removeObject(forKey: legacyV3Key)
            return decoded
        }
        
        // Try to load v2 and migrate forward
        if let data = ud.data(forKey: legacyV2Key),
           let v2Progress = try? decoder.decode(GameProgress.self, from: data) {
            // Migrate v2 to v3 by adding new fields with defaults
            let v3Progress = GameProgress(
                highestTile: v2Progress.highestTile,
                bestScore: v2Progress.bestScore,
                gems: v2Progress.gems,
                gamesPlayed: v2Progress.gamesPlayed,
                achievements: v2Progress.achievements,
                theme: v2Progress.theme,
                rank: v2Progress.rank,
                lastUpdatedAt: v2Progress.lastUpdatedAt,
                totalMerges: v2Progress.totalMerges,
                totalTimePlayed: v2Progress.totalTimePlayed,
                unlockedThemes: v2Progress.unlockedThemes,
                completedDailyChallenges: v2Progress.completedDailyChallenges,
                currentWinStreak: v2Progress.currentWinStreak,
                bestWinStreak: v2Progress.bestWinStreak,
                currentSessionState: nil,
                powerUpInventory: ["hammer": 3, "shuffle": 2, "swap": 2, "undo": 1],
                journeyState: GameProgress.JourneyState(),
                sessionTracking: GameProgress.SessionTracking(),
                hasInfinityAchievement: false
            )
            try? _save(v3Progress)
            ud.removeObject(forKey: legacyV2Key)
            return v3Progress
        }
        
        // Attempt legacy migration if v2 blob absent
        if let legacy = loadLegacy() {
            try? _save(legacy)
            clearLegacyKeys()
            return legacy
        }
        
        return nil
    }
    
    private func _save(_ progress: GameProgress) throws {
        var p = progress
        p.version = GameProgress.schemaVersion
        p.lastUpdatedAt = Date()
        let data = try encoder.encode(p)
        ud.set(data, forKey: key)
    }
    
    public func load() async throws -> GameProgress? {
        return queue.sync {
            return _load()
        }
    }

    public func save(_ progress: GameProgress) async throws {
        try queue.sync {
            try _save(progress)
        }
    }
    
    public func clear() async throws {
        queue.sync {
            ud.removeObject(forKey: key)
            ud.removeObject(forKey: legacyV3Key)
            ud.removeObject(forKey: legacyV2Key)
            clearLegacyKeys()
        }
    }

    // MARK: - Legacy Migration
    private func loadLegacy() -> GameProgress? {
        // Check if any legacy data exists
        let hasLegacyData = legacyKeys.contains { key in
            ud.object(forKey: key) != nil
        }
        
        guard hasLegacyData else { return nil }
        
        // Map legacy keys to new progress
        let bestTile = ud.object(forKey: "bestTile") != nil ? ud.integer(forKey: "bestTile") : 0
        let highestTile = ud.object(forKey: "highestTile") != nil ? ud.integer(forKey: "highestTile") : bestTile
        let bestScore = ud.object(forKey: "bestScore") != nil ? ud.integer(forKey: "bestScore") : 0
        let gems = ud.object(forKey: "coins") != nil ? ud.integer(forKey: "coins") : 305
        let gamesPlayed = ud.object(forKey: "gamesPlayed") != nil ? ud.integer(forKey: "gamesPlayed") : 0
        let theme = ud.string(forKey: "theme") ?? "beach"
        let rank = ud.object(forKey: "rank") != nil ? ud.integer(forKey: "rank") : nil
        let lastPlayedAt = ud.object(forKey: "lastPlayedAt") as? Date ?? Date()
        
        // Extract unlocked themes from various possible keys
        var unlockedThemes: Set<String> = ["beach", "aqua"]
        if ud.bool(forKey: "theme_unlocked_desert") { unlockedThemes.insert("desert") }
        if ud.bool(forKey: "theme_unlocked_jungle") { unlockedThemes.insert("jungle") }
        if ud.bool(forKey: "theme_unlocked_space") { unlockedThemes.insert("space") }
        if ud.bool(forKey: "theme_unlocked_neon") { unlockedThemes.insert("neon") }
        
        return GameProgress(
            highestTile: max(highestTile, bestTile),
            bestScore: bestScore,
            gems: gems,
            gamesPlayed: gamesPlayed,
            achievements: [],
            theme: theme,
            rank: rank,
            lastUpdatedAt: lastPlayedAt,
            totalMerges: 0,
            totalTimePlayed: 0,
            unlockedThemes: unlockedThemes,
            completedDailyChallenges: 0,
            currentWinStreak: 0,
            bestWinStreak: 0
        )
    }
    
    private func clearLegacyKeys() {
        for key in legacyKeys {
            ud.removeObject(forKey: key)
        }
        // Also clear theme unlock keys
        ["desert", "jungle", "space", "neon", "retro", "ice"].forEach { theme in
            ud.removeObject(forKey: "theme_unlocked_\(theme)")
        }
    }
}

// MARK: - Remote Store (Stub)
public actor RemoteProgressStore: ProgressStore {
    private var cache: GameProgress?
    
    public init() {}
    
    public func load() async throws -> GameProgress? {
        // TODO: Implement with CloudKit/Firebase
        // For now, return cached value
        return cache
    }
    
    public func save(_ progress: GameProgress) async throws {
        // TODO: Save to CloudKit/Firebase
        cache = progress
    }
    
    public func clear() async throws {
        cache = nil
    }
}
