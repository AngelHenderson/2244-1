import Foundation

@MainActor
@Observable
public final class DailyClaimsStore {
    public struct DailyClaim: Identifiable {
        public let id: String
        public let day: Int
        public let rewards: AchievementDef.Rewards
        public var isClaimed: Bool
        public var isAvailable: Bool
    }
    
    public struct DailyStreak: Identifiable {
        public let id: String
        public let day: Int
        public let rewards: AchievementDef.Rewards
        public var isUnlocked: Bool
    }
    
    public private(set) var dailyClaims: [DailyClaim] = []
    public private(set) var dailyStreaks: [DailyStreak] = []
    public private(set) var currentStreak: Int = 0
    public private(set) var currentClaimDay: Int = 0
    public private(set) var lastClaimDate: Date?
    public private(set) var canClaimToday: Bool = false
    
    private let storage: UserDefaults
    private let visibleLookaheadDays = 21
    private static let streakKey = "dailyStreak"
    private static let claimDayKey = "dailyClaimDay"
    private static let lastClaimKey = "lastClaimDate"
    private static let claimedDaysKey = "claimedDays"
    private static let unlockedStreaksKey = "unlockedStreaks"
    
    private var claimedDays: Set<Int> = []
    private var unlockedStreaks: Set<Int> = []
    
    public var onReward: (@MainActor (AchievementDef.Rewards) -> Void)?
    
    public init(storage: UserDefaults = .standard) {
        self.storage = storage
        loadProgress()
        Task {
            await loadCatalogs()
            updateAvailability()
        }
    }
    
    @MainActor
    public func loadCatalogs() async {
        // Procedurally generate daily claims
        ensureClaims(upTo: visibleUpperBound())
        
        // Load daily streaks catalog
        if let streaksURL = Bundle.main.url(forResource: "daily_streaks_365", withExtension: "json") {
            do {
                let data = try Data(contentsOf: streaksURL)
                let achievements = try JSONDecoder().decode([AchievementDef].self, from: data)
                
                dailyStreaks = achievements.compactMap { achievement in
                    // Extract day number from conditions
                    if let dayCondition = achievement.conditions.first(where: { $0.field == "daily_streak" }),
                       let day = dayCondition.value.map(Int.init) {
                        return DailyStreak(
                            id: achievement.id,
                            day: day,
                            rewards: achievement.rewards ?? AchievementDef.Rewards(),
                            isUnlocked: unlockedStreaks.contains(day)
                        )
                    }
                    return nil
                }.sorted { $0.day < $1.day }
            } catch {
                print("Failed to load daily streaks catalog: \(error)")
            }
        }
    }
    
    private func loadProgress() {
        currentStreak = storage.integer(forKey: Self.streakKey)
        currentClaimDay = storage.integer(forKey: Self.claimDayKey)
        if let lastClaimTimestamp = storage.object(forKey: Self.lastClaimKey) as? Double {
            lastClaimDate = Date(timeIntervalSince1970: lastClaimTimestamp)
        }
        
        claimedDays = Set(storage.array(forKey: Self.claimedDaysKey) as? [Int] ?? [])
        unlockedStreaks = Set(storage.array(forKey: Self.unlockedStreaksKey) as? [Int] ?? [])
    }
    
    private func saveProgress() {
        storage.set(currentStreak, forKey: Self.streakKey)
        storage.set(currentClaimDay, forKey: Self.claimDayKey)
        if let lastClaimDate = lastClaimDate {
            storage.set(lastClaimDate.timeIntervalSince1970, forKey: Self.lastClaimKey)
        }
        
        // Save claimed days
        storage.set(Array(claimedDays).sorted(), forKey: Self.claimedDaysKey)
        
        // Save unlocked streaks
        storage.set(Array(unlockedStreaks).sorted(), forKey: Self.unlockedStreaksKey)
    }
    
    @MainActor
    public func updateAvailability() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if we can claim today
        if let lastClaim = lastClaimDate {
            let daysSinceLastClaim = calendar.dateComponents([.day], from: lastClaim, to: now).day ?? 0
            
            if daysSinceLastClaim == 0 {
                // Already claimed today
                canClaimToday = false
            } else if daysSinceLastClaim == 1 {
                // Consecutive day - continue streak
                canClaimToday = true
            } else {
                // Streak broken - lose streak but keep reward progress
                currentStreak = 0
                canClaimToday = true
            }
        } else {
            // First time claiming
            canClaimToday = true
        }
        
        // Ensure catalog has enough entries for the next visible window
        ensureClaims(upTo: visibleUpperBound())
        
        // Update claim availability
        let nextClaimDay = currentClaimDay + 1
        for i in 0..<dailyClaims.count {
            dailyClaims[i].isAvailable = canClaimToday && dailyClaims[i].day == nextClaimDay
        }
    }
    
    @MainActor
    public func claimDailyReward() {
        guard canClaimToday else { return }
        
        let nextClaimDay = currentClaimDay + 1
        guard let claimIndex = dailyClaims.firstIndex(where: { $0.day == nextClaimDay }) else { return }
        
        // Mark as claimed
        dailyClaims[claimIndex].isClaimed = true
        dailyClaims[claimIndex].isAvailable = false
        
        // Update progress
        currentClaimDay = nextClaimDay
        currentStreak += 1
        lastClaimDate = Date()
        canClaimToday = false
        
        claimedDays.insert(nextClaimDay)
        
        // Distribute rewards
        let rewards = dailyClaims[claimIndex].rewards
        onReward?(rewards)
        
        // Check for newly unlocked streaks
        for i in 0..<dailyStreaks.count {
            if !dailyStreaks[i].isUnlocked && dailyStreaks[i].day <= currentStreak {
                dailyStreaks[i].isUnlocked = true
                unlockedStreaks.insert(dailyStreaks[i].day)
                onReward?(dailyStreaks[i].rewards)
            }
        }
        
        // Save progress
        saveProgress()
        
        // Update availability for next claim
        ensureClaims(upTo: visibleUpperBound())
        updateAvailability()
    }
    
    public func getNextClaimableDay() -> Int? {
        return canClaimToday ? currentClaimDay + 1 : nil
    }
    
    public func getTimeUntilNextClaim() -> TimeInterval? {
        guard !canClaimToday else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return nil }

        return max(0, startOfTomorrow.timeIntervalSince(now))
    }
    
    public func combinedRewardForNextClaim() -> AchievementDef.Rewards? {
        guard let nextDay = getNextClaimableDay(),
              let daily = dailyClaims.first(where: { $0.day == nextDay })?.rewards
        else { return nil }
        
        let streakBonus = pendingStreakRewards(afterClaimingDay: nextDay)
        return streakBonus.reduce(daily) { $0.merged(with: $1) }
    }
    
    public func ensureClaimsCovering(pageIndex: Int) {
        let upperBound = min(max(pageIndex, 0), Int.max / 7) * 7 + 7
        ensureClaims(upTo: max(upperBound, visibleUpperBound()))
    }
    
    private func visibleUpperBound() -> Int {
        let highestClaimed = max(currentClaimDay, claimedDays.max() ?? 0)
        return max(highestClaimed + visibleLookaheadDays, visibleLookaheadDays)
    }
    
    private func ensureClaims(upTo targetDay: Int) {
        guard targetDay > dailyClaims.count else {
            refreshClaimStates()
            return
        }
        
        let start = max(dailyClaims.last?.day ?? 0, 0) + 1
        if start > targetDay {
            refreshClaimStates()
            return
        }
        
        for day in start...targetDay {
            let rewards = DailyRewardSchedule.rewards(for: day)
            let claim = DailyClaim(
                id: String(format: "daily_claim_day_%03d", day),
                day: day,
                rewards: rewards,
                isClaimed: claimedDays.contains(day),
                isAvailable: false
            )
            dailyClaims.append(claim)
        }
        refreshClaimStates()
    }
    
    private func refreshClaimStates() {
        for index in 0..<dailyClaims.count {
            let day = dailyClaims[index].day
            dailyClaims[index].isClaimed = claimedDays.contains(day)
        }
    }
    
    private func pendingStreakRewards(afterClaimingDay day: Int) -> [AchievementDef.Rewards] {
        let resultingStreak = currentStreak + 1 // streak increments when day is claimed
        return dailyStreaks
            .filter { !$0.isUnlocked && $0.day <= resultingStreak }
            .map(\.rewards)
    }
}

private enum DailyRewardSchedule {
    private static let cycle: [AchievementDef.Rewards] = [
        // Week 1
        AchievementDef.Rewards(gems: 15),
        AchievementDef.Rewards(gems: 25),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(gems: 40),
        AchievementDef.Rewards(gems: 50),
        AchievementDef.Rewards(boost2x: 1),
        AchievementDef.Rewards(gems: 75, hammers: 1),
        // Week 2
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(boost3x: 1),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(gems: 110),
        AchievementDef.Rewards(gems: 125),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(gems: 200),
        // Week 3
        AchievementDef.Rewards(gems: 100, hammers: 1, magnets: 1, boost2x: 1),
        AchievementDef.Rewards(swaps: 2),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(spins: 1, boost4x: 1),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(gems: 150, magnets: 2),
        AchievementDef.Rewards(gems: 175),
        // Week 4
        AchievementDef.Rewards(gems: 220, spins: 1),
        AchievementDef.Rewards(magnets: 2, boost4x: 1),
        AchievementDef.Rewards(boost2x: 1, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 250, magnets: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 244, boost4x: 1),
        AchievementDef.Rewards(spins: 2),
        AchievementDef.Rewards(spins: 2, boost2x: 1),
        // Week 5
        AchievementDef.Rewards(spins: 1, boost3x: 1),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(magnets: 2, boost2x: 1),
        AchievementDef.Rewards(gems: 273, spins: 1, swaps: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 222, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 300, swaps: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 331, spins: 1, swaps: 2),
        // Week 6
        AchievementDef.Rewards(gems: 344, magnets: 1, boost4x: 1),
        AchievementDef.Rewards(swaps: 3, boost3x: 1),
        AchievementDef.Rewards(spins: 1, magnets: 1, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 373, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 400, spins: 1, swaps: 1, boost3x: 1),
        AchievementDef.Rewards(spins: 2),
        AchievementDef.Rewards(boost4x: 1),
        // Week 7
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(gems: 403, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 465, magnets: 1),
        AchievementDef.Rewards(gems: 466, magnets: 1),
        AchievementDef.Rewards(gems: 445, spins: 2, hammers: 1, magnets: 1, boost2x: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 435, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(magnets: 5),
        // Week 8
        AchievementDef.Rewards(magnets: 3, boost4x: 1),
        AchievementDef.Rewards(spins: 1, boost2x: 1, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 497, magnets: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 511, magnets: 1, boost3x: 1),
        AchievementDef.Rewards(magnets: 2, boost2x: 1),
        AchievementDef.Rewards(gems: 524, hammers: 2, swaps: 1),
        AchievementDef.Rewards(gems: 577),
        // Week 9
        AchievementDef.Rewards(magnets: 1, boost3x: 1),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(gems: 568, magnets: 2, swaps: 2),
        AchievementDef.Rewards(gems: 587),
        AchievementDef.Rewards(gems: 603),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(gems: 600, hammers: 1, boost2x: 1, boost3x: 1),
        // Week 10
        AchievementDef.Rewards(gems: 617, boost2x: 1),
        AchievementDef.Rewards(gems: 622, boost3x: 1),
        AchievementDef.Rewards(hammers: 1, magnets: 1, swaps: 1),
        AchievementDef.Rewards(gems: 644, swaps: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 666, hammers: 2, boost3x: 1),
        AchievementDef.Rewards(magnets: 1, boost2x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 681, boost3x: 1, boost4x: 1),
        // Week 11
        AchievementDef.Rewards(gems: 694, magnets: 2, boost3x: 1),
        AchievementDef.Rewards(gems: 800),
        AchievementDef.Rewards(spins: 3, boost3x: 1),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(gems: 743, boost3x: 1),
        AchievementDef.Rewards(gems: 777, magnets: 1, boost2x: 1),
        AchievementDef.Rewards(magnets: 2),
        // Week 12
        AchievementDef.Rewards(gems: 839, hammers: 1),
        AchievementDef.Rewards(swaps: 2),
        AchievementDef.Rewards(hammers: 2),
        AchievementDef.Rewards(spins: 2, boost2x: 1),
        AchievementDef.Rewards(spins: 3),
        AchievementDef.Rewards(gems: 919),
        AchievementDef.Rewards(gems: 882, swaps: 1, boost2x: 1)
    ]
    
    static func rewards(for day: Int) -> AchievementDef.Rewards {
        guard day > 0 else { return AchievementDef.Rewards() }
        let index = (day - 1) % cycle.count
        let week = max((day - 1) / cycle.count, 0)
        return cycle[index].scaled(forWeek: week)
    }
}

private extension AchievementDef.Rewards {
    func scaled(forWeek week: Int) -> AchievementDef.Rewards {
        AchievementDef.Rewards(
            gems: scaleLinear(base: gems, week: week, step: 40),
            spins: scaleFrequency(base: spins, week: week, frequency: 2),
            hammers: scaleFrequency(base: hammers, week: week, frequency: 3),
            magnets: scaleFrequency(base: magnets, week: week, frequency: 3),
            swaps: scaleFrequency(base: swaps, week: week, frequency: 2),
            boost2x: scaleFrequency(base: boost2x, week: week, frequency: 4),
            boost3x: scaleFrequency(base: boost3x, week: week, frequency: 4),
            boost4x: scaleFrequency(base: boost4x, week: week, frequency: 5)
        )
    }
    
    private func scaleLinear(base: Int?, week: Int, step: Int) -> Int? {
        guard let base else { return nil }
        return base + (week * step)
    }
    
    private func scaleFrequency(base: Int?, week: Int, frequency: Int) -> Int? {
        guard let base else { return nil }
        guard frequency > 0 else { return base }
        return base + (week / frequency)
    }
}
