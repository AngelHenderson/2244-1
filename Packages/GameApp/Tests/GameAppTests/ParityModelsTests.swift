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
                var lowercasedText = comment.text.lowercased()
                if lowercasedText.hasPrefix("@") {
                    let parts = lowercasedText.split(separator: " ", maxSplits: 1)
                    if parts.count > 1 {
                        lowercasedText = String(parts[1])
                    }
                }
                #expect(!lowercasedText.contains("competition"), "Found 'competition' in bot comment: \(comment.text)")
                
                if !isTimeTopic {
                    let hasTooSlow = lowercasedText.contains("too slow")
                    #expect(!hasTooSlow, "Found 'too slow' in non-time bot comment: \(comment.text)")
                } else {
                    let hasInfinitelyFaster = lowercasedText.contains("infinitely faster")
                    #expect(!hasInfinitelyFaster, "Found 'infinitely faster' in time bot comment: \(comment.text)")
                }
                
                let hasWonWord = lowercasedText.range(of: "\\bwon\\b(?!')", options: .regularExpression) != nil
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
                    "comfortably ahead", "only at", "is a joke", "you'll never catch",
                    "you're not catching", "out of your reach", "don't bother comparing", "my floor", "casually coasting",
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

@Test("Too slow phrasing is only used for time gaps of 10+ seconds")
    func tooSlowPhrasingRequiresTenSecondsGap() async throws {
        let service = MockSocialService()

        // Test Case 1: Gap of 1 second (under 10s) -> "too slow" should NOT be used in slower time brag replies.
        for _ in 0..<50 {
            let reply = service.generateContextualReply(to: "beat you 0:07", message: "0:06", forceTone: "one_up")
            #expect(!reply.lowercased().contains("too slow"), "Should not contain 'too slow' when gap is 1s: \(reply)")
        }

        // Test Case 2: Gap of 19 seconds (10s+) -> "too slow" is allowed and should be generated at least sometimes.
        var sawTooSlow = false
        for _ in 0..<50 {
            let reply = service.generateContextualReply(to: "beat you 0:25", message: "0:06", forceTone: "one_up")
            if reply.lowercased().contains("too slow") {
                sawTooSlow = true
                break
            }
        }
        #expect(sawTooSlow, "Should generate 'too slow' when gap is 19s")

        // Test Case 3: Small gap when commenting on single time post -> "too slow" should NOT be used.
        // If we reply to "beat you 0:07", since the time is <= 10s, the generated higherNum will be at least 4s, meaning gap <= 3s.
        for _ in 0..<50 {
            let reply = service.generateContextualReply(to: "beat you 0:07", message: "no time here", forceTone: "one_up")
            #expect(!reply.lowercased().contains("too slow"), "Should not contain 'too slow' when commenting on a 7s post: \(reply)")
        }
    }

    private func isTooLowMilestoneReply(_ reply: String) -> Bool {
        let lowered = reply.lowercased()
        if lowered.contains("too low to get ahead") || lowered.contains("acting like") || lowered.contains("a long time ago") {
            return true
        }
        if lowered.contains("laughing from") && (lowered.contains("only at") || lowered.contains("still at")) {
            return true
        }
        return false
    }

    @Test("Too low/slow phrasing is only used when replying to competitive/one-upmanship comments")
    func tooLowSlowRequiresCompetitiveComment() async throws {
        let service = MockSocialService()

        // 1. Time topic:
        // Reply to a non-competitive comment (no competitive keywords):
        let timeReplyNonComp = service.generateContextualReply(to: "I only managed 0:07.", message: "0:06", forceTone: "one_up")
        #expect(!timeReplyNonComp.lowercased().contains("too slow") && !timeReplyNonComp.lowercased().contains("fast enough"), "Should not use too slow/slow brag if comment is not competitive: \(timeReplyNonComp)")

        // Reply to a competitive comment (contains "beat you"):
        let timeReplyComp = service.generateContextualReply(to: "I beat you, clocked 0:07.", message: "0:06", forceTone: "one_up")
        #expect(timeReplyComp.lowercased().contains("not fast enough") || timeReplyComp.lowercased().contains("too slow"), "Should use slow brag if comment is competitive: \(timeReplyComp)")

        // 2. Milestone topic:
        // Reply to a non-competitive comment:
        let milestoneReplyNonComp = service.generateContextualReply(to: "I reached 256.", message: "Unlocked milestone 512.", forceTone: "one_up")
        let isTooLowNonComp = isTooLowMilestoneReply(milestoneReplyNonComp)
        #expect(!isTooLowNonComp, "Should not use too low brag if comment is not competitive: \(milestoneReplyNonComp)")

        // Reply to a competitive comment:
        let milestoneReplyComp = service.generateContextualReply(to: "My 256 is better, you cute.", message: "Unlocked milestone 512.", forceTone: "one_up")
        let isMilestoneBrag = isTooLowMilestoneReply(milestoneReplyComp)
        #expect(isMilestoneBrag, "Should use too low/lower brag if comment is competitive: \(milestoneReplyComp)")

        // 3. Comment directly to the poster (commentText == message):
        // Even if it has competitive keywords, we shouldn't use "too low/slow" brags.
        let postTimeText = "I beat you, clocked 0:07."
        let commentToPosterTime = service.generateContextualReply(to: postTimeText, message: postTimeText, forceTone: "one_up")
        #expect(!commentToPosterTime.lowercased().contains("too slow") && !commentToPosterTime.lowercased().contains("fast enough"), "Should not use too slow brag when commenting directly to the poster: \(commentToPosterTime)")

        let postMilestoneText = "My 256 is better, you cute."
        let commentToPosterMilestone = service.generateContextualReply(to: postMilestoneText, message: postMilestoneText, forceTone: "one_up")
        let isTooLowToPoster = isTooLowMilestoneReply(commentToPosterMilestone)
        #expect(!isTooLowToPoster, "Should not use too low brag when commenting directly to the poster: \(commentToPosterMilestone)")
    }

    @Test("Competitive replies pause and tie when replying to 0:02")
    func competitiveRepliesPauseAtTwoSeconds() async throws {
        let service = MockSocialService()

        for _ in 0..<50 {
            // Reply to "0:02" comment (should use peak limit responses instead of trying to go faster)
            let reply = service.generateContextualReply(to: "I clocked 0:02.", message: "I clocked 0:06.", forceTone: "one_up")
            
            // Check that it doesn't contain "shaved time off your 0:02. My best is 0:02" or other faster brags
            #expect(!reply.contains("shaved time off"), "Should not try to shave time off 0:02: \(reply)")
            #expect(!reply.contains("leagues faster"), "Should not claim to be leagues faster than 0:02: \(reply)")
            #expect(!reply.contains("clear it in"), "Should not claim to clear 0:02 in faster time: \(reply)")
            
            // Check that it contains the limit/peak message substrings
            let isLimitReply = ["limit", "peak", "share the record", "theoretical limit"].contains { reply.lowercased().contains($0) }
            #expect(isLimitReply, "Should recognize 0:02 is the limit: \(reply)")
        }
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

    @Test("NPCs have a ~45% chance to reply with a low milestone")
    func testLowMilestoneChance() async throws {
        let service = MockSocialService()
        var lowMilestoneCount = 0
        let totalRuns = 200

        for _ in 0..<totalRuns {
            let reply = service.generateContextualReply(to: "Unlocked milestone 65K.", message: "Unlocked milestone 65K.", forceTone: "one_up")
            let isLowM = ["2048", "4096", "8192", "16K", "32K"].contains { reply.contains($0) }
            if isLowM {
                lowMilestoneCount += 1
            }
        }
        
        let ratio = Double(lowMilestoneCount) / Double(totalRuns)
        #expect(ratio >= 0.30 && ratio <= 0.60, "Low milestone reply ratio is \(ratio), expected around 0.45")
    }

    @Test("Replying to a lower milestone has a ~95% chance to trigger too low reply")
    func testTooLowReplyChance() async throws {
        let service = MockSocialService()
        var tooLowCount = 0
        let totalRuns = 200

        for _ in 0..<totalRuns {
            let reply = service.generateContextualReply(to: "I easily beat 32K.", message: "Unlocked milestone 65K.", forceTone: "one_up")
            let isTooLow = isTooLowMilestoneReply(reply)
            if isTooLow {
                tooLowCount += 1
            }
        }
        
        let ratio = Double(tooLowCount) / Double(totalRuns)
        #expect(ratio >= 0.88 && ratio <= 0.99, "Too low reply ratio is \(ratio), expected around 0.95")
    }

    @Test("Player record is consistent across a competitive comment thread")
    func testPlayerRecordConsistency() async throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "socialFeed.cache.v40")
        defaults.removeObject(forKey: "socialFeed.cacheDate.v37")
        defaults.removeObject(forKey: "socialFeed.userPosts.v2")
        
        let service = MockSocialService()
        // Generate threads with different topics
        let milestones = ["65K", "100 days streak", "timed challenge in 0:45", "15 infinities count"]
        
        for message in milestones {
            try await service.postEvent(message: "I am playing! \(message)", statText: "stat")
        }
        
        guard let data = defaults.data(forKey: "socialFeed.userPosts.v2"),
              let items = try? JSONDecoder().decode([SocialFeedItem].self, from: data) else {
            Issue.record("Failed to decode user posts")
            return
        }
        
        #expect(!items.isEmpty)
        
        for item in items {
            let topic = MockSocialService.determineTopic(message: item.message)
            
            // Build all reply chains
            var chains: [[SocialFeedComment]] = []
            var currentChain: [SocialFeedComment] = []
            
            for comment in item.comments {
                let text = comment.text
                if text.hasPrefix("@") {
                    let parts = text.split(separator: " ")
                    if let first = parts.first {
                        let targetName = String(first.dropFirst())
                        if let last = currentChain.last, targetName == last.authorName {
                            currentChain.append(comment)
                        } else {
                            if !currentChain.isEmpty {
                                chains.append(currentChain)
                            }
                            currentChain = [comment]
                        }
                    } else {
                        if !currentChain.isEmpty {
                            chains.append(currentChain)
                        }
                        currentChain = [comment]
                    }
                } else {
                    if !currentChain.isEmpty {
                        chains.append(currentChain)
                    }
                    currentChain = [comment]
                }
            }
            if !currentChain.isEmpty {
                chains.append(currentChain)
            }
            
            // Verify record consistency only for competitive threads (chains of length >= 3)
            for chain in chains where chain.count >= 3 {
                var playerRecords: [String: String] = [:]
                for comment in chain {
                    let author = comment.authorName
                    if let val = MockSocialService.extractValue(from: comment.text, topic: topic) {
                        if let establishedVal = playerRecords[author] {
                            // val must be worse than or equal to establishedVal
                            let isBetter = MockSocialService.isRecord(establishedVal, worseThan: val, topic: topic)
                            #expect(!isBetter, "Player \(author) claimed value \(val) in competitive thread, which is better than their established record of \(establishedVal) (topic: \(topic), comment: \(comment.text))")
                        } else {
                            playerRecords[author] = val
                        }
                    }
                }
            }
        }
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
