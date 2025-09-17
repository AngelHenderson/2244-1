import Testing
@testable import GameApp
@testable import GameCore

@Suite("Initial Inventory Integration Tests")
struct InitialInventoryTests {

    @Test("Initial inventory [3,2,5,1,0,0]")
    func initialInventoryValues() async {
        let profile = Profile()

        #expect(profile.powerUpInventory[.hammer] == 3)
        #expect(profile.powerUpInventory[.swap] == 2)
        #expect(profile.powerUpInventory[.undo] == 5)
        #expect(profile.powerUpInventory[.shuffle] == 1)
        #expect(profile.powerUpInventory[.magnet] == 0)
        #expect(profile.powerUpInventory[.double] == 0)

        let totalPowerUps = profile.powerUpInventory.values.reduce(0, +)
        #expect(totalPowerUps == 11)
    }

    @Test("Inventory persists across sessions")
    func inventoryPersistence() async {
        let profileStore = ProfileStore()
        await profileStore.loadProfile()

        profileStore.currentProfile!.powerUpInventory[.hammer] = 10
        profileStore.currentProfile!.powerUpInventory[.swap] = 5

        await profileStore.saveProfile(profileStore.currentProfile!)

        let newStore = ProfileStore()
        await newStore.loadProfile()

        #expect(newStore.currentProfile!.powerUpInventory[.hammer] == 10)
        #expect(newStore.currentProfile!.powerUpInventory[.swap] == 5)
    }

    @Test("Initial coins value is 305")
    func initialCoinsValue() async {
        let profile = Profile()
        #expect(profile.coins == 305)
    }
}

extension Profile {
    var totalPowerUps: Int {
        return powerUpInventory.values.reduce(0, +)
    }
}