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
    public var achievementEvaluator: AchievementEvaluator?

    // Track if game over has been processed for this session (reset on new game)
    private var gameOverProcessed: Bool = false

    // Sandboxed mode for challenges - doesn't persist progress to main game
    public let sandboxed: Bool

    // Progress store for comprehensive auto-save
    private let progressStore: UserDefaultsProgressStore
    // Track if we're building a chain that may end on a gift
    public private(set) var isExtendingToGift: Bool = false
    // Pending unlock reward (base amount before multiplier)
    public private(set) var pendingUnlockRewardBase: Int? = nil
    public private(set) var pendingUnlockTile: Int? = nil
    // Milestone notification pipeline
    public enum MergeNotification: Equatable, Sendable {
        case unlocked(Int)
        case added(Int)
        case excluded(Int)
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
    // Pending double offer value to apply (base value for doubling)
    public private(set) var pendingDoubleBase: Int? = nil
    // Track which glass tiles have been broken (positions in row 0)
    public private(set) var brokenGlassTiles: Set<Position> = []
    // Pending gift boxes (glass shattered but reward not claimed)
    public private(set) var pendingGiftBoxes: [Position: GiftReward] = [:]
    // Tiles spawned during refill that should fade in after gravity settles
    public private(set) var pendingRefillPositions: Set<Position> = []
    private var refillRevealTask: Task<Void, Never>? = nil
    private var mergeCleanupTask: Task<Void, Never>? = nil
    public private(set) var hammerAnimationState: HammerAnimationState? = nil
    // Gift reward sheet state
    public var pendingGiftReward: GiftReward? = nil
    private let journeyAbbreviationClaimsKey = "journeyAbbreviationClaims"
    public private(set) var claimedJourneyAbbreviationRewards: Set<String> = []
    private var pendingJourneyRewardTierID: String? = nil
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
    public static func sandboxed(config: GameConfig = GameConfig(), initialGems: Int = 0) -> GameStore {
        let store = GameStore(config: config, sandboxed: true)
        store.coins = initialGems
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
            // Don't call refreshDerivedState here - we'll do a simple setup
            // since sandboxed mode doesn't need to track derived state
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
            
            // Restore power-up inventory
            self.powerUpInventory = progress.powerUpInventory
            
            // Restore journey state
            self.journey.highestTile = progress.journeyState.highestTile
            self.journey.claimed = progress.journeyState.claimedTiles
            self.claimedJourneyAbbreviationRewards = progress.journeyState.claimedAbbreviationTiers
            
            // Restore session-specific data
            self.brokenGlassTiles = Set(sessionState.brokenGlassTiles)
            self.movesHistory = sessionState.movesHistory
            self.lastDailyDateUTC = sessionState.lastDailyDateUTC
            
            print("🎮 Restored complete game session - Moves: \(sessionState.moves), Score: \(sessionState.score), Highest: \(sessionState.highestTile)")
        } else {
            // Start fresh
            let engine = GameEngine(config: config)
            self.engine = engine
            self.state = engine.currentState()
            refreshDerivedState(highestStep: persistedHighestTileStep())
            
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
                self.journey.highestTile = progress.journeyState.highestTile
                self.journey.claimed = progress.journeyState.claimedTiles
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
        isExtendingToGift = false
    }
    
    public func extendPath(to position: Position) {
        guard !currentPath.contains(position) else { return }
        guard pendingGiftBoxes[position] == nil else { return }
        
        if let last = currentPath.last, !last.isAdjacent(to: position) {
            return
        }
        
        currentPath.append(position)
        
        // Check if we're extending to a gift cell
        let boardIndex = BoardIndex(position)
        isExtendingToGift = state.board[boardIndex].kind == .gift
        
        // Use gift-aware validation if the chain ends on a gift
        if isExtendingToGift {
            pathValidation = engine.validateGiftChain(currentPath)
        } else {
            pathValidation = engine.validateChain(currentPath)
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
        isInputLocked = false
        isExtendingToGift = false
    }
    
    public func commitPath() {
        guard pathValidation.isValid else { return }
        guard !currentPath.isEmpty else { return }
        
        let positions = currentPath
        guard let lastPos = positions.last else { return }
        
        print("[GameStore] Starting commitPath sequence. Positions: \(positions.count)")
        
        // Lock input to prevent interaction during animation
        isInputLocked = true
        
        // Clear the path immediately so the line disappears
        currentPath = []
        pathValidation = .valid
        
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
                
                // Wait 0.5s for shatter and delay
                try await Task.sleep(nanoseconds: 500_000_000)
                
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
                print("[GameStore] Phase 3: Commit (Logic)")
                let (requiresGravityDrop, affectedColumns) = self.performCommit(positions: positions)
                
                if requiresGravityDrop {
                    print("[GameStore] Phase 3b: Gravity Drop")
                    self.performGravityDrop(columns: affectedColumns)
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
    
    private func performRefill(columns: Set<Int>? = nil) {
        let previousBoard = state.board
        if let cols = columns, !cols.isEmpty {
            let newState = engine.refillColumns(cols)
            state = newState
            markRefills(previousBoard: previousBoard, newBoard: newState.board, scopedColumns: cols)
        } else {
            let newState = engine.refillBoard()
            applyStateUpdate(newState, previousBoard: previousBoard)
        }
    }
    
    private func performGravityDrop(columns: Set<Int>? = nil) {
        if let cols = columns, !cols.isEmpty {
            let newState = engine.collapseColumns(cols)
            state = newState
        } else {
            let newState = engine.applyGravityAfterChain()
            state = newState
        }
    }
    
    @discardableResult
    private func performCommit(positions: [Position]) -> (Bool, Set<Int>) {
        let previousHighest = state.highestTile
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
        // IMPORTANT: Preserve gems from UserDefaults - the engine doesn't track spending correctly
        let savedGems = UserDefaults.standard.integer(forKey: "coins")
        let gemsToPreserve = savedGems > 0 ? savedGems : state.gems
        state = newState
        state.gems = gemsToPreserve  // Restore gems after state update
        // We manually handle refill reveal later in performRefill
        
        // Break glass tiles for any positions in row 0 that were part of this connection
        for position in positions {
            if position.row == 0 {
                if brokenGlassTiles.insert(position).inserted {
                    newlyBrokenGlass.append(position)
                }
            }
        }
        
        if !newlyBrokenGlass.isEmpty {
            for position in newlyBrokenGlass {
                pendingGiftBoxes[position] = GiftReward.randomReward(isFromGlassShatter: true)
            }
            persistPendingGiftBoxes()
        }
        // Added value is the tile now at lastPos
        let addedValue: Int = {
            if let lp = lastPos, let v = state.board[lp]?.value { return v }
            return 0
        }()
        lastAddedTileValue = addedValue > 0 ? addedValue : nil

        // IMPORTANT: Remove non-glass gift triggers. Gifts are only awarded on shattered glass.
        // (No milestone/random gift triggers here.)
        
        // Notify JourneyKit of the new tile value
        if addedValue > 0 {
            journey.didReach(tile: addedValue)
            // Also persist the highest tile to UserDefaults
            if addedValue > previousHighest {
                UserDefaults.standard.set(addedValue, forKey: "highestTile")
            }
            
            if let lastPos,
               let tile = state.board[lastPos],
               tile.isInfinity {
                achievementEvaluator?.onInfinityCreated()
            }
            
            // CRITICAL: Auto-save progress for any new tile creation
            saveProgressImmediately(newTile: addedValue)
        }
        // Offer to double only if we created a tile that is one below the previous highest
        // or another instance of the previous highest.
        if addedValue > 0 {
            if let resultPosition = lastPos {
                incrementTierMasteryCount(for: state.board[resultPosition], value: addedValue, chainLength: positions.count)
            }
            let offerIfOneBelow = (previousHighest >= 4) && (addedValue == previousHighest / 2)
            let offerIfAnotherHighest = (addedValue == previousHighest)
            pendingDoubleBase = (offerIfOneBelow || offerIfAnotherHighest) ? addedValue : nil
        } else {
            pendingDoubleBase = nil
        }
        let unlockedValue: Int? = state.highestTile > previousHighest ? state.highestTile : nil
        if let unlockedValue {
            setPendingUnlockRewardIfNeeded(for: unlockedValue, previousHigh: previousHighest)
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
        print("🎮 Game over processed - playtime saved")
    }

    private static let mergeAnimationDelay: UInt64 = 400_000_000
    private static let gravityAnimationDelay: UInt64 = 350_000_000
    private static let refillRevealDelay: UInt64 = 350_000_000
    private static let magnetSuckDelay: UInt64 = 400_000_000
    private static let hammerWindupDelay: UInt64 = 250_000_000
    private static let hammerImpactDelay: UInt64 = 250_000_000
    
    private func applyStateUpdate(
        _ newState: GameState,
        previousBoard: Board,
        refillProtectedPositions: Set<Position> = []
    ) {
        // ALWAYS preserve gems from UserDefaults - this is the source of truth for spending
        let savedGems = UserDefaults.standard.integer(forKey: "coins")
        let gemsToUse = savedGems > 0 ? savedGems : state.gems
        state = newState
        state.gems = gemsToUse
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
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false  // Reset for new game session

        // Notify achievement evaluator
        achievementEvaluator?.onGameStart(state: state)
    }

    /// Reset game with a custom GameConfig (used for challenge mode)
    public func resetGame(with config: GameConfig) {
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
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false

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
        brokenGlassTiles = []
        pendingGiftBoxes = [:]
        movesHistory = []
        powerUpHistory = []
        persistPendingGiftBoxes()
        gameOverProcessed = false  // Reset for new game session
    }


    // MARK: - Economy
    public func addCoins(_ amount: Int) {
        state.gems = max(0, state.gems + amount)
        syncEngineGems()
        UserDefaults.standard.set(state.gems, forKey: "coins")
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
        UserDefaults.standard.set(state.gems, forKey: "coins")
        // Force immediate synchronization to prevent race conditions
        UserDefaults.standard.synchronize()
        // Also save to progress store immediately
        saveProgressToStore()
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
    private func baseUnlockReward(for tileValue: Int) -> Int {
        // Milestone rewards start at 512 (2^9) with +2 gems per subsequent milestone.
        guard tileValue >= 512 else { return 0 }
        guard tileValue.nonzeroBitCount == 1 else { return 0 } // Require true power-of-two milestones.
        let exponent = tileValue.trailingZeroBitCount
        let stepsFromFirstMilestone = max(0, exponent - 9)
        return 50 + (stepsFromFirstMilestone * 2)
    }
    
    private func setPendingUnlockRewardIfNeeded(for newHigh: Int, previousHigh: Int) {
        guard newHigh > previousHigh else { return }
        let base = baseUnlockReward(for: newHigh)
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
        guard isAbbreviationTierUnlocked(tier), !hasClaimedAbbreviationTier(tier) else { return }
        pendingJourneyRewardTierID = tier.id
        pendingGiftReward = JourneyAbbreviationRewardCurve.reward(for: tier)
    }
    
    public func claimGiftReward() {
        guard let reward = pendingGiftReward else { return }
        
        // Apply the rewards to the player's inventory
        for item in reward.items {
            switch item.type {
            case .hammer:
                addPowerUp("hammer", count: item.amount)
            case .magnet:
                addPowerUp("magnet", count: item.amount)
            case .gems:
                // Add gems to coins (assuming gems are stored as coins)
                addCoins(item.amount)
            case .swap:
                addPowerUp("swap", count: item.amount)
            case .undo:
                addPowerUp("undo", count: item.amount)
            case .bonusSpin:
                addBonusSpins(item.amount)
            case .boost2x:
                addMultipliers(.twoX, count: item.amount)
            case .boost3x:
                addMultipliers(.threeX, count: item.amount)
            case .boost4x:
                addMultipliers(.fourX, count: item.amount)
            }
        }
        
        // Clear the pending reward
        pendingGiftReward = nil
        
        if let tierID = pendingJourneyRewardTierID {
            claimedJourneyAbbreviationRewards.insert(tierID)
            persistAbbreviationClaims()
            pendingJourneyRewardTierID = nil
        }
    }
    
    public func dismissGiftReward() {
        pendingGiftReward = nil
        pendingJourneyRewardTierID = nil
    }
    
    public func tapGiftBox(at position: Position) {
        guard pendingGiftReward == nil else { return }
        guard let reward = pendingGiftBoxes.removeValue(forKey: position) else { return }
        pendingJourneyRewardTierID = nil
        pendingGiftReward = reward
        persistPendingGiftBoxes()
    }
    
    // MARK: - Double Offer
    public func clearPendingDoubleOffer() {
        pendingDoubleBase = nil
    }
    
    @discardableResult
    public func applyDouble(to position: Position) -> Bool {
        guard let base = pendingDoubleBase else { return false }
        
        // Capture previous highest for milestone detection
        let previousHighest = state.highestTile
        
        let previousBoard = state.board
        let newState = engine.applyDouble(to: position, from: base)
        applyStateUpdate(newState, previousBoard: previousBoard, refillProtectedPositions: Set([position]))
        pendingDoubleBase = nil
        
        // Notify JourneyKit if we created a new highest tile
        // Use safe multiplication to prevent overflow
        let doubledValue = base <= (Int.max >> 1) ? base * 2 : Int.max
        journey.didReach(tile: doubledValue)
        
        // Show milestone notification if this created a new highest tile
        setMergeInfoIfMilestone(previousHighest: previousHighest, newTileValue: doubledValue)
        
        // Persist if this is a new highest tile
        if doubledValue > state.highestTile {
            UserDefaults.standard.set(doubledValue, forKey: "highestTile")
            // Save formatted milestone for leaderboard display
            let formattedMilestone = TileStepLabelFormatter.formatTileValue(doubledValue)
            UserDefaults.standard.set(formattedMilestone, forKey: "leaderboard.milestone")
        }

        // Save progress for doubled tile (could be massive achievement)
        saveProgressImmediately(newTile: doubledValue)
        
        return true
    }
    
    public func clearLastMagnetEvent() {
        lastMagnetEvent = nil
    }
    
    private func showNextNotification() {
        guard !notificationQueue.isEmpty else {
            currentNotification = nil
            return
        }
        currentNotification = notificationQueue.removeFirst()
    }
    
    public func dismissCurrentNotification() {
        currentNotification = nil
        showNextNotification()
    }
    
    /// Queue milestone notifications in the order: unlocked → added → eliminated.
    /// Only shows notifications for actual changes (not for skip milestones)
    private func setMergeInfoIfMilestone(previousHighest: Int, newTileValue: Int) {
        guard newTileValue > previousHighest else { return }

        var pending: [MergeNotification] = []

        // Get all milestones we passed
        let passedMilestones = engine.milestonesBetween(previousHighest, and: newTileValue)

        // Always show unlock notification for the new highest tile
        pending.append(.unlocked(newTileValue))

        // Check if any passed milestones add new spawn values
        var addedValue: Int? = nil
        for milestone in passedMilestones {
            if let added = engine.milestoneAddedValue(for: milestone) {
                // Track the highest added value
                if addedValue == nil || added > addedValue! {
                    addedValue = added
                }
            }
        }

        // Only show added notification if something was actually added
        if let added = addedValue {
            pending.append(.added(added))
        }

        // Check if any passed milestones eliminate values
        var eliminatedValues: Set<Int> = []
        for milestone in passedMilestones {
            if let eliminated = engine.milestoneExcludedValue(for: milestone) {
                eliminatedValues.insert(eliminated)
            }
        }

        // Only show excluded notification if something was actually eliminated
        // Show the highest eliminated value (most recent)
        if let maxEliminated = eliminatedValues.max() {
            pending.append(.excluded(maxEliminated))
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
            
            let dropState = self.engine.collapseColumns([position.col])
            self.state = dropState
            
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
        previousHighest: Int
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
            
            let magnetResult = self.engine.magnetize(value: value, to: position)
            self.state = magnetResult
            
            let mergedValue = magnetResult.board[position]?.value ?? {
                return value <= (Int.max >> 1) ? value * 2 : Int.max
            }()
            
            self.setMergeInfoIfMilestone(previousHighest: previousHighest, newTileValue: mergedValue)
            self.achievementEvaluator?.onTilesMerged(count: matchingPositions.count)
            
            let cols = self.columnsWithEmpties(in: self.state.board)
            self.performGravityDrop(columns: cols)
            
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
        let highest = state.highestTile
        guard highest >= 512 else { return 0 }
        let exponent = Int.bitWidth - highest.leadingZeroBitCount - 1
        let milestonesUnlocked = max(0, exponent - 8)
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
        } else {
            guard spendCoins(powerUpPrice("hammer")) else { return false }
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
        } else {
            guard spendCoins(powerUpPrice("swap")) else { return false }
        }
        
        let previousBoard = state.board
        let newState = engine.swap(a, b)
        applyStateUpdate(newState, previousBoard: previousBoard)
        powerUpHistory.append(.swap(a, b))
        trackPowerUpAnalytics(action: .swap(a, b))
        achievementEvaluator?.onPowerUpUsed(type: "swap")
        
        // Save progress after swap power-up
        saveProgressImmediately(newTile: nil)
        
        return true
    }
    
    @discardableResult
    public func useShuffle() -> Bool {
        guard isPowerUpAvailable("shuffle") else { return false }
        
        // Use inventory first, then coins
        if powerUpInventory["shuffle", default: 0] > 0 {
            powerUpInventory["shuffle", default: 0] -= 1
        } else {
            guard spendCoins(powerUpPrice("shuffle")) else { return false }
        }
        
        let previousBoard = state.board
        let newState = engine.shuffle()
        applyStateUpdate(newState, previousBoard: previousBoard)
        powerUpHistory.append(.shuffle)
        trackPowerUpAnalytics(action: .shuffle)
        achievementEvaluator?.onPowerUpUsed(type: "shuffle")
        
        // Save progress after shuffle power-up
        saveProgressImmediately(newTile: nil)
        
        return true
    }
    
    @discardableResult
    public func useUndo() -> Bool {
        guard state.undoAvailable else { return false }
        // Undo doesn't use inventory in this implementation
        let previousBoard = state.board
        // Preserve the current gems value (coins) before undo
        let currentGems = state.gems
        var newState = engine.undo()
        // Restore the current gems value to prevent reverting purchases
        newState.gems = currentGems
        applyStateUpdate(newState, previousBoard: previousBoard)
        // Sync the engine's gems state to match the preserved value
        syncEngineGems()
        powerUpHistory.append(.undo)
        trackPowerUpAnalytics(action: .undo)
        achievementEvaluator?.onUndoUsed()
        
        // Save progress after undo (could restore significant state)
        saveProgressImmediately(newTile: nil)
        
        return true
    }
    
    @discardableResult
    public func useMagnet(value: Int, to position: Position) -> Bool {
        guard !isInputLocked else { return false }
        guard isPowerUpAvailable("magnet") else { return false }
        guard let tile = state.board[position],
              tile.value == value,
              let targetStep = tile.stepIndex else { return false }
        guard pendingGiftBoxes[position] == nil else { return false }
        
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
        guard matchingPositions.count > 1 else { return false }
        
        // Deduct power-up cost
        if powerUpInventory["magnet", default: 0] > 0 {
            powerUpInventory["magnet", default: 0] -= 1
        } else {
            guard spendCoins(powerUpPrice("magnet")) else { return false }
        }
        
        // Capture previous highest for milestone detection
        let previousHighest = state.highestTile
        
        // Track power-up usage
        trackPowerUpAnalytics(action: .magnet(value: value, position: position))
        achievementEvaluator?.onMagnetUsed(mergeCount: matchingPositions.count)
        runMagnetPipeline(
            value: value,
            position: position,
            matchingPositions: matchingPositions,
            previousHighest: previousHighest
        )
        
        return true
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

    
    public func exportReplay() throws -> String {
        let replay = Replay(seed: engine.seedUsed, moves: movesHistory, powerUps: powerUpHistory)
        let data = try JSONEncoder().encode(replay)
        return "GR1|" + data.base64EncodedString()
    }
    
    public func importReplay(_ code: String) throws -> Replay {
        let parts = code.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0] == "GR1" else { throw ReplayError.invalidFormat }
        guard let data = Data(base64Encoded: parts[1]) else { throw ReplayError.invalidFormat }
        return try JSONDecoder().decode(Replay.self, from: data)
    }
    
    public enum ReplayError: Error { case invalidFormat }

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
        tierMasteryCounts[suffix, default: 0] += chainLength
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
            state.scoreValue = scoreAlpha
        } else if state.scoreValue.isZero && state.score > 0 {
            state.scoreValue = AlphaNumber(state.score)
        }

        // CRITICAL FIX: Always use the persisted highestTileStep as the source of truth
        // This fixes the bug where tiles with step >= 62 lose their .highValue(step:) type
        // during save/restore, causing them to be recalculated as step 62 (from Int.max)
        let persistedStep = persistedHighestTileStep() ?? 0

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
        
        // Create session state
        let sessionState = GameProgress.SessionState(
            board: state.board,
            score: state.score,
            moves: state.moves,
            level: state.level,
            highestTile: state.highestTile,
            highestTileStep: state.highestTileStep,
            seed: engine.seedUsed,
            brokenGlassTiles: Array(brokenGlassTiles),
            movesHistory: movesHistory,
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
    
    public func registerChallengeCreationCompleted() {
        achievementEvaluator?.onChallengeCreationCompleted()
    }
    
    
    // MARK: - Legacy Progress Auto-Save System (for backward compatibility)
    
    public func saveProgressImmediately(newTile: Int?) {
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
        UserDefaults.standard.set(currentHighest, forKey: "currentHighestTile")
        
        // ALWAYS update all-time highest if current session beats it
        let allTimeHighest = UserDefaults.standard.integer(forKey: "savedHighestTile")
        if currentHighest > allTimeHighest {
            UserDefaults.standard.set(currentHighest, forKey: "savedHighestTile")
            print("🏆 New all-time highest tile: \(currentHighest)")
        }
        UserDefaults.standard.set(state.highestTileStep, forKey: ScoreDefaultsKey.currentHighestStep)
        #if DEBUG
        print("💾 Saved highestTileStep: \(state.highestTileStep)")
        #endif
        
        // Log EVERY tile creation (not just records)
        if let tile = newTile, tile > 0 {
            if tile >= Int.max {
                print("♾️  INFINITY TILE CREATED!")
            } else if tile >= 2_147_483_648 { // 2B
                print("🌟 2B TILE CREATED!")
            } else if tile >= 1_073_741_824 { // 1B
                print("💎 1B TILE CREATED!")
            } else {
                print("🆕 Tile created: \(tile)")
            }
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
        
        let currentTotalMoves = UserDefaults.standard.integer(forKey: "totalMoves")
        UserDefaults.standard.set(currentTotalMoves + 1, forKey: "totalMoves")
        
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
        UserDefaults.standard.set(true, forKey: "hasAchievementsBadge")
        
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
        print("   • Session highest: \(currentHighest)")
        print("   • Session score: \(state.score)")
        print("   • Gems: \(state.gems)")
        print("   • Moves: \(state.moves)")
        print("   • Power-ups: \(powerUpInventory)")
        print("   • Journey highest: \(journey.highestTile)")
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
        let savedBestScoreAlpha = persistedBestScoreAlpha()
        let savedGems = UserDefaults.standard.integer(forKey: "coins")
        let hasInfinityAchievement = UserDefaults.standard.bool(forKey: "hasInfinityAchievement")
        if let currentScoreString = UserDefaults.standard.string(forKey: ScoreDefaultsKey.currentScoreAlpha),
           let alpha = AlphaNumber(decimalString: currentScoreString) {
            state.scoreValue = alpha
        } else {
            state.scoreValue = AlphaNumber(state.score)
        }
        
        // Restore infinity achievement
        if hasInfinityAchievement {
            print("♾️  INFINITY ACHIEVEMENT RESTORED!")
        }
        
        if savedHighest > state.highestTile {
            state.highestTile = savedHighest
            journey.didReach(tile: savedHighest)
            if savedHighest >= 2_147_483_648 {
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
        if journeyHighest > 0 {
            journey.highestTile = journeyHighest
        }
        
        if let journeyClaimedData = UserDefaults.standard.data(forKey: "journeyClaimedTiles"),
           let claimedTiles = try? JSONDecoder().decode([Int].self, from: journeyClaimedData) {
            journey.claimed = Set(claimedTiles)
            print("🔄 Restored journey claimed tiles: \(claimedTiles.count)")
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
        let spinState = SpinWheelState()
        spinState.addBonusSpins(amount)
    }
    
    private func addMultipliers(_ tier: SpinWheelState.MultiplierTier, count: Int) {
        guard count > 0 else { return }
        let spinState = SpinWheelState()
        spinState.addMultiplier(tier, count: count)
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
}

#if DEBUG
extension GameStore {
    func _testTriggerUnlockReward(newHigh: Int, previousHigh: Int) {
        setPendingUnlockRewardIfNeeded(for: newHigh, previousHigh: previousHigh)
    }
    
    func _setHighestTileForTesting(_ value: Int) {
        state.highestTile = value
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
