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
    
    private let storage = UserDefaults.standard
    private static let streakKey = "dailyStreak"
    private static let claimDayKey = "dailyClaimDay"
    private static let lastClaimKey = "lastClaimDate"
    private static let claimedDaysKey = "claimedDays"
    private static let unlockedStreaksKey = "unlockedStreaks"
    
    public var onReward: ((AchievementDef.Rewards) -> Void)?
    
    public init() {
        loadProgress()
        Task {
            await loadCatalogs()
            updateAvailability()
        }
    }
    
    @MainActor
    public func loadCatalogs() async {
        // Load daily claims catalog
        if let claimsURL = Bundle.main.url(forResource: "daily_claims_365", withExtension: "json") {
            do {
                let data = try Data(contentsOf: claimsURL)
                let achievements = try JSONDecoder().decode([AchievementDef].self, from: data)
                
                let claimedDays = Set(storage.array(forKey: Self.claimedDaysKey) as? [Int] ?? [])
                
                dailyClaims = achievements.compactMap { achievement in
                    // Extract day number from conditions
                    if let dayCondition = achievement.conditions.first(where: { $0.field == "claim_day_index" }),
                       let day = dayCondition.value.map(Int.init) {
                        return DailyClaim(
                            id: achievement.id,
                            day: day,
                            rewards: achievement.rewards ?? AchievementDef.Rewards(gems: nil, spins: nil, hammers: nil, magnets: nil),
                            isClaimed: claimedDays.contains(day),
                            isAvailable: false
                        )
                    }
                    return nil
                }.sorted { $0.day < $1.day }
            } catch {
                print("Failed to load daily claims catalog: \(error)")
            }
        }
        
        // Load daily streaks catalog
        if let streaksURL = Bundle.main.url(forResource: "daily_streaks_365", withExtension: "json") {
            do {
                let data = try Data(contentsOf: streaksURL)
                let achievements = try JSONDecoder().decode([AchievementDef].self, from: data)
                
                let unlockedStreaks = Set(storage.array(forKey: Self.unlockedStreaksKey) as? [Int] ?? [])
                
                dailyStreaks = achievements.compactMap { achievement in
                    // Extract day number from conditions
                    if let dayCondition = achievement.conditions.first(where: { $0.field == "daily_streak" }),
                       let day = dayCondition.value.map(Int.init) {
                        return DailyStreak(
                            id: achievement.id,
                            day: day,
                            rewards: achievement.rewards ?? AchievementDef.Rewards(gems: nil, spins: nil, hammers: nil, magnets: nil),
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
    }
    
    private func saveProgress() {
        storage.set(currentStreak, forKey: Self.streakKey)
        storage.set(currentClaimDay, forKey: Self.claimDayKey)
        if let lastClaimDate = lastClaimDate {
            storage.set(lastClaimDate.timeIntervalSince1970, forKey: Self.lastClaimKey)
        }
        
        // Save claimed days
        let claimedDays = dailyClaims.filter(\.isClaimed).map(\.day)
        storage.set(claimedDays, forKey: Self.claimedDaysKey)
        
        // Save unlocked streaks
        let unlockedStreaks = dailyStreaks.filter(\.isUnlocked).map(\.day)
        storage.set(unlockedStreaks, forKey: Self.unlockedStreaksKey)
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
                // Streak broken - reset
                currentStreak = 0
                currentClaimDay = 0
                canClaimToday = true
            }
        } else {
            // First time claiming
            canClaimToday = true
        }
        
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
        
        // Distribute rewards
        let rewards = dailyClaims[claimIndex].rewards
        onReward?(rewards)
        
        // Check for newly unlocked streaks
        for i in 0..<dailyStreaks.count {
            if !dailyStreaks[i].isUnlocked && dailyStreaks[i].day <= currentStreak {
                dailyStreaks[i].isUnlocked = true
                onReward?(dailyStreaks[i].rewards)
            }
        }
        
        // Save progress
        saveProgress()
        
        // Update availability for next claim
        updateAvailability()
    }
    
    public func getNextClaimableDay() -> Int? {
        return canClaimToday ? currentClaimDay + 1 : nil
    }
    
    public func getTimeUntilNextClaim() -> TimeInterval? {
        guard !canClaimToday, let lastClaim = lastClaimDate else { return nil }
        
        let calendar = Calendar.current
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: lastClaim) else { return nil }
        let startOfNextDay = calendar.startOfDay(for: nextMidnight)
        
        return max(0, startOfNextDay.timeIntervalSinceNow)
    }
}