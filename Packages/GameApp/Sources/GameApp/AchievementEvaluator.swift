import Foundation
import GameCore
import GameServices

@MainActor
public final class AchievementEvaluator {
    private let achievementStore: AchievementStore
    private var currentGameSnapshot = GameSnapshot()
    public private(set) var sessionStartTime = Date()
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
    private var lifetimeMergedTiles: Int = 0
    private var hammerUsesTotal: Int = 0
    private var swapUsesTotal: Int = 0
    private var magnetUsesTotal: Int = 0
    private var surviveMovesTotal: Int = 0
    private var spinUsesTotal: Int = 0
    private var challengeCreationTotal: Int = 0
    private var totalPlayMinutes: Int = 0
    private var totalPlaySeconds: Int = 0
    private var infinityCreationsTotal: Int = 0
    private var boost2xUsesTotal: Int = 0
    private var boost3xUsesTotal: Int = 0
    private var boost4xUsesTotal: Int = 0
    private var spinPurchasesTotal: Int = 0
    private var dailyClaimsTotal: Int = 0
    private var boost5xUsesTotal: Int = 0
    private var boost20xUsesTotal: Int = 0
    private var wheelCollectsTotal: Int = 0
    private let combo610Key = "combo6to10Total"
    private let combo1115Key = "combo11to15Total"
    private let combo1620Key = "combo16to20Total"
    private let combo2130Key = "combo21to30Total"
    private let mergedTilesKey = "totalMergedTiles"
    private let hammerUsesKey = "powerUses.hammer"
    private let swapUsesKey = "powerUses.swap"
    private let magnetUsesKey = "powerUses.magnet"
    private let surviveMovesKey = "surviveMoves.total"
    private let spinUsesKey = "powerUses.spin"
    private let challengeCreationTotalKey = "challengeCreation.total"
    private let playtimeTotalMinutesKey = "playtime.totalMinutes"
    private let playtimeTotalSecondsKey = "playtime.totalSeconds"
    private let infinityCreationsKey = "infinity.creations.total"
    private let boost2xUsesKey = "powerUses.boost2x"
    private let boost3xUsesKey = "powerUses.boost3x"
    private let boost4xUsesKey = "powerUses.boost4x"
    private let spinPurchasesKey = "spinPurchases.total"
    private let dailyClaimsKey = "dailyClaims.total"
    private let boost5xUsesKey = "powerUses.boost5x"
    private let boost20xUsesKey = "powerUses.boost20x"
    private let wheelCollectsKey = "wheelCollects.total"
    private let achievementBoostExpirationKey = "achievementBoost.expiresAt"
    private let defaults = UserDefaults.standard

    /// Returns the current achievement boost multiplier (2 if boost is active, 1 otherwise)
    private var achievementBoostMultiplier: Int {
        guard let expiration = defaults.object(forKey: achievementBoostExpirationKey) as? Date else {
            return 1
        }
        return expiration > Date() ? 2 : 1
    }

    public init(achievementStore: AchievementStore) {
        self.achievementStore = achievementStore
        totalGamesPlayed = UserDefaults.standard.integer(forKey: "totalGamesPlayed")
        combo610Total = defaults.integer(forKey: combo610Key)
        combo1115Total = defaults.integer(forKey: combo1115Key)
        combo1620Total = defaults.integer(forKey: combo1620Key)
        combo2130Total = defaults.integer(forKey: combo2130Key)
        lifetimeMergedTiles = defaults.integer(forKey: mergedTilesKey)
        hammerUsesTotal = defaults.integer(forKey: hammerUsesKey)
        swapUsesTotal = defaults.integer(forKey: swapUsesKey)
        magnetUsesTotal = defaults.integer(forKey: magnetUsesKey)
        spinUsesTotal = defaults.integer(forKey: spinUsesKey)
        surviveMovesTotal = defaults.integer(forKey: surviveMovesKey)

        // Sync surviveMovesTotal with totalMoves if there's a significant discrepancy
        // This handles the case where totalMoves was tracked before surviveMovesTotal
        let totalMoves = defaults.integer(forKey: "totalMoves")
        if totalMoves > 0 && surviveMovesTotal < totalMoves {
            // Survive moves should roughly equal total moves (minus game overs)
            // If surviveMovesTotal is much lower, it wasn't being tracked properly before
            surviveMovesTotal = totalMoves
            defaults.set(surviveMovesTotal, forKey: surviveMovesKey)
            print("🔄 Synced surviveMovesTotal to totalMoves: \(surviveMovesTotal)")
        }
        challengeCreationTotal = defaults.integer(forKey: challengeCreationTotalKey)
        totalPlaySeconds = defaults.integer(forKey: playtimeTotalSecondsKey)
        // Migrate old minutes-only data if seconds is 0 but minutes exists
        if totalPlaySeconds == 0 {
            let oldMinutes = defaults.integer(forKey: playtimeTotalMinutesKey)
            if oldMinutes > 0 {
                totalPlaySeconds = oldMinutes * 60
                defaults.set(totalPlaySeconds, forKey: playtimeTotalSecondsKey)
            }
        }
        totalPlayMinutes = totalPlaySeconds / 60
        infinityCreationsTotal = defaults.integer(forKey: infinityCreationsKey)
        boost2xUsesTotal = defaults.integer(forKey: boost2xUsesKey)
        boost3xUsesTotal = defaults.integer(forKey: boost3xUsesKey)
        boost4xUsesTotal = defaults.integer(forKey: boost4xUsesKey)
        spinPurchasesTotal = defaults.integer(forKey: spinPurchasesKey)
        dailyClaimsTotal = defaults.integer(forKey: dailyClaimsKey)
        boost5xUsesTotal = defaults.integer(forKey: boost5xUsesKey)
        boost20xUsesTotal = defaults.integer(forKey: boost20xUsesKey)
        wheelCollectsTotal = defaults.integer(forKey: wheelCollectsKey)
        if challengeCreationTotal == 0,
           let data = UserDefaults.standard.data(forKey: "challengeCompletedIds"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            challengeCreationTotal = ids.count
            defaults.set(challengeCreationTotal, forKey: challengeCreationTotalKey)
        }
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
        currentGameSnapshot.hammer_uses_total = hammerUsesTotal
        currentGameSnapshot.swap_uses_total = swapUsesTotal
        currentGameSnapshot.magnet_uses_total = magnetUsesTotal
        currentGameSnapshot.spin_uses_total = spinUsesTotal
        currentGameSnapshot.survive_moves_total = surviveMovesTotal
        currentGameSnapshot.spin_uses_total = spinUsesTotal
        currentGameSnapshot.survive_moves_total = surviveMovesTotal
        currentGameSnapshot.challenge_creations_total = challengeCreationTotal
        currentGameSnapshot.play_minutes_total = totalPlayMinutes
        currentGameSnapshot.infinity_creations_total = infinityCreationsTotal
        currentGameSnapshot.boost2x_uses_total = boost2xUsesTotal
        currentGameSnapshot.boost3x_uses_total = boost3xUsesTotal
        currentGameSnapshot.boost4x_uses_total = boost4xUsesTotal
        currentGameSnapshot.spin_purchases_total = spinPurchasesTotal
        currentGameSnapshot.daily_claims_total = dailyClaimsTotal
        currentGameSnapshot.boost5x_uses_total = boost5xUsesTotal
        currentGameSnapshot.boost20x_uses_total = boost20xUsesTotal
        currentGameSnapshot.wheel_collects_total = wheelCollectsTotal
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
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
        currentGameSnapshot.hammer_uses_total = hammerUsesTotal
        currentGameSnapshot.swap_uses_total = swapUsesTotal
        currentGameSnapshot.magnet_uses_total = magnetUsesTotal
        currentGameSnapshot.challenge_creations_total = challengeCreationTotal
        currentGameSnapshot.play_minutes_total = totalPlayMinutes
        currentGameSnapshot.infinity_creations_total = infinityCreationsTotal
        currentGameSnapshot.boost2x_uses_total = boost2xUsesTotal
        currentGameSnapshot.boost3x_uses_total = boost3xUsesTotal
        currentGameSnapshot.boost4x_uses_total = boost4xUsesTotal
        currentGameSnapshot.spin_purchases_total = spinPurchasesTotal
        currentGameSnapshot.daily_claims_total = dailyClaimsTotal
        currentGameSnapshot.boost5x_uses_total = boost5xUsesTotal
        currentGameSnapshot.boost20x_uses_total = boost20xUsesTotal
        currentGameSnapshot.wheel_collects_total = wheelCollectsTotal
    }

    /// Saves accumulated playtime without ending the game session.
    /// Call this when the app backgrounds or viewing achievements.
    public func savePlaytimeProgress(state: GameState) {
        let elapsedSeconds = Int(Date().timeIntervalSince(sessionStartTime))
        totalPlaySeconds += elapsedSeconds
        totalPlayMinutes = totalPlaySeconds / 60
        defaults.set(totalPlaySeconds, forKey: playtimeTotalSecondsKey)
        defaults.set(totalPlayMinutes, forKey: playtimeTotalMinutesKey)
        print("⏱️ Playtime saved: +\(elapsedSeconds)s, Total: \(totalPlaySeconds)s (\(totalPlayMinutes) min)")

        // Reset session start for when app resumes
        sessionStartTime = Date()

        // Update snapshot and evaluate achievements
        currentGameSnapshot.play_minutes_total = totalPlayMinutes
        var snapshot = currentGameSnapshot
        snapshot.play_minutes_total = totalPlayMinutes
        snapshot.games_played = totalGamesPlayed
        snapshot.max_tile = state.highestTile
        snapshot.score = state.score
        snapshot.total_moves = defaults.integer(forKey: "totalMoves")

        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onChainCommitted(chain: [Position], state: GameState, resultingTileValue: Int?) {
        movesThisGame += 1
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
        
        if chain.count > 1 {
            mergesThisTurn = 1
            totalMerges += 1
            maxChainThisGame = max(maxChainThisGame, chain.count)
            updateComboProgress(for: chain.count)
            recordMergedTiles(chain.count)
            
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
        snapshot.merged_tiles_total = lifetimeMergedTiles
        snapshot.hammer_uses_total = hammerUsesTotal
        snapshot.swap_uses_total = swapUsesTotal
        snapshot.magnet_uses_total = magnetUsesTotal
        snapshot.spin_uses_total = spinUsesTotal
        snapshot.survive_moves_total = surviveMovesTotal
        snapshot.challenge_creations_total = challengeCreationTotal
        snapshot.play_minutes_total = totalPlayMinutes
        snapshot.infinity_creations_total = infinityCreationsTotal
        snapshot.boost2x_uses_total = boost2xUsesTotal
        snapshot.boost3x_uses_total = boost3xUsesTotal
        snapshot.boost4x_uses_total = boost4xUsesTotal

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

        // Track playtime using seconds for precision (same as savePlaytimeProgress)
        let elapsedSeconds = Int(Date().timeIntervalSince(sessionStartTime))
        totalPlaySeconds += elapsedSeconds
        totalPlayMinutes = totalPlaySeconds / 60
        defaults.set(totalPlaySeconds, forKey: playtimeTotalSecondsKey)
        defaults.set(totalPlayMinutes, forKey: playtimeTotalMinutesKey)
        print("⏱️ Game ended - Playtime: +\(elapsedSeconds)s, Total: \(totalPlaySeconds)s (\(totalPlayMinutes) min)")

        // If game ended due to game over (not a win), the last move caused it
        // so it should not count as a survived move - decrement by 1
        if !won && surviveMovesTotal > 0 {
            surviveMovesTotal -= 1
            defaults.set(surviveMovesTotal, forKey: surviveMovesKey)
            currentGameSnapshot.survive_moves_total = surviveMovesTotal
            print("🎯 Game over - Survived moves decremented to: \(surviveMovesTotal)")
        }

        // Reset session start for next game
        sessionStartTime = Date()
        
        var snapshot = GameSnapshot()
        snapshot.games_played = totalGamesPlayed
        snapshot.merges_total = totalMerges
        snapshot.max_chain = maxChainThisGame
        snapshot.score = state.score
        snapshot.moves = movesThisGame
        snapshot.max_tile = state.highestTile
        snapshot.win = won
        snapshot.run_completed = true
        snapshot.run_minutes = elapsedSeconds / 60
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        snapshot.merged_tiles_total = lifetimeMergedTiles
        snapshot.hammer_uses_total = hammerUsesTotal
        snapshot.swap_uses_total = swapUsesTotal
        snapshot.magnet_uses_total = magnetUsesTotal
        snapshot.spin_uses_total = spinUsesTotal
        snapshot.survive_moves_total = surviveMovesTotal
        snapshot.challenge_creations_total = challengeCreationTotal
        snapshot.play_minutes_total = totalPlayMinutes
        snapshot.infinity_creations_total = infinityCreationsTotal
        snapshot.boost2x_uses_total = boost2xUsesTotal
        snapshot.boost3x_uses_total = boost3xUsesTotal
        snapshot.boost4x_uses_total = boost4xUsesTotal
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
        recordPowerUpUse(type: type)
        currentGameSnapshot.powerups_used += 1
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
        currentGameSnapshot.hammer_uses_total = hammerUsesTotal
        currentGameSnapshot.swap_uses_total = swapUsesTotal
        currentGameSnapshot.magnet_uses_total = magnetUsesTotal
        currentGameSnapshot.spin_uses_total = spinUsesTotal
        
        var snapshot = currentGameSnapshot
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        snapshot.merged_tiles_total = lifetimeMergedTiles
        snapshot.hammer_uses_total = hammerUsesTotal
        snapshot.swap_uses_total = swapUsesTotal
        snapshot.magnet_uses_total = magnetUsesTotal
        snapshot.spin_uses_total = spinUsesTotal
        snapshot.survive_moves_total = surviveMovesTotal
        snapshot.games_played = totalGamesPlayed
        snapshot.play_minutes_total = totalPlayMinutes
        snapshot.infinity_creations_total = infinityCreationsTotal
        snapshot.boost2x_uses_total = boost2xUsesTotal
        snapshot.boost3x_uses_total = boost3xUsesTotal
        snapshot.boost4x_uses_total = boost4xUsesTotal

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
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
        
        var snapshot = currentGameSnapshot
        snapshot.combo610Total = combo610Total
        snapshot.combo1115Total = combo1115Total
        snapshot.combo1620Total = combo1620Total
        snapshot.combo2130Total = combo2130Total
        snapshot.merged_tiles_total = lifetimeMergedTiles
        snapshot.games_played = totalGamesPlayed
        
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    public func onTilesMerged(count: Int) {
        recordMergedTiles(count)
    }
    
    private func updateComboProgress(for chainCount: Int) {
        let multiplier = achievementBoostMultiplier
        if (6...10).contains(chainCount) {
            combo610Total += multiplier
            defaults.set(combo610Total, forKey: combo610Key)
        }
        if (11...15).contains(chainCount) {
            combo1115Total += multiplier
            defaults.set(combo1115Total, forKey: combo1115Key)
        }
        if (16...20).contains(chainCount) {
            combo1620Total += multiplier
            defaults.set(combo1620Total, forKey: combo1620Key)
        }
        if (21...30).contains(chainCount) {
            combo2130Total += multiplier
            defaults.set(combo2130Total, forKey: combo2130Key)
        }
        currentGameSnapshot.combo610Total = combo610Total
        currentGameSnapshot.combo1115Total = combo1115Total
        currentGameSnapshot.combo1620Total = combo1620Total
        currentGameSnapshot.combo2130Total = combo2130Total
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
    }

    private func recordMergedTiles(_ count: Int) {
        guard count > 0 else { return }
        let multiplier = achievementBoostMultiplier
        lifetimeMergedTiles += count * multiplier
        defaults.set(lifetimeMergedTiles, forKey: mergedTilesKey)
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles
    }
    
    public func onMoveSurvived() {
        let multiplier = achievementBoostMultiplier
        surviveMovesTotal += multiplier
        defaults.set(surviveMovesTotal, forKey: surviveMovesKey)
        currentGameSnapshot.survive_moves_total = surviveMovesTotal
        
        var snapshot = currentGameSnapshot
        snapshot.survive_moves_total = surviveMovesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    
    public func onInfinityCreated() {
        let multiplier = achievementBoostMultiplier
        infinityCreationsTotal += multiplier
        defaults.set(infinityCreationsTotal, forKey: infinityCreationsKey)
        currentGameSnapshot.infinity_creations_total = infinityCreationsTotal

        var snapshot = currentGameSnapshot
        snapshot.infinity_creations_total = infinityCreationsTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onBoost2xUsed() {
        boost2xUsesTotal += 1
        defaults.set(boost2xUsesTotal, forKey: boost2xUsesKey)
        currentGameSnapshot.boost2x_uses_total = boost2xUsesTotal

        var snapshot = currentGameSnapshot
        snapshot.boost2x_uses_total = boost2xUsesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onBoost3xUsed() {
        boost3xUsesTotal += 1
        defaults.set(boost3xUsesTotal, forKey: boost3xUsesKey)
        currentGameSnapshot.boost3x_uses_total = boost3xUsesTotal

        var snapshot = currentGameSnapshot
        snapshot.boost3x_uses_total = boost3xUsesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onBoost4xUsed() {
        boost4xUsesTotal += 1
        defaults.set(boost4xUsesTotal, forKey: boost4xUsesKey)
        currentGameSnapshot.boost4x_uses_total = boost4xUsesTotal

        var snapshot = currentGameSnapshot
        snapshot.boost4x_uses_total = boost4xUsesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onSpinPurchased(count: Int) {
        spinPurchasesTotal += count
        defaults.set(spinPurchasesTotal, forKey: spinPurchasesKey)
        currentGameSnapshot.spin_purchases_total = spinPurchasesTotal

        var snapshot = currentGameSnapshot
        snapshot.spin_purchases_total = spinPurchasesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onDailyClaimed() {
        dailyClaimsTotal += 1
        defaults.set(dailyClaimsTotal, forKey: dailyClaimsKey)
        currentGameSnapshot.daily_claims_total = dailyClaimsTotal

        var snapshot = currentGameSnapshot
        snapshot.daily_claims_total = dailyClaimsTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onBoost5xUsed() {
        boost5xUsesTotal += 1
        defaults.set(boost5xUsesTotal, forKey: boost5xUsesKey)
        currentGameSnapshot.boost5x_uses_total = boost5xUsesTotal

        var snapshot = currentGameSnapshot
        snapshot.boost5x_uses_total = boost5xUsesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onBoost20xUsed() {
        boost20xUsesTotal += 1
        defaults.set(boost20xUsesTotal, forKey: boost20xUsesKey)
        currentGameSnapshot.boost20x_uses_total = boost20xUsesTotal

        var snapshot = currentGameSnapshot
        snapshot.boost20x_uses_total = boost20xUsesTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onWheelCollected(count: Int) {
        wheelCollectsTotal += count
        defaults.set(wheelCollectsTotal, forKey: wheelCollectsKey)
        currentGameSnapshot.wheel_collects_total = wheelCollectsTotal

        var snapshot = currentGameSnapshot
        snapshot.wheel_collects_total = wheelCollectsTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }

    public func onChallengeCreationCompleted() {
        challengeCreationTotal += 1
        defaults.set(challengeCreationTotal, forKey: challengeCreationTotalKey)
        currentGameSnapshot.challenge_creations_total = challengeCreationTotal
        var snapshot = currentGameSnapshot
        snapshot.challenge_creations_total = challengeCreationTotal
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
    
    private func recordPowerUpUse(type: String) {
        let multiplier = achievementBoostMultiplier
        switch type {
        case "hammer":
            hammerUsesTotal += multiplier
            defaults.set(hammerUsesTotal, forKey: hammerUsesKey)
        case "swap":
            swapUsesTotal += multiplier
            defaults.set(swapUsesTotal, forKey: swapUsesKey)
        case "magnet":
            magnetUsesTotal += multiplier
            defaults.set(magnetUsesTotal, forKey: magnetUsesKey)
        case "spin":
            spinUsesTotal += multiplier
            defaults.set(spinUsesTotal, forKey: spinUsesKey)
        default:
            break
        }
        currentGameSnapshot.hammer_uses_total = hammerUsesTotal
        currentGameSnapshot.swap_uses_total = swapUsesTotal
        currentGameSnapshot.magnet_uses_total = magnetUsesTotal
        currentGameSnapshot.spin_uses_total = spinUsesTotal
        currentGameSnapshot.survive_moves_total = surviveMovesTotal
    }

    /// Called when magnet (MegaMerge) is used - tracks usage, combos, merges, and moves
    public func onMagnetUsed(mergeCount: Int) {
        let multiplier = achievementBoostMultiplier

        // Track magnet usage
        magnetUsesTotal += multiplier
        defaults.set(magnetUsesTotal, forKey: magnetUsesKey)
        currentGameSnapshot.magnet_uses_total = magnetUsesTotal

        // Count as merged tiles
        lifetimeMergedTiles += mergeCount * multiplier
        defaults.set(lifetimeMergedTiles, forKey: mergedTilesKey)
        currentGameSnapshot.merged_tiles_total = lifetimeMergedTiles

        // Count as a move
        let currentTotalMoves = defaults.integer(forKey: "totalMoves")
        defaults.set(currentTotalMoves + 1, forKey: "totalMoves")

        // Count towards combo achievements based on merge count
        updateComboProgress(for: mergeCount)

        // Evaluate achievements
        var snapshot = currentGameSnapshot
        snapshot.magnet_uses_total = magnetUsesTotal
        snapshot.merged_tiles_total = lifetimeMergedTiles
        snapshot.total_moves = defaults.integer(forKey: "totalMoves")
        Task {
            await achievementStore.evaluate(snapshot: snapshot)
        }
    }
}
