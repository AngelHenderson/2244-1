import Foundation
import GameCore
import GameServices

@MainActor
public final class AchievementEvaluator {
    private let achievementStore: AchievementStore
    private var currentGameSnapshot = GameSnapshot()
    private var sessionStartTime = Date()
    private var totalGamesPlayed: Int = 0
    private var mergesThisTurn: Int = 0
    private var consecutiveMergeTurns: Int = 0
    private var totalMerges: Int = 0
    private var maxChainThisGame: Int = 0
    private var movesThisGame: Int = 0
    private var combo610Total: Int = 0
    private var combo1115Total: Int = 0
    private var combo1620Total: Int = 0
    private var combo2130Total: Int = 0
    private let combo610Key = "combo6to10Total"
    private let combo1115Key = "combo11to15Total"
    private let combo1620Key = "combo16to20Total"
    private let combo2130Key = "combo21to30Total"
    private let defaults = UserDefaults.standard
    public init(achievementStore: AchievementStore) {
        self.achievementStore = achievementStore
        totalGamesPlayed = UserDefaults.standard.integer(forKey: "totalGamesPlayed")
        combo610Total = defaults.integer(forKey: combo610Key)
        combo1115Total = defaults.integer(forKey: combo1115Key)
        combo1620Total = defaults.integer(forKey: combo1620Key)
        combo2130Total = defaults.integer(forKey: combo2130Key)
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
    }
    
    public func onGameStart(state: GameState) {
        sessionStartTime = Date()
        movesThisGame = 0
        totalMerges = 0
        maxChainThisGame = 0
        mergesThisTurn = 0
        consecutiveMergeTurns = 0
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
    }
    
    public func onChainCommitted(chain: [Position], state: GameState, resultingTileValue: Int?) {
        movesThisGame += 1
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        
        if chain.count > 1 {
            mergesThisTurn = 1
            totalMerges += 1
            maxChainThisGame = max(maxChainThisGame, chain.count)
            updateComboProgress(for: chain.count)
            
            if mergesThisTurn > 0 {
                consecutiveMergeTurns += 1
            }
            
            if let firstPos = chain.first {
                let isCorner = (firstPos.row == 0 || firstPos.row == 5) && 
                              (firstPos.col == 0 || firstPos.col == 5)
                if isCorner {
                    currentGameSnapshot.merge_in_corner += 1
                }
                
                let isEdge = firstPos.row == 0 || firstPos.row == 5 || 
                            firstPos.col == 0 || firstPos.col == 5
                if isEdge {
                    currentGameSnapshot.merge_on_edge += 1
                }
            }
            
            if movesThisGame <= 10 {
                currentGameSnapshot.merges_first_10 += 1
            }
        } else {
            if mergesThisTurn == 0 {
                consecutiveMergeTurns = 0
            }
            mergesThisTurn = 0
        }
        
        var snapshot = GameSnapshot()
        snapshot.games_played = totalGamesPlayed
        snapshot.merges_total = totalMerges
        snapshot.merges_in_single_turn = mergesThisTurn
        snapshot.max_chain = maxChainThisGame
        snapshot.score = state.score
        snapshot.moves = movesThisGame
        snapshot.max_tile = state.highestTile
        snapshot.consecutive_merge_turns = consecutiveMergeTurns
        snapshot.merge_in_corner = currentGameSnapshot.merge_in_corner
        snapshot.merge_on_edge = currentGameSnapshot.merge_on_edge
        snapshot.merges_first_10 = currentGameSnapshot.merges_first_10
        snapshot.total_moves = UserDefaults.standard.integer(forKey: "totalMoves") + 1
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        
        if state.highestTile >= 2244 {
            snapshot.reached_core_target = true
        }
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    
    public func onGameEnd(state: GameState, won: Bool) {
        totalGamesPlayed += 1
        UserDefaults.standard.set(totalGamesPlayed, forKey: "totalGamesPlayed")
        
        let elapsedMinutes = Int(Date().timeIntervalSince(sessionStartTime) / 60)
        
        var snapshot = GameSnapshot()
        snapshot.games_played = totalGamesPlayed
        snapshot.merges_total = totalMerges
        snapshot.max_chain = maxChainThisGame
        snapshot.score = state.score
        snapshot.moves = movesThisGame
        snapshot.max_tile = state.highestTile
        snapshot.win = won
        snapshot.run_completed = true
        snapshot.run_minutes = elapsedMinutes
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        snapshot.reached_core_target = state.highestTile >= 2244
        
        var freeSlots = 0
        for row in 0..<6 {
            for col in 0..<6 {
                let position = Position(row: row, col: col)
                if state.board[position] == nil {
                    freeSlots += 1
                }
            }
        }
        snapshot.free_slots_end = freeSlots
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    
    public func onPowerUpUsed(type: String) {
        currentGameSnapshot.powerups_used += 1
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        
        var snapshot = currentGameSnapshot
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        snapshot.games_played = totalGamesPlayed
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    
    public func onUndoUsed() {
        currentGameSnapshot.undo_used += 1
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        
        var snapshot = currentGameSnapshot
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        snapshot.games_played = totalGamesPlayed
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    private func updateComboProgress(for chainCount: Int) {
        if (6...10).contains(chainCount) {
            combo610Total += 1
            defaults.set(combo610Total, forKey: combo610Key)
        }
        if (11...15).contains(chainCount) {
            combo1115Total += 1
            defaults.set(combo1115Total, forKey: combo1115Key)
        }
        if (16...20).contains(chainCount) {
            combo1620Total += 1
            defaults.set(combo1620Total, forKey: combo1620Key)
        }
        if (21...30).contains(chainCount) {
            combo2130Total += 1
            defaults.set(combo2130Total, forKey: combo2130Key)
        }
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
    }
}