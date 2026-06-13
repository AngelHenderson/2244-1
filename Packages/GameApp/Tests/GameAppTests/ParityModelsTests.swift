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
        let browseResults = try await service.searchFriends(query: "")
        let searchResults = try await service.searchFriends(query: "test")

        #expect(!feed.isEmpty)
        #expect(browseResults.count == 20)
        // Browse results should have real avatars, not SF Symbol fallbacks
        #expect(browseResults.allSatisfy { !$0.avatarID.contains("systemName") })
        // Search may or may not find matches — just ensure it doesn't crash
        #expect(searchResults.count >= 0)
    }

    @Test("Bot competitive comments and replies do not contain finite-match word 'competition'")
    func botCompetitiveCommentsDoNotContainCompetition() async throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "socialFeed.cache.v40")
        defaults.removeObject(forKey: "socialFeed.cacheDate.v37")
        defaults.removeObject(forKey: "socialFeed.userPosts.v2")
        
        let service = MockSocialService()
        // Post a few events to generate a large volume of bot comments/replies
        for milestone in [4, 8, 16, 32, 64] {
            try await service.postEvent(message: "Unlocked milestone \(milestone).", statText: "Milestone \(milestone)")
        }
        
        // Retrieve the cached items directly from UserDefaults to get all comments (even future ones)
        guard let data = defaults.data(forKey: "socialFeed.userPosts.v2"),
              let items = try? JSONDecoder().decode([SocialFeedItem].self, from: data) else {
            Issue.record("Failed to decode user posts")
            return
        }
        
        #expect(!items.isEmpty)
        
        var totalCommentsChecked = 0
        for item in items {
            let isTimeTopic = item.message.lowercased().contains("time") || item.message.lowercased().contains("speed") || item.message.lowercased().contains("timed challenge")
            for comment in item.comments {
                totalCommentsChecked += 1
                let lowercasedText = comment.text.lowercased()
                #expect(!lowercasedText.contains("competition"), "Found 'competition' in bot comment: \(comment.text)")
                
                if !isTimeTopic {
                    let hasTooSlow = lowercasedText.contains("too slow")
                    #expect(!hasTooSlow, "Found 'too slow' in non-time bot comment: \(comment.text)")
                } else {
                    let hasInfinitelyFaster = lowercasedText.contains("infinitely faster")
                    #expect(!hasInfinitelyFaster, "Found 'infinitely faster' in time bot comment: \(comment.text)")
                }
                
                let hasWonWord = lowercasedText.range(of: "\\bwon\\b", options: .regularExpression) != nil
                #expect(!hasWonWord, "Found finite-match word 'won' in bot comment: \(comment.text)")
                
                let hasCompeteWord = lowercasedText.range(of: "\\bcompete\\b", options: .regularExpression) != nil
                #expect(!hasCompeteWord, "Found finite-match word 'compete' in bot comment: \(comment.text)")
                
                let hasWinWord = lowercasedText.range(of: "\\bwin\\b", options: .regularExpression) != nil
                #expect(!hasWinWord, "Found finite-match word 'win' in bot comment: \(comment.text)")
                
                let hasGiveUp = lowercasedText.contains("give up")
                #expect(!hasGiveUp, "Found 'give up' phrase in bot comment: \(comment.text)")
                
                let hasTooEasy = lowercasedText.contains("too easy")
                #expect(!hasTooEasy, "Found 'too easy' phrase in bot comment: \(comment.text)")
                
                if lowercasedText.contains("do better") {
                    let isAllowed = lowercasedText.contains("i always do better") || lowercasedText.contains("i did do better")
                    #expect(isAllowed, "Found unexpected 'do better' phrase in bot comment: \(comment.text)")
                }
                
                #expect(!comment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Bot comment by \(comment.authorName) was blank/empty")
                
                let hasThisPlace = lowercasedText.contains("this place")
                #expect(!hasThisPlace, "Found generic 'this place' phrase in bot comment: \(comment.text)")
                
                let hasEffortless = lowercasedText.contains("effortless")
                #expect(!hasEffortless, "Found 'effortless' or 'effortlessly' in bot comment: \(comment.text)")
                
                let competitivePhrases = [
                    "grinding right now", "closing the gap", "lead while it lasts",
                    "coming for the top", "overtake you", "lower right now",
                    "irrelevant to my", "never exist on my level", "coasting at",
                    "joke", "safely ahead", "bypassed", "floor", "untouched",
                    "breeze through", "clocked", "leagues faster", "dominating",
                    "laughing from", "easily hit", "easily clear", "easily passed",
                    "easily reached", "easily beat", "easily bypassed", "easily crush",
                    "chasing my lead", "higher ceiling", "dominance", "unreachable",
                    "comfortably ahead", "only at", "is a joke", "try catching",
                    "try hitting", "don't bother comparing", "my floor", "casually coasting",
                    "record is", "my record", "permanent", "diamond tier", "diamond chests",
                    "already far ahead", "nothing compared", "always do better", "did do better",
                    "baseline", "left you behind", "no threat", "never stop climbing",
                    "practice runs", "without even looking", "time is cute", "shaved time",
                    "speedrun", "practice run", "in my sleep", "unmatched", "infinity count",
                    "hof entries", "speaks for itself", "farm ", "extended infinitely",
                    "pulls are cute", "dropped below", "talk to me", "anywhere near",
                    "ignoring this", "efforts are pointless", "flawless", "view from the bottom",
                    "one-sided", "might be lower", "ahead for now", "grinding", "too comfortable",
                    "watch your back", "watch me stay ahead", "watch my stats",
                    "endless dominance", "witness infinity", "extend my lead"
                ]
                let isCompetitiveComment = competitivePhrases.contains { lowercasedText.contains($0) }
                if isCompetitiveComment {
                    let forbiddenStruggleWords = [
                        "stuck", "struggling", "complaining", "clueless",
                        "pathetic", "struggle", "gave up", "giving up", "choke"
                    ]
                    for word in forbiddenStruggleWords {
                        #expect(!lowercasedText.contains(word), "Found forbidden struggle word '\(word)' in competitive comment: \(comment.text)")
                    }
                    let jealousSymbols = [":(", ":((", ">:(", ":/", ";-(", "-_-", ">_<"]
                    for sym in jealousSymbols {
                        #expect(!lowercasedText.contains(sym), "Found jealous symbol '\(sym)' in competitive comment: \(comment.text)")
                    }
                }
            }
        }
        
        #expect(totalCommentsChecked > 0, "No comments were generated to check")
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
