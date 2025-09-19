import Foundation

public struct Profile: Codable, Sendable {
    public var name: String
    public var isDefault: Bool
    public var coins: Int
    public var experience: Int
    public var level: Int

    public var gamesPlayed: Int
    public var highScore: Int
    public var totalScore: Int
    public var totalMerges: Int

    public var powerUpInventory: [PowerUpType: Int]

    public init(
        name: String = "Player",
        isDefault: Bool = true,
        coins: Int = 305,
        experience: Int = 0,
        level: Int = 1,
        gamesPlayed: Int = 0,
        highScore: Int = 0,
        totalScore: Int = 0,
        totalMerges: Int = 0,
        powerUpInventory: [PowerUpType: Int]? = nil
    ) {
        self.name = name
        self.isDefault = isDefault
        self.coins = coins
        self.experience = experience
        self.level = level
        self.gamesPlayed = gamesPlayed
        self.highScore = highScore
        self.totalScore = totalScore
        self.totalMerges = totalMerges
        self.powerUpInventory = powerUpInventory ?? Self.defaultPowerUpInventory
    }

    public static var defaultPowerUpInventory: [PowerUpType: Int] {
        return [
            .hammer: 3,
            .swap: 2,
            .undo: 5,
            .shuffle: 1,
            .magnet: 0,
            .double: 0
        ]
    }

    public func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "currentProfile")
        }
    }

    public static func load() -> Profile {
        if let data = UserDefaults.standard.data(forKey: "currentProfile"),
           let profile = try? JSONDecoder().decode(Profile.self, from: data) {
            return profile
        }
        return Profile()
    }
}

