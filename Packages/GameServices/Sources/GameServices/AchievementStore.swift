import SwiftUI
import Observation
import GameKit

@MainActor
@Observable
public final class AchievementStore {
    public struct UnlockState: Hashable {
        public var unlocked: Bool
        public var unlockedAt: Date?
        public var claimed: Bool
        
        public var isClaimable: Bool {
            unlocked && !claimed
        }
    }
    
    public private(set) var catalog: [AchievementDef] = []
    public private(set) var unlocks: [String: UnlockState] = [:]
    public private(set) var lastEvaluatedSnapshot: GameSnapshot?
    
    private let gc = GameCenterManager.shared
    public var onReward: ((AchievementDef.Rewards) -> Void)?

    public init() {}
    
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
    }
    
    public func evaluate(snapshot: GameSnapshot, reportToGameCenter: Bool = true) async {
        lastEvaluatedSnapshot = snapshot
        for def in catalog {
            guard unlocks[def.id]?.unlocked != true else { continue }
            if matches(def: def, snapshot: snapshot) {
                unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                
                if reportToGameCenter,
                   GKLocalPlayer.local.isAuthenticated {
                    let gcId = def.gcIdentifier ?? def.id
                    await gc.reportUnlock(gcIdentifier: gcId)
                }
            }
        }
    }
    
    public func claim(definition: AchievementDef) {
        guard var state = unlocks[definition.id], state.isClaimable else { return }
        state.claimed = true
        unlocks[definition.id] = state
        if let rewards = definition.rewards {
            onReward?(rewards)
        }
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
}