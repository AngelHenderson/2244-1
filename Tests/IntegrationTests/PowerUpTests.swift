import Testing
@testable import GameApp
@testable import GameCore

@Suite("Power-Up Integration Tests")
struct PowerUpTests {

    @Test("Power-ups consume from inventory correctly")
    func powerUpConsumption() async {
        let profileStore = ProfileStore()
        await profileStore.loadProfile()

        let initialHammers = profileStore.currentProfile!.powerUpInventory[.hammer]!
        let initialSwaps = profileStore.currentProfile!.powerUpInventory[.swap]!

        let powerUpManager = PowerUpManager(profileStore: profileStore)
        let hammerUsed = await powerUpManager.usePowerUp(.hammer)
        let swapUsed = await powerUpManager.usePowerUp(.swap)

        #expect(hammerUsed == true)
        #expect(swapUsed == true)

        #expect(profileStore.currentProfile!.powerUpInventory[.hammer]! == initialHammers - 1)
        #expect(profileStore.currentProfile!.powerUpInventory[.swap]! == initialSwaps - 1)
    }

    @Test("Cannot use power-up with zero inventory")
    func cannotUseEmptyPowerUp() async {
        let profileStore = ProfileStore()
        await profileStore.loadProfile()

        profileStore.currentProfile!.powerUpInventory[.magnet] = 0

        let powerUpManager = PowerUpManager(profileStore: profileStore)
        let magnetUsed = await powerUpManager.usePowerUp(.magnet)

        #expect(magnetUsed == false)
        #expect(profileStore.currentProfile!.powerUpInventory[.magnet]! == 0)
    }

    @Test("Power-up effects apply to game board")
    func powerUpEffects() async {
        let gameEngine = GameEngine()
        let board = Board(columns: 5, rows: 8)

        board.place(Tile(value: 2), at: Position(x: 2, y: 3))

        let hammerCommand = HammerCommand()
        let result = await hammerCommand.execute(at: Position(x: 2, y: 3), on: board)

        #expect(result.success == true)
        #expect(board.tile(at: Position(x: 2, y: 3)) == nil)
    }
}

@MainActor
class PowerUpManager {
    let profileStore: ProfileStore

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
    }

    func usePowerUp(_ type: PowerUpType) async -> Bool {
        guard let profile = profileStore.currentProfile,
              let count = profile.powerUpInventory[type],
              count > 0 else {
            return false
        }

        profile.powerUpInventory[type] = count - 1
        return true
    }
}

protocol PowerUpCommand {
    func execute(at position: Position, on board: Board) async -> PowerUpResult
}

struct PowerUpResult {
    let success: Bool
    let affectedPositions: [Position]
}

class HammerCommand: PowerUpCommand {
    func execute(at position: Position, on board: Board) async -> PowerUpResult {
        board.tiles.removeValue(forKey: position)
        return PowerUpResult(success: true, affectedPositions: [position])
    }
}