import Testing
@testable import GameApp
@testable import GameCore

@Suite("Profile Contract Tests")
struct ProfileContractTests {

    @Test("Profile initial state has 305 coins")
    func initialCoins() async {
        let profile = Profile()
        #expect(profile.coins == 305)
    }

    @Test("Profile initial inventory has correct power-ups")
    func initialPowerUpInventory() async {
        let profile = Profile()

        #expect(profile.powerUpInventory[.hammer] == 3)
        #expect(profile.powerUpInventory[.swap] == 2)
        #expect(profile.powerUpInventory[.undo] == 5)
        #expect(profile.powerUpInventory[.shuffle] == 1)
        #expect(profile.powerUpInventory[.magnet] == 0)
        #expect(profile.powerUpInventory[.double] == 0)
    }

    @Test("Profile auto-loads default profile on init")
    func autoLoadsDefaultProfile() async {
        let profile = Profile()

        #expect(profile.name == "Player")
        #expect(profile.isDefault == true)
    }

    @Test("Profile has experience and level fields")
    func hasProgressionFields() async {
        let profile = Profile()

        #expect(profile.experience == 0)
        #expect(profile.level == 1)
    }

    @Test("Profile tracks lifetime statistics")
    func tracksLifetimeStats() async {
        let profile = Profile()

        #expect(profile.gamesPlayed == 0)
        #expect(profile.highScore == 0)
        #expect(profile.totalScore == 0)
        #expect(profile.totalMerges == 0)
    }

    @Test("Profile supports persistence to UserDefaults")
    func persistsToUserDefaults() async {
        let profile = Profile()
        profile.coins = 500
        profile.save()

        let loadedProfile = Profile.load()
        #expect(loadedProfile.coins == 500)
    }
}

enum PowerUpType: String, CaseIterable, Codable {
    case hammer
    case swap
    case undo
    case shuffle
    case magnet
    case double
}

struct Profile: Codable {
    var name: String = "Player"
    var isDefault: Bool = true
    var coins: Int = 305
    var experience: Int = 0
    var level: Int = 1

    var gamesPlayed: Int = 0
    var highScore: Int = 0
    var totalScore: Int = 0
    var totalMerges: Int = 0

    var powerUpInventory: [PowerUpType: Int] = [
        .hammer: 3,
        .swap: 2,
        .undo: 5,
        .shuffle: 1,
        .magnet: 0,
        .double: 0
    ]

    init() {}

    func save() {

    }

    static func load() -> Profile {
        return Profile()
    }
}