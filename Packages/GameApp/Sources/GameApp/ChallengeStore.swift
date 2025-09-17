import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeStore: Sendable {
    public var challenges: [Challenge] = []
    public var completedIds: Set<UUID> = []
    private var challengeOrder: [UUID] = []
    
    public init() {
        loadChallenges()
    }
    
    public func status(for challenge: Challenge) -> ChallengeStatus {
        guard let index = challengeOrder.firstIndex(of: challenge.id) else {
            return .locked
        }

        if completedIds.contains(challenge.id) {
            return .completed
        }

        // Check if all previous challenges are completed
        let previousChallenges = challengeOrder.prefix(index)
        if previousChallenges.allSatisfy({ completedIds.contains($0) }) {
            return .active
        }

        return .locked
    }
    
    public var activeChallenge: Challenge? {
        for id in challengeOrder {
            if !completedIds.contains(id) {
                return challenges.first { $0.id == id }
            }
        }
        return nil
    }
    
    public func markCompleted(_ id: UUID) {
        completedIds.insert(id)
        saveProgress()
    }

    public var currentChallengeNumber: Int {
        return completedIds.count + 1
    }
    
    private func loadChallenges() {
        // Create challenges with stable UUIDs for consistent ordering

        challenges = [
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000001")!, //Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value
                name: "First Steps",
                description: "Reach tile 1a (27) within 5 minutes",
                mode: .custom,
                difficulty: .easy,
                targetTile: 27,
                timeLimit: 300,
                reward: ChallengeReward(coins: 50, experience: 100)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000002")!,
                name: "Speed Run",
                description: "Reach tile 1b (28) within 4 minutes",
                mode: .custom,
                difficulty: .easy,
                targetTile: 28,
                timeLimit: 240,
                reward: ChallengeReward(coins: 75, experience: 150)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000003")!,
                name: "Quick Thinking",
                description: "Reach tile 1c (29) within 3 minutes",
                mode: .custom,
                difficulty: .medium,
                targetTile: 29,
                timeLimit: 180,
                reward: ChallengeReward(coins: 100, experience: 200)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000004")!,
                name: "Move Master",
                description: "Reach tile 1d (30) in 100 moves or less",
                mode: .custom,
                difficulty: .medium,
                targetTile: 30,
                moveLimit: 100,
                reward: ChallengeReward(coins: 125, experience: 250)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000005")!,
                name: "No Tools",
                description: "Reach tile 1e (31) without Hammer or Magnet power-ups",
                mode: .custom,
                difficulty: .hard,
                targetTile: 31,
                timeLimit: 180,
                bannedPowerUps: [.hammer, .magnet],
                reward: ChallengeReward(coins: 150, experience: 300)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000006")!,
                name: "Lightning Fast",
                description: "Reach tile 1f (32) in 2.5 minutes",
                mode: .custom,
                difficulty: .hard,
                targetTile: 32,
                timeLimit: 150,
                reward: ChallengeReward(coins: 175, experience: 350)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000007")!,
                name: "Precision",
                description: "Reach tile 1g (33) in 75 moves or less",
                mode: .custom,
                difficulty: .hard,
                targetTile: 33,
                moveLimit: 75,
                reward: ChallengeReward(coins: 200, experience: 400)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000008")!,
                name: "Extreme Speed",
                description: "Reach tile 1h (34) in just 2 minutes",
                mode: .custom,
                difficulty: .expert,
                targetTile: 34,
                timeLimit: 120,
                reward: ChallengeReward(coins: 250, experience: 500)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-000000000009")!,
                name: "Ultimate Test",
                description: "Reach tile 1i (35) in 2 minutes with 60 moves max",
                mode: .custom,
                difficulty: .expert,
                targetTile: 35,
                timeLimit: 120,
                moveLimit: 60,
                reward: ChallengeReward(coins: 300, experience: 600)
            ),
            Challenge(
                id: UUID(uuidString: "22449999-0001-4000-8000-00000000000A")!,
                name: "Master Challenge",
                description: "Reach tile 1j (36) in 90 seconds",
                mode: .custom,
                difficulty: .expert,
                targetTile: 36,
                timeLimit: 90,
                reward: ChallengeReward(coins: 400, experience: 800)
            )
        ]

        // Set up the order of challenges
        challengeOrder = challenges.map { $0.id }

        loadProgress()
    }
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: "challengeCompletedIds"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            completedIds = ids
        }
    }
    
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(completedIds) {
            UserDefaults.standard.set(data, forKey: "challengeCompletedIds")
        }
    }
}

private struct ChallengeStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ChallengeStore()
}

public extension EnvironmentValues {
    var challengeStore: ChallengeStore {
        get { self[ChallengeStoreKey.self] }
        set { self[ChallengeStoreKey.self] = newValue }
    }
}

