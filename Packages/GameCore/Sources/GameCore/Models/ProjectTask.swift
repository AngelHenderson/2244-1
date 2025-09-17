import Foundation

public struct ProjectTask: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let mode: GameMode
    public let difficulty: TaskDifficulty
    public let requirement: Int
    public var progress: Int
    public var state: TaskState

    public init(
        id: String,
        title: String,
        description: String,
        mode: GameMode,
        difficulty: TaskDifficulty,
        requirement: Int,
        progress: Int = 0,
        state: TaskState = .notStarted
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.mode = mode
        self.difficulty = difficulty
        self.requirement = requirement
        self.progress = progress
        self.state = state
    }

    public var isCompleted: Bool {
        return state == .completed
    }

    public var progressPercentage: Double {
        guard requirement > 0 else { return 0 }
        return min(Double(progress) / Double(requirement), 1.0)
    }

    public var reward: TaskReward {
        switch difficulty {
        case .easy:
            return TaskReward(coins: 10, experience: 20, powerUps: [:])
        case .medium:
            return TaskReward(coins: 25, experience: 50, powerUps: [:])
        case .hard:
            return TaskReward(coins: 50, experience: 100, powerUps: [.hammer: 1])
        }
    }
}

public enum TaskDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard
}

public enum TaskState: String, CaseIterable, Codable, Sendable {
    case completed
    case inProgress
    case notStarted
}

public struct TaskReward: Codable, Sendable {
    public let coins: Int
    public let experience: Int
    public let powerUps: [PowerUpType: Int]

    public init(coins: Int, experience: Int, powerUps: [PowerUpType: Int] = [:]) {
        self.coins = coins
        self.experience = experience
        self.powerUps = powerUps
    }
}

public struct ProjectTaskManager {
    public static let sampleTasks: [ProjectTask] = [
        ProjectTask(id: "classic_1", title: "First Merge", description: "Create your first merge", mode: .classic, difficulty: .easy, requirement: 1, progress: 1, state: .completed),
        ProjectTask(id: "classic_2", title: "Chain Master", description: "Create a 5-tile chain", mode: .classic, difficulty: .medium, requirement: 1, progress: 0, state: .inProgress),
        ProjectTask(id: "classic_3", title: "High Scorer", description: "Score 10,000 points", mode: .classic, difficulty: .hard, requirement: 10000, progress: 0, state: .notStarted),
        ProjectTask(id: "classic_4", title: "Tile 512", description: "Create a 512 tile", mode: .classic, difficulty: .medium, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "classic_5", title: "Combo King", description: "Create 3 chains in one game", mode: .classic, difficulty: .easy, requirement: 3, progress: 1, state: .inProgress),
        ProjectTask(id: "classic_6", title: "No Power-Ups", description: "Score 5,000 without power-ups", mode: .classic, difficulty: .hard, requirement: 5000, progress: 0, state: .notStarted),
        ProjectTask(id: "classic_7", title: "Speed Run", description: "Score 3,000 in 2 minutes", mode: .classic, difficulty: .medium, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "classic_8", title: "Perfect Game", description: "Fill entire board", mode: .classic, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "classic_9", title: "Tile Collector", description: "Have 5 different tile values", mode: .classic, difficulty: .easy, requirement: 5, progress: 3, state: .inProgress),
        ProjectTask(id: "classic_10", title: "Marathon", description: "Play for 10 minutes", mode: .classic, difficulty: .easy, requirement: 600, progress: 600, state: .completed),
        ProjectTask(id: "classic_11", title: "Efficiency Expert", description: "Score 2,000 in 50 moves", mode: .classic, difficulty: .medium, requirement: 1, progress: 0, state: .notStarted),

        ProjectTask(id: "journey_1", title: "Journey Begin", description: "Start your journey", mode: .journey, difficulty: .easy, requirement: 1, progress: 1, state: .completed),
        ProjectTask(id: "journey_2", title: "First Milestone", description: "Reach tile 64", mode: .journey, difficulty: .easy, requirement: 1, progress: 1, state: .completed),
        ProjectTask(id: "journey_3", title: "Progress Path", description: "Reach tile 256", mode: .journey, difficulty: .medium, requirement: 1, progress: 0, state: .inProgress),
        ProjectTask(id: "journey_4", title: "Halfway There", description: "Reach tile 512", mode: .journey, difficulty: .medium, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "journey_5", title: "Almost Pro", description: "Reach tile 1024", mode: .journey, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "journey_6", title: "Journey Master", description: "Reach tile 2048", mode: .journey, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "journey_7", title: "Beyond Limits", description: "Reach tile 4096", mode: .journey, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "journey_8", title: "Chain Journey", description: "Create 10 chains total", mode: .journey, difficulty: .easy, requirement: 10, progress: 5, state: .inProgress),
        ProjectTask(id: "journey_9", title: "Power Journey", description: "Use 5 power-ups", mode: .journey, difficulty: .easy, requirement: 5, progress: 2, state: .inProgress),
        ProjectTask(id: "journey_10", title: "Score Journey", description: "Total score 50,000", mode: .journey, difficulty: .medium, requirement: 50000, progress: 12000, state: .inProgress),
        ProjectTask(id: "journey_11", title: "Complete Journey", description: "Complete all milestones", mode: .journey, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),

        ProjectTask(id: "daily_1", title: "Daily Player", description: "Play daily challenge", mode: .daily, difficulty: .easy, requirement: 1, progress: 1, state: .completed),
        ProjectTask(id: "daily_2", title: "Week Streak", description: "7 day streak", mode: .daily, difficulty: .medium, requirement: 7, progress: 3, state: .inProgress),
        ProjectTask(id: "daily_3", title: "Month Streak", description: "30 day streak", mode: .daily, difficulty: .hard, requirement: 30, progress: 0, state: .notStarted),
        ProjectTask(id: "daily_4", title: "Daily High Score", description: "Beat daily target", mode: .daily, difficulty: .medium, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "daily_5", title: "Daily Leaderboard", description: "Top 100 daily", mode: .daily, difficulty: .medium, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "daily_6", title: "Daily Champion", description: "Top 10 daily", mode: .daily, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "daily_7", title: "Consistent Player", description: "Play 10 dailies", mode: .daily, difficulty: .easy, requirement: 10, progress: 5, state: .inProgress),
        ProjectTask(id: "daily_8", title: "Daily Expert", description: "Beat target 5 times", mode: .daily, difficulty: .medium, requirement: 5, progress: 1, state: .inProgress),
        ProjectTask(id: "daily_9", title: "Perfect Daily", description: "Double the target", mode: .daily, difficulty: .hard, requirement: 1, progress: 0, state: .notStarted),
        ProjectTask(id: "daily_10", title: "Early Bird", description: "Play before 8 AM", mode: .daily, difficulty: .easy, requirement: 1, progress: 1, state: .completed),
        ProjectTask(id: "daily_11", title: "Night Owl", description: "Play after 10 PM", mode: .daily, difficulty: .easy, requirement: 1, progress: 1, state: .completed)
    ]

    public init() {}

    public func loadSampleTasks() -> [ProjectTask] {
        return Self.sampleTasks
    }

    public func tasksFor(mode: GameMode) -> [ProjectTask] {
        return Self.sampleTasks.filter { $0.mode == mode }
    }
}