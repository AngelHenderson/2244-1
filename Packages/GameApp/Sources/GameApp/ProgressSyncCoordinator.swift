import Foundation

public actor ProgressSyncCoordinator: Sendable {
    private let local: ProgressStore
    private let remote: ProgressStore?
    private let seed: SeedConfig
    
    public struct SeedConfig: Sendable {
        public var starterGems: Int = 305
        public var starterTheme: String? = "beach"
        public var starterRank: Int? = nil
        
        public init(
            starterGems: Int = 305,
            starterTheme: String? = "beach",
            starterRank: Int? = nil
        ) {
            self.starterGems = starterGems
            self.starterTheme = starterTheme
            self.starterRank = starterRank
        }
    }

    public init(
        local: ProgressStore,
        remote: ProgressStore? = nil,
        seed: SeedConfig = .init()
    ) {
        self.local = local
        self.remote = remote
        self.seed = seed
    }

    /// Bootstraps progress for the current user and ensures local/remote are consistent.
    public func bootstrap(userIsSignedIn: Bool) async throws -> GameProgress {
        // Load local and remote progress in parallel
        async let localProgress = local.load()
        async let remoteProgress = userIsSignedIn ? remote?.load() : nil
        
        let localVal = try await localProgress
        let remoteVal = try await remoteProgress ?? nil

        let merged: GameProgress
        switch (localVal, remoteVal) {
        case let (l?, r?):
            // Both exist - merge them
            merged = merge(l, r)
        case let (l?, nil):
            // Only local exists
            merged = l
        case let (nil, r?):
            // Only remote exists
            merged = r
        case (nil, nil):
            // Neither exists - create new with seed values
            merged = GameProgress(
                highestTile: 0,
                bestScore: 0,
                gems: seed.starterGems,
                gamesPlayed: 0,
                achievements: [],
                theme: seed.starterTheme,
                rank: seed.starterRank,
                lastUpdatedAt: Date()
            )
        }

        // Save merged state to both stores
        try await local.save(merged)
        if userIsSignedIn, let remote {
            try await remote.save(merged)
        }
        
        return merged
    }

    /// Apply a mutation and persist locally (and remotely if applicable).
    public func apply(
        _ mutate: @Sendable (inout GameProgress) -> Void,
        userIsSignedIn: Bool
    ) async throws -> GameProgress {
        let loadedProgress = try await local.load()
        var progress: GameProgress
        if let loaded = loadedProgress {
            progress = loaded
        } else {
            progress = try await bootstrap(userIsSignedIn: userIsSignedIn)
        }
        mutate(&progress)
        
        try await local.save(progress)
        if userIsSignedIn, let remote {
            try await remote.save(progress)
        }
        
        return progress
    }
    
    /// Sync local and remote progress
    public func sync(userIsSignedIn: Bool) async throws -> GameProgress {
        guard userIsSignedIn, let remote else {
            // No remote, just return local
            let localProgress = try await local.load()
            if let local = localProgress {
                return local
            } else {
                return try await bootstrap(userIsSignedIn: false)
            }
        }
        
        async let localProgress = local.load()
        async let remoteProgress = remote.load()
        
        let localVal = try await localProgress
        let remoteVal = try await remoteProgress
        
        // Merge and save
        let merged: GameProgress
        switch (localVal, remoteVal) {
        case let (l?, r?):
            merged = merge(l, r)
        case let (l?, nil):
            merged = l
        case let (nil, r?):
            merged = r
        case (nil, nil):
            return try await bootstrap(userIsSignedIn: userIsSignedIn)
        }
        
        try await local.save(merged)
        try await remote.save(merged)
        
        return merged
    }

    // MARK: - Merge Policy
    private func merge(_ a: GameProgress, _ b: GameProgress) -> GameProgress {
        // Merge policy: take the best/maximum values from both
        GameProgress(
            highestTile: max(a.highestTile, b.highestTile),
            bestScore: max(a.bestScore, b.bestScore),
            gems: max(a.gems, b.gems), // Conservative: avoid gem loss
            gamesPlayed: max(a.gamesPlayed, b.gamesPlayed),
            achievements: a.achievements.union(b.achievements),
            theme: b.lastUpdatedAt > a.lastUpdatedAt ? b.theme : a.theme,
            rank: b.rank ?? a.rank,
            lastUpdatedAt: max(a.lastUpdatedAt, b.lastUpdatedAt),
            totalMerges: max(a.totalMerges, b.totalMerges),
            totalTimePlayed: max(a.totalTimePlayed, b.totalTimePlayed),
            unlockedThemes: a.unlockedThemes.union(b.unlockedThemes),
            completedDailyChallenges: max(a.completedDailyChallenges, b.completedDailyChallenges),
            currentWinStreak: max(a.currentWinStreak, b.currentWinStreak),
            bestWinStreak: max(a.bestWinStreak, b.bestWinStreak)
        )
    }
}

// MARK: - HomeState Extension
extension HomeState {
    /// Update HomeState from GameProgress
    @MainActor
    public func apply(progress p: GameProgress, planner: MilestonePlanner) {
        rank = p.rank ?? rank
        gems = p.gems
        
        let m = planner.milestones(for: p.highestTile)
        highestTile = m.current
        milestoneBelow = m.below ?? milestoneBelow
        lockedMilestones = m.above
        // Compute locks from thresholds
        isCreateLocked = highestTile < createUnlockAt
        isChallengeLocked = highestTile < challengeUnlockAt
        
        // Update theme names based on current theme
        if let currentTheme = p.theme {
            // You could map theme IDs to display names here
            // For now, capitalize the theme ID
            themesLeftName = currentTheme == "beach" ? "Beach" : themesLeftName
            themesRightName = currentTheme == "aqua" ? "Aqua" : themesRightName
        }
    }
    
    /// Convert HomeState to GameProgress for saving
    public func toProgress() -> GameProgress {
        GameProgress(
            highestTile: highestTile,
            bestScore: 0, // Would need to get from GameStore
            gems: gems,
            gamesPlayed: 0, // Would need to track
            achievements: [],
            theme: themesLeftName.lowercased(),
            rank: rank,
            lastUpdatedAt: Date()
        )
    }
}
