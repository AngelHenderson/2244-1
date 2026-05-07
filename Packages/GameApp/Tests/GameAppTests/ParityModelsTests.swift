import Foundation
import GameServices
import Testing
@testable import GameApp

@Suite("Duolingo-style parity contracts")
struct ParityModelsTests {
    @Test("Deep links parse every new parity destination")
    func appRouteParsesParityDestinations() throws {
        let cases: [(String, AppRoute)] = [
            ("game2244://dailyquests", .dailyQuests),
            ("game2244://dailystreaks", .dailyStreaks),
            ("game2244://practice", .practice),
            ("game2244://modes", .modes),
            ("game2244://feed", .feed),
            ("game2244://friends", .friends),
            ("game2244://account", .account),
            ("game2244://subscription", .subscription),
            ("game2244://reminders", .reminders),
            ("game2244://widget", .widgetPromo),
            ("game2244://yearreview", .yearReview),
            ("game2244://procoach", .proCoach),
            ("game2244://profile", .profile),
            ("game2244://achievements", .achievements),
            ("game2244://leaderboard", .leaderboard),
            ("game2244://theme", .theme),
            ("game2244://music", .music)
        ]

        for (rawURL, expected) in cases {
            let route = try #require(AppRoute(url: URL(string: rawURL)!))
            #expect(route == expected)
        }
    }

    @Test("Old readiness snapshots decode with new onboarding defaults")
    func readinessSnapshotMigratesOldPayload() throws {
        let data = """
        {
          "hasCompletedTutorial": true,
          "sessionsStarted": 3,
          "completedRuns": 1,
          "totalMerges": 12,
          "hasEarnedFirstReward": true,
          "visibleFeatures": ["play", "journey", "settings"],
          "dismissedRecommendations": [],
          "lastRecordedRunID": "run-1"
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(PlayerReadinessSnapshot.self, from: data)
        #expect(snapshot.hasCompletedTutorial)
        #expect(snapshot.onboardingPreferences.dailyPlayGoalMinutes == 10)
        #expect(snapshot.reminderPreferences.streakReminderEnabled)
        #expect(snapshot.seenPromptIDs.isEmpty)
    }

    @MainActor
    @Test("Move review store records newest entries first")
    func moveReviewStoreRecordsEntries() {
        let storage = InMemoryMoveReviewStorage()
        let store = MoveReviewStore(storage: storage)
        store.record(MoveReviewEntry(boardSummary: "A", moveSummary: "First", explanation: "One", outcome: "OK"))
        store.record(MoveReviewEntry(boardSummary: "B", moveSummary: "Second", explanation: "Two", outcome: "Better"))

        #expect(store.entries.count == 2)
        #expect(store.entries.first?.moveSummary == "Second")
        #expect(storage.entries.count == 2)
    }

    @MainActor
    @Test("Reminder store persists preference changes")
    func reminderStorePersists() {
        let storage = InMemoryReminderStorage()
        let store = ReminderPreferenceStore(storage: storage)
        store.preferences.practiceReminderEnabled = true
        store.preferences.reminderHour = 8

        #expect(storage.preferences.practiceReminderEnabled)
        #expect(storage.preferences.reminderHour == 8)
    }

    @Test("Mock social service returns feed and friend search data")
    func mockSocialServiceReturnsData() async throws {
        let service = MockSocialService()
        let feed = try await service.feed()
        let results = try await service.searchFriends(query: "Neon")

        #expect(!feed.isEmpty)
        #expect(results.contains { $0.displayName.contains("Neon") })
    }

    @Test("Firebase-backed account service uses local fallback when Firebase is unavailable")
    func firebaseBackedAccountServiceFallsBackWithoutFirebaseConfiguration() async throws {
        guard !FirebaseService.shared.isConfigured else { return }

        let suiteName = "FirebaseBackedAccountServiceFallsBackWithoutFirebaseConfiguration"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = FirebaseBackedAccountService(
            fallback: LocalAccountService(defaults: defaults)
        )

        let initialState = await service.currentState()
        #expect(initialState == .signedOut)

        let profile = try await service.createAccount(
            email: "player@example.com",
            password: "secret",
            displayName: "Test Player"
        )
        let persistedState = await service.currentState()

        #expect(profile.email == "player@example.com")
        #expect(profile.displayName == "Test Player")
        #expect(persistedState == .signedIn(profile))
    }
}

private final class InMemoryMoveReviewStorage: MoveReviewStorage, @unchecked Sendable {
    var entries: [MoveReviewEntry] = []

    func load() -> [MoveReviewEntry] {
        entries
    }

    func save(_ entries: [MoveReviewEntry]) {
        self.entries = entries
    }
}

private final class InMemoryReminderStorage: ReminderPreferenceStorage, @unchecked Sendable {
    var preferences = ReminderPreferences()

    func load() -> ReminderPreferences {
        preferences
    }

    func save(_ preferences: ReminderPreferences) {
        self.preferences = preferences
    }
}
