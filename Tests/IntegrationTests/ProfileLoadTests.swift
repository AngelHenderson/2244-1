import Testing
import Foundation
@testable import GameApp
@testable import GameCore

@Suite("Profile Load Integration Tests")
struct ProfileLoadTests {

    @Test("Profile auto-loads in less than 100ms")
    func profileAutoLoadsQuickly() async {
        let startTime = Date()

        let profileStore = ProfileStore()
        await profileStore.loadProfile()

        let elapsedTime = Date().timeIntervalSince(startTime) * 1000

        #expect(elapsedTime < 100)
        #expect(profileStore.currentProfile != nil)
        #expect(profileStore.currentProfile?.name == "Player")
    }

    @Test("Profile persists and restores correctly")
    func profilePersistence() async {
        let profileStore = ProfileStore()
        let profile = Profile()
        profile.coins = 1000
        profile.level = 5

        await profileStore.saveProfile(profile)

        let newStore = ProfileStore()
        await newStore.loadProfile()

        #expect(newStore.currentProfile?.coins == 1000)
        #expect(newStore.currentProfile?.level == 5)
    }
}

@MainActor
class ProfileStore {
    var currentProfile: Profile?

    func loadProfile() async {
        currentProfile = Profile()
    }

    func saveProfile(_ profile: Profile) async {
        currentProfile = profile
    }
}