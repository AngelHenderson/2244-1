import Foundation
import SwiftUI
import GameCore
import GameServices
import Observation
import CryptoKit

// MARK: - Notification Names
extension Notification.Name {
    static let saveProgress = Notification.Name("SaveProgress")
}

@Observable
@MainActor
public final class GameStore {
    private var engine: GameEngine
    public private(set) var state: GameState
    public private(set) var currentPath: [Position] = []
    public private(set) var pathValidation: ChainValidation = .valid
    public private(set) var lastInvalidChainReason: String?
    public var achievementEvaluator: AchievementEvaluator?
    public var spinWheelState: SpinWheelState?
    public weak var rewardLedger: RewardLedgerStore?

    /// Count of valid move pairs (adjacent identical tiles) - stored for SwiftUI reactivity
    public private(set) var validMovesCount: Int = 0

    /// Length of the last committed chain (for tracking merged tiles in challenge mode)
    public private(set) var lastChainLength: Int = 0

    // Track if game over has been processed for this session (reset on new game)
    private var gameOverProcessed: Bool = false

    /// Set to true only when the player confirms game over (dismisses recovery overlay).
    /// Used by board views for the greyout animation instead of `state.isGameOver`.
    public var gameOverConfirmed: Bool = false

    /// Fires once per game session when the game ends. Wired by the app entry to
    /// submit the final score to the active leaderboard backend.
    public var onGameEnded: (@MainActor (GameRunSummary) -> Void)?

    // Sandboxed mode for challenges - doesn't persist progress to main game
    public let sandboxed: Bool

    // Player's highest tile for power-up cost scaling (used in sandboxed/challenge mode to match main game pricing)
    public var playerHighestTile: Int?
    // Player's highest tile step (for high-value tiles where value is Int.max)
    public var playerHighestTileStep: Int?

    // Challenge target step for power-up cost scaling in challenge mode
    public var challengeTargetStep: Int?

    // Progress store for comprehensive auto-save
    private let progressStore: UserDefaultsProgressStore
    // Track if we're building a chain that may end on a gift
    public private(set) var isExtendingToGift: Bool = false
    // Pending unlock reward (base amount before multiplier)
    public private(set) var pendingUnlockRewardBase: Int? = nil
    public private(set) var pendingUnlockTile: Int? = nil
    // Milestone notification pipeline
    public enum MergeNotification: Equatable, Sendable {
        case unlocked(Int, celebrationPhrase: String)
        case added(Int, celebrationPhrase: String)
        case excluded(Int, celebrationPhrase: String)
    }

    /// Shared celebration phrases for milestone notifications.
    /// When a milestone triggers multiple notifications, unique phrases are pre-selected
    /// so no two notifications in the sequence share the same word.
    private static let celebrationPhrases = [
        "Marvelous!", "Glorious!", "Excellent!", "Fantastic!",
        "Incredible!", "Brilliant!", "Outstanding!", "Superb!",
        "Amazing!", "Spectacular!", "Phenomenal!", "Magnificent!",
        "Great Job!", "Well Done!", "Awesome!", "Nice Work!",
        "Keep Going!", "Way to Go!", "Impressive!", "Stellar!",
        "Good Job!", "Nice!", "Progress!", "Moving Up!",
        "Onward!", "Advancing!", "Leveling Up!", "Rising!",
    ]

    /// Pick `count` unique random phrases from the shared pool.
    private static func pickUniquePhrases(_ count: Int) -> [String] {
        let pool = celebrationPhrases.shuffled()
        return Array(pool.prefix(count))
    }
    
    public struct MagnetEvent: Equatable, Sendable {
        public let target: Position
        public let sources: [Position]
        public let value: Int
    }
    
    public struct HammerAnimationState: Equatable, Sendable {
        public enum Phase: Equatable, Sendable {
            case windUp
            case impact
        }
        public let target: Position
        public let phase: Phase
        public let startedAt: Date
    }
    
    public enum MergePhase: Equatable, Sendable {
        case shatter
        case fly
    }

    public struct MergeAnimationState: Equatable, Sendable {
        public let sourcePositions: [Position]
        public let targetPosition: Position
        public let value: Int
        public let startTime: Date
        public let phase: MergePhase
    }
    
    private struct StoredGiftBox: Codable {
        let row: Int
        let col: Int
        let reward: GiftReward
    }
    
    private var notificationQueue: [MergeNotification] = []
    public private(set) var currentNotification: MergeNotification? = nil
    public private(set) var lastMagnetEvent: MagnetEvent? = nil
    public private(set) var mergeAnimationState: MergeAnimationState? = nil
    public private(set) var isInputLocked: Bool = false
    // Value of the most recently created tile from a commit (for HUD banner)
    public private(set) var lastAddedTileValue: Int? = nil
    // Position of the most recently created tile (for immediate doubling)
    public private(set) var lastAddedTilePosition: Position? = nil
    // Pending double offer value to apply (base value for doubling)
    public private(set) var pendingDoubleBase: Int? = nil
    // Step index for pending double (needed for tiles beyond Int.max)
    public private(set) var pendingDoubleBaseStep: Int? = nil
    // Track which glass tiles have been broken (positions in row 0)
    public private(set) var brokenGlassTiles: Set<Position> = []
    // Pending gift boxes (glass shattered but reward not claimed)
    public private(set) var pendingGiftBoxes: [Position: GiftReward] = [:]
    // Tiles spawned during refill that should fade in after gravity settles
    public private(set) var pendingRefillPositions: Set<Position> = []
    private var refillRevealTask: Task<Void, Never>? = nil
    private var mergeCleanupTask: Task<Void, Never>? = nil
    private var invalidFeedbackTask: Task<Void, Never>? = nil
    public private(set) var hammerAnimationState: HammerAnimationState? = nil
    private var runStartedAt: Date = Date()
    /// Fires once when the player creates their very first infinity tile (non-sandboxed only)
    public private(set) var didCreateFirstInfinity: Bool = false
    // Milestone elimination ghost animation - shows tiles fading out after elimination
    public private(set) var milestoneEliminatedTiles: [GameEngine.EliminatedTileInfo] = []
    // Pending elimination tiles to animate after excluded notification is dismissed
    private var pendingEliminationTiles: [GameEngine.EliminatedTileInfo] = []
    // Gift reward sheet state
    public var pendingGiftReward: GiftReward? = nil
    private let journeyAbbreviationClaimsKey = "journeyAbbreviationClaims"
    public private(set) var claimedJourneyAbbreviationRewards: Set<String> = []
    private var pendingJourneyRewardTierID: String? = nil
    // Track gems spent on the last power-up action for undo refund
    // Stores (gemCost, powerUpKey) — nil if the last action wasn't a gem-purchased power-up
    private var lastPowerUpGemSpend: (cost: Int, key: String)? = nil
    // Power-up inventory tracking
    public private(set) var powerUpInventory: [String: Int] = [
        "hammer": 3,
        "shuffle": 2,
        "swap": 2,
        "undo": 1
    ]
    
    public enum ScoreBoostTierID: String, CaseIterable, Sendable {
        case fiveX = "boost_5x"
        case twentyX = "boost_20x"
    }
    
    public struct ScoreBoostTier: Equatable, Sendable {
        public let id: ScoreBoostTierID
        public let label: String
        public let multiplier: Int
        public let cost: Int
        public let duration: TimeInterval
        
        public init(id: ScoreBoostTierID, label: String, multiplier: Int, cost: Int, duration: TimeInterval) {
            self.id = id
            self.label = label
            self.multiplier = multiplier
            self.cost = cost
            self.duration = duration
        }
    }
    
    private enum ScoreBoostDefaultsKey {
        static let activeTierID = "scoreBoost.activeTierID"
        static let activeExpiration = "scoreBoost.expiresAt"
        static let queuedTierID = "scoreBoost.queuedTierID"
    }
    
    private static let scoreBoostCatalog: [ScoreBoostTierID: ScoreBoostTier] = [
        .fiveX: ScoreBoostTier(
            id: .fiveX,
            label: "5× Score",
            multiplier: 5,
            cost: 12_500,
            duration: 15 * 60
        ),
        .twentyX: ScoreBoostTier(
            id: .twentyX,
            label: "20× Score",
            multiplier: 20,
            cost: 50_000,
            duration: 15 * 60
        )
    ]
    
    private static let scoreBoostFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
    
    public private(set) var activeScoreBoostTierID: ScoreBoostTierID?
    public private(set) var scoreBoostExpiresAt: Date?
    public private(set) var scoreBoostRemaining: TimeInterval = 0
    public private(set) var queuedScoreBoostTierID: ScoreBoostTierID?
    
    public enum PowerDiscountTierID: String, CaseIterable, Sendable {
        case quarterOff = "power_discount_25"
        case halfOff = "power_discount_50"
    }
    
    public struct PowerDiscountTier: Equatable, Sendable {
        public let id: PowerDiscountTierID
        public let label: String
        public let discountPercentage: Int
        public let cost: Int
        public let duration: TimeInterval
    }
    
    private enum PowerDiscountDefaultsKey {
        static let activeTierID = "powerDiscount.activeTierID"
        static let activeExpiration = "powerDiscount.expiresAt"
        static let queuedTierID = "powerDiscount.queuedTierID"
    }
    
    private static let powerDiscountCatalog: [PowerDiscountTierID: PowerDiscountTier] = [
        .quarterOff: PowerDiscountTier(
            id: .quarterOff,
            label: "25% Off Power-Ups",
            discountPercentage: 25,
            cost: 5_000,
            duration: 15 * 60
        ),
        .halfOff: PowerDiscountTier(
            id: .halfOff,
            label: "50% Off Power-Ups",
            discountPercentage: 50,
            cost: 15_000,
            duration: 15 * 60
        )
    ]

    public private(set) var activePowerDiscountTierID: PowerDiscountTierID?
    public private(set) var powerDiscountExpiresAt: Date?
    public private(set) var powerDiscountRemaining: TimeInterval = 0
    public private(set) var queuedPowerDiscountTierID: PowerDiscountTierID?

    // MARK: - Achievement Boost System

    public enum AchievementBoostTierID: String, CaseIterable, Sendable {
        case twoX = "achievement_boost_2x"
        case threeX = "achievement_boost_3x"
        case fiveX = "achievement_boost_5x"
        case eightX = "achievement_boost_8x"
        case elevenX = "achievement_boost_11x"
    }

    public struct AchievementBoostTier: Equatable, Sendable {
        public let id: AchievementBoostTierID
        public let label: String
        public let multiplier: Int
        public let cost: Int
        public let duration: TimeInterval
    }

    private enum AchievementBoostDefaultsKey {
        static let activeTierID = "achievementBoost.activeTierID"
        static let activeExpiration = "achievementBoost.expiresAt"
    }

    private static let achievementBoostCatalog: [AchievementBoostTierID: AchievementBoostTier] = [
        .twoX: AchievementBoostTier(
            id: .twoX,
            label: "2× Achievement Progress",
            multiplier: 2,
            cost: 2_500,
            duration: 20 * 60  // 20 minutes
        ),
        .threeX: AchievementBoostTier(
            id: .threeX,
            label: "3× Achievement Progress",
            multiplier: 3,
            cost: 6_000,
            duration: 18 * 60  // 18 minutes
        ),
        .fiveX: AchievementBoostTier(
            id: .fiveX,
            label: "5× Achievement Progress",
            multiplier: 5,
            cost: 12_500,
            duration: 15 * 60  // 15 minutes
        ),
        .eightX: AchievementBoostTier(
            id: .eightX,
            label: "8× Achievement Progress",
            multiplier: 8,
            cost: 15_000,
            duration: 14 * 60 + 30  // 14.5 minutes
        ),
        .elevenX: AchievementBoostTier(
            id: .elevenX,
            label: "11× Achievement Progress",
            multiplier: 11,
            cost: 17_500,
            duration: 14 * 60  // 14 minutes
        )
    ]

    private static let achievementBoostFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    public private(set) var activeAchievementBoostTierID: AchievementBoostTierID?
    public private(set) var achievementBoostExpiresAt: Date?
    public private(set) var achievementBoostRemaining: TimeInterval = 0

    @ObservationIgnored
    private var scoreBoostTickerTask: Task<Void, Never>? = nil
    @ObservationIgnored
    private var powerDiscountTickerTask: Task<Void, Never>? = nil
    @ObservationIgnored
    private var achievementBoostTickerTask: Task<Void, Never>? = nil
    
    public func addPowerUp(_ type: String, count: Int) {
        powerUpInventory[type, default: 0] += count
        persistPowerUpInventory()
    }

    /// Copies the power-up inventory from another GameStore (used to sync sandboxed stores)
    public func copyPowerUpInventory(from source: GameStore) {
        powerUpInventory = source.powerUpInventory
    }

    /// Decrements a single power-up from the inventory (used to sync challenge spending back to main store)
    public func consumePowerUp(_ type: String) {
        guard powerUpInventory[type, default: 0] > 0 else { return }
        powerUpInventory[type, default: 0] -= 1
        persistPowerUpInventory()
    }

    private func persistPowerUpInventory() {
        guard !sandboxed else { return }
        if let data = try? JSONEncoder().encode(powerUpInventory) {
            UserDefaults.standard.set(data, forKey: "powerUpInventory")
        }
    }

    /// Process pending rewards from GameState (power-ups, spins from gift boxes)
    private func processPendingRewards() {
        guard !state.pendingRewards.isEmpty else { return }

        for reward in state.pendingRewards {
            switch reward.type {
            case .powerUp:
                if let powerUpType = reward.powerUpType {
                    addPowerUp(powerUpType.rawValue, count: reward.value)
                    print("🎁 Awarded \(reward.value) \(powerUpType.rawValue)(s) from gift box")
                }
            case .spin:
                // Add spins to inventory (treat as a special power-up type)
                addPowerUp("spin", count: reward.value)
                print("🎁 Awarded \(reward.value) spin(s) from gift box")
            case .gems:
                // Gems are already handled in GameEngine, but process here for completeness
                break
            case .scoreBoost:
                // Score boosts are already handled in GameEngine
                break
            }
        }

        // Clear pending rewards from state
        state.pendingRewards.removeAll()
    }

    // JourneyKit integration
    public let journey = JourneyKit.Store(
        config: .init(minPower: 8, maxPower: 22) // 256 to 4_194_304
    )
    
    public var coins: Int {
        get { state.gems }
        set {
            state.gems = newValue
            syncEngineGems()
            if !sandboxed {
                UserDefaults.standard.set(newValue, forKey: "coins")
            }
        }
    }

    /// The minimum spawn step based on current game state (dynamic elimination threshold)
    public var minSpawnStep: Int {
        engine.minAllowedSpawnStep()
    }

    public var isScoreBoostActive: Bool {
        guard let expiration = scoreBoostExpiresAt else { return false }
        return expiration > Date()
    }
    
    public func scoreBoostTier(_ id: ScoreBoostTierID) -> ScoreBoostTier {
        Self.scoreBoostCatalog[id]!
    }
    
    public func scoreBoostLabel(for id: ScoreBoostTierID) -> String {
        scoreBoostTier(id).label
    }
    
    public func scoreBoostCost(for id: ScoreBoostTierID) -> Int {
        scoreBoostTier(id).cost
    }
    
    public func canPurchaseScoreBoost(_ id: ScoreBoostTierID) -> Bool {
        state.gems >= scoreBoostCost(for: id)
    }
    
    public func isScoreBoostActive(for id: ScoreBoostTierID) -> Bool {
        activeScoreBoostTierID == id && isScoreBoostActive
    }
    
    public func isScoreBoostQueued(for id: ScoreBoostTierID) -> Bool {
        queuedScoreBoostTierID == id
    }
    
    public func scoreBoostCountdownText(for id: ScoreBoostTierID) -> String {
        if isScoreBoostActive(for: id) {
            let seconds = max(0, scoreBoostRemaining)
            return Self.scoreBoostFormatter.string(from: seconds) ?? "00:00"
        }
        if isScoreBoostQueued(for: id) {
            return "Queued"
        }
        if canPurchaseScoreBoost(id) {
            return "Ready"
        }
        let shortfall = max(0, scoreBoostCost(for: id) - state.gems)
        return "Need \(shortfall)"
    }
    
    public var scoreBoostCountdownText: String {
        scoreBoostCountdownText(for: .fiveX)
    }
    
    private func activeScoreBoostTier() -> ScoreBoostTier? {
        guard let tierID = activeScoreBoostTierID else { return nil }
        return Self.scoreBoostCatalog[tierID]
    }
    
    public var isPowerDiscountActive: Bool {
        guard let expiration = powerDiscountExpiresAt else { return false }
        return expiration > Date()
    }
    
    public func powerDiscountTier(_ id: PowerDiscountTierID) -> PowerDiscountTier {
        Self.powerDiscountCatalog[id]!
    }
    
    public func powerDiscountLabel(for id: PowerDiscountTierID) -> String {
        powerDiscountTier(id).label
    }
    
    public func powerDiscountCost(for id: PowerDiscountTierID) -> Int {
        powerDiscountTier(id).cost
    }
    
    public func canPurchasePowerDiscount(_ id: PowerDiscountTierID) -> Bool {
        state.gems >= powerDiscountCost(for: id)
    }
    
    public func isPowerDiscountActive(for id: PowerDiscountTierID) -> Bool {
        activePowerDiscountTierID == id && isPowerDiscountActive
    }
    
    public func isPowerDiscountQueued(for id: PowerDiscountTierID) -> Bool {
        queuedPowerDiscountTierID == id
    }
    
    public func powerDiscountCountdownText(for id: PowerDiscountTierID) -> String {
        if isPowerDiscountActive(for: id) {
            let seconds = max(0, powerDiscountRemaining)
            return Self.scoreBoostFormatter.string(from: seconds) ?? "00:00"
        }
        if isPowerDiscountQueued(for: id) {
            return "Queued"
        }
        if canPurchasePowerDiscount(id) {
            return "Ready"
        }
        let shortfall = max(0, powerDiscountCost(for: id) - state.gems)
        return "Need \(shortfall)"
    }
    
    private func activePowerDiscountTier() -> PowerDiscountTier? {
        guard let tierID = activePowerDiscountTierID else { return nil }
        return Self.powerDiscountCatalog[tierID]
    }

    // MARK: - Achievement Boost Public API

    public var isAchievementBoostActive: Bool {
        guard let expiration = achievementBoostExpiresAt else { return false }
        return expiration > Date()
    }

    public func achievementBoostTier(_ id: AchievementBoostTierID) -> AchievementBoostTier {
        Self.achievementBoostCatalog[id]!
    }

    public func achievementBoostLabel(for id: AchievementBoostTierID) -> String {
        achievementBoostTier(id).label
    }

    public func achievementBoostCost(for id: AchievementBoostTierID) -> Int {
        achievementBoostTier(id).cost
    }

    public func canPurchaseAchievementBoost(_ id: AchievementBoostTierID) -> Bool {
        state.gems >= achievementBoostCost(for: id)
    }

    public func isAchievementBoostActive(for id: AchievementBoostTierID) -> Bool {
        activeAchievementBoostTierID == id && isAchievementBoostActive
    }

    public var achievementBoostMultiplier: Int {
        guard isAchievementBoostActive, let tierID = activeAchievementBoostTierID else { return 1 }
        return achievementBoostTier(tierID).multiplier
    }

    public func achievementBoostCountdownText(for id: AchievementBoostTierID) -> String {
        if isAchievementBoostActive(for: id) {
            let seconds = max(0, achievementBoostRemaining)
            return Self.achievementBoostFormatter.string(from: seconds) ?? "00:00"
        }
        if canPurchaseAchievementBoost(id) {
            return "Ready"
        }
        let shortfall = max(0, achievementBoostCost(for: id) - state.gems)
        return "Need \(shortfall)"
    }

    @discardableResult
    public func purchaseAchievementBoost(_ tierID: AchievementBoostTierID, now date: Date = Date()) -> Bool {
        let tier = achievementBoostTier(tierID)
        guard spendCoins(tier.cost) else { return false }
        activateAchievementBoost(tierID: tierID, now: date)
        saveProgressToStore()
        return true
    }

    private func persistScoreBoostState() {
        guard !sandboxed else { return }
        let defaults = UserDefaults.standard
        if let tierID = activeScoreBoostTierID, let expiresAt = scoreBoostExpiresAt {
            defaults.set(tierID.rawValue, forKey: ScoreBoostDefaultsKey.activeTierID)
            defaults.set(expiresAt, forKey: ScoreBoostDefaultsKey.activeExpiration)
        } else {
            defaults.removeObject(forKey: ScoreBoostDefaultsKey.activeTierID)
            defaults.removeObject(forKey: ScoreBoostDefaultsKey.activeExpiration)
        }

        if let queuedID = queuedScoreBoostTierID {
            defaults.set(queuedID.rawValue, forKey: ScoreBoostDefaultsKey.queuedTierID)
        } else {
            defaults.removeObject(forKey: ScoreBoostDefaultsKey.queuedTierID)
        }
    }

    private func persistPowerDiscountState() {
        guard !sandboxed else { return }
        let defaults = UserDefaults.standard
        if let tierID = activePowerDiscountTierID, let expiresAt = powerDiscountExpiresAt {
            defaults.set(tierID.rawValue, forKey: PowerDiscountDefaultsKey.activeTierID)
            defaults.set(expiresAt, forKey: PowerDiscountDefaultsKey.activeExpiration)
        } else {
            defaults.removeObject(forKey: PowerDiscountDefaultsKey.activeTierID)
            defaults.removeObject(forKey: PowerDiscountDefaultsKey.activeExpiration)
        }

        if let queuedID = queuedPowerDiscountTierID {
            defaults.set(queuedID.rawValue, forKey: PowerDiscountDefaultsKey.queuedTierID)
        } else {
            defaults.removeObject(forKey: PowerDiscountDefaultsKey.queuedTierID)
        }
    }
    
    private func syncEngineGems() {
        engine.overrideGems(with: state.gems)
    }
    
    private func syncEngineScoreBoost() {
        if let tierID = activeScoreBoostTierID,
           let tier = Self.scoreBoostCatalog[tierID],
           isScoreBoostActive {
            engine.setScoreMultiplier(tier.multiplier)
        } else {
            engine.setScoreMultiplier(1)
        }
    }
    
    // Lowest allowed spawn tile based on current highest (mirrors engine logic)
    public func currentMinAllowedTile() -> Int {
        let highest = state.highestTile
        // Progressive elimination starts at 1024 to maintain game balance
        guard highest >= 1024 else { return 2 }
        let exp = highest > 0 ? Int(floor(log2(Double(highest)))) : 0
        // Set minimum exponent: 2^10 -> 4, 2^11 -> 8, 2^12 -> 16, ...
        let minExp = max(1, exp - 8)
        return 1 << minExp
    }
    public private(set) var lastDailyDateUTC: String?
    
    // Replay recording
    public private(set) var movesHistory: [[Position]] = []
    public private(set) var powerUpHistory: [PowerUpAction] = []
    public private(set) var tierMasteryCounts: [String: Int] = [:]
    
    /// Creates a sandboxed GameStore for challenge mode (doesn't persist to main game)
    /// - Parameters:
    ///   - config: Game configuration
    ///   - initialGems: Starting gems (typically from player's main inventory)
    ///   - playerHighestTile: Player's highest tile from main game (for consistent power-up pricing)
    ///   - playerHighestTileStep: Player's highest tile step (for high-value tiles where value is Int.max)
    public static func sandboxed(config: GameConfig = GameConfig(), initialGems: Int = 0, playerHighestTile: Int? = nil, playerHighestTileStep: Int? = nil) -> GameStore {
        let store = GameStore(config: config, sandboxed: true)
        store.coins = initialGems
        store.playerHighestTile = playerHighestTile
        store.playerHighestTileStep = playerHighestTileStep
        return store
    }

    public init(config: GameConfig = GameConfig(), progressStore: UserDefaultsProgressStore = UserDefaultsProgressStore(), sandboxed: Bool = false) {
        self.sandboxed = sandboxed
        self.progressStore = progressStore

        // Sandboxed mode: start fresh without loading saved progress
        if sandboxed {
            let newEngine = GameEngine(config: config)
            self.engine = newEngine
            self.state = newEngine.currentState()
            // Initialize valid moves count for sandboxed mode
            self.validMovesCount = newEngine.countValidMoves()
            return
        }

        // Load saved progress synchronously during initialization
        let loadedProgress = progressStore.loadSync()
        self.tierMasteryCounts = GameStore.decodeTierMasteryCounts(from: loadedProgress)
        
        // Initialize engine with loaded state if available
        if let progress = loadedProgress, let sessionState = progress.currentSessionState {
            // Restore from saved session
            let restoredConfig = GameConfig(
                boardWidth: sessionState.board.width,
                boardHeight: sessionState.board.height,
                seed: sessionState.seed
            )
            // Use the most recent gem value for engine initialization
            let currentGems = UserDefaults.standard.integer(forKey: "coins") > 0
                ? UserDefaults.standard.integer(forKey: "coins")
                : progress.gems

            let restoredEngine = GameEngine(
                config: restoredConfig,
                initialBoard: sessionState.board,
                initialScore: sessionState.score,
                initialMoves: sessionState.moves,
                initialLevel: sessionState.level,
                initialGems: currentGems
            )
            self.engine = restoredEngine
            self.state = restoredEngine.currentState()
            let restoredStep = sessionState.highestTileStep ?? persistedHighestTileStep()
            #if DEBUG
            print("🔄 Restoring highestTileStep:")
            print("   From sessionState: \(String(describing: sessionState.highestTileStep))")
            print("   From UserDefaults: \(String(describing: persistedHighestTileStep()))")
            print("   Final restored step: \(String(describing: restoredStep))")
            #endif
            refreshDerivedState(
                scoreAlpha: sessionState.scoreAlpha ?? persistedScoreAlpha() ?? AlphaNumber(sessionState.score),
                highestStep: restoredStep
            )
            // Fill any gaps in the restored board (fixes corrupted saves)
            let gapColumns = columnsWithEmpties(in: state.board)
            if !gapColumns.isEmpty {
                print("🔧 Found gaps in restored board, filling columns: \(gapColumns)")
                let filledState = engine.refillColumns(gapColumns)
                self.state = filledState
            }

            // Initialize valid moves count after restoring session
            validMovesCount = engine.countValidMoves()
            // Use the most recent gem value - prefer UserDefaults as it's updated immediately
            let userDefaultsGems = UserDefaults.standard.integer(forKey: "coins")
            if userDefaultsGems > 0 {
                self.state.gems = userDefaultsGems
                print("💎 Using UserDefaults gems: \(userDefaultsGems) (progress had: \(progress.gems))")
            } else {
                self.state.gems = progress.gems
                print("💎 Using progress gems: \(progress.gems)")
            }
            syncEngineGems()
            syncEngineScoreBoost()
            self.state.highestTile = max(self.state.highestTile, sessionState.highestTile)
            // Ensure leaderboard milestone is set for restored highest tile
            // Use step-based formatting for high values to avoid overflow
            let formattedMilestone: String
            if let step = restoredStep, step >= 62 {
                formattedMilestone = TileStepLabelFormatter.labelForStep(step, start: 2)
            } else {
                formattedMilestone = TileStepLabelFormatter.formatTileValue(self.state.highestTile)
            }
            UserDefaults.standard.set(formattedMilestone, forKey: "leaderboard.milestone")

            // Restore power-up inventory
            self.powerUpInventory = progress.powerUpInventory
            
            // Restore journey state
            self.journey.restoreState(
                highestTile: progress.journeyState.highestTile,
                claimed: progress.journeyState.claimedTiles
            )
            self.claimedJourneyAbbreviationRewards = progress.journeyState.claimedAbbreviationTiers
            
            // Restore session-specific data
            self.brokenGlassTiles = Set(sessionState.brokenGlassTiles)
            self.movesHistory = sessionState.movesHistory
            self.lastDailyDateUTC = sessionState.lastDailyDateUTC
            
            let logStep = sessionState.highestTileStep ?? restoredStep ?? 0
            let logTile = logStep >= 62 ? TileStepLabelFormatter.labelForStep(logStep, start: 2) : "\(sessionState.highestTile)"
            let logScore: String
            if let alpha = sessionState.scoreAlpha {
                logScore = alpha.formattedLabel()
            } else {
                logScore = "\(sessionState.score)"
            }
            print("🎮 Restored complete game session - Moves: \(sessionState.moves), Score: \(logScore), Highest: \(logTile) (step \(logStep))")
        } else {
            // Start fresh
            let engine = GameEngine(config: config)
            self.engine = engine
            self.state = engine.currentState()
            refreshDerivedState(highestStep: persistedHighestTileStep())
            // Initialize valid moves count for fresh start
            validMovesCount = engine.countValidMoves()

            // Load basic progress if available
            if let progress = loadedProgress {
                // Use the most recent gem value - prefer UserDefaults as it's updated immediately
                let userDefaultsGems = UserDefaults.standard.integer(forKey: "coins")
                if userDefaultsGems > 0 {
                    self.state.gems = userDefaultsGems
                    print("💎 Fresh start - Using UserDefaults gems: \(userDefaultsGems) (progress had: \(progress.gems))")
                } else {
                    self.state.gems = progress.gems
                    print("💎 Fresh start - Using progress gems: \(progress.gems)")
                }
                syncEngineGems()
                syncEngineScoreBoost()
                self.powerUpInventory = progress.powerUpInventory
                self.journey.restoreState(
                    highestTile: progress.journeyState.highestTile,
                    claimed: progress.journeyState.claimedTiles
                )
                self.claimedJourneyAbbreviationRewards = progress.journeyState.claimedAbbreviationTiers
                print("📂 Loaded basic progress - Gems: \(progress.gems), Highest: \(progress.highestTile)")
            } else {
                // Truly starting fresh
                self.state.gems = UserDefaults.standard.integer(forKey: "coins")
                if self.state.gems == 0 {
                    self.state.gems = 305 // Default starter gems
                }
                syncEngineGems()
                syncEngineScoreBoost()
                print("🆕 Starting fresh game")
            }
        }
        
        // CRITICAL: Verify and fix highestTileStep if it seems corrupted
        verifyAndFixHighestTileStep()

        // Initialize comprehensive session tracking
        initializeSessionTracking()
        restoreScoreBoostState(from: loadedProgress)
        restorePowerDiscountState(from: loadedProgress)
        restoreAchievementBoostState()
        persistTierMasteryCountsToDefaults()

        // Note: restoreProgress() is now handled properly during GameProgress loading
        // Commenting out to prevent duplicate restoration that causes gem rollback
        // restoreProgress()
        
        // Listen for app lifecycle save notifications
        NotificationCenter.default.addObserver(
            forName: .saveProgress,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveProgress()
            }
        }
    }
    
    nonisolated deinit {
        Task { @MainActor [weak self] in
            self?.cancelRefillRevealTask()
            self?.cancelMergeCleanupTask()
            self?.scoreBoostTickerTask?.cancel()
            self?.powerDiscountTickerTask?.cancel()
            self?.achievementBoostTickerTask?.cancel()
            self?.invalidFeedbackTask?.cancel()
        }
    }
    
    public func beginPath(at position: Position) {
        // Don't allow starting on gift cells
        let boardIndex = BoardIndex(position)
        if state.board[boardIndex].kind == .gift {
            return
        }
        if pendingGiftBoxes[position] != nil {
            return
        }
        
        currentPath = [position]
        pathValidation = .valid
        clearInvalidChainReason()
        isExtendingToGift = false
    }
    
    public func isValidNextTile(_ position: Position) -> Bool {
        guard !currentPath.contains(position) else { return false }
        guard pendingGiftBoxes[position] == nil else { return false }
        
        if let last = currentPath.last, !last.isAdjacent(to: position) {
            return false
        }
        
        var testPath = currentPath
        testPath.append(position)
        
        let boardIndex = BoardIndex(position)
        let isGift = state.board[boardIndex].kind == .gift
        
        if isGift {
            return engine.validateGiftChain(testPath).isValid
        } else {
            return engine.validateChain(testPath).isValid
        }
    }
    
    @discardableResult
    public func extendPath(to position: Position) -> Bool {
        guard !currentPath.contains(position) else {
            showInvalidChainReason("You already used that tile")
            return false
        }
        guard pendingGiftBoxes[position] == nil else {
            showInvalidChainReason("Claim the gift before chaining through it")
            return false
        }
        
        if let last = currentPath.last, !last.isAdjacent(to: position) {
            showInvalidChainReason("Tiles must touch, including diagonals")
            return false
        }
        
        let proposedPath = currentPath + [position]
        
        // Check if we're extending to a gift cell
        let boardIndex = BoardIndex(position)
        let extendingToGift = state.board[boardIndex].kind == .gift
        
        let validation: ChainValidation
        if extendingToGift {
            validation = engine.validateGiftChain(proposedPath)
        } else {
            validation = engine.validateChain(proposedPath)
        }
        
        if validation.isValid {
            currentPath.append(position)
            isExtendingToGift = extendingToGift
            pathValidation = validation
            return true
        } else {
            // If the tile makes the chain invalid, DO NOT add it.
            // This prevents "poisoning" the chain when the user drags sloppily
            // over adjacent invalid tiles while tracing a U-shape.
            // The drag location will still cause the UI pipe to visually stretch
            // toward the finger without breaking the underlying valid path.
            showInvalidChainReason(validation.reason ?? "That tile cannot continue this chain")
            return false
        }
    }
    
    public func backtrackPath() {
        guard currentPath.count > 1 else { return }
        currentPath.removeLast()
        
        // Re-check if we're still extending to a gift
        if let last = currentPath.last {
            let boardIndex = BoardIndex(last)
            isExtendingToGift = state.board[boardIndex].kind == .gift
        } else {
            isExtendingToGift = false
        }
        
        // Use appropriate validation
        if isExtendingToGift {
            pathValidation = engine.validateGiftChain(currentPath)
        } else {
            pathValidation = engine.validateChain(currentPath)
        }
    }
    
    public func cancelPath() {
        currentPath = []
        pathValidation = .valid
        clearInvalidChainReason()
        isInputLocked = false
        isExtendingToGift = false
    }

    /// Reset input state when the game screen appears.
    /// Clears any stale input lock or path state left over from a
    /// previous merge animation that was interrupted by navigation.
    public func resetInputState() {
        mergeCleanupTask?.cancel()
        mergeCleanupTask = nil
        mergeAnimationState = nil
        currentPath = []
        pathValidation = .valid
        clearInvalidChainReason()
        isInputLocked = false
        isExtendingToGift = false

        // Apply any pending deferred elimination so the board is consistent
        if !pendingEliminationTiles.isEmpty {
            state = engine.applyDeferredElimination()
            pendingEliminationTiles = []
            milestoneEliminatedTiles = []
        }
    }

    private func showInvalidChainReason(_ reason: String) {
        lastInvalidChainReason = reason
        invalidFeedbackTask?.cancel()
        invalidFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard !Task.isCancelled else { return }
            self?.lastInvalidChainReason = nil
        }
    }

    private func clearInvalidChainReason() {
        invalidFeedbackTask?.cancel()
        invalidFeedbackTask = nil
        lastInvalidChainReason = nil
    }
    
    public func commitPath() {
        guard pathValidation.isValid else { return }
        guard !currentPath.isEmpty else { return }
        
        let positions = currentPath
        guard let lastPos = positions.last else { return }
        
        print("[GameStore] Starting commitPath sequence. Positions: \(positions.count)")

        // Track chain length for challenge mode achievement tracking
        lastChainLength = positions.count

        // Lock input to prevent interaction during animation
        isInputLocked = true
        
        // Clear the path immediately so the line disappears
        currentPath = []
        pathValidation = .valid
        clearInvalidChainReason()
        
        mergeCleanupTask?.cancel()
        
        // Determine the value being merged (for particle color)
        let firstPos = positions[0]
        let value = state.board[firstPos]?.value ?? 2
        
        // Start the animation sequence
        mergeCleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            print("[GameStore] Task started")
            
            do {
                // 1. Shatter phase
                print("[GameStore] Phase 1: Shatter")
                self.mergeAnimationState = MergeAnimationState(
                    sourcePositions: Array(positions.dropLast()),
                    targetPosition: lastPos,
                    value: value,
                    startTime: Date(),
                    phase: .shatter
                )
                
                // Keep feedback crisp; long locks make quick chains feel sticky.
                try await Task.sleep(nanoseconds: 240_000_000)
                
                if Task.isCancelled {
                    print("[GameStore] Task cancelled after shatter")
                    self.isInputLocked = false
                    return
                }
                
                // 2. Fly phase
                print("[GameStore] Phase 2: Fly")
                self.mergeAnimationState = MergeAnimationState(
                    sourcePositions: Array(positions.dropLast()),
                    targetPosition: lastPos,
                    value: value,
                    startTime: Date(),
                    phase: .fly
                )
                
                // Wait for fly animation
                try await Task.sleep(nanoseconds: Self.mergeAnimationDelay)
                
                if Task.isCancelled {
                    print("[GameStore] Task cancelled after fly")
                    self.isInputLocked = false
                    return
                }
                
                // 3. Commit (Shatter/Fly complete, now apply logic)
                // Defer elimination so tiles stay on the board until the
                // excluded notification is dismissed.
                print("[GameStore] Phase 3: Commit (Logic)")
                self.engine.deferElimination = true
                let (requiresGravityDrop, affectedColumns) = self.performCommit(positions: positions)
                self.engine.deferElimination = false

                // 3b. Check if milestone elimination was deferred
                let eliminatedTiles = self.engine.lastMilestoneEliminatedTiles
                if !eliminatedTiles.isEmpty {
                    print("[GameStore] Phase 3b: Storing \(eliminatedTiles.count) tiles for deferred elimination after notification")
                    self.pendingEliminationTiles = eliminatedTiles
                    // Don't clear yet — applyDeferredElimination will clear after actual removal
                }

                if requiresGravityDrop {
                    print("[GameStore] Phase 3c: Gravity Drop")
                    // Yield to let SwiftUI render pre-gravity positions first.
                    // The per-tile .animation(.spring, value: position) needs to see
                    // the "before" position to animate to the "after" position.
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame
                    self.performGravityDrop(columns: affectedColumns)

                    // Update lastAddedTilePosition after gravity — the merged tile
                    // may have dropped to a lower row in the same column.
                    if let oldPos = self.lastAddedTilePosition,
                       let targetStep = self.pendingDoubleBaseStep ?? self.lastAddedTileValue.flatMap({ TileStepLabelFormatter.stepForValue($0) }) {
                        let col = oldPos.col
                        // Search from bottom up in the same column for the tile
                        for row in stride(from: self.state.board.height - 1, through: 0, by: -1) {
                            let pos = Position(row: row, col: col)
                            if let tile = self.state.board[pos], tile.stepIndex == targetStep {
                                if pos != oldPos {
                                    print("[GameStore] Gravity moved tile from \(oldPos) to \(pos)")
                                }
                                self.lastAddedTilePosition = pos
                                break
                            }
                        }
                    }
                }

                // Wait for gravity animation (tiles dropping)
                // Assuming standard spring animation duration ~0.35s
                try await Task.sleep(nanoseconds: Self.gravityAnimationDelay)

                if Task.isCancelled {
                    print("[GameStore] Task cancelled after gravity")
                    self.isInputLocked = false
                    return
                }

                // 4. Refill Phase
                print("[GameStore] Phase 4: Refill")
                self.performRefill(columns: affectedColumns)

                // 5. Update valid moves count once at the very end
                self.updateValidMovesCount()

                // Clear animation
                self.mergeAnimationState = nil
                print("[GameStore] Sequence complete")
                
            } catch {
                print("[GameStore] Task error: \(error)")
            }
            
            // Always unlock input when done
            if !Task.isCancelled {
                self.isInputLocked = false
            }
        }
    }
    
    /// Ensure highestTileStep and highestTile never decrease.
    /// Called after copying engine state to prevent cleanup/elimination
    /// from regressing the all-time highest achievement.
    private func preserveHighWatermark(previous: (step: Int, tile: Int)) {
        if state.highestTileStep < previous.step {
            state.highestTileStep = previous.step
        }
        if state.highestTile < previous.tile {
            state.highestTile = previous.tile
        }
    }

    private func performRefill(columns: Set<Int>? = nil) {
        let watermark = (step: state.highestTileStep, tile: state.highestTile)
        let previousBoard = state.board
        if let cols = columns, !cols.isEmpty {
            let newState = engine.refillColumns(cols)
            state = newState
            preserveHighWatermark(previous: watermark)
            markRefills(previousBoard: previousBoard, newBoard: newState.board, scopedColumns: cols)
        } else {
            let newState = engine.refillBoard()
            state = newState
            preserveHighWatermark(previous: watermark)
            scheduleRefillReveal(previousBoard: previousBoard, newBoard: newState.board, protectedPositions: [])
        }
        // Force cleanup of any tiles below the elimination threshold
        // Handles edge cases: saved state with stale tiles, cancelled tasks that skipped cleanup
        // Skip in sandboxed/challenge mode where elimination is disabled
        // Skip when elimination is deferred (pendingEliminationTiles is non-empty) —
        // the deferred elimination will handle cleanup after the notification is dismissed.
        if !sandboxed && pendingEliminationTiles.isEmpty {
            let cleanedState = engine.cleanupTilesBelowThreshold()
            state = cleanedState
            preserveHighWatermark(previous: watermark)
        }
    }

    /// Update valid moves count - call once after all board changes are complete
    private func updateValidMovesCount() {
        let oldCount = validMovesCount
        let newCount = engine.countValidMoves()
        validMovesCount = newCount

        if newCount == 0 {
            state.isGameOver = true
        }

        // Log when moves are low (1–5) with percentage change
        if newCount > 0 && newCount <= 5 && newCount != oldCount {
            if oldCount > 0 {
                let changePercent = Int(round(abs(Double(newCount - oldCount) / Double(oldCount) * 100)))
                print("⚠️ VALID MOVES: Low moves — \(oldCount) → \(newCount) (\(changePercent)% change)")
            } else {
                print("⚠️ VALID MOVES: Low moves — \(oldCount) → \(newCount)")
            }
        } else if newCount > 5 && newCount != oldCount {
            // Log large changes only when not already covered by low-moves log
            let diff = newCount - oldCount
            if oldCount > 0 {
                let changePercent = Int(round(abs(Double(diff) / Double(oldCount) * 100)))
                if changePercent > 50 {
                    if diff > 0 {
                        print("📈 VALID MOVES: Large increase — \(oldCount) → \(newCount) (+\(changePercent)% change, new milestone / board opened up)")
                    } else {
                        print("📉 VALID MOVES: Large decrease — \(oldCount) → \(newCount) (\(changePercent)% change, tile eliminated / board tightened)")
                    }
                }
            } else if oldCount == 0 && newCount > 0 {
                print("📈 VALID MOVES: Recovered from 0 → \(newCount)")
            }
        }
    }

    private func performGravityDrop(columns: Set<Int>? = nil) {
        let watermark = (step: state.highestTileStep, tile: state.highestTile)
        if let cols = columns, !cols.isEmpty {
            let newState = engine.collapseColumns(cols)
            state = newState
        } else {
            let newState = engine.applyGravityAfterChain()
            state = newState
        }
        preserveHighWatermark(previous: watermark)
        // Note: validMovesCount is updated in performRefill after gravity completes
    }
    
    @discardableResult
    private func performCommit(positions: [Position]) -> (Bool, Set<Int>) {
        // Clear power-up gem tracking — a regular move means the previous
        // power-up can no longer be undone for a gem refund.
        lastPowerUpGemSpend = nil

        let previousHighest = state.highestTile
        let previousHighestStep = state.highestTileStep
        let lastPos = positions.last
        var affectedColumns = columnsWithEmpties(in: state.board)

        // Track newly shattered glass tiles (row 0)
        var newlyBrokenGlass: [Position] = []

        // Check if ending on gift and use appropriate commit method
        let endsOnGift = lastPos.map { BoardIndex($0) }.map { state.board[$0].kind == .gift } ?? false

        let newState: GameState
        let requiresGravityDrop = true
        if endsOnGift {
            newState = engine.commitGiftChain(positions)
        } else {
            newState = engine.commitChain(positions, applyGravity: false)
        }
        
        affectedColumns = columnsWithEmpties(in: newState.board)

        // Update state but DO NOT schedule refill reveal yet, as refill hasn't happened
        // Track gems earned from this action (gifts, etc.)
        let previousGems = state.gems
        let gemsEarned = newState.gems - state.gems  // Gems awarded by engine
        state = newState
        if sandboxed {
            // Sandboxed/challenge mode: use the challenge's own gem state
            // Do NOT read from UserDefaults (that's the main game's balance)
            state.gems = previousGems + max(0, gemsEarned)
        } else {
            // Main game: use UserDefaults as source of truth to prevent race conditions
            let savedGems = UserDefaults.standard.integer(forKey: "coins")
            let baseGems = savedGems > 0 ? savedGems : previousGems
            state.gems = baseGems + max(0, gemsEarned)
        }

        // Process pending rewards (power-ups, spins from gift boxes)
        processPendingRewards()
        // We manually handle refill reveal later in performRefill
        
        // Break glass tiles for any positions in row 0 that were part of this connection
        // Skip glass breaking in sandboxed/challenge mode
        if !sandboxed {
            for position in positions {
                if position.row == 0 {
                    if brokenGlassTiles.insert(position).inserted {
                        newlyBrokenGlass.append(position)
                    }
                }
            }

            if !newlyBrokenGlass.isEmpty {
                for position in newlyBrokenGlass {
                    // Use column-based rewards instead of random
                    pendingGiftBoxes[position] = GiftReward.rewardForColumn(position.col, isFromGlassShatter: true)
                }
                persistPendingGiftBoxes()
                persistBrokenGlassTiles()
            }
        }
        // Added value is the tile now at lastPos
        let addedValue: Int = {
            if let lp = lastPos, let v = state.board[lp]?.value { return v }
            return 0
        }()
        lastAddedTileValue = addedValue > 0 ? addedValue : nil
        lastAddedTilePosition = addedValue > 0 ? lastPos : nil

        // IMPORTANT: Remove non-glass gift triggers. Gifts are only awarded on shattered glass.
        // (No milestone/random gift triggers here.)
        
        // Notify JourneyKit of the new tile value
        if addedValue > 0 {
            journey.didReach(tile: addedValue)
            // Also persist the highest tile to UserDefaults (not for sandboxed challenges)
            if !sandboxed && addedValue > previousHighest {
                UserDefaults.standard.set(addedValue, forKey: "highestTile")
            }
            
            if let lastPos,
               let tile = state.board[lastPos],
               tile.isInfinity {
                achievementEvaluator?.onInfinityCreated()
                // Fire the first-infinity event once (non-sandboxed only)
                if !sandboxed && !UserDefaults.standard.bool(forKey: "hasInfinityAchievement") {
                    didCreateFirstInfinity = true
                }
            }
            
            // Track infinity merges for Hall of Fame leaderboard
            if state.infinityMergeCount > 0 {
                let previousCount = UserDefaults.standard.integer(forKey: "infinityMergeCount")
                let newTotal = previousCount + state.infinityMergeCount
                UserDefaults.standard.set(newTotal, forKey: "infinityMergeCount")
                print("∞ HALL OF FAME: Infinity merge count updated to \(newTotal)")
            }
            
            // CRITICAL: Auto-save progress for any new tile creation
            saveProgressImmediately(newTile: addedValue)
        }
        // Offer to double only if we created a tile that is one below the previous highest
        // or another instance of the previous highest.
        // For high tiles (step >= 62), use step-based comparison since values overflow to Int.max
        if addedValue > 0 {
            if let resultPosition = lastPos {
                incrementTierMasteryCount(for: state.board[resultPosition], value: addedValue)
            }

            // Get the step of the added tile
            let addedStep: Int? = {
                if let lp = lastPos, let tile = state.board[lp] {
                    return tile.stepIndex
                }
                return TileStepLabelFormatter.stepForValue(addedValue)
            }()

            // previousHighestStep was captured at start of function, before state update
            var shouldOfferDouble = false

            if let step = addedStep {
                // Use step-based comparison (works for all tile values including high tiles)
                // Only offer double if tile is one below OR same as previous highest (not a new record)
                let isOneBelow = (previousHighestStep >= 1) && (step == previousHighestStep - 1)
                let isSameAsHighest = (step == previousHighestStep)
                shouldOfferDouble = isOneBelow || isSameAsHighest
            } else {
                // Fallback to value-based comparison for legacy cases
                let offerIfOneBelow = (previousHighest >= 4) && (addedValue == previousHighest / 2)
                let offerIfAnotherHighest = (addedValue == previousHighest)
                shouldOfferDouble = offerIfOneBelow || offerIfAnotherHighest
            }

            if shouldOfferDouble && !sandboxed {
                pendingDoubleBase = addedValue
                pendingDoubleBaseStep = addedStep
            } else {
                pendingDoubleBase = nil
                pendingDoubleBaseStep = nil
            }
        } else {
            pendingDoubleBase = nil
            pendingDoubleBaseStep = nil
        }
        // Check if we created a new highest tile and show milestone notifications
        let currentStep = state.highestTileStep
        let isNewHighest = currentStep > previousHighestStep || state.highestTile > previousHighest
        print("🔔 MILESTONE CHECK: previousStep=\(previousHighestStep) currentStep=\(currentStep) previousHighest=\(previousHighest) currentHighest=\(state.highestTile) isNewHighest=\(isNewHighest)")
        if isNewHighest {
            // Show unlock/added/eliminated notifications
            setMergeInfoIfMilestone(
                previousHighest: previousHighest,
                newTileValue: state.highestTile,
                previousStep: previousHighestStep,
                newStep: currentStep
            )
            setPendingUnlockRewardIfNeeded(for: state.highestTile, previousHigh: previousHighest)
        }
        movesHistory.append(positions)
        
        // Update session analytics
        updateSessionAnalytics()
        trackMoveAnalytics(move: positions)
        
        // Track surviving moves (total moves taken while still in play)
        achievementEvaluator?.onMoveSurvived()
        
        // Evaluate achievements
        achievementEvaluator?.onChainCommitted(chain: positions, state: state, resultingTileValue: addedValue)

        // Check if game just ended and notify achievement evaluator
        checkAndProcessGameOver()

        // Auto-save progress for score changes and achievements
        saveProgressImmediately(newTile: addedValue)

        return (requiresGravityDrop, affectedColumns)
    }

    /// Check if game just ended and notify achievement evaluator (only once per game)
    private func checkAndProcessGameOver() {
        guard state.isGameOver, !gameOverProcessed else { return }
        gameOverProcessed = true
        // Game ended - notify achievement evaluator to save playtime and other stats
        achievementEvaluator?.onGameEnd(state: state, won: state.highestTile >= 2244)
        if !sandboxed {
            onGameEnded?(currentRunSummary())
        }
        #if DEBUG
        print("🎮 Game over processed - playtime saved")
        #endif
    }

    public func currentRunSummary(endedAt: Date = Date()) -> GameRunSummary {
        GameRunSummary(
            score: state.score,
            scoreAlpha: state.scoreValue,
            highestTile: state.highestTile,
            highestTileStep: state.highestTileStep,
            moves: state.moves,
            duration: endedAt.timeIntervalSince(runStartedAt),
            seed: engine.seedUsed,
            infinityMergeCount: state.infinityMergeCount,
            endedAt: endedAt
        )
    }

    private static let mergeAnimationDelay: UInt64 = 260_000_000
    private static let gravityAnimationDelay: UInt64 = 260_000_000
    private static let refillRevealDelay: UInt64 = 240_000_000
    private static let magnetSuckDelay: UInt64 = 400_000_000
    private static let hammerWindupDelay: UInt64 = 250_000_000
    private static let hammerImpactDelay: UInt64 = 250_000_000
    private static let eliminationAnimationDelay: UInt64 = 500_000_000  // 0.5s for elimination fade
    
    private func applyStateUpdate(
        _ newState: GameState,
        previousBoard: Board,
        refillProtectedPositions: Set<Position> = []
    ) {
        // Preserve gems: in sandboxed mode use challenge's own state,
        // in main game use UserDefaults as source of truth for spending
        let gemsToUse: Int
        if sandboxed {
            gemsToUse = state.gems
        } else {
            let savedGems = UserDefaults.standard.integer(forKey: "coins")
            gemsToUse = savedGems > 0 ? savedGems : state.gems
        }
        // Preserve highestTileStep/highestTile as permanent high watermarks.
        // These represent all-time achievements and must never decrease,
        // even if the tile is removed from the board by cleanup or elimination.
        let previousHighestStep = state.highestTileStep
        let previousHighestTile = state.highestTile
        state = newState
        state.gems = gemsToUse
        if state.highestTileStep < previousHighestStep {
            state.highestTileStep = previousHighestStep
        }
        if state.highestTile < previousHighestTile {
            state.highestTile = previousHighestTile
        }
        // Note: caller is responsible for calling updateValidMovesCount() when done
        scheduleRefillReveal(previousBoard: previousBoard, newBoard: newState.board, protectedPositions: refillProtectedPositions)
    }
    
    private func scheduleRefillReveal(previousBoard: Board, newBoard: Board, protectedPositions: Set<Position>) {
        cancelRefillRevealTask()
        let newPositions = detectNewSpawnPositions(previousBoard: previousBoard, newBoard: newBoard)
            .subtracting(protectedPositions)
        pendingRefillPositions = newPositions
        
        guard !newPositions.isEmpty else {
            refillRevealTask = nil
            return
        }
        
        refillRevealTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Self.refillRevealDelay)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.pendingRefillPositions.removeAll()
            }
        }
    }
    
    @MainActor
    private func cancelRefillRevealTask() {
        refillRevealTask?.cancel()
        refillRevealTask = nil
    }
    
    @MainActor
    private func cancelMergeCleanupTask() {
        mergeCleanupTask?.cancel()
        mergeCleanupTask = nil
        mergeAnimationState = nil
        hammerAnimationState = nil
        isInputLocked = false
    }
    
    private func detectNewSpawnPositions(previousBoard: Board, newBoard: Board) -> Set<Position> {
        var existingIDs: Set<UUID> = []
        for row in 0..<previousBoard.height {
            for col in 0..<previousBoard.width {
                let position = Position(row: row, col: col)
                if let tile = previousBoard[position] {
                    existingIDs.insert(tile.id)
                }
            }
        }
        
        var result: Set<Position> = []
        for row in 0..<newBoard.height {
            for col in 0..<newBoard.width {
                let position = Position(row: row, col: col)
                guard let tile = newBoard[position] else { continue }
                guard previousBoard[position] == nil else { continue }
                if existingIDs.contains(tile.id) { continue }
                result.insert(position)
            }
        }
        return result
    }
    
    public func resetGame() {
        engine = GameEngine(config: GameConfig())

        // Note: Gift row initialization is optional
        // _ = engine.initializeGiftRow()

        state = engine.currentState()
        refreshDerivedState(highestStep: persistedHighestTileStep())
        syncEngineScoreBoost()
        cancelRefillRevealTask()
        cancelMergeCleanupTask()
        pendingRefillPositions = []
        currentPath = []
        pathValidation = .valid
        isInputLocked = false
        lastAddedTileValue = nil
        pendingDoubleBase = nil
        pendingDoubleBaseStep = nil
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false  // Reset for new game session
        gameOverConfirmed = false
        runStartedAt = Date()

        // Notify achievement evaluator
        achievementEvaluator?.onGameStart(state: state)
    }

    /// Reset game at a specific milestone step (gem-purchased head start)
    /// The board fills with tiles in a 4-step window around the milestone.
    public func resetGameAtMilestone(step: Int) {
        let minStep = max(0, step - 3)
        let config = GameConfig(
            minSpawnStep: minStep,
            maxSpawnStep: step
        )
        engine = GameEngine(config: config)

        state = engine.currentState()
        refreshDerivedState(highestStep: persistedHighestTileStep())
        syncEngineScoreBoost()
        cancelRefillRevealTask()
        cancelMergeCleanupTask()
        pendingRefillPositions = []
        currentPath = []
        pathValidation = .valid
        isInputLocked = false
        lastAddedTileValue = nil
        pendingDoubleBase = nil
        pendingDoubleBaseStep = nil
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false
        gameOverConfirmed = false
        runStartedAt = Date()

        achievementEvaluator?.onGameStart(state: state)
    }

    /// Reset game with a custom GameConfig (used for challenge mode)
    public func resetGame(with config: GameConfig) {
        engine = GameEngine(config: config)

        state = engine.currentState()
        refreshDerivedState(highestStep: sandboxed ? nil : persistedHighestTileStep())
        syncEngineScoreBoost()
        cancelRefillRevealTask()
        cancelMergeCleanupTask()
        pendingRefillPositions = []
        currentPath = []
        pathValidation = .valid
        isInputLocked = false
        lastAddedTileValue = nil
        pendingDoubleBase = nil
        pendingDoubleBaseStep = nil
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false
        gameOverConfirmed = false
        runStartedAt = Date()

        achievementEvaluator?.onGameStart(state: state)
    }

    // Start a new game with a custom seed (user-designed challenge)
    public func startCustomGame(seed: UInt64) {
        engine = GameEngine(config: GameConfig(seed: seed))
        
        // Note: Gift row initialization is optional
        // _ = engine.initializeGiftRow()
        
        state = engine.currentState()
        refreshDerivedState(highestStep: persistedHighestTileStep())
        syncEngineScoreBoost()
        cancelRefillRevealTask()
        cancelMergeCleanupTask()
        pendingRefillPositions = []
        currentPath = []
        pathValidation = .valid
        isInputLocked = false
        lastAddedTileValue = nil
        pendingDoubleBase = nil
        pendingDoubleBaseStep = nil
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false  // Reset for new game session
        gameOverConfirmed = false
        runStartedAt = Date()
    }


    // MARK: - Economy
    public func addCoins(_ amount: Int) {
        state.gems = max(0, state.gems + amount)
        syncEngineGems()
        if !sandboxed {
            UserDefaults.standard.set(state.gems, forKey: "coins")
            saveProgressToStore()
        }
    }

    public func claimJourneyReward(coins: Int) {
        addCoins(coins)
        print("🎁 Claimed journey reward: +\(coins) coins")
        saveProgressToStore()
    }
    
    public func spendCoins(_ amount: Int) -> Bool {
        guard state.gems >= amount else { return false }
        state.gems -= amount
        syncEngineGems()
        if !sandboxed {
            UserDefaults.standard.set(state.gems, forKey: "coins")
            // Force immediate synchronization to prevent race conditions
            UserDefaults.standard.synchronize()
            // Also save to progress store immediately
            saveProgressToStore()
        }
        print("💰 Spent \(amount) gems. New balance: \(state.gems)")
        return true
    }
    
    @discardableResult
    public func purchaseScoreBoost(_ tierID: ScoreBoostTierID, now date: Date = Date()) -> Bool {
        let tier = scoreBoostTier(tierID)
        guard spendCoins(tier.cost) else { return false }
        
        if activeScoreBoostTierID == nil {
            activateScoreBoost(tierID: tierID, now: date)
        } else if activeScoreBoostTierID == tierID {
            activateScoreBoost(tierID: tierID, now: date)
        } else {
            queuedScoreBoostTierID = tierID
            persistScoreBoostState()
            print("⚡️ Queued \(tier.label) boost. It will start after the current boost ends.")
        }
        
        saveProgressToStore()
        return true
    }
    
    @discardableResult
    public func purchasePowerDiscount(_ tierID: PowerDiscountTierID, now date: Date = Date()) -> Bool {
        let tier = powerDiscountTier(tierID)
        guard spendCoins(tier.cost) else { return false }
        
        if activePowerDiscountTierID == nil {
            activatePowerDiscount(tierID: tierID, now: date)
        } else if activePowerDiscountTierID == tierID {
            activatePowerDiscount(tierID: tierID, now: date)
        } else {
            queuedPowerDiscountTierID = tierID
            persistPowerDiscountState()
            print("🪄 Queued \(tier.label). It will start after the current discount ends.")
        }
        
        saveProgressToStore()
        return true
    }
    
    // MARK: - Score Boost Lifecycle
    
    private func activateScoreBoost(tierID: ScoreBoostTierID, now date: Date = Date(), persist: Bool = true) {
        let tier = scoreBoostTier(tierID)
        let expiration = date.addingTimeInterval(tier.duration)
        activateScoreBoost(tierID: tierID, expiresAt: expiration, now: date, persist: persist)
    }
    
    private func activateScoreBoost(tierID: ScoreBoostTierID, expiresAt expiration: Date, now date: Date = Date(), persist: Bool = true) {
        activeScoreBoostTierID = tierID
        scoreBoostExpiresAt = expiration
        scoreBoostRemaining = max(0, expiration.timeIntervalSince(date))
        if queuedScoreBoostTierID == tierID {
            queuedScoreBoostTierID = nil
        }
        syncEngineScoreBoost()
        if persist {
            persistScoreBoostState()
        }
        if expiration > date {
            startScoreBoostTicker()
            refreshScoreBoostCountdown(now: date)
        } else {
            finishActiveBoost(now: date)
        }
    }
    
    private func finishActiveBoost(now date: Date = Date()) {
        activeScoreBoostTierID = nil
        scoreBoostExpiresAt = nil
        scoreBoostRemaining = 0
        syncEngineScoreBoost()
        persistScoreBoostState()
        cancelScoreBoostTicker()
        startQueuedBoostIfNeeded(now: date)
    }
    
    private func startQueuedBoostIfNeeded(now date: Date = Date()) {
        guard let queuedID = queuedScoreBoostTierID else { return }
        queuedScoreBoostTierID = nil
        persistScoreBoostState()
        activateScoreBoost(tierID: queuedID, now: date)
    }
    
    private func refreshScoreBoostCountdown(now date: Date = Date()) {
        guard let expiration = scoreBoostExpiresAt, activeScoreBoostTierID != nil else {
            if activeScoreBoostTierID != nil {
                finishActiveBoost(now: date)
            } else if activeScoreBoostTierID == nil {
                startQueuedBoostIfNeeded(now: date)
            }
            return
        }
        let remaining = expiration.timeIntervalSince(date)
        if remaining <= 0 {
            finishActiveBoost(now: date)
        } else {
            scoreBoostRemaining = remaining
        }
    }
    
    private func restoreScoreBoostState(from progress: GameProgress?) {
        let defaults = UserDefaults.standard
        let defaultsTierID = defaults.string(forKey: ScoreBoostDefaultsKey.activeTierID).flatMap(ScoreBoostTierID.init(rawValue:))
        let defaultsExpiration = defaults.object(forKey: ScoreBoostDefaultsKey.activeExpiration) as? Date
        let progressTierID: ScoreBoostTierID? = {
            guard let rawValue = progress?.activeScoreBoost?.tierID else { return nil }
            return ScoreBoostTierID(rawValue: rawValue)
        }()
        let progressExpiration = progress?.activeScoreBoost?.expiresAt
        let now = Date()
        
        let candidates = [
            (defaultsTierID, defaultsExpiration),
            (progressTierID, progressExpiration)
        ].compactMap { (maybeID, maybeDate) -> (ScoreBoostTierID, Date)? in
            guard let id = maybeID, let date = maybeDate else { return nil }
            return (id, date)
        }.filter { $0.1 > now }
        
        if let (tierID, expiration) = candidates.max(by: { $0.1 < $1.1 }) {
            activateScoreBoost(tierID: tierID, expiresAt: expiration, now: now, persist: false)
        } else {
            activeScoreBoostTierID = nil
            scoreBoostExpiresAt = nil
            scoreBoostRemaining = 0
            syncEngineScoreBoost()
            persistScoreBoostState()
        }
        
        let queuedFromProgress: ScoreBoostTierID? = {
            guard let rawValue = progress?.queuedScoreBoostTierID else { return nil }
            return ScoreBoostTierID(rawValue: rawValue)
        }()
        let queuedFromDefaults = defaults.string(forKey: ScoreBoostDefaultsKey.queuedTierID).flatMap(ScoreBoostTierID.init(rawValue:))
        queuedScoreBoostTierID = queuedFromProgress ?? queuedFromDefaults
        if queuedScoreBoostTierID == activeScoreBoostTierID {
            queuedScoreBoostTierID = nil
        }
        persistScoreBoostState()
        refreshScoreBoostCountdown(now: now)
        if activeScoreBoostTierID != nil {
            startScoreBoostTicker()
        }
    }
    
    private func startScoreBoostTicker() {
        scoreBoostTickerTask?.cancel()
        guard activeScoreBoostTierID != nil else { return }
        scoreBoostTickerTask = Task { @MainActor [weak self] in
            while let self, self.activeScoreBoostTierID != nil {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                self.refreshScoreBoostCountdown()
            }
        }
    }
    
    private func cancelScoreBoostTicker() {
        scoreBoostTickerTask?.cancel()
        scoreBoostTickerTask = nil
    }
    
    // MARK: - Power Discount Lifecycle
    
    private func activatePowerDiscount(tierID: PowerDiscountTierID, now date: Date = Date(), persist: Bool = true) {
        let tier = powerDiscountTier(tierID)
        let expiration = date.addingTimeInterval(tier.duration)
        activatePowerDiscount(tierID: tierID, expiresAt: expiration, now: date, persist: persist)
    }
    
    private func activatePowerDiscount(tierID: PowerDiscountTierID, expiresAt expiration: Date, now date: Date = Date(), persist: Bool = true) {
        activePowerDiscountTierID = tierID
        powerDiscountExpiresAt = expiration
        powerDiscountRemaining = max(0, expiration.timeIntervalSince(date))
        if queuedPowerDiscountTierID == tierID {
            queuedPowerDiscountTierID = nil
        }
        if persist {
            persistPowerDiscountState()
        }
        if expiration > date {
            startPowerDiscountTicker()
            refreshPowerDiscountCountdown(now: date)
        } else {
            finishActivePowerDiscount(now: date)
        }
    }
    
    private func finishActivePowerDiscount(now date: Date = Date()) {
        activePowerDiscountTierID = nil
        powerDiscountExpiresAt = nil
        powerDiscountRemaining = 0
        persistPowerDiscountState()
        cancelPowerDiscountTicker()
        startQueuedPowerDiscountIfNeeded(now: date)
    }
    
    private func startQueuedPowerDiscountIfNeeded(now date: Date = Date()) {
        guard let queuedID = queuedPowerDiscountTierID else { return }
        queuedPowerDiscountTierID = nil
        persistPowerDiscountState()
        activatePowerDiscount(tierID: queuedID, now: date)
    }
    
    private func refreshPowerDiscountCountdown(now date: Date = Date()) {
        guard let expiration = powerDiscountExpiresAt, activePowerDiscountTierID != nil else {
            if activePowerDiscountTierID != nil {
                finishActivePowerDiscount(now: date)
            } else if activePowerDiscountTierID == nil {
                startQueuedPowerDiscountIfNeeded(now: date)
            }
            return
        }
        let remaining = expiration.timeIntervalSince(date)
        if remaining <= 0 {
            finishActivePowerDiscount(now: date)
        } else {
            powerDiscountRemaining = remaining
        }
    }
    
    private func restorePowerDiscountState(from progress: GameProgress?) {
        let defaults = UserDefaults.standard
        let defaultsTierID = defaults.string(forKey: PowerDiscountDefaultsKey.activeTierID).flatMap(PowerDiscountTierID.init(rawValue:))
        let defaultsExpiration = defaults.object(forKey: PowerDiscountDefaultsKey.activeExpiration) as? Date
        let progressTierID: PowerDiscountTierID? = {
            guard let rawValue = progress?.activePowerDiscount?.tierID else { return nil }
            return PowerDiscountTierID(rawValue: rawValue)
        }()
        let progressExpiration = progress?.activePowerDiscount?.expiresAt
        let now = Date()
        
        let candidates = [
            (defaultsTierID, defaultsExpiration),
            (progressTierID, progressExpiration)
        ].compactMap { (maybeID, maybeDate) -> (PowerDiscountTierID, Date)? in
            guard let id = maybeID, let date = maybeDate else { return nil }
            return (id, date)
        }.filter { $0.1 > now }
        
        if let (tierID, expiration) = candidates.max(by: { $0.1 < $1.1 }) {
            activatePowerDiscount(tierID: tierID, expiresAt: expiration, now: now, persist: false)
        } else {
            activePowerDiscountTierID = nil
            powerDiscountExpiresAt = nil
            powerDiscountRemaining = 0
            persistPowerDiscountState()
        }
        
        let queuedFromProgress: PowerDiscountTierID? = {
            guard let rawValue = progress?.queuedPowerDiscountTierID else { return nil }
            return PowerDiscountTierID(rawValue: rawValue)
        }()
        let queuedFromDefaults = defaults.string(forKey: PowerDiscountDefaultsKey.queuedTierID).flatMap(PowerDiscountTierID.init(rawValue:))
        queuedPowerDiscountTierID = queuedFromProgress ?? queuedFromDefaults
        if queuedPowerDiscountTierID == activePowerDiscountTierID {
            queuedPowerDiscountTierID = nil
        }
        persistPowerDiscountState()
        refreshPowerDiscountCountdown(now: now)
        if activePowerDiscountTierID != nil {
            startPowerDiscountTicker()
        }
    }
    
    private func startPowerDiscountTicker() {
        powerDiscountTickerTask?.cancel()
        guard activePowerDiscountTierID != nil else { return }
        powerDiscountTickerTask = Task { @MainActor [weak self] in
            while let self, self.activePowerDiscountTierID != nil {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                self.refreshPowerDiscountCountdown()
            }
        }
    }
    
    private func cancelPowerDiscountTicker() {
        powerDiscountTickerTask?.cancel()
        powerDiscountTickerTask = nil
    }

    // MARK: - Achievement Boost Lifecycle

    private func activateAchievementBoost(tierID: AchievementBoostTierID, now date: Date = Date(), persist: Bool = true) {
        let tier = achievementBoostTier(tierID)
        // If same tier is already active, extend the duration
        if activeAchievementBoostTierID == tierID, let existingExpiration = achievementBoostExpiresAt, existingExpiration > date {
            let newExpiration = existingExpiration.addingTimeInterval(tier.duration)
            achievementBoostExpiresAt = newExpiration
            achievementBoostRemaining = max(0, newExpiration.timeIntervalSince(date))
        } else {
            // New activation or different tier - start fresh
            activeAchievementBoostTierID = tierID
            let expiration = date.addingTimeInterval(tier.duration)
            achievementBoostExpiresAt = expiration
            achievementBoostRemaining = max(0, expiration.timeIntervalSince(date))
        }
        if persist {
            persistAchievementBoostState()
        }
        startAchievementBoostTicker()
        print("🏆 Achievement Boost activated! \(tier.multiplier)× progress for \(Int(tier.duration / 60)) minutes")
    }

    private func finishAchievementBoost() {
        activeAchievementBoostTierID = nil
        achievementBoostExpiresAt = nil
        achievementBoostRemaining = 0
        persistAchievementBoostState()
        cancelAchievementBoostTicker()
        print("🏆 Achievement Boost expired")
    }

    private func refreshAchievementBoostCountdown(now date: Date = Date()) {
        guard let expiration = achievementBoostExpiresAt else {
            return
        }
        let remaining = expiration.timeIntervalSince(date)
        if remaining <= 0 {
            finishAchievementBoost()
        } else {
            achievementBoostRemaining = remaining
        }
    }

    private func persistAchievementBoostState() {
        let defaults = UserDefaults.standard
        if let tierID = activeAchievementBoostTierID, let expiresAt = achievementBoostExpiresAt {
            defaults.set(tierID.rawValue, forKey: AchievementBoostDefaultsKey.activeTierID)
            defaults.set(expiresAt, forKey: AchievementBoostDefaultsKey.activeExpiration)
        } else {
            defaults.removeObject(forKey: AchievementBoostDefaultsKey.activeTierID)
            defaults.removeObject(forKey: AchievementBoostDefaultsKey.activeExpiration)
        }
    }

    private func restoreAchievementBoostState() {
        let defaults = UserDefaults.standard
        guard let tierIDRaw = defaults.string(forKey: AchievementBoostDefaultsKey.activeTierID),
              let tierID = AchievementBoostTierID(rawValue: tierIDRaw),
              let expiration = defaults.object(forKey: AchievementBoostDefaultsKey.activeExpiration) as? Date else {
            return
        }
        let now = Date()
        if expiration > now {
            activeAchievementBoostTierID = tierID
            achievementBoostExpiresAt = expiration
            achievementBoostRemaining = expiration.timeIntervalSince(now)
            startAchievementBoostTicker()
        } else {
            defaults.removeObject(forKey: AchievementBoostDefaultsKey.activeTierID)
            defaults.removeObject(forKey: AchievementBoostDefaultsKey.activeExpiration)
        }
    }

    private func startAchievementBoostTicker() {
        achievementBoostTickerTask?.cancel()
        guard achievementBoostExpiresAt != nil else { return }
        achievementBoostTickerTask = Task { @MainActor [weak self] in
            while let self, self.achievementBoostExpiresAt != nil {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                self.refreshAchievementBoostCountdown()
            }
        }
    }

    private func cancelAchievementBoostTicker() {
        achievementBoostTickerTask?.cancel()
        achievementBoostTickerTask = nil
    }

    // MARK: - Unlock Rewards

    /// Calculate unlock reward based on tile step (power of 2 exponent - 1).
    /// This handles values beyond Int.max by using step-based math.
    /// Step 8 = 512 (2^9), Step 9 = 1024 (2^10), etc.
    private func baseUnlockRewardForStep(_ step: Int) -> Int {
        // Milestone rewards start at step 8 (512 = 2^9) with +2 gems per subsequent milestone.
        // Step 8 = 50 gems, Step 9 = 52 gems, Step 10 = 54 gems, etc.
        guard step >= 8 else { return 0 }
        let stepsFromFirstMilestone = step - 8
        return 50 + (stepsFromFirstMilestone * 2)
    }

    /// Legacy function for backward compatibility with lower tile values.
    private func baseUnlockReward(for tileValue: Int) -> Int {
        // For values that overflow or are at Int.max, use step-based calculation
        if tileValue >= Int.max || tileValue.nonzeroBitCount != 1 {
            return 0 // Will be handled by step-based version
        }
        // Milestone rewards start at 512 (2^9) with +2 gems per subsequent milestone.
        guard tileValue >= 512 else { return 0 }
        let exponent = tileValue.trailingZeroBitCount
        let stepsFromFirstMilestone = max(0, exponent - 9)
        return 50 + (stepsFromFirstMilestone * 2)
    }

    private func setPendingUnlockRewardIfNeeded(for newHigh: Int, previousHigh: Int) {
        // Skip unlock rewards in sandboxed/challenge mode
        guard !sandboxed else { return }
        // Use step-based comparison for reliable handling of values beyond Int.max
        let newStep = state.highestTileStep
        let previousStep = TileStepLabelFormatter.stepForValue(previousHigh, start: 2) ?? 0

        guard newStep > previousStep else { return }
        // Skip unlock rewards in sandboxed (challenge) mode
        guard !sandboxed else { return }

        // Use step-based reward calculation to handle arbitrarily large tile values
        let base = baseUnlockRewardForStep(newStep)
        guard base > 0 else { return }

        pendingUnlockRewardBase = base
        pendingUnlockTile = newHigh
    }
    
    public func claimPendingUnlockReward(multiplier: Int) {
        guard let base = pendingUnlockRewardBase, base > 0 else { return }
        let total = max(1, multiplier) * base
        addCoins(total)
        clearPendingUnlockReward()
    }
    
    public func clearPendingUnlockReward() {
        pendingUnlockRewardBase = nil
        pendingUnlockTile = nil
    }

    
    // MARK: - Gift Rewards

    public func isAbbreviationTierUnlocked(_ tier: JourneyAbbreviationTier) -> Bool {
        if tier.isInfinity {
            return boardContainsInfinityTile() || UserDefaults.standard.bool(forKey: "hasInfinityAchievement")
        }
        guard let step = tier.step, let highestStep = currentHighestJourneyStep() else { return false }
        return highestStep >= step
    }
    
    public func hasClaimedAbbreviationTier(_ tier: JourneyAbbreviationTier) -> Bool {
        claimedJourneyAbbreviationRewards.contains(tier.id)
    }
    
    public func presentJourneyReward(for tier: JourneyAbbreviationTier) {
        guard pendingGiftReward == nil else { return }
        // Skip gift rewards in sandboxed (challenge) mode
        guard !sandboxed else { return }
        guard isAbbreviationTierUnlocked(tier), !hasClaimedAbbreviationTier(tier) else { return }
        pendingJourneyRewardTierID = tier.id
        pendingGiftReward = JourneyAbbreviationRewardCurve.reward(for: tier)
    }
    
    public func claimGiftReward() {
        guard let reward = pendingGiftReward else { return }

        let contextKey: String
        if let tierID = pendingJourneyRewardTierID {
            contextKey = "journey:\(tierID)"
        } else {
            contextKey = "gift:\(reward.message):\(reward.items.count):\(Int(Date().timeIntervalSince1970))"
        }

        // Apply the rewards to the player's inventory; route each through the
        // ledger when one is wired so we get an idempotent audit trail.
        for (index, item) in reward.items.enumerated() {
            let key = "\(contextKey):\(index):\(item.type.rawValue):\(item.amount)"
            applyGiftItem(item, source: pendingJourneyRewardTierID != nil ? .journey : .gift, key: key)
        }

        // Clear the pending reward
        pendingGiftReward = nil

        if let tierID = pendingJourneyRewardTierID {
            claimedJourneyAbbreviationRewards.insert(tierID)
            persistAbbreviationClaims()
            pendingJourneyRewardTierID = nil
        }
    }

    private func applyGiftItem(
        _ item: GiftRewardItem,
        source: RewardLedgerEntry.Source,
        key: String
    ) {
        let apply: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            switch item.type {
            case .hammer:
                self.addPowerUp("hammer", count: item.amount)
            case .magnet:
                self.addPowerUp("magnet", count: item.amount)
            case .gems:
                self.addCoins(item.amount)
            case .swap:
                self.addPowerUp("swap", count: item.amount)
            case .undo:
                self.addPowerUp("undo", count: item.amount)
            case .bonusSpin:
                self.addBonusSpins(item.amount)
            case .boost2x:
                self.addMultipliers(.twoX, count: item.amount)
            case .boost3x:
                self.addMultipliers(.threeX, count: item.amount)
            case .boost4x:
                self.addMultipliers(.fourX, count: item.amount)
            }
        }

        guard let ledger = rewardLedger else {
            apply()
            return
        }

        ledger.grant(
            source: source,
            itemType: ledgerItemType(for: item.type),
            amount: item.amount,
            idempotencyKey: key,
            apply: apply
        )
    }

    private func ledgerItemType(for giftType: GiftRewardItem.GiftType) -> RewardLedgerEntry.ItemType {
        switch giftType {
        case .gems: return .gems
        case .hammer: return .hammer
        case .magnet: return .magnet
        case .swap: return .swap
        case .undo: return .undo
        case .bonusSpin: return .spin
        case .boost2x: return .multiplier2x
        case .boost3x: return .multiplier3x
        case .boost4x: return .multiplier4x
        }
    }
    
    public func dismissGiftReward() {
        pendingGiftReward = nil
        pendingJourneyRewardTierID = nil
    }
    
    public func tapGiftBox(at position: Position) {
        guard pendingGiftReward == nil else { return }
        // Skip gift boxes in sandboxed (challenge) mode
        guard !sandboxed else { return }
        guard let reward = pendingGiftBoxes.removeValue(forKey: position) else { return }
        pendingJourneyRewardTierID = nil
        pendingGiftReward = reward
        persistPendingGiftBoxes()
    }
    
    // MARK: - Double Offer
    public func clearPendingDoubleOffer() {
        pendingDoubleBase = nil
        pendingDoubleBaseStep = nil
    }

    /// Immediately apply the pending double to the last added tile position
    @discardableResult
    public func applyPendingDouble() -> Bool {
        guard let position = lastAddedTilePosition else { return false }
        return applyDouble(to: position)
    }

    @discardableResult
    public func applyDouble(to position: Position) -> Bool {
        guard let base = pendingDoubleBase else { return false }

        // Capture previous highest for milestone detection
        let previousHighest = state.highestTile
        let previousHighestStep = state.highestTileStep

        // Get the base step - use stored step for high-value tiles, calculate for normal values
        let baseStep = pendingDoubleBaseStep ?? TileStepLabelFormatter.stepForValue(base, start: 2) ?? 0
        let doubledStep = baseStep + 1

        let previousBoard = state.board
        // Pass the base step to handle high-value tiles correctly
        // Defer elimination so tiles stay until notifications complete
        engine.deferElimination = true
        let newState = engine.applyDouble(to: position, from: base, baseStep: baseStep)
        engine.deferElimination = false
        applyStateUpdate(newState, previousBoard: previousBoard, refillProtectedPositions: Set([position]))
        pendingDoubleBase = nil
        pendingDoubleBaseStep = nil

        // Store any deferred elimination tiles
        let eliminatedTiles = engine.lastMilestoneEliminatedTiles
        if !eliminatedTiles.isEmpty {
            print("[GameStore] Double: Storing \(eliminatedTiles.count) tiles for deferred elimination")
            pendingEliminationTiles = eliminatedTiles
        }

        // Notify JourneyKit if we created a new highest tile
        // Use safe multiplication to prevent overflow
        let doubledValue = base <= (Int.max >> 1) ? base * 2 : Int.max
        journey.didReach(tile: doubledValue)

        // Show milestone notification if this created a new highest tile
        // Pass steps for high-value tiles to enable proper comparison
        setMergeInfoIfMilestone(
            previousHighest: previousHighest,
            newTileValue: doubledValue,
            previousStep: previousHighestStep,
            newStep: doubledStep
        )

        // Persist if this is a new highest tile
        let isHighStep = doubledStep >= 62

        // Use step-based comparison for very high tiles to avoid overflow issues
        let shouldPersist = isHighStep ? (doubledStep > state.highestTileStep) : (doubledValue > state.highestTile)

        if shouldPersist {
            state.highestTileStep = doubledStep
            // Persist to UserDefaults (not for sandboxed challenges)
            if !sandboxed {
                UserDefaults.standard.set(doubledValue, forKey: "highestTile")
                // Save formatted milestone for leaderboard display
                // Use step-based formatting for high values to avoid overflow
                let formattedMilestone: String
                if isHighStep {
                    formattedMilestone = TileStepLabelFormatter.labelForStep(doubledStep, start: 2)
                } else {
                    formattedMilestone = TileStepLabelFormatter.formatTileValue(doubledValue)
                }
                UserDefaults.standard.set(formattedMilestone, forKey: "leaderboard.milestone")
            }
        }

        // Save progress for doubled tile (could be massive achievement)
        saveProgressImmediately(newTile: doubledValue)

        // Update valid moves count at the end
        updateValidMovesCount()

        return true
    }

    public func clearLastMagnetEvent() {
        lastMagnetEvent = nil
    }
    
    private var notificationWatchdog: Task<Void, Never>?

    private func showNextNotification() {
        // Cancel any existing watchdog
        notificationWatchdog?.cancel()

        guard !notificationQueue.isEmpty else {
            currentNotification = nil
            return
        }
        currentNotification = notificationQueue.removeFirst()

        // Start a watchdog timer — if the notification hasn't been dismissed within
        // 30 seconds (e.g., SwiftUI sheet failed to present), auto-dismiss it so
        // the queue doesn't get permanently stuck.
        notificationWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            guard !Task.isCancelled, let self, self.currentNotification != nil else { return }
            print("🔔 WATCHDOG: Auto-dismissing stale notification")
            self.dismissCurrentNotification()
        }
    }
    
    public func dismissCurrentNotification() {
        // Cancel watchdog since the notification was properly dismissed
        notificationWatchdog?.cancel()
        notificationWatchdog = nil

        // Check if we're dismissing an excluded notification - trigger elimination animation
        // after a short delay so the notification overlay finishes its dismiss animation first.
        if case .excluded(_, _) = currentNotification, !pendingEliminationTiles.isEmpty {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                self?.triggerEliminationAnimation()
            }
        }
        currentNotification = nil
        // Delay before showing next notification so SwiftUI can complete the
        // sheet dismiss animation. Without this, the binding goes
        // true→false→true in a single frame and SwiftUI won't re-present.
        if !notificationQueue.isEmpty {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                showNextNotification()
            }
        } else if !pendingEliminationTiles.isEmpty {
            // All notifications are done but deferred elimination was never triggered
            // (e.g., no excluded notification was queued). Apply now.
            triggerEliminationAnimation()
        }
    }

    /// Acknowledge the first-infinity event (called by UI after playing the cheer sound)
    public func clearFirstInfinityEvent() {
        didCreateFirstInfinity = false
    }

    /// Trigger the elimination ghost animation after excluded notification is dismissed,
    /// then apply the deferred elimination to actually remove tiles from the board.
    private func triggerEliminationAnimation() {
        print("[GameStore] Triggering elimination animation for \(pendingEliminationTiles.count) tiles")
        milestoneEliminatedTiles = pendingEliminationTiles
        pendingEliminationTiles = []

        // Apply the deferred elimination now — removes tiles from the board and refills.
        // The ghost overlay is already showing, so the user sees the fade-out animation
        // while the board updates underneath.
        state = engine.applyDeferredElimination()

        // Clear ghost overlay after animation completes
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.eliminationAnimationDelay)
            self.milestoneEliminatedTiles = []
        }
    }
    
    /// Queue milestone notifications in the order: unlocked → added → eliminated.
    /// Only shows notifications for actual changes (not for skip milestones)
    /// For high-value tiles (step >= 62), pass the steps directly since values overflow to Int.max.
    private func setMergeInfoIfMilestone(previousHighest: Int, newTileValue: Int, previousStep: Int? = nil, newStep: Int? = nil) {
        // For high-value tiles, use step-based comparison
        let isHighValueTile = (newStep ?? 0) >= 62 || (previousStep ?? 0) >= 62

        if isHighValueTile {
            // For high-value tiles, we MUST have both steps provided and newStep > prevStep
            // to show a milestone notification. Otherwise, it's not a new milestone.
            guard let prevStep = previousStep, let newStepVal = newStep, newStepVal > prevStep else {
                // Not a new milestone - don't show any notification
                print("🔔 HIGH-VALUE SKIP: prevStep=\(previousStep as Any) newStep=\(newStep as Any) - guard failed")
                return
            }

            // Skip pattern for high-value milestones:
            // Matches milestoneExcludedValue: (step+1 - 26) % 3 == 2 → skip
            // step+1 = log2(milestone), log67M = 26
            let isSkipMilestone = (newStepVal + 1 - 26) % 3 == 2

            // Pre-select unique phrases for this milestone sequence
            let notificationCount = isSkipMilestone ? 1 : 3
            let phrases = Self.pickUniquePhrases(notificationCount)

            // Step-based notification for high-value tiles
            var pending: [MergeNotification] = []
            pending.append(.unlocked(newTileValue, celebrationPhrase: phrases[0]))

            if !isSkipMilestone {
                // Added = eliminated << 7 = milestone >> 7 (step - 7)
                // Use Int.max as placeholder - the UI formats based on step
                pending.append(.added(Int.max, celebrationPhrase: phrases[1]))

                // Eliminated = milestone >> 12 (step - 12)
                // Use Int.max as placeholder - the UI formats based on step
                pending.append(.excluded(Int.max, celebrationPhrase: phrases[2]))
            }

            enqueueNotifications(pending)
            print("🎯 HIGH-VALUE MILESTONE: Unlocked step \(newStepVal), previous step \(prevStep), isSkip=\(isSkipMilestone), queued \(pending.count) notifications, currentNotification=\(String(describing: currentNotification))")
            return
        }

        // Standard value-based logic for normal tiles
        guard newTileValue > previousHighest else { return }

        var pending: [MergeNotification] = []

        // Get all milestones we passed
        let passedMilestones = engine.milestonesBetween(previousHighest, and: newTileValue)

        // Check if any passed milestones add new spawn values
        var addedValue: Int? = nil
        for milestone in passedMilestones {
            if let added = engine.milestoneAddedValue(for: milestone) {
                if addedValue == nil || added > addedValue! {
                    addedValue = added
                }
            }
        }

        // Check if any passed milestones eliminate values
        var eliminatedValues: Set<Int> = []
        for milestone in passedMilestones {
            if let eliminated = engine.milestoneExcludedValue(for: milestone) {
                eliminatedValues.insert(eliminated)
            }
        }

        // Filter out trivial eliminations (e.g. eliminating the "1" tile)
        eliminatedValues = eliminatedValues.filter { $0 > 1 }

        // Also skip the added notification when the eliminated value is trivial
        // (the added tile is derived from the eliminated tile)
        if eliminatedValues.isEmpty {
            addedValue = nil
        }

        // Count how many notifications we need and pre-select unique phrases
        var notificationCount = 1 // unlocked is always shown
        if addedValue != nil { notificationCount += 1 }
        if eliminatedValues.max() != nil { notificationCount += 1 }
        let phrases = Self.pickUniquePhrases(notificationCount)
        var phraseIndex = 0

        // Always show unlock notification for the new highest tile
        pending.append(.unlocked(newTileValue, celebrationPhrase: phrases[phraseIndex]))
        phraseIndex += 1

        // Only show added notification if something was actually added
        if let added = addedValue {
            pending.append(.added(added, celebrationPhrase: phrases[phraseIndex]))
            phraseIndex += 1
        }

        // Only show excluded notification if something was actually eliminated
        // Show the highest eliminated value (most recent)
        if let maxEliminated = eliminatedValues.max() {
            pending.append(.excluded(maxEliminated, celebrationPhrase: phrases[phraseIndex]))
        }

        enqueueNotifications(pending)

        // Debug logging
        if passedMilestones.contains(8192) || passedMilestones.contains(131072) ||
           passedMilestones.contains(2097152) || passedMilestones.contains(33554432) {
            print("🎯 SKIP MILESTONE: Reached \(newTileValue), no elimination/addition changes")
        } else if !eliminatedValues.isEmpty || addedValue != nil {
            print("🎯 MILESTONE: Unlocked \(newTileValue), Added: \(addedValue ?? 0), Eliminated: \(eliminatedValues), Queued \(pending.count) notifications")
        }
    }
    
    private func enqueueNotifications(_ notifications: [MergeNotification]) {
        guard !notifications.isEmpty else { return }
        // Skip merge notifications in sandboxed (challenge) mode
        guard !sandboxed else { return }
        print("🔔 ENQUEUE: \(notifications.count) notifications, currentNotification=\(currentNotification == nil ? "nil" : "active"), queueSize=\(notificationQueue.count)")
        notificationQueue.append(contentsOf: notifications)
        if currentNotification == nil {
            showNextNotification()
        }
    }
    
    private func runHammerPipeline(at position: Position) {
        mergeCleanupTask?.cancel()
        isInputLocked = true
        hammerAnimationState = HammerAnimationState(target: position, phase: .windUp, startedAt: Date())
        
        mergeCleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            do {
                try await Task.sleep(nanoseconds: Self.hammerWindupDelay)
            } catch {
                print("[GameStore] Hammer wind-up sleep failed: \(error)")
                self.resetHammerAnimation()
                return
            }
            
            if Task.isCancelled {
                self.resetHammerAnimation()
                return
            }
            
            self.hammerAnimationState = HammerAnimationState(target: position, phase: .impact, startedAt: Date())

            let hammeredState = self.engine.hammer(at: position, applyGravity: false)
            self.state = hammeredState
            
            do {
                try await Task.sleep(nanoseconds: Self.hammerImpactDelay)
            } catch {
                print("[GameStore] Hammer impact sleep failed: \(error)")
                self.resetHammerAnimation()
                return
            }
            
            if Task.isCancelled {
                self.resetHammerAnimation()
                return
            }
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let dropState = self.engine.collapseColumns([position.col])
                self.state = dropState
            }
            
            do {
                try await Task.sleep(nanoseconds: Self.gravityAnimationDelay)
            } catch {
                print("[GameStore] Hammer drop sleep failed: \(error)")
                self.resetHammerAnimation()
                return
            }
            
            if Task.isCancelled {
                self.resetHammerAnimation()
                return
            }
            
            let cols = self.columnsWithEmpties(in: self.state.board)
            self.performRefill(columns: cols)
            self.updateValidMovesCount()
            self.resetHammerAnimation()
        }
    }

    @MainActor
    private func resetHammerAnimation() {
        hammerAnimationState = nil
        isInputLocked = false
        mergeCleanupTask = nil
    }
    
    private func columnsWithEmpties(in board: Board) -> Set<Int> {
        var result: Set<Int> = []
        for col in 0..<board.width {
            for row in 0..<board.height {
                let idx = BoardIndex(row: row, col: col)
                if board[idx].kind == .empty {
                    result.insert(col)
                    break
                }
            }
        }
        return result
    }
    
    private func markRefills(previousBoard: Board, newBoard: Board, scopedColumns: Set<Int>? = nil) {
        var newPositions = detectNewSpawnPositions(previousBoard: previousBoard, newBoard: newBoard)
        if let scopedColumns {
            newPositions = newPositions.filter { scopedColumns.contains($0.col) }
        }
        pendingRefillPositions = Set(newPositions)
        
        guard !pendingRefillPositions.isEmpty else { return }
        
        cancelRefillRevealTask()
        refillRevealTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Self.refillRevealDelay)
            await MainActor.run {
                self.pendingRefillPositions.removeAll()
            }
        }
    }
    
    private func runMagnetPipeline(
        value: Int,
        position: Position,
        matchingPositions: [Position],
        previousHighest: Int,
        previousHighestStep: Int
    ) {
        mergeCleanupTask?.cancel()
        isInputLocked = true
        lastMagnetEvent = MagnetEvent(target: position, sources: matchingPositions, value: value)

        mergeCleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isInputLocked = false
                self.mergeCleanupTask = nil
                self.clearLastMagnetEvent()
            }

            do {
                try await Task.sleep(nanoseconds: Self.magnetSuckDelay)
            } catch {
                print("[GameStore] Magnet pipeline sleep error: \(error)")
                self.clearLastMagnetEvent()
                return
            }

            if Task.isCancelled {
                print("[GameStore] Magnet pipeline cancelled before merge")
                return
            }

            self.engine.deferElimination = true
            let magnetResult = self.engine.magnetize(value: value, to: position)
            self.engine.deferElimination = false
            self.state = magnetResult
            self.processPendingRewards()

            // Store any deferred elimination tiles
            let eliminatedTiles = self.engine.lastMilestoneEliminatedTiles
            if !eliminatedTiles.isEmpty {
                print("[GameStore] Magnet: Storing \(eliminatedTiles.count) tiles for deferred elimination")
                self.pendingEliminationTiles = eliminatedTiles
            }

            let mergedTile = magnetResult.board[position]
            let mergedValue = mergedTile?.value ?? {
                return value <= (Int.max >> 1) ? value * 2 : Int.max
            }()
            let mergedStep = mergedTile?.stepIndex ?? (TileStepLabelFormatter.stepForValue(mergedValue, start: 2) ?? 0)

            // Increment mastery count
            self.incrementTierMasteryCount(for: mergedTile, value: mergedValue)

            self.setMergeInfoIfMilestone(
                previousHighest: previousHighest,
                newTileValue: mergedValue,
                previousStep: previousHighestStep,
                newStep: mergedStep
            )
            self.achievementEvaluator?.onTilesMerged(count: matchingPositions.count)

            // Set up double offer for magnet merges (same rules as regular merges)
            // Only offer double if tile is one step below OR same as previous highest (not a new record)
            self.lastAddedTileValue = mergedValue
            self.lastAddedTilePosition = position
            let isOneBelow = (previousHighestStep >= 1) && (mergedStep == previousHighestStep - 1)
            let isSameAsHighest = (mergedStep == previousHighestStep)
            if (isOneBelow || isSameAsHighest) && !self.sandboxed {
                self.pendingDoubleBase = mergedValue
                self.pendingDoubleBaseStep = mergedStep
            } else {
                self.pendingDoubleBase = nil
                self.pendingDoubleBaseStep = nil
            }

            let cols = self.columnsWithEmpties(in: self.state.board)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.performGravityDrop(columns: cols)
            }

            do {
                try await Task.sleep(nanoseconds: Self.gravityAnimationDelay)
            } catch {
                print("[GameStore] Magnet pipeline gravity error: \(error)")
                return
            }
            
            if Task.isCancelled {
                print("[GameStore] Magnet pipeline cancelled before refill")
                return
            }

            let refillCols = self.columnsWithEmpties(in: self.state.board)
            self.performRefill(columns: refillCols)
            self.updateValidMovesCount()
            self.saveProgressImmediately(newTile: mergedValue)
        }
    }
    
    // MARK: - PowerUps via Engine wrapper
    public enum PowerUpAction: Codable, Sendable, Equatable {
        case hammer(Position)
        case swap(Position, Position)
        case shuffle
        case undo
        case magnet(value: Int, position: Position)
    }
    
    public enum PowerUpCost {
        public static let hammer = 50
        public static let swap = 70
        public static let shuffle = 100
        public static let magnet = 90
    }
    
    private func milestonePriceDelta() -> Int {
        // Use step-based calculation to support high-value tiles beyond Int.max
        // Step 8 = 512 (first milestone), each step adds +10 gems
        let step: Int
        if let playerStep = playerHighestTileStep {
            // In challenge/sandbox mode, use player's step directly (supports high-value tiles)
            step = playerStep
        } else if let playerTile = playerHighestTile {
            // Fallback: convert player's tile value to step
            step = TileStepLabelFormatter.stepForValue(playerTile, start: 2) ?? state.highestTileStep
        } else {
            step = state.highestTileStep
        }
        guard step >= 8 else { return 0 }
        let milestonesUnlocked = step - 8
        return milestonesUnlocked * 10
    }
    
    private func applyPowerDiscount(to price: Int) -> Int {
        guard price > 0,
              let tierID = activePowerDiscountTierID,
              let tier = Self.powerDiscountCatalog[tierID],
              isPowerDiscountActive else {
            return price
        }
        let percentage = max(0, min(100, tier.discountPercentage))
        let discounted = price * (100 - percentage) / 100
        return max(1, discounted)
    }
    
    public func powerUpPrice(_ powerUp: String) -> Int {
        let delta = milestonePriceDelta()
        let basePrice: Int
        switch powerUp {
        case "hammer":
            basePrice = PowerUpCost.hammer + delta
        case "swap":
            basePrice = PowerUpCost.swap + delta
        case "magnet":
            basePrice = PowerUpCost.magnet + delta
        case "shuffle":
            basePrice = PowerUpCost.shuffle
        default:
            basePrice = PowerUpCost.hammer + delta
        }
        return applyPowerDiscount(to: basePrice)
    }
    
    @discardableResult
    public func useHammer(at position: Position) -> Bool {
        guard !isInputLocked else { return false }
        guard state.board[position] != nil else { return false }
        guard hammerAnimationState == nil else { return false }
        guard isPowerUpAvailable("hammer") else { return false }
        
        // Use inventory first, then coins
        if powerUpInventory["hammer", default: 0] > 0 {
            powerUpInventory["hammer", default: 0] -= 1
            lastPowerUpGemSpend = nil
        } else {
            let price = powerUpPrice("hammer")
            guard spendCoins(price) else { return false }
            lastPowerUpGemSpend = (cost: price, key: "hammer")
        }
        
        runHammerPipeline(at: position)
        powerUpHistory.append(.hammer(position))
        trackPowerUpAnalytics(action: .hammer(position))
        achievementEvaluator?.onPowerUpUsed(type: "hammer")
        
        // Save progress after power-up use
        saveProgressImmediately(newTile: nil)
        
        return true
    }
    
    @discardableResult
    public func useSwap(_ a: Position, _ b: Position) -> Bool {
        guard isPowerUpAvailable("swap") else { return false }
        
        // Use inventory first, then coins
        if powerUpInventory["swap", default: 0] > 0 {
            powerUpInventory["swap", default: 0] -= 1
            lastPowerUpGemSpend = nil
        } else {
            let price = powerUpPrice("swap")
            guard spendCoins(price) else { return false }
            lastPowerUpGemSpend = (cost: price, key: "swap")
        }
        
        let previousBoard = state.board
        let newState = engine.swap(a, b)
        applyStateUpdate(newState, previousBoard: previousBoard)
        powerUpHistory.append(.swap(a, b))
        trackPowerUpAnalytics(action: .swap(a, b))
        achievementEvaluator?.onPowerUpUsed(type: "swap")

        // Save progress after swap power-up
        saveProgressImmediately(newTile: nil)

        // Update valid moves count at the end
        updateValidMovesCount()

        return true
    }

    @discardableResult
    public func useShuffle() -> Bool {
        guard isPowerUpAvailable("shuffle") else { return false }
        
        // Use inventory first, then coins
        if powerUpInventory["shuffle", default: 0] > 0 {
            powerUpInventory["shuffle", default: 0] -= 1
            lastPowerUpGemSpend = nil
        } else {
            let price = powerUpPrice("shuffle")
            guard spendCoins(price) else { return false }
            lastPowerUpGemSpend = (cost: price, key: "shuffle")
        }
        
        let previousBoard = state.board
        let newState = engine.shuffle()
        applyStateUpdate(newState, previousBoard: previousBoard)
        powerUpHistory.append(.shuffle)
        trackPowerUpAnalytics(action: .shuffle)
        achievementEvaluator?.onPowerUpUsed(type: "shuffle")

        // Save progress after shuffle power-up
        saveProgressImmediately(newTile: nil)

        // Update valid moves count at the end
        updateValidMovesCount()

        return true
    }

    @discardableResult
    public func useUndo() -> Bool {
        guard state.undoAvailable else { return false }
        // Undo doesn't use inventory in this implementation
        let previousBoard = state.board
        // Preserve the current gems value (coins) before undo
        var currentGems = state.gems

        // Refund gems if the last action was a gem-purchased power-up
        if let gemSpend = lastPowerUpGemSpend {
            currentGems += gemSpend.cost
            print("💰 UNDO REFUND: Refunding \(gemSpend.cost) gems for \(gemSpend.key). New balance: \(currentGems)")
            lastPowerUpGemSpend = nil
        }

        var newState = engine.undo()
        // Restore the gems value (with refund applied) to prevent reverting unrelated purchases
        newState.gems = currentGems
        applyStateUpdate(newState, previousBoard: previousBoard)
        // Sync the engine's gems state to match the preserved value
        syncEngineGems()
        // Persist the refunded gem balance
        if !sandboxed {
            UserDefaults.standard.set(state.gems, forKey: "coins")
            UserDefaults.standard.synchronize()
        }
        powerUpHistory.append(.undo)
        trackPowerUpAnalytics(action: .undo)
        achievementEvaluator?.onUndoUsed()

        // Save progress after undo (could restore significant state)
        saveProgressImmediately(newTile: nil)

        // Update valid moves count at the end
        updateValidMovesCount()

        return true
    }
    
    @discardableResult
    public func useMagnet(value: Int, to position: Position) -> Int {
        guard !isInputLocked else { return 0 }
        guard isPowerUpAvailable("magnet") else { return 0 }
        guard let tile = state.board[position],
              tile.value == value,
              let targetStep = tile.stepIndex else { return 0 }
        guard pendingGiftBoxes[position] == nil else { return 0 }
        
        // Count how many tiles with this value exist on the board
        var matchingPositions: [Position] = []
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if let t = state.board[pos],
                   let step = t.stepIndex,
                   step == targetStep {
                    matchingPositions.append(pos)
                }
            }
        }
        
        // Need at least 2 tiles to merge
        guard matchingPositions.count > 1 else { return 0 }
        
        // Deduct power-up cost
        if powerUpInventory["magnet", default: 0] > 0 {
            powerUpInventory["magnet", default: 0] -= 1
            lastPowerUpGemSpend = nil
        } else {
            let price = powerUpPrice("magnet")
            guard spendCoins(price) else { return 0 }
            lastPowerUpGemSpend = (cost: price, key: "magnet")
        }
        
        // Capture previous highest for milestone detection
        let previousHighest = state.highestTile
        let previousHighestStep = state.highestTileStep

        // Track power-up usage
        trackPowerUpAnalytics(action: .magnet(value: value, position: position))
        achievementEvaluator?.onMagnetUsed(mergeCount: matchingPositions.count)
        runMagnetPipeline(
            value: value,
            position: position,
            matchingPositions: matchingPositions,
            previousHighest: previousHighest,
            previousHighestStep: previousHighestStep
        )

        return matchingPositions.count
    }

    // Helper to check if power-up is available (inventory or affordable)
    public func isPowerUpAvailable(_ powerUp: String) -> Bool {
        if powerUpInventory[powerUp, default: 0] > 0 { return true }
        switch powerUp {
        case "hammer", "swap", "magnet":
            return coins >= powerUpPrice(powerUp)
        case "shuffle":
            return coins >= powerUpPrice("shuffle")
        default: return false
        }
    }
    
    // MARK: - Optional Gift Row Features
    
    /// Enable gift row functionality in the top row (optional feature)
    @discardableResult
    public func enableGiftRow() -> Bool {
        _ = engine.initializeGiftRow()
        state = engine.currentState()
        refreshDerivedState(highestStep: persistedHighestTileStep())
        cancelRefillRevealTask()
        cancelMergeCleanupTask()
        pendingRefillPositions = []
        return true
    }
    
    /// Check if gift row is currently enabled
    public var hasGiftRow: Bool {
        return !engine.giftPositions().isEmpty
    }
    
    // MARK: - Daily Seed
    public func configureDailyGameIfNeeded(salt: String, utcDate: Date) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: utcDate)
        guard lastDailyDateUTC != dateString else { return }
        let seed = Self.dailySeed(from: dateString, salt: salt)
        engine = GameEngine(config: GameConfig(seed: seed))
        
        // Note: Gift row initialization is optional
        // _ = engine.initializeGiftRow()
        
        state = engine.currentState()
        refreshDerivedState(highestStep: persistedHighestTileStep())
        syncEngineScoreBoost()
        currentPath = []
        pathValidation = .valid
        cancelRefillRevealTask()
        cancelMergeCleanupTask()
        pendingRefillPositions = []
        lastDailyDateUTC = dateString
        UserDefaults.standard.set(dateString, forKey: "lastDailyDateUTC")
        movesHistory = []
        powerUpHistory = []
    }
    
    static func dailySeed(from dateString: String, salt: String) -> UInt64 {
        let combined = salt + dateString
        let data = Data(combined.utf8)
        let digest = SHA256.hash(data: data)
        // First 8 bytes as UInt64 big-endian
        let bytes = Array(digest)
        let value = bytes.prefix(8).reduce(UInt64(0)) { acc, byte in
            (acc << 8) | UInt64(byte)
        }
        return value
    }
    
    // Derive a deterministic seed from an arbitrary string
    public static func seed(from string: String) -> UInt64 {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest)
        return bytes.prefix(8).reduce(UInt64(0)) { acc, byte in (acc << 8) | UInt64(byte) }
    }
    
    // MARK: - Replay
    public struct Replay: Codable, Sendable, Equatable {
        public let seed: UInt64?
               public let moves: [[Position]]
        public let powerUps: [PowerUpAction]
    }

    /// Replay share-code tag. The prefix identifies the schema; the suffix is version bytes.
    /// Bump to "GR2" etc. when the ``Replay`` payload gains fields that older clients can't decode;
    /// keep prior-version cases in ``importReplay`` so old codes still round-trip.
    public enum ReplayTag {
        /// Original schema: `{seed, moves, powerUps}` JSON, base64-encoded.
        public static let v1 = "GR1"
        /// Tag written by ``exportReplay`` today.
        public static let current = v1
    }

    public func exportReplay() throws -> String {
        let replay = Replay(seed: engine.seedUsed, moves: movesHistory, powerUps: powerUpHistory)
        let data = try JSONEncoder().encode(replay)
        return ReplayTag.current + "|" + data.base64EncodedString()
    }

    public func importReplay(_ code: String) throws -> Replay {
        let parts = code.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw ReplayError.invalidFormat }
        guard let data = Data(base64Encoded: parts[1]) else { throw ReplayError.invalidFormat }
        switch parts[0] {
        case ReplayTag.v1:
            return try JSONDecoder().decode(Replay.self, from: data)
        // Add future versions here, e.g.:
        // case ReplayTag.v2:
        //     let v2 = try JSONDecoder().decode(ReplayV2.self, from: data)
        //     return Replay(upgrading: v2)
        default:
            throw ReplayError.unsupportedVersion(parts[0])
        }
    }

    public enum ReplayError: Error, Equatable {
        case invalidFormat
        case unsupportedVersion(String)
    }

    // Simulate a replay quickly (headless). Returns final state.
    public func simulateReplay(_ replay: Replay) -> GameState {
        let engine = GameEngine(config: GameConfig(seed: replay.seed))
        var state = engine.currentState()
        for path in replay.moves {
            _ = engine.commitChain(path)
            state = engine.currentState()
        }
        for action in replay.powerUps {
            switch action {
            case .hammer(let p):
                _ = engine.hammer(at: p)
            case .swap(let a, let b):
                _ = engine.swap(a, b)
            case .shuffle:
                _ = engine.shuffle()
            case .undo:
                _ = engine.undo()
            case .magnet(let value, let position):
                _ = engine.magnetize(value: value, to: position)
            }
            state = engine.currentState()
        }
        return state
    }
}

// MARK: - Persistence (Local Slots)
extension GameStore {
    private func flattenBoard(_ board: Board) -> [Int] {
        var values: [Int] = []
        values.reserveCapacity(board.width * board.height)
        for row in 0..<board.height {
            for col in 0..<board.width {
                let position = Position(row: row, col: col)
                if let tile = board[position] {
                    values.append(tile.value)
                } else {
                    values.append(0)
                }
            }
        }
        return values
    }
    
    private func board(from flat: [Int], width: Int, height: Int) -> Board {
        var board = Board(width: width, height: height)
        let expectedCount = width * height
        guard flat.count == expectedCount else { return board }
        var index = 0
        for row in 0..<height {
            for col in 0..<width {
                let v = flat[index]
                if v > 0 { board[Position(row: row, col: col)] = Tile(value: v) }
                index += 1
            }
        }
        return board
    }
    
    private enum ScoreDefaultsKey {
        static let currentScoreAlpha = "currentScoreAlpha"
        static let savedBestScoreAlpha = "savedBestScoreAlpha"
        static let currentHighestStep = "currentHighestTileStep"
        static let savedHighestTileStep = "savedHighestTileStep"
    }
    
    private enum TierDefaultsKey {
        static let counts = "tierMasteryCounts"
    }
    
    private func persistedBestScoreAlpha() -> AlphaNumber {
        if let string = UserDefaults.standard.string(forKey: ScoreDefaultsKey.savedBestScoreAlpha),
           let alpha = AlphaNumber(decimalString: string) {
            return alpha
        }
        return AlphaNumber(UserDefaults.standard.integer(forKey: "savedBestScore"))
    }
    
    private static func decodeTierMasteryCounts(from progress: GameProgress?) -> [String: Int] {
        if let counts = progress?.tierMasteryCounts, !counts.isEmpty {
            return counts
        }
        if let data = UserDefaults.standard.data(forKey: TierDefaultsKey.counts),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return decoded
        }
        return [:]
    }
    
    private func persistTierMasteryCountsToDefaults() {
        if let data = try? JSONEncoder().encode(tierMasteryCounts) {
            UserDefaults.standard.set(data, forKey: TierDefaultsKey.counts)
        }
    }
    
    private func incrementTierMasteryCount(for tile: Tile?, value: Int, chainLength: Int = 1) {
        guard let suffix = tierSuffix(for: tile, value: value) else { return }
        // Use full assignment to ensure @Observable detects the change
        var newCounts = tierMasteryCounts
        newCounts[suffix, default: 0] += chainLength
        tierMasteryCounts = newCounts
        persistTierMasteryCountsToDefaults()
    }
    
    private func tierSuffix(for tile: Tile?, value: Int) -> String? {
        guard value > 0 else { return nil }
        if let tile, tile.isInfinity { return "∞" }
        let step: Int?
        if let tile, let tileStep = tile.stepIndex {
            step = tileStep
        } else {
            step = TileStepLabelFormatter.stepForValue(value)
        }
        guard let step else { return nil }
        
        // Clamp to supported journey tiers (bz max). Anything beyond bz is recorded as bz.
        let maxStep = JourneyAbbreviationTiers.maxSupportedStep
        let clampedStep = min(step, maxStep)
        let label = (clampedStep == maxStep && step > maxStep)
            ? "1bz"
            : TileStepLabelFormatter.labelForStep(clampedStep)
        let suffix = label.trimmingCharacters(in: .decimalDigits)
        return suffix.isEmpty ? nil : suffix
    }
    
    private func persistedScoreAlpha() -> AlphaNumber? {
        guard let string = UserDefaults.standard.string(forKey: ScoreDefaultsKey.currentScoreAlpha) else {
            return nil
        }
        return AlphaNumber(decimalString: string)
    }
    
    private func persistedHighestTileStep() -> Int? {
        guard let stored = UserDefaults.standard.object(forKey: ScoreDefaultsKey.currentHighestStep) else {
            return nil
        }
        if let number = stored as? NSNumber {
            return number.intValue
        }
        return stored as? Int
    }
    
    private func refreshDerivedState(scoreAlpha: AlphaNumber? = nil, highestStep: Int? = nil) {
        if let scoreAlpha {
            // SAFEGUARD: Only update score if the new value is >= current value
            // This prevents accidental score deductions from stale persisted data
            if scoreAlpha >= state.scoreValue {
                state.scoreValue = scoreAlpha
                // CRITICAL: Also sync to engine to prevent score loss on next merge
                engine.overrideScore(with: scoreAlpha)
            } else {
                print("⚠️ SCORE SAFEGUARD: Blocked attempt to decrease score from \(state.scoreValue.formattedLabel()) to \(scoreAlpha.formattedLabel())")
            }
        } else if state.scoreValue.isZero && state.score > 0 {
            let alpha = AlphaNumber(state.score)
            state.scoreValue = alpha
            // CRITICAL: Also sync to engine to prevent score loss on next merge
            engine.overrideScore(with: alpha)
        }

        // CRITICAL FIX: Always use the persisted highestTileStep as the source of truth
        // This fixes the bug where tiles with step >= 62 lose their .highValue(step:) type
        // during save/restore, causing them to be recalculated as step 62 (from Int.max)
        let persistedStep = sandboxed ? 0 : (persistedHighestTileStep() ?? 0)

        if let highestStep {
            // Use the maximum of provided step and persisted step
            state.highestTileStep = max(highestStep, persistedStep)
        } else {
            // Calculate from board tiles, but always consider persisted value as floor
            var maxStep = max(state.highestTileStep, persistedStep)
            for row in 0..<state.board.height {
                for col in 0..<state.board.width {
                    let pos = Position(row: row, col: col)
                    if let tile = state.board[pos],
                       let step = tile.stepIndex {
                        maxStep = max(maxStep, step)
                    }
                }
            }
            state.highestTileStep = maxStep
        }

        print("📐 refreshDerivedState: highestTileStep = \(state.highestTileStep) (persisted was: \(persistedStep))")
        // Note: validMovesCount is updated separately via updateValidMovesCount()
        // at the end of board operations (commit, hammer, swap, etc.)
    }

    /// Verifies that highestTileStep matches the actual tiles on the board.
    /// This fixes corruption where high-step tiles lost their .highValue(step:) type.
    private func verifyAndFixHighestTileStep() {
        // Scan board for the highest tile, checking BOTH stepIndex and the tile's actual type
        var maxStepFromBoard = 0
        var highestValueOnBoard: Int = 0
        var foundHighValueTile = false

        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos] {
                    // Check if tile has explicit .highValue step (most reliable)
                    if case .highValue(let step) = tile.type {
                        maxStepFromBoard = max(maxStepFromBoard, step)
                        foundHighValueTile = true
                        print("   Found .highValue tile at \(pos) with step \(step)")
                    } else if let step = tile.stepIndex {
                        maxStepFromBoard = max(maxStepFromBoard, step)
                    }
                    highestValueOnBoard = max(highestValueOnBoard, tile.value)
                }
            }
        }

        let persistedStep = persistedHighestTileStep() ?? 0

        print("🔍 verifyAndFixHighestTileStep:")
        print("   Max step from board tiles: \(maxStepFromBoard)")
        print("   Found explicit .highValue tile: \(foundHighValueTile)")
        print("   Highest value on board: \(highestValueOnBoard)")
        print("   Persisted highestTileStep: \(persistedStep)")
        print("   Current state.highestTileStep: \(state.highestTileStep)")

        // Use the maximum of all sources
        let correctedStep = max(state.highestTileStep, max(maxStepFromBoard, persistedStep))

        if correctedStep > state.highestTileStep {
            print("   ⚠️ FIXING: Updating highestTileStep from \(state.highestTileStep) to \(correctedStep)")
            state.highestTileStep = correctedStep
            // Also update the persisted value
            UserDefaults.standard.set(correctedStep, forKey: ScoreDefaultsKey.currentHighestStep)
        } else {
            print("   ✅ highestTileStep looks correct")
        }

        // MIGRATION: Initialize or fix savedHighestTileStep
        // This ensures the profile displays the correct all-time best milestone
        let savedHighestStep = UserDefaults.standard.integer(forKey: ScoreDefaultsKey.savedHighestTileStep)
        let currentSessionStep = persistedHighestTileStep() ?? 0

        // Use the maximum of all known step sources
        let bestKnownStep = max(correctedStep, max(savedHighestStep, currentSessionStep))

        if bestKnownStep > savedHighestStep {
            print("   🔄 MIGRATION: Updating savedHighestTileStep from \(savedHighestStep) to \(bestKnownStep)")
            print("      (correctedStep=\(correctedStep), currentSessionStep=\(currentSessionStep), state=\(state.highestTileStep))")
            UserDefaults.standard.set(bestKnownStep, forKey: ScoreDefaultsKey.savedHighestTileStep)

            // Also update savedHighestTile for consistency
            let savedHighestTile = UserDefaults.standard.integer(forKey: "savedHighestTile")
            if savedHighestTile < state.highestTile {
                UserDefaults.standard.set(state.highestTile, forKey: "savedHighestTile")
                print("   🔄 MIGRATION: Updated savedHighestTile to \(state.highestTile)")
            }
        }
    }

    /// Force-update the highest tile step to a specific value.
    /// Use this to fix corrupted achievement progress.
    /// Step calculation: step = log2(tileValue) - 1
    /// Examples: 36c (3.6e19) ≈ step 64, 100c (1e20) ≈ step 66
    public func forceUpdateHighestTileStep(toStep step: Int) {
        print("🔧 FORCE UPDATE: Setting highestTileStep to \(step)")
        state.highestTileStep = step
        UserDefaults.standard.set(step, forKey: ScoreDefaultsKey.currentHighestStep)
        saveProgressImmediately(newTile: nil)
        print("   ✅ Done. Achievement should now show: \(String(format: "%.2e", pow(2.0, Double(step + 1))))")
    }

    public func save(to slotId: String, using storage: any StorageServiceProtocol, theme: String) async {
        let current = state
        let bestExisting = await storage.bestScore()
        let bestToPersist = max(bestExisting, current.score)
        let payload = SaveData(
            board: flattenBoard(current.board),
            width: current.board.width,
            height: current.board.height,
            score: current.score,
            best: bestToPersist,
            seed: engine.seedUsed,
            theme: theme,
            timestamp: Date()
        )
        await storage.save(slotId: slotId, data: payload)
    }
    
    @discardableResult
    public func load(from slotId: String, using storage: any StorageServiceProtocol) async -> Bool {
        guard let data = await storage.load(slotId: slotId) else { return false }
        // If saved board size differs from current defaults (5x8), reinitialize to new size
        if data.width != 5 || data.height != 8 {
            engine = GameEngine(config: GameConfig(boardWidth: 5, boardHeight: 8, seed: data.seed))
            state = engine.currentState()
            refreshDerivedState(highestStep: persistedHighestTileStep())
            syncEngineScoreBoost()
        } else {
            let restoredBoard = board(from: data.board, width: data.width, height: data.height)
            let config = GameConfig(boardWidth: data.width, boardHeight: data.height, seed: data.seed)
            let restoredEngine = GameEngine(
                config: config,
                initialBoard: restoredBoard,
                initialScore: data.score,
                initialMoves: 0,
                initialLevel: 1,
                initialGems: state.gems
            )
            engine = restoredEngine
            state = restoredEngine.currentState()
            refreshDerivedState(highestStep: persistedHighestTileStep())
            syncEngineScoreBoost()
        }
        
        // IMPORTANT: Sync JourneyKit with the loaded game state
        if state.highestTile > 0 {
            journey.didReach(tile: state.highestTile)
        }
        
        currentPath = []
        pathValidation = .valid
        movesHistory = []
        powerUpHistory = []
        return true
    }
    
    public func deleteSlot(_ slotId: String, using storage: any StorageServiceProtocol) async {
        await storage.delete(slotId: slotId)
    }
    
    public func listSlots(using storage: any StorageServiceProtocol) async -> [SaveSlotMeta] {
        await storage.loadSlots()
    }
    
    public func bestScore(using storage: any StorageServiceProtocol) async -> Int {
        await storage.bestScore()
    }
    
    // MARK: - Comprehensive Progress Auto-Save System
    
    /// Creates a comprehensive GameProgress snapshot from current state
    private func createProgressSnapshot() -> GameProgress {
        let snapshotDate = Date()
        // Check for infinity achievement
        var hasInfinity = false
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.isInfinity {
                    hasInfinity = true
                    break
                }
            }
        }
        
        // Create session state (cap movesHistory to last 200 to prevent save bloat)
        let cappedMovesHistory = Array(movesHistory.suffix(200))
        let sessionState = GameProgress.SessionState(
            board: state.board,
            score: state.score,
            moves: state.moves,
            level: state.level,
            highestTile: state.highestTile,
            highestTileStep: state.highestTileStep,
            seed: engine.seedUsed,
            brokenGlassTiles: Array(brokenGlassTiles),
            movesHistory: cappedMovesHistory,
            lastDailyDateUTC: lastDailyDateUTC,
            scoreAlpha: state.scoreValue
        )
        
        // Create journey state
        let journeyState = GameProgress.JourneyState(
            highestTile: journey.highestTile,
            claimedTiles: journey.claimed,
            claimedAbbreviationTiers: claimedJourneyAbbreviationRewards
        )
        
        // Create session tracking
        let sessionTracking = GameProgress.SessionTracking(
            sessionStartTime: UserDefaults.standard.object(forKey: "sessionStartTime") as? Date,
            currentSessionStartTime: UserDefaults.standard.object(forKey: "currentSessionStartTime") as? Date,
            currentSessionDuration: UserDefaults.standard.double(forKey: "currentSessionDuration"),
            sessionMoves: UserDefaults.standard.integer(forKey: "sessionMoves"),
            sessionScore: UserDefaults.standard.integer(forKey: "sessionScore"),
            sessionMerges: UserDefaults.standard.integer(forKey: "sessionMerges"),
            sessionHighestTile: UserDefaults.standard.integer(forKey: "sessionHighestTile"),
            sessionPowerUpsUsed: UserDefaults.standard.integer(forKey: "sessionPowerUpsUsed"),
            sessionEfficiencyScore: UserDefaults.standard.double(forKey: "sessionEfficiencyScore")
        )
        
        // Get all-time bests
        let allTimeHighest = max(state.highestTile, UserDefaults.standard.integer(forKey: "savedHighestTile"))
        let storedBestAlpha = persistedBestScoreAlpha()
        let bestAlpha = state.scoreValue > storedBestAlpha ? state.scoreValue : storedBestAlpha
        let allTimeBest = bestAlpha.toInt()
        
        // Get existing progress data or use defaults
        let totalMerges = UserDefaults.standard.integer(forKey: "totalMerges")
        let totalTimePlayed = UserDefaults.standard.double(forKey: "totalTimePlayed")
        let gamesPlayed = max(1, UserDefaults.standard.integer(forKey: "gamesPlayed"))
        let completedDailyChallenges = UserDefaults.standard.integer(forKey: "completedDailyChallenges")
        let currentWinStreak = UserDefaults.standard.integer(forKey: "currentWinStreak")
        let bestWinStreak = UserDefaults.standard.integer(forKey: "bestWinStreak")
        
        // Get unlocked themes
        var unlockedThemes: Set<String> = ["beach", "aqua"]
        for theme in ["desert", "jungle", "space", "neon", "retro", "ice"] {
            if UserDefaults.standard.bool(forKey: "theme_unlocked_\(theme)") {
                unlockedThemes.insert(theme)
            }
        }
        
        let theme = UserDefaults.standard.string(forKey: "theme")
        let rank = UserDefaults.standard.object(forKey: "rank") as? Int
        
        let boostState: GameProgress.ScoreBoostState?
        if let tierID = activeScoreBoostTierID,
           let expiresAt = scoreBoostExpiresAt,
           expiresAt > snapshotDate,
           let tier = Self.scoreBoostCatalog[tierID] {
            boostState = GameProgress.ScoreBoostState(
                tierID: tier.id.rawValue,
                multiplier: tier.multiplier,
                expiresAt: expiresAt
            )
        } else {
            boostState = nil
        }
        
        let discountState: GameProgress.PowerDiscountState?
        if let tierID = activePowerDiscountTierID,
           let expiresAt = powerDiscountExpiresAt,
           expiresAt > snapshotDate,
           let tier = Self.powerDiscountCatalog[tierID] {
            discountState = GameProgress.PowerDiscountState(
                tierID: tier.id.rawValue,
                discountPercentage: tier.discountPercentage,
                expiresAt: expiresAt
            )
        } else {
            discountState = nil
        }
        
        return GameProgress(
            highestTile: allTimeHighest,
            bestScore: allTimeBest,
            bestScoreAlpha: bestAlpha,
            gems: state.gems,
            gamesPlayed: gamesPlayed,
            achievements: [],
            theme: theme,
            rank: rank,
            lastUpdatedAt: snapshotDate,
            totalMerges: totalMerges,
            totalTimePlayed: totalTimePlayed,
            unlockedThemes: unlockedThemes,
            completedDailyChallenges: completedDailyChallenges,
            currentWinStreak: currentWinStreak,
            bestWinStreak: bestWinStreak,
            currentSessionState: sessionState,
            activeScoreBoost: boostState,
            powerUpInventory: powerUpInventory,
            tierMasteryCounts: tierMasteryCounts,
            journeyState: journeyState,
            sessionTracking: sessionTracking,
            hasInfinityAchievement: hasInfinity,
            infinityMergeCount: state.infinityMergeCount + UserDefaults.standard.integer(forKey: "infinityMergeCount"),
            queuedScoreBoostTierID: queuedScoreBoostTierID?.rawValue,
            activePowerDiscount: discountState,
            queuedPowerDiscountTierID: queuedPowerDiscountTierID?.rawValue
        )
    }
    
    /// Saves comprehensive progress to persistent storage
    public func saveProgressToStore() {
        guard !sandboxed else { return }
        let progress = createProgressSnapshot()
        // Use synchronous save to ensure data is persisted immediately
        // This prevents data loss if the app is terminated shortly after a move
        do {
            try progressStore.saveSync(progress)
            // We don't print the full success message here to avoid log spam,
            // as this is called frequently.
            // print("💾 Comprehensive progress saved")

            // Also ensure UserDefaults is synced for gems/coins
            UserDefaults.standard.set(progress.gems, forKey: "coins")
        } catch {
            print("❌ Failed to save comprehensive progress: \(error)")
        }
    }
    
    public func registerSpinUse() {
        achievementEvaluator?.onPowerUpUsed(type: "spin")
    }
    
    public func registerChallengeCreationCompleted(withCapturedMultiplier multiplier: Int? = nil) {
        achievementEvaluator?.onChallengeCreationCompleted(withCapturedMultiplier: multiplier)
    }

    public func registerLeaderboardRank(_ rank: Int) {
        achievementEvaluator?.onLeaderboardRankUpdated(rank)
    }


    // MARK: - Legacy Progress Auto-Save System (for backward compatibility)
    
    public func saveProgressImmediately(newTile: Int?) {
        // Don't save progress from sandboxed challenge stores
        guard !sandboxed else { return }

        // SAVE EVERYTHING ON EVERY ACTION - not just new records

        // Check for infinity tiles on board
        var hasInfinityTile = false
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.isInfinity {
                    hasInfinityTile = true
                    break
                }
            }
        }
        
        // Save infinity achievement if found
        if hasInfinityTile {
            UserDefaults.standard.set(true, forKey: "hasInfinityAchievement")
            print("♾️  INFINITY TILE ON BOARD - SAVED!")
        }
        
        // ALWAYS save current session highest (regardless of all-time record)
        let currentHighest = state.highestTile
        let currentHighestStep = state.highestTileStep
        UserDefaults.standard.set(currentHighest, forKey: "currentHighestTile")
        UserDefaults.standard.set(currentHighestStep, forKey: ScoreDefaultsKey.currentHighestStep)

        // ALWAYS update all-time highest if current session beats it
        // For high tiles (step >= 62), use step-based comparison to avoid Int.max overflow issues
        let allTimeHighest = UserDefaults.standard.integer(forKey: "savedHighestTile")
        let allTimeHighestStep = UserDefaults.standard.integer(forKey: ScoreDefaultsKey.savedHighestTileStep)

        var shouldUpdateAllTime = false
        if currentHighestStep >= 62 || allTimeHighestStep >= 62 {
            // Use step-based comparison for very high tiles
            shouldUpdateAllTime = currentHighestStep > allTimeHighestStep
        } else {
            // Use value-based comparison for normal tiles
            shouldUpdateAllTime = currentHighest > allTimeHighest
        }

        if shouldUpdateAllTime {
            UserDefaults.standard.set(currentHighest, forKey: "savedHighestTile")
            UserDefaults.standard.set(currentHighestStep, forKey: ScoreDefaultsKey.savedHighestTileStep)
            // Update leaderboard milestone - use step-based formatting for high values
            let formattedMilestone: String
            if currentHighestStep >= 62 {
                formattedMilestone = TileStepLabelFormatter.labelForStep(currentHighestStep, start: 2)
            } else {
                formattedMilestone = TileStepLabelFormatter.formatTileValue(currentHighest)
            }
            UserDefaults.standard.set(formattedMilestone, forKey: "leaderboard.milestone")
            print("🏆 New all-time highest tile: \(formattedMilestone) (step \(currentHighestStep))")
        }

        #if DEBUG
        print("💾 Saved highestTileStep: \(state.highestTileStep)")
        #endif
        
        // Log EVERY tile creation (not just records)
        if let tile = newTile, tile > 0 {
            let step = state.highestTileStep
            let label = step >= 62
                ? TileStepLabelFormatter.labelForStep(step, start: 2)
                : "\(tile)"
            print("🆕 Tile created: \(label) (step \(step))")
        }
        
        // ALWAYS save current score (regardless of all-time best)
        UserDefaults.standard.set(state.score, forKey: "currentScore")
        UserDefaults.standard.set(state.scoreValue.decimalString, forKey: ScoreDefaultsKey.currentScoreAlpha)
        
        // ALWAYS update all-time best score if current beats it
        let previousBestAlpha = persistedBestScoreAlpha()
        if state.scoreValue > previousBestAlpha {
            UserDefaults.standard.set(state.score, forKey: "savedBestScore")
            UserDefaults.standard.set(state.scoreValue.decimalString, forKey: ScoreDefaultsKey.savedBestScoreAlpha)
            print("🎯 New all-time best score: \(state.scoreValue.formattedLabel())")
        }
        
        // ALWAYS save gems balance
        UserDefaults.standard.set(state.gems, forKey: "coins")
        
        // COMPREHENSIVE SESSION DATA PERSISTENCE
        
        // Save current game state
        UserDefaults.standard.set(state.moves, forKey: "currentMoves")
        UserDefaults.standard.set(state.score, forKey: "currentSessionScore")
        UserDefaults.standard.set(state.level, forKey: "currentLevel")
        
        // Save enhanced session analytics
        let sessionAnalytics = getSessionAnalytics()
        if let analyticsData = try? JSONSerialization.data(withJSONObject: sessionAnalytics) {
            UserDefaults.standard.set(analyticsData, forKey: "sessionAnalytics")
        }
        
        // Save power-up inventory
        let powerUpData = try? JSONEncoder().encode(powerUpInventory)
        UserDefaults.standard.set(powerUpData, forKey: "powerUpInventory")
        
        // Save JourneyKit state
        UserDefaults.standard.set(journey.highestTile, forKey: "journeyHighestTile")
        let journeyClaimedData = try? JSONEncoder().encode(Array(journey.claimed))
        UserDefaults.standard.set(journeyClaimedData, forKey: "journeyClaimedTiles")
        let abbreviationClaimsData = try? JSONEncoder().encode(Array(claimedJourneyAbbreviationRewards))
        UserDefaults.standard.set(abbreviationClaimsData, forKey: journeyAbbreviationClaimsKey)
        
        // Save session tracking data
        if UserDefaults.standard.object(forKey: "sessionStartTime") == nil {
            UserDefaults.standard.set(Date(), forKey: "sessionStartTime")
        }
        
        // Update session statistics
        let currentMerges = UserDefaults.standard.integer(forKey: "totalMerges")
        UserDefaults.standard.set(currentMerges + 1, forKey: "totalMerges")

        // Note: totalMoves is now incremented in AchievementEvaluator.onMoveSurvived()
        // to apply the achievement boost multiplier
        
        // Update total time played
        if let sessionStart = UserDefaults.standard.object(forKey: "sessionStartTime") as? Date {
            let sessionDuration = Date().timeIntervalSince(sessionStart)
            let totalTimePlayed = UserDefaults.standard.double(forKey: "totalTimePlayed")
            UserDefaults.standard.set(totalTimePlayed + sessionDuration, forKey: "totalTimePlayed")
        }
        
        // Save games played count
        let gamesPlayed = UserDefaults.standard.integer(forKey: "gamesPlayed")
        if gamesPlayed == 0 {
            UserDefaults.standard.set(1, forKey: "gamesPlayed")
        }
        
        // Save win streak data
        let currentWinStreak = UserDefaults.standard.integer(forKey: "currentWinStreak")
        let bestWinStreak = UserDefaults.standard.integer(forKey: "bestWinStreak")
        UserDefaults.standard.set(max(currentWinStreak, bestWinStreak), forKey: "bestWinStreak")
        
        // Save current path state
        let currentPathData = try? JSONEncoder().encode(currentPath.map { ["row": $0.row, "col": $0.col] })
        UserDefaults.standard.set(currentPathData, forKey: "currentPath")
        UserDefaults.standard.set(pathValidation.isValid, forKey: "pathValidation")
        
        // Save session state flags
        UserDefaults.standard.set(isExtendingToGift, forKey: "isExtendingToGift")
        if let pendingReward = pendingUnlockRewardBase {
            UserDefaults.standard.set(pendingReward, forKey: "pendingUnlockRewardBase")
        }
        if let pendingTile = pendingUnlockTile {
            UserDefaults.standard.set(pendingTile, forKey: "pendingUnlockTile")
        }
        if let lastAdded = lastAddedTileValue {
            UserDefaults.standard.set(lastAdded, forKey: "lastAddedTileValue")
        }
        if let doubleBase = pendingDoubleBase {
            UserDefaults.standard.set(doubleBase, forKey: "pendingDoubleBase")
        }
        if let doubleStep = pendingDoubleBaseStep {
            UserDefaults.standard.set(doubleStep, forKey: "pendingDoubleBaseStep")
        }
        
        // Save broken glass tiles
        let brokenGlassData = try? JSONEncoder().encode(Array(brokenGlassTiles).map { ["row": $0.row, "col": $0.col] })
        UserDefaults.standard.set(brokenGlassData, forKey: "brokenGlassTiles")
        
        // Save pending gift boxes
        persistPendingGiftBoxes()
        persistTierMasteryCountsToDefaults()
        
        // Save power-up history (last 10 actions)
        let recentPowerUpHistory = Array(powerUpHistory.suffix(10))
        let powerUpHistoryArray = recentPowerUpHistory.map { action in
            switch action {
            case .hammer(let pos):
                return [
                    "type": "hammer",
                    "timestamp": Date().timeIntervalSince1970,
                    "position": ["row": pos.row, "col": pos.col]
                ]
            case .swap(let pos1, let pos2):
                return [
                    "type": "swap",
                    "timestamp": Date().timeIntervalSince1970,
                    "position": ["row": pos1.row, "col": pos1.col],
                    "position2": ["row": pos2.row, "col": pos2.col]
                ]
            case .shuffle:
                return [
                    "type": "shuffle",
                    "timestamp": Date().timeIntervalSince1970,
                    "position": NSNull()
                ]
            case .undo:
                return [
                    "type": "undo",
                    "timestamp": Date().timeIntervalSince1970,
                    "position": NSNull()
                ]
            case .magnet(let value, let position):
                return [
                    "type": "magnet",
                    "timestamp": Date().timeIntervalSince1970,
                    "value": value,
                    "position": ["row": position.row, "col": position.col]
                ]
            }
        }
        let powerUpHistoryData = try? JSONSerialization.data(withJSONObject: powerUpHistoryArray)
        UserDefaults.standard.set(powerUpHistoryData, forKey: "powerUpHistory")
        
        // Save moves history (last 20 moves)
        let recentMovesHistory = Array(movesHistory.suffix(20))
        let movesHistoryArray = recentMovesHistory.map { positions in
            [
                "positions": positions.map { ["row": $0.row, "col": $0.col] },
                "timestamp": Date().timeIntervalSince1970,
                "score": state.score
            ]
        }
        let movesHistoryData = try? JSONSerialization.data(withJSONObject: movesHistoryArray)
        UserDefaults.standard.set(movesHistoryData, forKey: "movesHistory")
        
        // Save daily challenge data
        if let dailyDate = lastDailyDateUTC {
            UserDefaults.standard.set(dailyDate, forKey: "lastDailyDateUTC")
        }
        
        // Save theme and UI preferences
        UserDefaults.standard.set("beach", forKey: "selectedTheme") // Default theme
        UserDefaults.standard.set(true, forKey: "isMusicOn") // Default music on
        
        // Save achievements
        let achievements = ["first_2048", "high_score", "power_user"] // Example achievements
        UserDefaults.standard.set(achievements, forKey: "achievements")
        
        // Save unlocked themes
        let unlockedThemes = ["beach", "aqua", "forest"] // Example themes
        UserDefaults.standard.set(unlockedThemes, forKey: "unlockedThemes")
        
        // Save rank and progression data
        UserDefaults.standard.set(231_105, forKey: "rank") // Example rank
        UserDefaults.standard.set(1024, forKey: "milestoneBelow")
        UserDefaults.standard.set([4096, 8192], forKey: "lockedMilestones")
        
        // Save badge states
        UserDefaults.standard.set(true, forKey: "hasDailyBadge")
        UserDefaults.standard.set(true, forKey: "hasFreeSpinBadge")
        UserDefaults.standard.set(true, forKey: "hasShopBadge")
        UserDefaults.standard.set(true, forKey: "hasProfileBadge")
        // achievementsBadgeCount is calculated dynamically from AchievementStore.claimableCount
        
        // Save unlock states
        UserDefaults.standard.set(true, forKey: "isCreateLocked")
        UserDefaults.standard.set(true, forKey: "isChallengeLocked")
        UserDefaults.standard.set(1_048_576, forKey: "createUnlockAt")
        UserDefaults.standard.set(1_048_576, forKey: "challengeUnlockAt")
        
        // Save ad reward data
        UserDefaults.standard.set(68, forKey: "adReward")
        UserDefaults.standard.set(Date().addingTimeInterval(3600), forKey: "bestOfferDeadline")
        
        // Save theme names
        UserDefaults.standard.set("Beach", forKey: "themesLeftName")
        UserDefaults.standard.set("Aqua", forKey: "themesRightName")
        
        // ALWAYS save timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastProgressSave")
        
        // Force immediate write to disk
        UserDefaults.standard.synchronize()
        
        // Save comprehensive progress to structured store
        saveProgressToStore()
        
        print("💾 COMPREHENSIVE SESSION DATA SAVED")
        let logHighestLabel = state.highestTileStep >= 62
            ? TileStepLabelFormatter.labelForStep(state.highestTileStep, start: 2)
            : "\(currentHighest)"
        print("   • Session highest: \(logHighestLabel) (step \(state.highestTileStep))")
        print("   • Session score: \(state.scoreValue.formattedLabel())")
        print("   • Gems: \(state.gems)")
        print("   • Moves: \(state.moves)")
        print("   • Power-ups: \(powerUpInventory)")
        let journeyLabel = journey.highestTile >= Int.max / 2
            ? "step \(state.highestTileStep)+"
            : "\(journey.highestTile)"
        print("   • Journey highest: \(journeyLabel)")
        print("   • Total merges: \(UserDefaults.standard.integer(forKey: "totalMerges"))")
        print("   • Total time: \(String(format: "%.1f", UserDefaults.standard.double(forKey: "totalTimePlayed")))s")
        print("   • Session efficiency: \(String(format: "%.2f", UserDefaults.standard.double(forKey: "sessionEfficiencyScore")))")
        print("   • Session duration: \(String(format: "%.1f", UserDefaults.standard.double(forKey: "currentSessionDuration")))s")
        print("   • Session moves: \(UserDefaults.standard.integer(forKey: "sessionMoves"))")
        print("   • Power-ups used: \(UserDefaults.standard.integer(forKey: "sessionPowerUpsUsed"))")
    }
    
    /// Restore progress from saved data (called on app launch)
    public func restoreProgress() {
        let savedHighest = UserDefaults.standard.integer(forKey: "savedHighestTile")
        let savedHighestStep = UserDefaults.standard.integer(forKey: ScoreDefaultsKey.savedHighestTileStep)
        let savedBestScoreAlpha = persistedBestScoreAlpha()
        let savedGems = UserDefaults.standard.integer(forKey: "coins")
        let hasInfinityAchievement = UserDefaults.standard.bool(forKey: "hasInfinityAchievement")
        if let currentScoreString = UserDefaults.standard.string(forKey: ScoreDefaultsKey.currentScoreAlpha),
           let alpha = AlphaNumber(decimalString: currentScoreString) {
            // SAFEGUARD: Only update if persisted value is >= current (prevents score decrease)
            if alpha >= state.scoreValue {
                state.scoreValue = alpha
                // CRITICAL: Also sync to engine to prevent score loss on next merge
                engine.overrideScore(with: alpha)
            } else {
                print("⚠️ RESTORE SAFEGUARD: Blocked score decrease from \(state.scoreValue.formattedLabel()) to \(alpha.formattedLabel())")
            }
        } else if state.scoreValue.isZero && state.score > 0 {
            let alpha = AlphaNumber(state.score)
            state.scoreValue = alpha
            // CRITICAL: Also sync to engine to prevent score loss on next merge
            engine.overrideScore(with: alpha)
        }

        // Restore infinity achievement
        if hasInfinityAchievement {
            print("♾️  INFINITY ACHIEVEMENT RESTORED!")
        }

        // For very high tiles (step >= 62), the raw value overflows Int64
        // Use step-based comparison and milestone calculation
        var shouldRestore = false
        if savedHighestStep >= 62 || state.highestTileStep >= 62 {
            shouldRestore = savedHighestStep > state.highestTileStep
        } else {
            shouldRestore = savedHighest > state.highestTile
        }

        if shouldRestore {
            state.highestTile = savedHighest
            state.highestTileStep = savedHighestStep
            journey.didReach(tile: savedHighest)
            // Ensure leaderboard milestone is set for restored highest tile
            // Use step-based formatting for high values to avoid overflow
            let restoredMilestone: String
            if savedHighestStep >= 62 {
                restoredMilestone = TileStepLabelFormatter.labelForStep(savedHighestStep, start: 2)
            } else {
                restoredMilestone = TileStepLabelFormatter.formatTileValue(savedHighest)
            }
            UserDefaults.standard.set(restoredMilestone, forKey: "leaderboard.milestone")
            if savedHighestStep >= 62 {
                print("🔄 Restored high step achievement: step \(savedHighestStep) (\(restoredMilestone))")
            } else if savedHighest >= 2_147_483_648 {
                print("🔄 Restored 2B+ achievement: \(savedHighest)")
            } else {
                print("🔄 Restored highest tile: \(savedHighest)")
            }
        }
        
        // Only restore gems if we have NO gems currently (fresh start)
        // This prevents overwriting current gem balance with old values
        if state.gems == 0 && savedGems > 0 {
            state.gems = savedGems
            syncEngineGems()
            print("🔄 Restored gems: \(savedGems)")
        } else if savedGems != state.gems {
            // If gems differ, trust the current state as it's more recent
            print("⚠️ Gem mismatch - Current: \(state.gems), Saved: \(savedGems). Keeping current value.")
            // Ensure UserDefaults matches current state
            UserDefaults.standard.set(state.gems, forKey: "coins")
        }
        
        // COMPREHENSIVE SESSION DATA RESTORATION
        
        // Restore power-up inventory
        if let powerUpData = UserDefaults.standard.data(forKey: "powerUpInventory"),
           let restoredInventory = try? JSONDecoder().decode([String: Int].self, from: powerUpData) {
            powerUpInventory = restoredInventory
            print("🔄 Restored power-up inventory: \(powerUpInventory)")
        }
        
        // Restore JourneyKit state
        let journeyHighest = UserDefaults.standard.integer(forKey: "journeyHighestTile")
        var claimedTiles: Set<Int> = []
        if let journeyClaimedData = UserDefaults.standard.data(forKey: "journeyClaimedTiles"),
           let decoded = try? JSONDecoder().decode([Int].self, from: journeyClaimedData) {
            claimedTiles = Set(decoded)
            print("🔄 Restored journey claimed tiles: \(claimedTiles.count)")
        }
        if journeyHighest > 0 || !claimedTiles.isEmpty {
            journey.restoreState(highestTile: journeyHighest, claimed: claimedTiles)
        }
        
        if let abbreviationClaimsData = UserDefaults.standard.data(forKey: journeyAbbreviationClaimsKey),
           let claims = try? JSONDecoder().decode([String].self, from: abbreviationClaimsData) {
            claimedJourneyAbbreviationRewards = Set(claims)
        }
        
        // Restore current path state
        if let currentPathData = UserDefaults.standard.data(forKey: "currentPath"),
           let pathArray = try? JSONDecoder().decode([[String: Int]].self, from: currentPathData) {
            currentPath = pathArray.compactMap { dict in
                guard let row = dict["row"], let col = dict["col"] else { return nil }
                return Position(row: row, col: col)
            }
        }
        
        let pathValidationIsValid = UserDefaults.standard.bool(forKey: "pathValidation")
        pathValidation = pathValidationIsValid ? .valid : .invalid("Restored invalid state")
        
        // Restore session state flags
        isExtendingToGift = UserDefaults.standard.bool(forKey: "isExtendingToGift")
        pendingUnlockRewardBase = UserDefaults.standard.object(forKey: "pendingUnlockRewardBase") as? Int
        pendingUnlockTile = UserDefaults.standard.object(forKey: "pendingUnlockTile") as? Int
        lastAddedTileValue = UserDefaults.standard.object(forKey: "lastAddedTileValue") as? Int
        pendingDoubleBase = UserDefaults.standard.object(forKey: "pendingDoubleBase") as? Int
        pendingDoubleBaseStep = UserDefaults.standard.object(forKey: "pendingDoubleBaseStep") as? Int

        // Restore broken glass tiles
        if let brokenGlassData = UserDefaults.standard.data(forKey: "brokenGlassTiles"),
           let glassArray = try? JSONDecoder().decode([[String: Int]].self, from: brokenGlassData) {
            brokenGlassTiles = Set(glassArray.compactMap { dict in
                guard let row = dict["row"], let col = dict["col"] else { return nil }
                return Position(row: row, col: col)
            })
        }
        
        restorePendingGiftBoxes()
        
        // Restore power-up history
        if let powerUpHistoryData = UserDefaults.standard.data(forKey: "powerUpHistory"),
           let historyArray = try? JSONSerialization.jsonObject(with: powerUpHistoryData) as? [[String: Any]] {
            powerUpHistory = historyArray.compactMap { dict in
                guard let type = dict["type"] as? String else { return nil }
                
                switch type {
                case "hammer":
                    if let posDict = dict["position"] as? [String: Int],
                       let row = posDict["row"], let col = posDict["col"] {
                        return .hammer(Position(row: row, col: col))
                    }
                case "swap":
                    if let pos1Dict = dict["position"] as? [String: Int],
                       let pos2Dict = dict["position2"] as? [String: Int],
                       let row1 = pos1Dict["row"], let col1 = pos1Dict["col"],
                       let row2 = pos2Dict["row"], let col2 = pos2Dict["col"] {
                        return .swap(Position(row: row1, col: col1), Position(row: row2, col: col2))
                    }
                case "shuffle":
                    return .shuffle
                case "undo":
                    return .undo
                default:
                    break
                }
                return nil
            }
        }
        
        // Restore moves history
        if let movesHistoryData = UserDefaults.standard.data(forKey: "movesHistory"),
           let movesArray = try? JSONSerialization.jsonObject(with: movesHistoryData) as? [[String: Any]] {
            movesHistory = movesArray.compactMap { dict -> [Position]? in
                guard let positionsArray = dict["positions"] as? [[String: Int]] else { return nil }
                
                let positions = positionsArray.compactMap { posDict -> Position? in
                    guard let row = posDict["row"], let col = posDict["col"] else { return nil }
                    return Position(row: row, col: col)
                }
                
                return positions.isEmpty ? nil : positions
            }
        }
        
        // Restore session statistics
        _ = UserDefaults.standard.integer(forKey: "totalMerges")
        _ = UserDefaults.standard.double(forKey: "totalTimePlayed")
        _ = UserDefaults.standard.integer(forKey: "gamesPlayed")
        _ = UserDefaults.standard.integer(forKey: "currentWinStreak")
        _ = UserDefaults.standard.integer(forKey: "bestWinStreak")
        
        // Restore session analytics
        if let analyticsData = UserDefaults.standard.data(forKey: "sessionAnalytics"),
           let analytics = try? JSONSerialization.jsonObject(with: analyticsData) as? [String: Any] {
            print("📊 Restored session analytics: \(analytics)")
        }
        
        print("📱 COMPREHENSIVE PROGRESS RESTORATION COMPLETE")
        print("   • Highest Tile: \(state.highestTile)")
        print("   • Best Score: \(savedBestScoreAlpha.formattedLabel())")
        print("   • Gems: \(state.gems)")
        if hasInfinityAchievement {
            print("   • Infinity Achievement: ✅")
        }
        refreshDerivedState(
            scoreAlpha: persistedScoreAlpha() ?? state.scoreValue,
            highestStep: persistedHighestTileStep() ?? state.highestTileStep
        )
        restoreScoreBoostState(from: nil)
        restorePowerDiscountState(from: nil)
        restoreAchievementBoostState()
    }
    
    private func persistPendingGiftBoxes() {
        guard !sandboxed else { return }
        let stored = pendingGiftBoxes.map { StoredGiftBox(row: $0.key.row, col: $0.key.col, reward: $0.value) }
        let data = try? JSONEncoder().encode(stored)
        UserDefaults.standard.set(data, forKey: "pendingGiftBoxes")
    }
    
    private func persistBrokenGlassTiles() {
        guard !sandboxed else { return }
        let brokenGlassData = try? JSONEncoder().encode(Array(brokenGlassTiles).map { ["row": $0.row, "col": $0.col] })
        UserDefaults.standard.set(brokenGlassData, forKey: "brokenGlassTiles")
    }
    
    private func restorePendingGiftBoxes() {
        guard let data = UserDefaults.standard.data(forKey: "pendingGiftBoxes"),
              let stored = try? JSONDecoder().decode([StoredGiftBox].self, from: data) else {
            pendingGiftBoxes = [:]
            return
        }
        pendingGiftBoxes = Dictionary(uniqueKeysWithValues: stored.map { (Position(row: $0.row, col: $0.col), $0.reward) })
    }
    
    private func persistAbbreviationClaims() {
        let payload = Array(claimedJourneyAbbreviationRewards)
        let data = try? JSONEncoder().encode(payload)
        UserDefaults.standard.set(data, forKey: journeyAbbreviationClaimsKey)
    }
    
    private func currentHighestJourneyStep() -> Int? {
        let highestValue = max(state.highestTile, journey.highestTile)
        return TileStepLabelFormatter.stepForValue(highestValue)
    }
    
    private func boardContainsInfinityTile() -> Bool {
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if state.board[pos]?.isInfinity == true {
                    return true
                }
            }
        }
        return false
    }
    
    private func addBonusSpins(_ amount: Int) {
        guard amount > 0 else { return }
        if let shared = spinWheelState {
            shared.addBonusSpins(amount)
        } else {
            // Fallback: create temporary instance (persists to UserDefaults)
            SpinWheelState().addBonusSpins(amount)
        }
    }
    
    private func addMultipliers(_ tier: SpinWheelState.MultiplierTier, count: Int) {
        guard count > 0 else { return }
        if let shared = spinWheelState {
            shared.addMultiplier(tier, count: count)
        } else {
            // Fallback: create temporary instance (persists to UserDefaults)
            SpinWheelState().addMultiplier(tier, count: count)
        }
    }

    // MARK: - Challenge Rewards

    /// Grants a full challenge reward including gems, power-ups, spins, and score boosts.
    /// `challengeID` should be a stable identifier (e.g. challenge slug, generated UUID per
    /// completion) so the ledger can dedup retries. Pass nil if there is no stable ID;
    /// a timestamp will be used and replays will be permitted within different seconds.
    public func grantChallengeReward(_ reward: ChallengeReward, challengeID: String? = nil) {
        let context = challengeID.map { "challenge:\($0)" }
            ?? "challenge:run:\(Int(Date().timeIntervalSince1970))"

        if reward.coins > 0 {
            grantWithLedger(source: .challenge, type: .gems, amount: reward.coins, contextKey: context) {
                self.addCoins(reward.coins)
            }
        }

        for (powerUpType, count) in reward.powerUps {
            let item: RewardLedgerEntry.ItemType
            switch powerUpType {
            case .hammer: item = .hammer
            case .swap: item = .swap
            case .magnet: item = .magnet
            case .undo: item = .undo
            case .shuffle: item = .shuffle
            case .double: item = .double
            }
            grantWithLedger(source: .challenge, type: item, amount: count, contextKey: context) {
                self.addPowerUp(powerUpType.rawValue, count: count)
            }
        }

        if reward.spins > 0 {
            grantWithLedger(source: .challenge, type: .spin, amount: reward.spins, contextKey: context) {
                self.addBonusSpins(reward.spins)
            }
        }

        for (multiplier, count) in reward.scoreBoosts {
            let tier: SpinWheelState.MultiplierTier?
            let type: RewardLedgerEntry.ItemType
            switch multiplier {
            case 2: tier = .twoX; type = .multiplier2x
            case 3: tier = .threeX; type = .multiplier3x
            case 4: tier = .fourX; type = .multiplier4x
            default: tier = nil; type = .multiplier2x
            }
            guard let tier else { continue }
            grantWithLedger(source: .challenge, type: type, amount: count, contextKey: context) {
                self.addMultipliers(tier, count: count)
            }
        }
    }

    private func grantWithLedger(
        source: RewardLedgerEntry.Source,
        type: RewardLedgerEntry.ItemType,
        amount: Int,
        contextKey: String,
        apply: @MainActor () -> Void
    ) {
        guard amount > 0 else { return }
        if let rewardLedger {
            rewardLedger.grant(
                source: source,
                itemType: type,
                amount: amount,
                idempotencyKey: "\(contextKey):\(type.rawValue):\(amount)",
                apply: apply
            )
        } else {
            apply()
        }
    }

    // MARK: - Session Tracking & Analytics
    
    /// Initialize comprehensive session tracking system
    public func initializeSessionTracking() {
        let now = Date()
        
        // Check if this is a new session or continuation
        if let lastSessionEnd = UserDefaults.standard.object(forKey: "lastSessionEndTime") as? Date {
            let timeSinceLastSession = now.timeIntervalSince(lastSessionEnd)
            
            // If more than 30 minutes have passed, start a new session
            if timeSinceLastSession > 1800 {
                startNewSession(now)
            } else {
                continueSession(now)
            }
        } else {
            // First time playing
            startNewSession(now)
        }
    }
    
    /// Start a new session with comprehensive tracking
    private func startNewSession(_ startTime: Date) {
        UserDefaults.standard.set(startTime, forKey: "sessionStartTime")
        UserDefaults.standard.set(startTime, forKey: "currentSessionStartTime")
        UserDefaults.standard.set(0, forKey: "sessionMoves")
        UserDefaults.standard.set(0, forKey: "sessionScore")
        UserDefaults.standard.set(0, forKey: "sessionMerges")
        UserDefaults.standard.set(0, forKey: "sessionHighestTile")
        UserDefaults.standard.set(0, forKey: "sessionPowerUpsUsed")
        UserDefaults.standard.set(0, forKey: "sessionEfficiencyScore")
        UserDefaults.standard.set([], forKey: "sessionMoveHistory")
        UserDefaults.standard.set([], forKey: "sessionPowerUpHistory")
        UserDefaults.standard.set([], forKey: "sessionAchievementHistory")
        
        // Initialize session analytics
        UserDefaults.standard.set(0, forKey: "sessionAverageMoveTime")
        UserDefaults.standard.set(0, forKey: "sessionLongestChain")
        UserDefaults.standard.set(0, forKey: "sessionShortestPath")
        UserDefaults.standard.set(0, forKey: "sessionWastedMoves")
        UserDefaults.standard.set(0, forKey: "sessionOptimalMoves")
        
        print("🎮 NEW SESSION STARTED at \(startTime)")
    }
    
    /// Continue existing session
    private func continueSession(_ currentTime: Date) {
        // Update session duration
        if let sessionStart = UserDefaults.standard.object(forKey: "currentSessionStartTime") as? Date {
            let sessionDuration = currentTime.timeIntervalSince(sessionStart)
            UserDefaults.standard.set(sessionDuration, forKey: "currentSessionDuration")
        }
        
        print("🔄 CONTINUING SESSION - Duration: \(UserDefaults.standard.double(forKey: "currentSessionDuration"))s")
    }
    
    /// Update session analytics in real-time
    public func updateSessionAnalytics() {
        // Update session statistics
        let sessionMoves = UserDefaults.standard.integer(forKey: "sessionMoves") + 1
        UserDefaults.standard.set(sessionMoves, forKey: "sessionMoves")
        
        let sessionScore = UserDefaults.standard.integer(forKey: "sessionScore")
        if state.score > sessionScore {
            UserDefaults.standard.set(state.score, forKey: "sessionScore")
        }
        
        let sessionHighest = UserDefaults.standard.integer(forKey: "sessionHighestTile")
        if state.highestTile > sessionHighest {
            UserDefaults.standard.set(state.highestTile, forKey: "sessionHighestTile")
        }
        
        // Calculate session efficiency
        let efficiency = calculateSessionEfficiency()
        UserDefaults.standard.set(efficiency, forKey: "sessionEfficiencyScore")
        
        // Update session duration
        if let sessionStart = UserDefaults.standard.object(forKey: "currentSessionStartTime") as? Date {
            let duration = Date().timeIntervalSince(sessionStart)
            UserDefaults.standard.set(duration, forKey: "currentSessionDuration")
        }
    }
    
    /// Calculate session efficiency score
    private func calculateSessionEfficiency() -> Double {
        let sessionMoves = UserDefaults.standard.integer(forKey: "sessionMoves")
        let sessionScore = UserDefaults.standard.integer(forKey: "sessionScore")
        let sessionDuration = UserDefaults.standard.double(forKey: "currentSessionDuration")
        
        guard sessionMoves > 0 && sessionDuration > 0 else { return 0.0 }
        
        // Efficiency = (Score per move) * (Moves per minute) * (Quality factor)
        let scorePerMove = Double(sessionScore) / Double(sessionMoves)
        let movesPerMinute = Double(sessionMoves) / (sessionDuration / 60.0)
        let qualityFactor = min(1.0, Double(sessionScore) / 10000.0) // Normalize quality
        
        return scorePerMove * movesPerMinute * qualityFactor
    }
    
    /// Track detailed move analytics
    public func trackMoveAnalytics(move: [Position]) {
        var moveHistory = UserDefaults.standard.array(forKey: "sessionMoveHistory") as? [[String: Any]] ?? []
        
        let moveData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "positions": move.map { ["row": $0.row, "col": $0.col] },
            "moveLength": move.count,
            "score": state.score,
            "highestTile": state.highestTile
        ]
        
        moveHistory.append(moveData)
        
        // Keep only last 100 moves to prevent memory issues
        if moveHistory.count > 100 {
            moveHistory = Array(moveHistory.suffix(100))
        }
        
        UserDefaults.standard.set(moveHistory, forKey: "sessionMoveHistory")
        
        // Update analytics
        let moveLength = move.count
        let currentLongest = UserDefaults.standard.integer(forKey: "sessionLongestChain")
        if moveLength > currentLongest {
            UserDefaults.standard.set(moveLength, forKey: "sessionLongestChain")
        }
        
        let currentShortest = UserDefaults.standard.integer(forKey: "sessionShortestPath")
        if currentShortest == 0 || moveLength < currentShortest {
            UserDefaults.standard.set(moveLength, forKey: "sessionShortestPath")
        }
    }
    
    /// Track power-up usage analytics
    public func trackPowerUpAnalytics(action: PowerUpAction) {
        var powerUpHistory = UserDefaults.standard.array(forKey: "sessionPowerUpHistory") as? [[String: Any]] ?? []
        
        let powerUpData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "type": String(describing: action),
            "score": state.score,
            "moves": state.moves
        ]
        
        powerUpHistory.append(powerUpData)
        UserDefaults.standard.set(powerUpHistory, forKey: "sessionPowerUpHistory")
        
        let sessionPowerUps = UserDefaults.standard.integer(forKey: "sessionPowerUpsUsed") + 1
        UserDefaults.standard.set(sessionPowerUps, forKey: "sessionPowerUpsUsed")
    }
    
    /// End current session and save comprehensive analytics
    public func endSession() {
        let endTime = Date()
        UserDefaults.standard.set(endTime, forKey: "lastSessionEndTime")
        
        // Calculate final session statistics
        let sessionDuration = UserDefaults.standard.double(forKey: "currentSessionDuration")
        let sessionMoves = UserDefaults.standard.integer(forKey: "sessionMoves")
        let sessionScore = UserDefaults.standard.integer(forKey: "sessionScore")
        let sessionEfficiency = UserDefaults.standard.double(forKey: "sessionEfficiencyScore")
        
        // Save session summary
        let sessionSummary: [String: Any] = [
            "startTime": UserDefaults.standard.object(forKey: "currentSessionStartTime") as? Date ?? Date(),
            "endTime": endTime,
            "duration": sessionDuration,
            "moves": sessionMoves,
            "score": sessionScore,
            "highestTile": UserDefaults.standard.integer(forKey: "sessionHighestTile"),
            "efficiency": sessionEfficiency,
            "powerUpsUsed": UserDefaults.standard.integer(forKey: "sessionPowerUpsUsed"),
            "longestChain": UserDefaults.standard.integer(forKey: "sessionLongestChain"),
            "shortestPath": UserDefaults.standard.integer(forKey: "sessionShortestPath")
        ]
        
        // Save to session history
        var sessionHistory = UserDefaults.standard.array(forKey: "sessionHistory") as? [[String: Any]] ?? []
        sessionHistory.append(sessionSummary)
        
        // Keep only last 50 sessions
        if sessionHistory.count > 50 {
            sessionHistory = Array(sessionHistory.suffix(50))
        }
        
        UserDefaults.standard.set(sessionHistory, forKey: "sessionHistory")
        
        print("📊 SESSION ENDED - Duration: \(String(format: "%.1f", sessionDuration))s, Score: \(sessionScore), Efficiency: \(String(format: "%.2f", sessionEfficiency))")
    }
    
    /// Get comprehensive session analytics
    public func getSessionAnalytics() -> [String: Any] {
        return [
            "currentSession": [
                "duration": UserDefaults.standard.double(forKey: "currentSessionDuration"),
                "moves": UserDefaults.standard.integer(forKey: "sessionMoves"),
                "score": UserDefaults.standard.integer(forKey: "sessionScore"),
                "highestTile": UserDefaults.standard.integer(forKey: "sessionHighestTile"),
                "efficiency": UserDefaults.standard.double(forKey: "sessionEfficiencyScore"),
                "powerUpsUsed": UserDefaults.standard.integer(forKey: "sessionPowerUpsUsed"),
                "longestChain": UserDefaults.standard.integer(forKey: "sessionLongestChain"),
                "shortestPath": UserDefaults.standard.integer(forKey: "sessionShortestPath")
            ],
            "sessionHistory": UserDefaults.standard.array(forKey: "sessionHistory") ?? [],
            "totalSessions": UserDefaults.standard.array(forKey: "sessionHistory")?.count ?? 0
        ]
    }

    // MARK: - Manual Progress Management
    
    /// Manually save current progress (call anytime)
    public func saveProgress() {
        saveProgressImmediately(newTile: nil)
        print("💾 Manual progress save completed")
    }

    /// Force sync gems from GameStore to Progress store
    /// Use when gems are out of sync (e.g., Progress has stale higher value)
    public func forceGemSync() {
        let gameStoreGems = state.gems
        let progressGems = progressStore.loadSync()?.gems ?? 0

        print("💎 Force gem sync: GameStore=\(gameStoreGems), Progress=\(progressGems)")

        // Ensure UserDefaults coins matches state.gems
        UserDefaults.standard.set(gameStoreGems, forKey: "coins")

        // Save full progress snapshot (uses state.gems)
        saveProgressToStore()

        print("💎 Gem sync complete: All stores now have \(gameStoreGems) gems")
    }
    
    /// Get current progress summary
    public func getProgressSummary() -> (highestTile: Int, bestScore: Int, gems: Int, hasInfinity: Bool) {
        let savedHighest = UserDefaults.standard.integer(forKey: "savedHighestTile")
        let savedBestAlpha = persistedBestScoreAlpha()
        let bestAlpha = state.scoreValue > savedBestAlpha ? state.scoreValue : savedBestAlpha
        let hasInfinity = UserDefaults.standard.bool(forKey: "hasInfinityAchievement")

        return (
            highestTile: max(savedHighest, state.highestTile),
            bestScore: bestAlpha.toInt(),
            gems: state.gems,
            hasInfinity: hasInfinity
        )
    }

    /// Reset corrupted score data and save current actual score
    /// Call this to fix score corruption from challenge mode bugs
    public func resetCorruptedScoreData() {
        guard !sandboxed else { return }

        // Clear all score-related UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedBestScore")
        UserDefaults.standard.removeObject(forKey: ScoreDefaultsKey.savedBestScoreAlpha)
        UserDefaults.standard.removeObject(forKey: "currentScore")
        UserDefaults.standard.removeObject(forKey: ScoreDefaultsKey.currentScoreAlpha)
        UserDefaults.standard.removeObject(forKey: "currentSessionScore")

        // Now save the current actual score from this game session
        UserDefaults.standard.set(state.score, forKey: "savedBestScore")
        UserDefaults.standard.set(state.scoreValue.decimalString, forKey: ScoreDefaultsKey.savedBestScoreAlpha)
        UserDefaults.standard.set(state.score, forKey: "currentScore")
        UserDefaults.standard.set(state.scoreValue.decimalString, forKey: ScoreDefaultsKey.currentScoreAlpha)

        UserDefaults.standard.synchronize()

        print("🔧 Reset corrupted score data. New best score: \(state.scoreValue.formattedLabel())")
    }
}

#if DEBUG
extension GameStore {
    func _testTriggerUnlockReward(newHigh: Int, previousHigh: Int) {
        state.highestTile = newHigh
        if let step = TileStepLabelFormatter.stepForValue(newHigh, start: 2) {
            state.highestTileStep = step
        }
        setPendingUnlockRewardIfNeeded(for: newHigh, previousHigh: previousHigh)
    }
    
    func _setHighestTileForTesting(_ value: Int) {
        state.highestTile = value
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            state.highestTileStep = step
        }
    }
    
    func _forceScoreBoost(tier: ScoreBoostTierID, expiration: Date?) {
        if let expiration {
            activateScoreBoost(tierID: tier, expiresAt: expiration, now: Date(), persist: false)
        } else {
            finishActiveBoost()
        }
    }
    
    func _refreshScoreBoost(now date: Date) {
        refreshScoreBoostCountdown(now: date)
    }
    
    func _activeScoreBoostTierIDForTesting() -> ScoreBoostTierID? {
        activeScoreBoostTierID
    }
    
    func _queuedScoreBoostTierIDForTesting() -> ScoreBoostTierID? {
        queuedScoreBoostTierID
    }
    
    func _forcePowerDiscount(tier: PowerDiscountTierID, expiration: Date?) {
        if let expiration {
            activatePowerDiscount(tierID: tier, expiresAt: expiration, now: Date(), persist: false)
        } else {
            finishActivePowerDiscount()
        }
    }
    
    func _refreshPowerDiscount(now date: Date) {
        refreshPowerDiscountCountdown(now: date)
    }
    
    func _activePowerDiscountTierIDForTesting() -> PowerDiscountTierID? {
        activePowerDiscountTierID
    }
    
    func _queuedPowerDiscountTierIDForTesting() -> PowerDiscountTierID? {
        queuedPowerDiscountTierID
    }
}
#endif
