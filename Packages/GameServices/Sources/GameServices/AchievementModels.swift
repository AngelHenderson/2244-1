import Foundation

public struct AchievementDef: Codable, Identifiable, Hashable {
    public struct Condition: Codable, Hashable {
        public let field: String
        public let op: String
        public let value: Double?
    }
    
    public struct Rewards: Codable, Hashable, Sendable {
        public let gems: Int?
        public let spins: Int?
        public let hammers: Int?
        public let magnets: Int?
        public let swaps: Int?
        public let boost2x: Int?
        public let boost3x: Int?
        public let boost4x: Int?
        
        public init(
            gems: Int? = nil,
            spins: Int? = nil,
            hammers: Int? = nil,
            magnets: Int? = nil,
            swaps: Int? = nil,
            boost2x: Int? = nil,
            boost3x: Int? = nil,
            boost4x: Int? = nil
        ) {
            self.gems = gems
            self.spins = spins
            self.hammers = hammers
            self.magnets = magnets
            self.swaps = swaps
            self.boost2x = boost2x
            self.boost3x = boost3x
            self.boost4x = boost4x
        }
    }
    
    public let id: String
    public let gcIdentifier: String?
    public let title: String
    public let description: String
    public let category: String
    public let rewards: Rewards?
    public let hidden: Bool
    public let conditionExpr: String
    public let conditions: [Condition]
}

public extension AchievementDef.Rewards {
    struct Entry: Hashable {
        public enum Kind: Hashable {
            case gems, spins, hammers, magnets, swaps, boost2x, boost3x, boost4x
        }
        
        public let kind: Kind
        public let amount: Int
        
        public init(kind: Kind, amount: Int) {
            self.kind = kind
            self.amount = amount
        }
    }
    
    var entries: [Entry] {
        var result: [Entry] = []
        func append(_ kind: Entry.Kind, value: Int?) {
            if let value, value > 0 {
                result.append(Entry(kind: kind, amount: value))
            }
        }
        append(.gems, value: gems)
        append(.spins, value: spins)
        append(.hammers, value: hammers)
        append(.magnets, value: magnets)
        append(.swaps, value: swaps)
        append(.boost2x, value: boost2x)
        append(.boost3x, value: boost3x)
        append(.boost4x, value: boost4x)
        return result
    }
    
    func merged(with other: AchievementDef.Rewards) -> AchievementDef.Rewards {
        AchievementDef.Rewards(
            gems: sum(gems, other.gems),
            spins: sum(spins, other.spins),
            hammers: sum(hammers, other.hammers),
            magnets: sum(magnets, other.magnets),
            swaps: sum(swaps, other.swaps),
            boost2x: sum(boost2x, other.boost2x),
            boost3x: sum(boost3x, other.boost3x),
            boost4x: sum(boost4x, other.boost4x)
        )
    }
    
    private func sum(_ a: Int?, _ b: Int?) -> Int? {
        switch (a, b) {
        case let (x?, y?): return x + y
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }
}

public struct GameSnapshot: Sendable, Codable {
    public var games_played: Int = 0
    public var merges_total: Int = 0
    public var merges_in_single_turn: Int = 0
    public var max_chain: Int = 0
    public var score: Int = 0
    public var merge_in_corner: Int = 0
    public var merge_on_edge: Int = 0
    public var merges_first_10: Int = 0
    public var reached_core_target: Bool = false
    public var moves: Int = 0
    public var undo_used: Int = 0
    public var powerups_used: Int = 0
    public var session_pauses: Int = 0
    public var highest_tile_corner_moves: Int = 0
    public var free_slots_end: Int = 0
    public var invalid_moves: Int = 0
    public var run_completed: Bool = false
    public var consecutive_merge_turns: Int = 0
    
    public var score_60s: Int = 0
    public var score_180s: Int = 0
    public var max_tile_120s: Int = 0
    public var merges_10s: Int = 0
    public var valid_moves_30s: Int = 0
    public var seconds_elapsed: Int = 0
    public var seconds_left: Int = 0
    public var timed_mode: Bool = false
    public var max_chain_60s: Int = 0
    public var max_tile_300s: Int = 0
    
    public var daily_completed: Int = 0
    public var daily_streak: Int = 0
    public var weekend_back_to_back: Bool = false
    public var prev_losing_streak: Int = 0
    public var play_streak_days: Int = 0
    
    public var endless_milestone: Int = 0
    public var low_free_slots_turns: Int = 0
    public var run_minutes: Int = 0
    
    public var monotonic_row_or_col_moves: Int = 0
    public var top3_same_quadrant: Bool = false
    public var edge_descending_no_gaps: Bool = false
    public var merges_from_center: Int = 0
    public var square_2x2_identical_value: Int = 0
    
    public var different_powerups_used: Int = 0
    public var powerups_unused: Int = 0
    public var free_slots_at_booster_use: Int = 99
    
    public var moved_right: Int = 0
    public var moved_left: Int = 0
    public var moved_down: Int = 0
    public var board_monotonic_end: Bool = false
    public var made_2244_square: Bool = false
    
    public var max_tile: Int = 0
    public var win: Bool = false
    public var total_moves: Int = 0
    public var combo610Total: Int = 0
    public var combo1115Total: Int = 0
    public var combo1620Total: Int = 0
    public var combo2130Total: Int = 0
    public var merged_tiles_total: Int = 0
    public var hammer_uses_total: Int = 0
    public var swap_uses_total: Int = 0
    public var magnet_uses_total: Int = 0
    public var spin_uses_total: Int = 0
    public var survive_moves_total: Int = 0
    public var challenge_creations_total: Int = 0
    public var play_minutes_total: Int = 0
    public var infinity_creations_total: Int = 0
    public var boost2x_uses_total: Int = 0
    public var boost3x_uses_total: Int = 0
    public var boost4x_uses_total: Int = 0
    public var spin_purchases_total: Int = 0

    public init() {}
}