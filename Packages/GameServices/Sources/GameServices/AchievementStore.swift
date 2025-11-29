import SwiftUI
import Observation
import GameKit

@MainActor
@Observable
public final class AchievementStore {
    public struct UnlockState: Hashable, Codable {
        public var unlocked: Bool
        public var unlockedAt: Date?
        public var claimed: Bool
        
        public var isClaimable: Bool {
            unlocked && !claimed
        }
    }
    
    public struct ComboTierDisplay: Sendable {
        public let milestone: Int
        public let level: Int
        public let title: String
        public let description: String
        public let categoryLabel: String
        public let rewards: AchievementDef.Rewards
    }
    
    // MARK: - Tile Progression System
    /// The AlphaMag tiers for progressive tile achievement
    public static let tileTiers: [(suffix: String, label: String, value: Double)] = [
        ("M", "1M", 1_000_000),
        ("B", "1B", 1_000_000_000),
        ("a", "1a", 1e12),
        ("b", "1b", 1e15),
        ("c", "1c", 1e18),
        ("d", "1d", 1e21),
        ("e", "1e", 1e24),
        ("f", "1f", 1e27),
        ("g", "1g", 1e30),
        ("h", "1h", 1e33),
        ("i", "1i", 1e36),
        ("j", "1j", 1e39),
        ("k", "1k", 1e42),
        ("l", "1l", 1e45),
        ("m", "1m", 1e48),
        ("n", "1n", 1e51),
        ("o", "1o", 1e54),
        ("p", "1p", 1e57),
        ("q", "1q", 1e60),
        ("r", "1r", 1e63),
        ("s", "1s", 1e66),
        ("t", "1t", 1e69),
        ("u", "1u", 1e72),
        ("v", "1v", 1e75),
        ("w", "1w", 1e78),
        ("x", "1x", 1e81),
        ("y", "1y", 1e84),
        ("z", "1z", 1e87),
        ("aa", "1aa", 1e90),
        ("ab", "1ab", 1e93),
        ("az", "1az", 1e165),
        ("ba", "1ba", 1e168),
        ("bx", "1bx", 1e237),
        ("by", "1by", 1e240),
        ("bz", "1bz", 1e243),
        ("∞", "∞", Double.infinity)
    ]
    
    // MARK: - Moves Progression System
    public static let movesTiers: [(label: String, value: Double)] = [
        ("25", 25),
        ("50", 50),
        ("100", 100),
        ("200", 200),
        ("500", 500),
        ("1K", 1000),
        ("2K", 2000),
        ("3K", 3000),
        ("5K", 5000),
        ("10K", 10000),
        ("30K", 30000),
        ("50K", 50000),
        ("100K", 100000),
        ("200K", 200000),
        ("300K", 300000),
        ("500K", 500000),
        ("750K", 750000),
        ("1M", 1000000)
    ]
    
    private struct ComboTierDefinition {
        let milestone: Int
        let categoryLabel: String
        let rewards: AchievementDef.Rewards
    }
    
    private static let combo610Tiers: [ComboTierDefinition] = [
        .init(milestone: 10, categoryLabel: "10. Good Combo", rewards: .init(gems: 50)),
        .init(milestone: 25, categoryLabel: "25. Great Combo", rewards: .init(gems: 75)),
        .init(milestone: 50, categoryLabel: "50. Amazing Combo", rewards: .init(gems: 100, hammers: 1)),
        .init(milestone: 100, categoryLabel: "100. Glorious Combo", rewards: .init(gems: 100, spins: 1, swaps: 1)),
        .init(milestone: 200, categoryLabel: "200. Combo Master", rewards: .init(gems: 150, hammers: 1, magnets: 1)),
        .init(milestone: 300, categoryLabel: "300. Good Combo Master", rewards: .init(gems: 200, spins: 2)),
        .init(milestone: 400, categoryLabel: "400. Great Combo Master", rewards: .init(gems: 500)),
        .init(milestone: 500, categoryLabel: "500. Glorious Combo Master", rewards: .init(gems: 300, spins: 1, hammers: 1, magnets: 1)),
        .init(milestone: 600, categoryLabel: "600. Unbelievable Combo", rewards: .init(gems: 400, spins: 2, magnets: 1)),
        .init(milestone: 750, categoryLabel: "750. 750 IQ Combo Master", rewards: .init(gems: 1000, hammers: 1, swaps: 2)),
        .init(
            milestone: 1000,
            categoryLabel: "1000. 1000 IQ Combo Master",
            rewards: .init(gems: 1000, spins: 1, boost4x: 1)
        )
    ]
    
    private static let combo1115Tiers: [ComboTierDefinition] = [
        .init(milestone: 10, categoryLabel: "10. Good Combo", rewards: .init(gems: 100)),
        .init(milestone: 25, categoryLabel: "25. Great Combo", rewards: .init(gems: 75, magnets: 1)),
        .init(milestone: 50, categoryLabel: "50. Amazing Combo", rewards: .init(hammers: 1, boost2x: 1)),
        .init(milestone: 100, categoryLabel: "100. Glorious Combo", rewards: .init(gems: 250, spins: 1)),
        .init(milestone: 200, categoryLabel: "200. Combo Master", rewards: .init(gems: 300, swaps: 1, boost3x: 1)),
        .init(milestone: 300, categoryLabel: "300. Good Combo Master", rewards: .init(gems: 200, boost2x: 1, boost4x: 1)),
        .init(milestone: 400, categoryLabel: "400. Great Combo Master", rewards: .init(gems: 500, swaps: 1)),
        .init(milestone: 500, categoryLabel: "500. Glorious Combo Master", rewards: .init(gems: 750, spins: 1, magnets: 1)),
        .init(milestone: 600, categoryLabel: "600. Unbelievable Combo", rewards: .init(spins: 2, magnets: 1, boost2x: 1)),
        .init(milestone: 750, categoryLabel: "750. 750 IQ Combo Master", rewards: .init(gems: 500, hammers: 1, magnets: 1, swaps: 1)),
        .init(milestone: 1000, categoryLabel: "1000. 1000 IQ Combo Master", rewards: .init(gems: 800, spins: 1, hammers: 1, boost4x: 1))
    ]
    
    /// Current tier index for the moves progression achievement (persisted)
    public var movesProgressionTier: Int {
        didSet {
            defaults.set(movesProgressionTier, forKey: "movesProgressionTier")
            // Reset unlock state when tier advances
            unlocks["moves_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    /// Get current moves tier info
    public var currentMovesTier: (label: String, value: Double) {
        let index = min(movesProgressionTier, Self.movesTiers.count - 1)
        return Self.movesTiers[index]
    }
    
    /// Check if moves progression is at max tier
    public var isMovesProgressionMaxed: Bool {
        movesProgressionTier >= Self.movesTiers.count - 1
    }
    
    /// Combo 6-10 tier index (persisted)
    public var combo610Tier: Int {
        didSet {
            defaults.set(combo610Tier, forKey: "combo610Tier")
            unlocks["combo_6_10"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentCombo610Tier: ComboTierDefinition {
        let index = min(combo610Tier, Self.combo610Tiers.count - 1)
        return Self.combo610Tiers[index]
    }
    
    public var combo610Display: ComboTierDisplay {
        let tier = currentCombo610Tier
        return makeComboDisplay(
            rangeLabel: "6-10",
            tier: tier,
            levelIndex: combo610Tier,
            maxCount: Self.combo610Tiers.count,
            isMaxed: isCombo610Maxed
        )
    }
    
    public var isCombo610Maxed: Bool {
        combo610Tier >= Self.combo610Tiers.count - 1
    }
    
    /// Combo 11-15 tier index (persisted)
    public var combo1115Tier: Int {
        didSet {
            defaults.set(combo1115Tier, forKey: "combo1115Tier")
            unlocks["combo_11_15"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentCombo1115Tier: ComboTierDefinition {
        let index = min(combo1115Tier, Self.combo1115Tiers.count - 1)
        return Self.combo1115Tiers[index]
    }
    
    public var combo1115Display: ComboTierDisplay {
        let tier = currentCombo1115Tier
        return makeComboDisplay(
            rangeLabel: "11-15",
            tier: tier,
            levelIndex: combo1115Tier,
            maxCount: Self.combo1115Tiers.count,
            isMaxed: isCombo1115Maxed
        )
    }
    
    public var isCombo1115Maxed: Bool {
        combo1115Tier >= Self.combo1115Tiers.count - 1
    }
    
    private func makeComboDisplay(
        rangeLabel: String,
        tier: ComboTierDefinition,
        levelIndex: Int,
        maxCount: Int,
        isMaxed: Bool
    ) -> ComboTierDisplay {
        let clampedIndex = min(levelIndex, maxCount - 1)
        let level = clampedIndex + 1
        let description: String
        if isMaxed {
            description = "You've reached the final combo milestone for \(rangeLabel) tiles. Claim your mastery reward."
        } else {
            description = "Trigger combos of \(rangeLabel) tiles \(tier.milestone) times across all games to unlock the next level."
        }
        let title = "Level \(level): \(tier.milestone) combos"
        return ComboTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )
    }
    
    /// Current tier index for the tile progression achievement (persisted)
    public var tileProgressionTier: Int {
        didSet {
            defaults.set(tileProgressionTier, forKey: "tileProgressionTier")
            // Reset unlock state when tier advances
            unlocks["tile_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    /// Get current tile tier info
    public var currentTileTier: (suffix: String, label: String, value: Double) {
        let index = min(tileProgressionTier, Self.tileTiers.count - 1)
        return Self.tileTiers[index]
    }
    
    /// Check if tile progression is at max tier
    public var isTileProgressionMaxed: Bool {
        tileProgressionTier >= Self.tileTiers.count - 1
    }
    
    public private(set) var catalog: [AchievementDef] = []
    public private(set) var unlocks: [String: UnlockState] = [:]
    public private(set) var lastEvaluatedSnapshot: GameSnapshot?
    
    private let gc = GameCenterManager.shared
    public var onReward: (@MainActor (AchievementDef.Rewards) -> Void)?
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.tileProgressionTier = defaults.integer(forKey: "tileProgressionTier")
        self.movesProgressionTier = defaults.integer(forKey: "movesProgressionTier")
        self.combo610Tier = defaults.integer(forKey: "combo610Tier")
        self.combo1115Tier = defaults.integer(forKey: "combo1115Tier")
        loadUnlocks()
    }
    
    public func loadCatalogFromBundle(named filename: String = "2244_achievements", in bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw NSError(domain: "AchievementStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "JSON '\(filename).json' not found in bundle."])
        }
        try loadCatalog(from: url)
    }
    
    public func loadCatalog(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        catalog = try decoder.decode([AchievementDef].self, from: data)
        
        for def in catalog where unlocks[def.id] == nil {
            unlocks[def.id] = .init(unlocked: false, unlockedAt: nil, claimed: false)
        }
    }
    
    public func syncWithGameCenter() async {
        let existing = await gc.loadExistingAchievements()
        for gk in existing where gk.percentComplete >= 100.0 {
            if let idx = catalog.firstIndex(where: { ($0.gcIdentifier ?? $0.id) == gk.identifier }) {
                let id = catalog[idx].id
                let alreadyClaimed = unlocks[id]?.claimed ?? true
                unlocks[id] = .init(unlocked: true, unlockedAt: gk.lastReportedDate, claimed: alreadyClaimed)
            }
        }
        saveUnlocks()
    }
    
    public func evaluate(snapshot: GameSnapshot, reportToGameCenter: Bool = true) async {
        lastEvaluatedSnapshot = snapshot
        var didUnlock = false
        for def in catalog {
            guard unlocks[def.id]?.unlocked != true else { continue }
            
            // Special handling for tile progression achievement
            if def.id == "tile_progression" {
                let targetValue = currentTileTier.value
                if Double(snapshot.max_tile) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            // Special handling for moves progression achievement
            if def.id == "moves_progression" {
                let targetValue = currentMovesTier.value
                if Double(snapshot.total_moves) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "combo_6_10" {
                let targetValue = Double(currentCombo610Tier.milestone)
                if Double(snapshot.combo610Total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "combo_11_15" {
                let targetValue = Double(currentCombo1115Tier.milestone)
                if Double(snapshot.combo1115Total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if matches(def: def, snapshot: snapshot) {
                unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                didUnlock = true
                
                if reportToGameCenter,
                   GKLocalPlayer.local.isAuthenticated {
                    let gcId = def.gcIdentifier ?? def.id
                    await gc.reportUnlock(gcIdentifier: gcId)
                }
            }
        }
        
        if didUnlock {
            saveUnlocks()
        }
    }
    
    public func claim(definition: AchievementDef) {
        guard var state = unlocks[definition.id], state.isClaimable else { return }
        
        // Special handling for tile progression achievement
        if definition.id == "tile_progression" {
            // Grant rewards
            if let rewards = definition.rewards {
                if let gems = rewards.gems, gems > 0 {
                    grantGemsDirectly(gems)
                }
                onReward?(rewards)
            }
            
            // Advance to next tier (don't mark as claimed, reset for next tier)
            if !isTileProgressionMaxed {
                tileProgressionTier += 1
                // State is already reset in the didSet of tileProgressionTier
            } else {
                // Max tier reached - mark as fully claimed
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        // Special handling for moves progression achievement
        if definition.id == "moves_progression" {
            // Grant rewards
            if let rewards = definition.rewards {
                if let gems = rewards.gems, gems > 0 {
                    grantGemsDirectly(gems)
                }
                onReward?(rewards)
            }
            
            // Advance to next tier (don't mark as claimed, reset for next tier)
            if !isMovesProgressionMaxed {
                movesProgressionTier += 1
                // State is already reset in the didSet of movesProgressionTier
            } else {
                // Max tier reached - mark as fully claimed
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "combo_6_10" {
            let rewards = combo610Display.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isCombo610Maxed {
                combo610Tier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "combo_11_15" {
            let rewards = combo1115Display.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isCombo1115Maxed {
                combo1115Tier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        // Standard achievement claim
        state.claimed = true
        unlocks[definition.id] = state
        saveUnlocks()
        
        guard let rewards = definition.rewards else { return }
        
        // Always grant gems directly so UI and wallet stay in sync
        if let gems = rewards.gems, gems > 0 {
            grantGemsDirectly(gems)
        }
        
        // Call reward callback for power-ups, spins, etc.
        onReward?(rewards)
    }
    
    public var claimableCount: Int {
        unlocks.values.filter { $0.isClaimable }.count
    }
    
    private func matches(def: AchievementDef, snapshot s: GameSnapshot) -> Bool {
        def.conditions.allSatisfy { cond in
            let lhs = value(for: cond.field, in: s)
            let rhs = cond.value ?? 0.0
            switch cond.op {
            case "==": return lhs == rhs
            case "!=": return lhs != rhs
            case ">":  return lhs > rhs
            case ">=": return lhs >= rhs
            case "<":  return lhs < rhs
            case "<=": return lhs <= rhs
            default:   return false
            }
        }
    }
    
    private func value(for field: String, in s: GameSnapshot) -> Double {
        func b(_ flag: Bool) -> Double { flag ? 1 : 0 }
        
        switch field {
        case "games_played": return .init(s.games_played)
        case "merges_total": return .init(s.merges_total)
        case "merges_in_single_turn": return .init(s.merges_in_single_turn)
        case "max_chain": return .init(s.max_chain)
        case "score": return .init(s.score)
        case "merge_in_corner": return .init(s.merge_in_corner)
        case "merge_on_edge": return .init(s.merge_on_edge)
        case "merges_first_10": return .init(s.merges_first_10)
        case "reached_core_target": return b(s.reached_core_target)
        case "moves": return .init(s.moves)
        case "total_moves": return .init(s.total_moves)
        case "combo_6_10_total": return .init(s.combo610Total)
        case "combo_11_15_total": return .init(s.combo1115Total)
        case "undo_used": return .init(s.undo_used)
        case "powerups_used": return .init(s.powerups_used)
        case "session_pauses": return .init(s.session_pauses)
        case "highest_tile_corner_moves": return .init(s.highest_tile_corner_moves)
        case "free_slots_end": return .init(s.free_slots_end)
        case "invalid_moves": return .init(s.invalid_moves)
        case "run_completed": return b(s.run_completed)
        case "consecutive_merge_turns": return .init(s.consecutive_merge_turns)
        case "score_60s": return .init(s.score_60s)
        case "score_180s": return .init(s.score_180s)
        case "max_tile_120s": return .init(s.max_tile_120s)
        case "merges_10s": return .init(s.merges_10s)
        case "valid_moves_30s": return .init(s.valid_moves_30s)
        case "seconds_elapsed": return .init(s.seconds_elapsed)
        case "seconds_left": return .init(s.seconds_left)
        case "timed_mode": return b(s.timed_mode)
        case "max_chain_60s": return .init(s.max_chain_60s)
        case "max_tile_300s": return .init(s.max_tile_300s)
        case "daily_completed": return .init(s.daily_completed)
        case "daily_streak": return .init(s.daily_streak)
        case "weekend_back_to_back": return b(s.weekend_back_to_back)
        case "prev_losing_streak": return .init(s.prev_losing_streak)
        case "play_streak_days": return .init(s.play_streak_days)
        case "endless_milestone": return .init(s.endless_milestone)
        case "low_free_slots_turns": return .init(s.low_free_slots_turns)
        case "run_minutes": return .init(s.run_minutes)
        case "monotonic_row_or_col_moves": return .init(s.monotonic_row_or_col_moves)
        case "top3_same_quadrant": return b(s.top3_same_quadrant)
        case "edge_descending_no_gaps": return b(s.edge_descending_no_gaps)
        case "merges_from_center": return .init(s.merges_from_center)
        case "square_2x2_identical_value": return .init(s.square_2x2_identical_value)
        case "different_powerups_used": return .init(s.different_powerups_used)
        case "powerups_unused": return .init(s.powerups_unused)
        case "free_slots_at_booster_use": return .init(s.free_slots_at_booster_use)
        case "moved_right": return .init(s.moved_right)
        case "moved_left": return .init(s.moved_left)
        case "moved_down": return .init(s.moved_down)
        case "board_monotonic_end": return b(s.board_monotonic_end)
        case "made_2244_square": return b(s.made_2244_square)
        case "max_tile": return .init(s.max_tile)
        case "win": return b(s.win)
        default:
            #if DEBUG
            print("⚠️ Unknown telemetry field: \(field) -> treating as 0")
            #endif
            return 0.0
        }
    }
    
    private func grantGemsDirectly(_ gems: Int) {
        let currentGems = defaults.integer(forKey: "coins")
        let newGems = currentGems + gems
        defaults.set(newGems, forKey: "coins")
        
        NotificationCenter.default.post(
            name: Notification.Name("GemsDidChange"),
            object: nil,
            userInfo: ["newBalance": newGems, "added": gems]
        )
    }
    
    private func saveUnlocks() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(unlocks) {
            defaults.set(data, forKey: "achievementUnlocks_v2")
            defaults.synchronize()
            print("💾 AchievementStore: Saved \(unlocks.count) unlocks")
        } else {
            print("❌ AchievementStore: Failed to encode unlocks")
        }
    }
    
    private func loadUnlocks() {
        if let data = defaults.data(forKey: "achievementUnlocks_v2") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                unlocks = try decoder.decode([String: UnlockState].self, from: data)
                print("📂 AchievementStore: Loaded \(unlocks.count) unlocks")
            } catch {
                print("❌ AchievementStore: Failed to decode unlocks: \(error)")
            }
        } else {
            // Fallback to legacy key if v2 missing
            if let data = defaults.data(forKey: "achievementUnlocks") {
                if let saved = try? JSONDecoder().decode([String: UnlockState].self, from: data) {
                    unlocks = saved
                    print("📂 AchievementStore: Migrated \(saved.count) unlocks from legacy")
                    saveUnlocks() // Save to v2 immediately
                }
            } else {
                print("⚠️ AchievementStore: No saved unlocks found")
            }
        }
    }
}
