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
            // IMPORTANT: Compare calendar days using startOfDay, not raw timestamps
            // This ensures claiming at 11pm and checking at 10am next day works correctly
            let lastClaimDay = calendar.startOfDay(for: lastClaim)
            let today = calendar.startOfDay(for: now)
            let daysSinceLastClaim = calendar.dateComponents([.day], from: lastClaimDay, to: today).day ?? 0

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

        // Rebuild array with updated states to ensure @Observable properly notifies SwiftUI
        let nextDay = currentClaimDay + 1
        dailyClaims = dailyClaims.map { claim in
            var updated = claim
            updated.isClaimed = claimedDays.contains(claim.day)
            updated.isAvailable = canClaimToday && claim.day == nextDay
            return updated
        }
    }
    
    @MainActor
    public func claimDailyReward() {
        guard canClaimToday else { return }

        let nextClaimDay = currentClaimDay + 1
        guard let claimIndex = dailyClaims.firstIndex(where: { $0.day == nextClaimDay }) else { return }

        // Get rewards before updating state
        let rewards = dailyClaims[claimIndex].rewards

        // Update progress state FIRST
        currentClaimDay = nextClaimDay
        currentStreak += 1
        lastClaimDate = Date()
        canClaimToday = false

        // Add to claimed days set
        claimedDays.insert(nextClaimDay)

        // Save progress IMMEDIATELY to ensure persistence
        saveProgress()

        // Rebuild the dailyClaims array to ensure @Observable triggers SwiftUI updates
        // This is more reliable than modifying individual struct elements
        dailyClaims = dailyClaims.map { claim in
            var updated = claim
            updated.isClaimed = claimedDays.contains(claim.day)
            updated.isAvailable = false  // Nothing available after claiming today
            return updated
        }

        // Distribute rewards
        onReward?(rewards)

        // Check for newly unlocked streaks and give random bonus rewards
        for i in 0..<dailyStreaks.count {
            if !dailyStreaks[i].isUnlocked && dailyStreaks[i].day <= currentStreak {
                dailyStreaks[i].isUnlocked = true
                unlockedStreaks.insert(dailyStreaks[i].day)
                // Generate random bonus with equal probability (12.5% each type)
                let randomBonus = BonusRewardGenerator.generateRandomBonus(forStreakDay: dailyStreaks[i].day)
                onReward?(randomBonus)
            }
        }

        // Save again to persist streak unlocks
        saveProgress()
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
        // Handle special page structure:
        // Pages 0-51: Weeks 1-52 (days 1-364)
        // Page 52: Day 365 (Year 1)
        // Page 53: Week 53 (days 366-371, 6 days)
        // Pages 54-104: Weeks 54-104 (days 372-728)
        // Page 105: Week 105 first part (day 729)
        // Page 106: Day 730 (Year 2)
        // Page 107: Rest of Week 105 (days 731-735)
        // Pages 108+: Week 106+ (days 736+)
        let upperBound: Int
        if pageIndex < 52 {
            upperBound = (pageIndex + 1) * 7  // Normal week pages
        } else if pageIndex == 52 {
            upperBound = 365  // Day 365 page
        } else if pageIndex == 53 {
            upperBound = 371  // Week 53 (days 366-371)
        } else if pageIndex <= 104 {
            // Pages 54-104: Weeks 54-104
            upperBound = 371 + (pageIndex - 53) * 7
        } else if pageIndex == 105 {
            upperBound = 729  // Week 105 first part
        } else if pageIndex == 106 {
            upperBound = 730  // Day 730 page
        } else if pageIndex == 107 {
            upperBound = 735  // Rest of Week 105
        } else {
            // Pages 108+: days 736 + (page - 108) * 7 + 7
            upperBound = 735 + (pageIndex - 107) * 7
        }
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
        // Return random bonus rewards for each pending streak unlock
        // Each bonus type has 12.5% probability (equal distribution)
        return dailyStreaks
            .filter { !$0.isUnlocked && $0.day <= resultingStreak }
            .map { streak in
                BonusRewardGenerator.generateRandomBonus(forStreakDay: streak.day)
            }
    }

    /// Returns the count of pending streak bonuses without generating rewards
    public func pendingStreakBonusCount(afterClaimingDay day: Int) -> Int {
        let resultingStreak = currentStreak + 1
        return dailyStreaks
            .filter { !$0.isUnlocked && $0.day <= resultingStreak }
            .count
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
        AchievementDef.Rewards(gems: 882, swaps: 1, boost2x: 1),
        // Week 13
        AchievementDef.Rewards(gems: 900),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(gems: 899, swaps: 1),
        AchievementDef.Rewards(magnets: 1, boost2x: 1),
        AchievementDef.Rewards(boost3x: 1, boost4x: 1),
        // Week 14
        AchievementDef.Rewards(gems: 911, hammers: 1),
        AchievementDef.Rewards(gems: 927, magnets: 1, boost3x: 1),
        AchievementDef.Rewards(spins: 1, boost2x: 1),
        AchievementDef.Rewards(spins: 2),
        AchievementDef.Rewards(spins: 2, swaps: 1, boost3x: 1),
        AchievementDef.Rewards(hammers: 2, boost2x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 933, swaps: 1),
        // Week 15
        AchievementDef.Rewards(gems: 944),
        AchievementDef.Rewards(gems: 955),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(gems: 962, boost2x: 1),
        AchievementDef.Rewards(gems: 967),
        AchievementDef.Rewards(gems: 966, swaps: 1),
        AchievementDef.Rewards(magnets: 1),
        // Week 16
        AchievementDef.Rewards(gems: 966, boost4x: 1),
        AchievementDef.Rewards(gems: 978, magnets: 1, boost3x: 1),
        AchievementDef.Rewards(magnets: 1, boost4x: 1),
        AchievementDef.Rewards(hammers: 1, swaps: 1),
        AchievementDef.Rewards(gems: 974, hammers: 1),
        AchievementDef.Rewards(gems: 972, swaps: 1),
        AchievementDef.Rewards(gems: 975, swaps: 1),
        // Week 17
        AchievementDef.Rewards(gems: 987, hammers: 1),
        AchievementDef.Rewards(gems: 983, magnets: 1),
        AchievementDef.Rewards(gems: 999),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(boost3x: 1),
        AchievementDef.Rewards(hammers: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 1000),
        // Week 18
        AchievementDef.Rewards(gems: 1003),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(gems: 933, spins: 3, boost2x: 1),
        AchievementDef.Rewards(boost3x: 1),
        AchievementDef.Rewards(boost2x: 1),
        AchievementDef.Rewards(gems: 1000),
        // Week 19
        AchievementDef.Rewards(gems: 1000),
        AchievementDef.Rewards(magnets: 1, boost2x: 1),
        AchievementDef.Rewards(spins: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 965, hammers: 1, boost4x: 1),
        AchievementDef.Rewards(hammers: 1, magnets: 1, swaps: 1),
        AchievementDef.Rewards(swaps: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 975),
        // Week 20
        AchievementDef.Rewards(gems: 1100),
        AchievementDef.Rewards(gems: 875, spins: 2),
        AchievementDef.Rewards(magnets: 2),
        AchievementDef.Rewards(swaps: 2),
        AchievementDef.Rewards(hammers: 2),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(gems: 978, hammers: 1),
        // Week 21
        AchievementDef.Rewards(gems: 897),
        AchievementDef.Rewards(gems: 899),
        AchievementDef.Rewards(magnets: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 987, swaps: 1),
        AchievementDef.Rewards(gems: 1111),
        AchievementDef.Rewards(gems: 766, spins: 3),
        AchievementDef.Rewards(gems: 779, magnets: 2, boost3x: 1),
        // Week 22
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(gems: 996, hammers: 1),
        AchievementDef.Rewards(gems: 799, swaps: 1),
        AchievementDef.Rewards(gems: 882, boost2x: 1),
        AchievementDef.Rewards(gems: 921, hammers: 1, swaps: 1, boost2x: 1, boost3x: 1),
        AchievementDef.Rewards(hammers: 2, boost4x: 1),
        AchievementDef.Rewards(spins: 1, magnets: 1, swaps: 1),
        // Week 23
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(gems: 777),
        AchievementDef.Rewards(gems: 882),
        AchievementDef.Rewards(magnets: 1, boost2x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 900, hammers: 1),
        AchievementDef.Rewards(spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1)
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

/// Generates random bonus rewards with equal probability for each type (12.5% each)
public enum BonusRewardGenerator {
    public enum BonusType: CaseIterable {
        case gems
        case spins
        case hammers
        case megaMerges
        case swaps
        case boost2x
        case boost3x
        case boost4x
    }

    /// Generates a random bonus reward with equal probability (12.5% each type)
    public static func generateRandomBonus(baseAmount: Int = 1) -> AchievementDef.Rewards {
        let allTypes = BonusType.allCases
        let randomIndex = Int.random(in: 0..<allTypes.count)
        let selectedType = allTypes[randomIndex]

        return rewardFor(type: selectedType, amount: baseAmount)
    }

    /// Generates a bonus with scaled amount based on streak day
    public static func generateRandomBonus(forStreakDay day: Int) -> AchievementDef.Rewards {
        let allTypes = BonusType.allCases
        let randomIndex = Int.random(in: 0..<allTypes.count)
        let selectedType = allTypes[randomIndex]

        // Scale amount based on streak day (higher streak = better bonus)
        let amount = scaledAmount(for: selectedType, streakDay: day)

        return rewardFor(type: selectedType, amount: amount)
    }

    private static func rewardFor(type: BonusType, amount: Int) -> AchievementDef.Rewards {
        switch type {
        case .gems:
            return AchievementDef.Rewards(gems: amount * 50)
        case .spins:
            return AchievementDef.Rewards(spins: amount)
        case .hammers:
            return AchievementDef.Rewards(hammers: amount)
        case .megaMerges:
            return AchievementDef.Rewards(magnets: amount)
        case .swaps:
            return AchievementDef.Rewards(swaps: amount)
        case .boost2x:
            return AchievementDef.Rewards(boost2x: amount)
        case .boost3x:
            return AchievementDef.Rewards(boost3x: amount)
        case .boost4x:
            return AchievementDef.Rewards(boost4x: amount)
        }
    }

    private static func scaledAmount(for type: BonusType, streakDay: Int) -> Int {
        // Base amount increases every 7 days (weekly bonus scaling)
        let weekMultiplier = max(1, (streakDay - 1) / 7 + 1)

        switch type {
        case .gems:
            return weekMultiplier
        case .spins, .hammers, .megaMerges, .swaps:
            // Power-ups scale slower
            return max(1, weekMultiplier / 2)
        case .boost2x, .boost3x, .boost4x:
            // Boosts are always 1
            return 1
        }
    }
}
