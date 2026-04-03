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
    public private(set) var availableClaims: Int = 0  // Number of claims available (for catching up on missed days)
    
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
    public func updateAvailability(banStartDate: Date? = nil, banEndDate: Date? = nil) {
        let calendar = Calendar.current
        let now = Date()

        // Check if we can claim today and how many claims are available
        if let lastClaim = lastClaimDate {
            // IMPORTANT: Compare calendar days using startOfDay, not raw timestamps
            // This ensures claiming at 11pm and checking at 10am next day works correctly
            let lastClaimDay = calendar.startOfDay(for: lastClaim)
            let today = calendar.startOfDay(for: now)
            let daysSinceLastClaim = calendar.dateComponents([.day], from: lastClaimDay, to: today).day ?? 0

            if daysSinceLastClaim == 0 {
                // Already claimed today
                canClaimToday = false
                availableClaims = 0
            } else if daysSinceLastClaim == 1 {
                // Consecutive day - continue streak
                canClaimToday = true
                availableClaims = 1
            } else {
                // Missed days - check how many fell during a ban
                // Days during ban are forfeited, not available for catch-up
                var bannedDays = 0
                if let banStart = banStartDate {
                    let banStartDay = calendar.startOfDay(for: banStart)
                    // banEnd is either the end date or now (still banned)
                    let banEndDay = calendar.startOfDay(for: banEndDate ?? now)

                    // Count forfeited days: days between lastClaim and today that were during ban
                    for offset in 1..<daysSinceLastClaim {
                        if let checkDay = calendar.date(byAdding: .day, value: offset, to: lastClaimDay) {
                            let checkStart = calendar.startOfDay(for: checkDay)
                            if checkStart >= banStartDay && checkStart <= banEndDay {
                                bannedDays += 1
                            }
                        }
                    }
                }

                // Streak resets but user can only claim non-banned days
                currentStreak = 0
                let claimable = max(0, daysSinceLastClaim - bannedDays)

                // Advance currentClaimDay past forfeited days
                if bannedDays > 0 {
                    currentClaimDay += bannedDays
                    // Mark forfeited days as claimed so they don't appear as available
                    for offset in 1...bannedDays {
                        let forfeitDay = currentClaimDay - bannedDays + offset
                        claimedDays.insert(forfeitDay)
                    }
                    saveProgress()
                }

                canClaimToday = claimable > 0
                availableClaims = claimable
            }
        } else {
            // First time claiming
            canClaimToday = true
            availableClaims = 1
        }

        // Ensure catalog has enough entries for the next visible window
        ensureClaims(upTo: visibleUpperBound())

        // Rebuild array with updated states to ensure @Observable properly notifies SwiftUI
        // Multiple days can be available if user missed days
        let nextDay = currentClaimDay + 1
        let maxAvailableDay = currentClaimDay + availableClaims
        dailyClaims = dailyClaims.map { claim in
            var updated = claim
            updated.isClaimed = claimedDays.contains(claim.day)
            updated.isAvailable = canClaimToday && claim.day >= nextDay && claim.day <= maxAvailableDay
            return updated
        }
    }
    
    @MainActor
    public func claimDailyReward() {
        guard canClaimToday, availableClaims > 0 else { return }

        let nextClaimDay = currentClaimDay + 1
        guard let claimIndex = dailyClaims.firstIndex(where: { $0.day == nextClaimDay }) else { return }

        // Get rewards before updating state
        let rewards = dailyClaims[claimIndex].rewards

        // Update progress state FIRST
        currentClaimDay = nextClaimDay
        currentStreak += 1
        lastClaimDate = Date()
        availableClaims -= 1

        // If no more claims available, can't claim anymore today
        if availableClaims == 0 {
            canClaimToday = false
        }

        // Add to claimed days set
        claimedDays.insert(nextClaimDay)

        // Save progress IMMEDIATELY to ensure persistence
        saveProgress()

        // Rebuild the dailyClaims array to ensure @Observable triggers SwiftUI updates
        let nextAvailableDay = currentClaimDay + 1
        let maxAvailableDay = currentClaimDay + availableClaims
        dailyClaims = dailyClaims.map { claim in
            var updated = claim
            updated.isClaimed = claimedDays.contains(claim.day)
            updated.isAvailable = availableClaims > 0 && claim.day >= nextAvailableDay && claim.day <= maxAvailableDay
            return updated
        }

        // Distribute rewards
        onReward?(rewards)

        // Check for newly unlocked streaks and give weighted random bonus rewards
        for i in 0..<dailyStreaks.count {
            if !dailyStreaks[i].isUnlocked && dailyStreaks[i].day <= currentStreak {
                dailyStreaks[i].isUnlocked = true
                unlockedStreaks.insert(dailyStreaks[i].day)
                // Generate weighted random bonus (50% gems, 15% megaMerge, etc.)
                let bonus = BonusRewardGenerator.generateBonus(forStreakDay: dailyStreaks[i].day)
                onReward?(bonus)
            }
        }

        // Save again to persist streak unlocks
        saveProgress()
    }
    
    public func getNextClaimableDay() -> Int? {
        return (canClaimToday && availableClaims > 0) ? currentClaimDay + 1 : nil
    }
    
    public func getTimeUntilNextClaim() -> TimeInterval? {
        guard !canClaimToday || availableClaims == 0 else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return nil }

        return max(0, startOfTomorrow.timeIntervalSince(now))
    }

    /// Returns the total combined rewards across all available catch-up days, or nil when there are 0-1 claims.
    public func totalCatchUpRewards() -> AchievementDef.Rewards? {
        guard availableClaims > 1 else { return nil }

        let startDay = currentClaimDay + 1
        let endDay = currentClaimDay + availableClaims

        // Make sure claim entries exist for the full catch-up range
        ensureClaims(upTo: endDay)

        var total = AchievementDef.Rewards()
        for day in startDay...endDay {
            if let claim = dailyClaims.first(where: { $0.day == day }) {
                total = total.merged(with: claim.rewards)
            }
        }
        return total
    }

    /// Claims all available catch-up rewards in sequence, calling onReward for each.
    @MainActor
    public func claimAllDailyRewards() {
        // Make sure claim entries exist for the full catch-up range
        let endDay = currentClaimDay + availableClaims
        ensureClaims(upTo: endDay)

        while availableClaims > 0 && canClaimToday {
            let before = currentClaimDay
            claimDailyReward()
            // Safety: break if claim didn't advance (missing entry)
            if currentClaimDay == before { break }
        }
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

    /// Returns a preview of the next streak bonus (type, display amount, and rewards)
    public func nextStreakBonusPreview() -> (type: BonusRewardGenerator.BonusType, amount: Int, rewards: AchievementDef.Rewards)? {
        let resultingStreak = currentStreak + 1
        guard let nextStreak = dailyStreaks.first(where: { !$0.isUnlocked && $0.day <= resultingStreak }) else {
            return nil
        }
        let type = BonusRewardGenerator.bonusType(forStreakDay: nextStreak.day)
        let rewards = BonusRewardGenerator.previewBonus(forStreakDay: nextStreak.day)
        // Return actual reward amount for display (not raw multiplier)
        let displayAmount = rewards.displayAmount(forBonusType: type.typeName)
        return (type, displayAmount, rewards)
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
        AchievementDef.Rewards(spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1),
        // Week 24
        AchievementDef.Rewards(gems: 1000, hammers: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(spins: 1, swaps: 1),
        AchievementDef.Rewards(gems: 686, spins: 2, boost4x: 1),
        AchievementDef.Rewards(gems: 733, swaps: 2),
        AchievementDef.Rewards(gems: 688, hammers: 1, magnets: 1, boost2x: 1, boost3x: 1),
        // Week 25
        AchievementDef.Rewards(gems: 445, hammers: 2, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 399, spins: 1),
        AchievementDef.Rewards(gems: 994, hammers: 2, swaps: 2, boost4x: 1),
        AchievementDef.Rewards(gems: 1122),
        AchievementDef.Rewards(spins: 1, swaps: 2),
        AchievementDef.Rewards(spins: 1, boost2x: 1, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 1084),
        // Week 26
        AchievementDef.Rewards(gems: 1111, spins: 1, magnets: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 958, spins: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 992, magnets: 1),
        AchievementDef.Rewards(magnets: 1, swaps: 1, boost2x: 1),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(spins: 2),
        AchievementDef.Rewards(gems: 791, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1),
        // Week 27
        AchievementDef.Rewards(gems: 865, magnets: 1),
        AchievementDef.Rewards(hammers: 1, boost3x: 1),
        AchievementDef.Rewards(spins: 1, boost4x: 1),
        AchievementDef.Rewards(magnets: 1, swaps: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 922, spins: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 1172),
        AchievementDef.Rewards(gems: 799, spins: 1, hammers: 1, magnets: 1, boost2x: 1, boost3x: 1),
        // Week 28
        AchievementDef.Rewards(gems: 677),
        AchievementDef.Rewards(gems: 877),
        AchievementDef.Rewards(swaps: 2),
        AchievementDef.Rewards(spins: 1, boost4x: 1),
        AchievementDef.Rewards(spins: 1, magnets: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 1234, hammers: 1),
        AchievementDef.Rewards(gems: 1414),
        // Week 29
        AchievementDef.Rewards(magnets: 1, swaps: 1),
        AchievementDef.Rewards(spins: 1, swaps: 1),
        AchievementDef.Rewards(hammers: 1, boost3x: 1),
        AchievementDef.Rewards(gems: 1222, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 888, spins: 2, boost4x: 1),
        AchievementDef.Rewards(gems: 1098, spins: 1, boost3x: 1),
        AchievementDef.Rewards(hammers: 1, magnets: 1, swaps: 1),
        // Week 30
        AchievementDef.Rewards(swaps: 2),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(gems: 1100),
        AchievementDef.Rewards(boost3x: 1),
        AchievementDef.Rewards(boost2x: 1),
        AchievementDef.Rewards(gems: 1124, magnets: 1),
        AchievementDef.Rewards(spins: 1, hammers: 1, boost4x: 1),
        // Week 31
        AchievementDef.Rewards(gems: 1000),
        AchievementDef.Rewards(gems: 880),
        AchievementDef.Rewards(gems: 688, magnets: 1, boost2x: 1),
        AchievementDef.Rewards(gems: 1777),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(hammers: 1, boost2x: 1),
        AchievementDef.Rewards(magnets: 1, boost4x: 1),
        // Week 32
        AchievementDef.Rewards(hammers: 3),
        AchievementDef.Rewards(gems: 499, magnets: 1, boost2x: 1, boost3x: 1, boost4x: 1),
        AchievementDef.Rewards(gems: 1111),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(magnets: 1),
        // Week 33
        AchievementDef.Rewards(gems: 1222),
        AchievementDef.Rewards(hammers: 2),
        AchievementDef.Rewards(gems: 990, swaps: 2, boost3x: 1),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(spins: 2, swaps: 2),
        AchievementDef.Rewards(boost2x: 1, boost4x: 1),
        // Week 34
        AchievementDef.Rewards(gems: 727),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(boost2x: 1),
        AchievementDef.Rewards(gems: 649, magnets: 1),
        // Week 35
        AchievementDef.Rewards(gems: 655),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(spins: 4),
        AchievementDef.Rewards(gems: 670),
        AchievementDef.Rewards(gems: 1221),
        AchievementDef.Rewards(magnets: 1, swaps: 1, boost3x: 1),
        // Week 36
        AchievementDef.Rewards(gems: 565, swaps: 1, boost4x: 1),
        AchievementDef.Rewards(hammers: 1, magnets: 1, swaps: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(gems: 388),
        AchievementDef.Rewards(gems: 1725),
        AchievementDef.Rewards(spins: 1, hammers: 4, boost2x: 1),
        AchievementDef.Rewards(gems: 779, spins: 1, boost3x: 1),
        // Week 37
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(gems: 1234),
        AchievementDef.Rewards(gems: 1877),
        AchievementDef.Rewards(boost4x: 1),
        AchievementDef.Rewards(boost3x: 1),
        AchievementDef.Rewards(gems: 1746),
        // Week 38
        AchievementDef.Rewards(spins: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(hammers: 1),
        AchievementDef.Rewards(swaps: 1),
        AchievementDef.Rewards(magnets: 1),
        AchievementDef.Rewards(boost3x: 1),
        AchievementDef.Rewards(gems: 2475),
        // Week 39
        AchievementDef.Rewards(gems: 2546),
        AchievementDef.Rewards(spins: 2),
        AchievementDef.Rewards(spins: 4),
        AchievementDef.Rewards(magnets: 3),
        AchievementDef.Rewards(gems: 2735, swaps: 1),
        AchievementDef.Rewards(gems: 1983),
        AchievementDef.Rewards(gems: 3000),
        // Week 40
        AchievementDef.Rewards(gems: 3544),
        AchievementDef.Rewards(swaps: 2),
        AchievementDef.Rewards(spins: 3),
        AchievementDef.Rewards(spins: 1, boost4x: 1),
        AchievementDef.Rewards(boost2x: 1),
        AchievementDef.Rewards(gems: 2123),
        AchievementDef.Rewards(gems: 2849)
    ]
    
    static func rewards(for day: Int) -> AchievementDef.Rewards {
        guard day > 0 else { return AchievementDef.Rewards() }

        // Pattern repeats every 365 days (yearly)
        let dayInYear = ((day - 1) % 365) + 1
        let index = (dayInYear - 1) % cycle.count

        // Calculate year for gem multiplier
        // Year 1: 1.0x, Year 2: 1.5x, Year 3: 2.0x, Year 4: 2.5x, etc.
        let year = ((day - 1) / 365) + 1
        let gemMultiplier = 1.0 + (Double(year - 1) * 0.5)

        return cycle[index].scaled(forYear: year, gemMultiplier: gemMultiplier)
    }
}

private extension AchievementDef.Rewards {
    func scaled(forYear year: Int, gemMultiplier: Double) -> AchievementDef.Rewards {
        AchievementDef.Rewards(
            gems: gems.map { Int(Double($0) * gemMultiplier) },
            spins: spins,
            hammers: hammers,
            magnets: magnets,
            swaps: swaps,
            boost2x: boost2x,
            boost3x: boost3x,
            boost4x: boost4x
        )
    }
}

/// Generates weighted random bonus rewards based on streak day (deterministic via seeded RNG)
public enum BonusRewardGenerator {
    public enum BonusType: CaseIterable, Sendable {
        case gems
        case megaMerges
        case swaps
        case hammers
        case spins
        case boost2x
        case boost3x
        case boost4x

        public var displayName: String {
            switch self {
            case .gems: return "Gems"
            case .spins: return "Spin"
            case .hammers: return "Hammer"
            case .megaMerges: return "MegaMerge"
            case .swaps: return "Swap"
            case .boost2x: return "2X Boost"
            case .boost3x: return "3X Boost"
            case .boost4x: return "4X Boost"
            }
        }

        /// Internal type name for reward lookup
        var typeName: String {
            switch self {
            case .gems: return "gems"
            case .spins: return "spins"
            case .hammers: return "hammers"
            case .megaMerges: return "megaMerges"
            case .swaps: return "swaps"
            case .boost2x: return "boost2x"
            case .boost3x: return "boost3x"
            case .boost4x: return "boost4x"
            }
        }

        /// Weight for weighted random selection (out of 1000 for precision)
        var weight: Int {
            switch self {
            case .gems: return 500       // 50%
            case .megaMerges: return 150 // 15%
            case .swaps: return 100      // 10%
            case .hammers: return 50     // 5%
            case .spins: return 50       // 5%
            case .boost2x: return 75     // 7.5%
            case .boost3x: return 50     // 5%
            case .boost4x: return 25     // 2.5%
            }
        }
    }

    /// Returns the bonus type for a given streak day (deterministic via seeded random)
    public static func bonusType(forStreakDay day: Int) -> BonusType {
        // Use day as seed for deterministic "random" selection
        var seededValue = day * 2654435761 // Knuth's multiplicative hash
        seededValue = seededValue ^ (seededValue >> 16)
        let roll = abs(seededValue) % 1000

        var cumulative = 0
        for type in BonusType.allCases {
            cumulative += type.weight
            if roll < cumulative {
                return type
            }
        }
        return .gems // Fallback
    }

    /// Returns the bonus amount for a given streak day
    public static func bonusAmount(forStreakDay day: Int) -> Int {
        let type = bonusType(forStreakDay: day)
        return scaledAmount(for: type, streakDay: day)
    }

    /// Preview the bonus reward for a streak day (without claiming)
    public static func previewBonus(forStreakDay day: Int) -> AchievementDef.Rewards {
        let type = bonusType(forStreakDay: day)
        let amount = scaledAmount(for: type, streakDay: day)
        return rewardFor(type: type, amount: amount, streakDay: day)
    }

    /// Generates a deterministic bonus based on streak day
    public static func generateBonus(forStreakDay day: Int) -> AchievementDef.Rewards {
        return previewBonus(forStreakDay: day)
    }

    /// Legacy method - now deterministic
    public static func generateRandomBonus(forStreakDay day: Int) -> AchievementDef.Rewards {
        return generateBonus(forStreakDay: day)
    }

    /// Legacy method - now deterministic based on amount as day
    public static func generateRandomBonus(baseAmount: Int = 1) -> AchievementDef.Rewards {
        return generateBonus(forStreakDay: baseAmount)
    }

    private static func rewardFor(type: BonusType, amount: Int, streakDay: Int = 1) -> AchievementDef.Rewards {
        // Year-based scaling: year 1 = days 1-365, year 2 = days 366-730, etc.
        let year = max(1, (streakDay - 1) / 365 + 1)

        switch type {
        case .gems:
            // Cap increases by 500 for each year (year 1: 500, year 2: 1000, etc.)
            let gemCap = year * 500
            return AchievementDef.Rewards(gems: min(amount * 50, gemCap))
        case .spins:
            return AchievementDef.Rewards(spins: min(amount, year))
        case .hammers:
            return AchievementDef.Rewards(hammers: min(amount, year))
        case .megaMerges:
            return AchievementDef.Rewards(magnets: min(amount, year))
        case .swaps:
            return AchievementDef.Rewards(swaps: min(amount, year))
        case .boost2x:
            // Boosts cap increases by 1 every two years (years 1-2: 1, years 3-4: 2, etc.)
            let boostCap = max(1, (year + 1) / 2)
            return AchievementDef.Rewards(boost2x: min(amount, boostCap))
        case .boost3x:
            let boostCap = max(1, (year + 1) / 2)
            return AchievementDef.Rewards(boost3x: min(amount, boostCap))
        case .boost4x:
            let boostCap = max(1, (year + 1) / 2)
            return AchievementDef.Rewards(boost4x: min(amount, boostCap))
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
