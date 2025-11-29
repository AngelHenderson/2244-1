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
    private let combo610Key = "combo6to10Total"
    private let defaults = UserDefaults.standard
    public init(achievementStore: AchievementStore) {
        self.achievementStore = achievementStore
        totalGamesPlayed = UserDefaults.standard.integer(forKey: "totalGamesPlayed")
        combo610Total = defaults.integer(forKey: combo610Key)
        currentGameSnapshot.combo610Total = combo610Total
    }
    
    public func onGameStart(state: GameState) {
        sessionStartTime = Date()
        movesThisGame = 0
        totalMerges = 0
        maxChainThisGame = 0
        mergesThisTurn = 0
        consecutiveMergeTurns = 0
        currentGameSnapshot.combo610Total = combo610Total
    }
    
    public func onChainCommitted(chain: [Position], state: GameState, resultingTileValue: Int?) {
        movesThisGame += 1
        currentGameSnapshot.combo610Total = combo610Total
        
        if chain.count > 1 {
            mergesThisTurn = 1
            totalMerges += 1
            maxChainThisGame = max(maxChainThisGame, chain.count)
            updateComboProgressIfNeeded(for: chain.count)
            
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
        
        var snapshot = currentGameSnapshot
        snapshot.combo610Total = combo610Total
        snapshot.games_played = totalGamesPlayed
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    
    public func onUndoUsed() {
        currentGameSnapshot.undo_used += 1
        currentGameSnapshot.combo610Total = combo610Total
        
        var snapshot = currentGameSnapshot
        snapshot.combo610Total = combo610Total
        snapshot.games_played = totalGamesPlayed
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    private func updateComboProgressIfNeeded(for chainCount: Int) {
        guard (6...10).contains(chainCount) else { return }
        combo610Total += 1
        defaults.set(combo610Total, forKey: combo610Key)
        currentGameSnapshot.combo610Total = combo610Total
    }
}