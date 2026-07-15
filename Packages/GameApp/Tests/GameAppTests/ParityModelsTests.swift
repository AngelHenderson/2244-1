import Foundation
import GameServices
import Testing
@testable import GameApp

@Suite("Duolingo-style parity contracts", .serialized)
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
        let searchResults = try await service.searchFriends(query: "Carlos")

        #expect(!feed.isEmpty)
        #expect(browseResults.count == 20)
        // Browse results should have real avatars, not SF Symbol fallbacks
        #expect(browseResults.allSatisfy { !$0.avatarID.contains("systemName") })
        // Search should find all matching names exhaustively
        #expect(searchResults.count > 0, "Searching for 'Carlos' should return results")
        #expect(searchResults.allSatisfy { $0.displayName.localizedCaseInsensitiveContains("Carlos") })
    }

    @Test("Bot competitive comments and replies do not contain finite-match word 'competition'")
    func botCompetitiveCommentsDoNotContainCompetition() async throws {
        let defaults = UserDefaults.standard
        MockSocialService.clearFileStorageForTests()
        defaults.removeObject(forKey: MockSocialService.feedDateKey)
        
        let service = MockSocialService()
        // Post a few events to generate a large volume of bot comments/replies
        for milestone in [4, 8, 16, 32, 64] {
            try await service.postEvent(message: "Unlocked milestone \(milestone).", statText: "Milestone \(milestone)")
        }
        
        // Retrieve the cached items directly from UserDefaults to get all comments (even future ones)
        guard let items = MockSocialService.loadUserPosts() else {
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
                
                let hasMatchWord = lowercasedText.range(of: "\\bmatch\\b", options: .regularExpression) != nil
                #expect(!hasMatchWord, "Found finite-match word 'match' in bot comment: \(comment.text)")
                
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
                    "record is", "my record", "permanent",
                    "already far ahead", "nothing compared", "always do better", "did do better",
                    "baseline", "left you behind", "no threat", "never stop climbing",
                    "practice runs", "without even looking", "time is cute", "shaved time",
                    "speedrun", "practice run", "in my sleep", "unrivaled", "infinity count",
                    "hof entries", "speaks for itself", "farm ", "extended infinitely",
                    "pulls are cute", "dropped below", "talk to me", "anywhere near",
                    "ignoring that", "efforts are pointless", "flawless", "view from the bottom",
                    "one-sided", "might be lower", "ahead for now", "grinding", "too comfortable",
                    "watch your back", "watch me stay ahead", "watch my stats",
                    "sidelines", "witness infinity", "extend my lead"
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

        // Test Case 4: Gap of 1 or 2 seconds -> "leagues faster" should NOT be used.
        for _ in 0..<50 {
            let reply = service.generateContextualReply(to: "beat you 0:08", message: "0:06", forceTone: "one_up")
            #expect(!reply.lowercased().contains("leagues faster"), "Should not contain 'leagues faster' when gap is 2s: \(reply)")
        }
    }

    private func isTooLowMilestoneReply(_ reply: String) -> Bool {
        let lowered = reply.lowercased()
        let matchPhrases = ["too low to get ahead", "acting like", "a long time ago", "child's play", "is a joke", "you're celebrating", "in the dust", "out of your reach", "old news", "never get there", "always be behind", "completely outclassed", "except you", "delusional", "completely irrelevant", "final", "barrier", "infinitely behind", "stuck in the lower tiers", "never catch up", "dominate", "ahead of your", "nothing compared", "way past", "easily passed", "toying with", "untouchable", "ceiling", "embarrassing", "not built for", "stuck at", "lagging at", "warming up", "fell for it"]
        if matchPhrases.contains(where: { lowered.contains($0) }) {
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
            let reply = service.generateContextualReply(to: "I clocked 0:02.", message: "I clocked 0:02.", forceTone: "one_up")
            
            // Check that it doesn't contain "shaved time off your 0:02. My best is 0:02" or other faster brags
            #expect(!reply.contains("shaved time off"), "Should not try to shave time off 0:02: \(reply)")
            #expect(!reply.contains("leagues faster"), "Should not claim to be leagues faster than 0:02: \(reply)")
            #expect(!reply.contains("clear it in"), "Should not claim to clear 0:02 in faster time: \(reply)")
            
            // Check that it is a tie/rivalry reply
            let isTieReply = reply.contains("tied") || reply.contains("both at 0:02") || reply.contains("right there at 0:02") || reply.contains("also clocked 0:02") || reply.contains("sitting at 0:02") || reply.contains("Cute, but irrelevant.") || reply.contains("race starts now") || reply.contains("breaks it first")
            #expect(isTieReply, "Should recognize 0:02 is tied: \(reply)")
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
        #expect(ratio >= 0.88 && ratio <= 1.0, "Too low reply ratio is \(ratio), expected around 0.95")
    }

    @Test("Verify that milestone strings exist in MockSocialService.allMilestones")
    func testMilestoneExistence() {
        let milestones = MockSocialService.allMilestones
        #expect(milestones.contains("3q"))
        #expect(milestones.contains("51q"))
        #expect(milestones.contains("883t"))
        
        let index3q = milestones.firstIndex(of: "3q")
        let index51q = milestones.firstIndex(of: "51q")
        let index883t = milestones.firstIndex(of: "883t")
        let index7w = milestones.firstIndex(of: "7w")
        print("INDEX OF 883T: \(index883t ?? -1)")
        print("INDEX OF 7W: \(index7w ?? -1)")
        
        let oneUp = MockSocialService.oneUpValue(for: "883t", topic: "milestone")
        let lower = MockSocialService.lowerValue(for: "883t", topic: "milestone")
        
        #expect(index3q != nil)
        #expect(index51q != nil)
        #expect(index883t != nil)
        #expect(index7w != nil)
    }

    @Test("Verify extractValue filters out milestones inside leading mentions with spaces")
    func testExtractValueWithSpaceMention() {
        let text = "@Amanda 2048 I hit 8192"
        let val = MockSocialService.extractValue(from: text, topic: "milestone")
        #expect(val == "8192")
    }

    @Test("Verify that lower brag replies are correctly selected when speaker record is lower than the comment milestone")
    func testLowerBragReplySelection() {
        let service = MockSocialService()
        
        let milestones = MockSocialService.allMilestones
        let lowerMilestone = milestones[100]
        let higherMilestone = milestones[200]
        
        let comment = "My \(higherMilestone) is better, you cute."
        let reply = service.generateContextualReply(to: comment, message: "Unlocked milestone \(higherMilestone).", forceTone: "one_up", speakerValue: lowerMilestone)
        
        #expect(reply.contains(lowerMilestone), "Expected lower brag reply to contain speaker record: \(lowerMilestone) (Reply: \(reply))")
        #expect(reply.contains(higherMilestone), "Expected lower brag reply to contain target milestone: \(higherMilestone) (Reply: \(reply))")
    }

    @Test("Verify that lower brag replies are correctly selected for streaks when speaker record is lower")
    func testStreakLowerBragReplySelection() {
        let service = MockSocialService()
        
        let comment = "My 50 day streak is better, you cute."
        let reply = service.generateContextualReply(to: comment, message: "Unlocked milestone 50 days.", forceTone: "one_up", speakerValue: "20")
        
        #expect(reply.contains("20"), "Expected lower brag reply to contain speaker record: 20 (Reply: \(reply))")
        #expect(reply.contains("50"), "Expected lower brag reply to contain target streak: 50 (Reply: \(reply))")
    }

    @Test("Verify that lower brag replies are correctly selected for time when speaker record is slower")
    func testTimeLowerBragReplySelection() {
        let service = MockSocialService()
        
        let comment = "I clocked 0:15."
        let reply = service.generateContextualReply(to: comment, message: "timed challenge in 0:15", forceTone: "one_up", speakerValue: "0:30")
        
        #expect(reply.contains("0:30"), "Expected lower brag reply to contain speaker record: 0:30 (Reply: \(reply))")
        #expect(reply.contains("0:15"), "Expected lower brag reply to contain target time: 0:15 (Reply: \(reply))")
    }

    @Test("Verify that lower brag replies are correctly selected for HOF when speaker record is lower")
    func testHofLowerBragReplySelection() {
        let service = MockSocialService()
        
        let comment = "My 10 infinities is better, you cute."
        let reply = service.generateContextualReply(to: comment, message: "10 infinities count", forceTone: "one_up", speakerValue: "5")
        
        #expect(reply.contains("5"), "Expected lower brag reply to contain speaker record: 5 (Reply: \(reply))")
        #expect(reply.contains("10"), "Expected lower brag reply to contain target HOF entries: 10 (Reply: \(reply))")
    }

    @Test("Player record is consistent across a competitive comment thread")
    func testPlayerRecordConsistency() async throws {
        let defaults = UserDefaults.standard
        MockSocialService.clearFileStorageForTests()
        defaults.removeObject(forKey: MockSocialService.feedDateKey)
        MockSocialService.inMemoryUserPostsOverride = []
        
        let service = MockSocialService()
        // Generate threads with different topics
        let milestones = ["65K", "100 days streak", "timed challenge in 0:45", "15 infinities count"]
        
        for message in milestones {
            try await service.postEvent(message: "I am playing! \(message)", statText: "stat")
        }
        
        guard let items = MockSocialService.loadUserPosts() else {
            Issue.record("Failed to decode user posts")
            return
        }
        
        #expect(!items.isEmpty)
        
        for item in items {
            let topic = MockSocialService.determineTopic(message: item.message)
            
            // Build all reply chains
            var chains: [[SocialFeedComment]] = []
            let allPossibleNames = Set([item.authorName] + item.comments.map { $0.authorName })
            
            func extractTargetName(from text: String) -> String? {
                if !text.hasPrefix("@") { return nil }
                let sortedCandidates = allPossibleNames.sorted(by: { $0.count > $1.count })
                for candidate in sortedCandidates {
                    if text.hasPrefix("@\(candidate)") {
                        return candidate
                    }
                }
                return nil
            }
            
            func extractNumbers(from text: String) -> Set<Int> {
                let pattern = "\\b(\\d+)\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
                let nsText = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                let nums = matches.compactMap { match -> Int? in
                    Int(nsText.substring(with: match.range))
                }
                return Set(nums)
            }
            
            func doesCommentMatchConversation(author: String, targetName: String, last: SocialFeedComment) -> Bool {
                let lastTarget = extractTargetName(from: last.text)
                if last.authorName == targetName {
                    return lastTarget == nil || lastTarget == author
                } else if last.authorName == author {
                    return lastTarget == targetName
                }
                return false
            }
            
            for comment in item.comments {
                let text = comment.text
                let author = comment.authorName
                
                func isChainCompatible(_ chain: [SocialFeedComment]) -> Bool {
                    var playerRecords: [String: String] = [:]
                    for chainComment in chain {
                        let cAuthor = chainComment.authorName
                        let cTextLower = chainComment.text.lowercased()
                        let cIsCatchUpReply = cTextLower.contains("just beat your") ||
                                              cTextLower.contains("got ahead") ||
                                              cTextLower.contains("ahead now") ||
                                              cTextLower.contains("blew past your") ||
                                              cTextLower.contains("caught up and passed") ||
                                              cTextLower.contains("clocked faster than") ||
                                              (cTextLower.contains("overtake you") && !cTextLower.contains("overtake your")) ||
                                              (cTextLower.contains("passed you") && !cTextLower.contains("passed your")) ||
                                              cTextLower.contains("just passed your")
                        
                        let cCompetitivePhrases = [
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
                            "record is", "my record", "permanent",
                            "already far ahead", "nothing compared", "always do better", "did do better",
                            "baseline", "left you behind", "no threat", "never stop climbing",
                            "practice runs", "without even looking", "time is cute", "shaved time",
                            "speedrun", "practice run", "in my sleep", "unrivaled", "infinity count",
                            "hof entries", "speaks for itself", "farm ", "extended infinitely",
                            "pulls are cute", "dropped below", "talk to me", "anywhere near",
                            "ignoring that", "efforts are pointless", "flawless", "view from the bottom",
                            "one-sided", "might be lower", "ahead for now", "grinding", "too comfortable",
                            "watch your back", "watch me stay ahead", "watch my stats",
                            "sidelines", "witness infinity", "extend my lead"
                        ]
                        let cIsReply = chainComment.text.hasPrefix("@")
                        let cIsCompetitiveComment = !cIsReply || cCompetitivePhrases.contains { cTextLower.contains($0) }
                        
                        var cVal: String? = nil
                        if cIsCompetitiveComment {
                            cVal = MockSocialService.extractValue(from: chainComment.text, topic: topic)
                            if cVal == nil && cIsCatchUpReply {
                                if let prevIdx = chain.firstIndex(where: { $0.id == chainComment.id }),
                                   prevIdx > 0 {
                                    let competitor = chain[prevIdx - 1].authorName
                                    if let compVal = playerRecords[competitor] {
                                        cVal = MockSocialService.oneUpValue(for: compVal, topic: topic)
                                    }
                                }
                            }
                        }
                        if let cVal = cVal {
                            playerRecords[cAuthor] = cVal
                        }
                    }
                    
                    let textLower = text.lowercased()
                    let isCatchUpReply = textLower.contains("just beat your") ||
                                         textLower.contains("got ahead") ||
                                         textLower.contains("ahead now") ||
                                         textLower.contains("blew past your") ||
                                         textLower.contains("caught up and passed") ||
                                         textLower.contains("clocked faster than") ||
                                         (textLower.contains("overtake you") && !textLower.contains("overtake your")) ||
                                         (textLower.contains("passed you") && !textLower.contains("passed your")) ||
                                         textLower.contains("just passed your")
                    
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
                        "record is", "my record", "permanent",
                        "already far ahead", "nothing compared", "always do better", "did do better",
                        "baseline", "left you behind", "no threat", "never stop climbing",
                        "practice runs", "without even looking", "time is cute", "shaved time",
                        "speedrun", "practice run", "in my sleep", "unrivaled", "infinity count",
                        "hof entries", "speaks for itself", "farm ", "extended infinitely",
                        "pulls are cute", "dropped below", "talk to me", "anywhere near",
                        "ignoring that", "efforts are pointless", "flawless", "view from the bottom",
                        "one-sided", "might be lower", "ahead for now", "grinding", "too comfortable",
                        "watch your back", "watch me stay ahead", "watch my stats",
                        "sidelines", "witness infinity", "extend my lead"
                    ]
                    let isReply = text.hasPrefix("@")
                    let isCompetitiveComment = !isReply || competitivePhrases.contains { textLower.contains($0) }
                    
                    var val: String? = nil
                    if isCompetitiveComment {
                        val = MockSocialService.extractValue(from: text, topic: topic)
                        if val == nil && isCatchUpReply {
                            if let last = chain.last {
                                let competitor = last.authorName
                                if let compVal = playerRecords[competitor] {
                                    val = MockSocialService.oneUpValue(for: compVal, topic: topic)
                                }
                            }
                        }
                    }
                    
                    if let val = val {
                        if let establishedVal = playerRecords[author] {
                            let isWorse = MockSocialService.isRecord(val, worseThan: establishedVal, topic: topic)
                            if isWorse {
                                return false
                            }
                        }
                    }
                    return true
                }
                
                if let targetName = extractTargetName(from: text) {
                    // Find all candidate chains that match the conversation and are within 300 seconds
                    var candidates: [(index: Int, last: SocialFeedComment)] = []
                    for (idx, chain) in chains.enumerated() {
                        if let last = chain.last,
                           doesCommentMatchConversation(author: author, targetName: targetName, last: last),
                           comment.createdAt.timeIntervalSince(last.createdAt) <= 300 {
                            candidates.append((index: idx, last: last))
                        }
                    }
                    
                    let compatibleCandidates = candidates.filter { isChainCompatible(chains[$0.index]) }
                    
                    if !compatibleCandidates.isEmpty {
                        var bestIdx = compatibleCandidates[0].index
                        if compatibleCandidates.count > 1 {
                            let commentNums = extractNumbers(from: text)
                            var maxMatches = -1
                            for candidate in compatibleCandidates {
                                let chain = chains[candidate.index]
                                var matchCount = 0
                                for chainComment in chain {
                                    let chainNums = extractNumbers(from: chainComment.text)
                                    let intersection = commentNums.intersection(chainNums)
                                    matchCount += intersection.count
                                }
                                if matchCount > maxMatches {
                                    maxMatches = matchCount
                                    bestIdx = candidate.index
                                }
                            }
                        }
                        chains[bestIdx].append(comment)
                    } else {
                        chains.append([comment])
                    }
                } else {
                    chains.append([comment])
                }
            }
            
            // Verify record consistency only for competitive threads (chains of length >= 3)
            for chain in chains where chain.count >= 3 {
                print("DEBUG CHAIN (\(topic)):")
                for comment in chain {
                    print("  [\(comment.authorName)]: \(comment.text)")
                }
                var playerRecords: [String: String] = [:]
                for comment in chain {
                    let author = comment.authorName
                    let textLower = comment.text.lowercased()
                    let isCatchUpReply = textLower.contains("just beat your") ||
                                         textLower.contains("got ahead") ||
                                         textLower.contains("ahead now") ||
                                         textLower.contains("blew past your") ||
                                         textLower.contains("caught up and passed") ||
                                         textLower.contains("clocked faster than") ||
                                         (textLower.contains("overtake you") && !textLower.contains("overtake your")) ||
                                         (textLower.contains("passed you") && !textLower.contains("passed your")) ||
                                         textLower.contains("just passed your")
                    
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
                        "record is", "my record", "permanent",
                        "already far ahead", "nothing compared", "always do better", "did do better",
                        "baseline", "left you behind", "no threat", "never stop climbing",
                        "practice runs", "without even looking", "time is cute", "shaved time",
                        "speedrun", "practice run", "in my sleep", "unrivaled", "infinity count",
                        "hof entries", "speaks for itself", "farm ", "extended infinitely",
                        "pulls are cute", "dropped below", "talk to me", "anywhere near",
                        "ignoring that", "efforts are pointless", "flawless", "view from the bottom",
                        "one-sided", "might be lower", "ahead for now", "grinding", "too comfortable",
                        "watch your back", "watch me stay ahead", "watch my stats",
                        "sidelines", "witness infinity", "extend my lead"
                    ]
                    let isReply = comment.text.hasPrefix("@")
                    let isCompetitiveComment = !isReply || competitivePhrases.contains { textLower.contains($0) }
                    
                    var val: String? = nil
                    if isCompetitiveComment {
                        val = MockSocialService.extractValue(from: comment.text, topic: topic)
                        if val == nil && isCatchUpReply {
                            if let prevIdx = chain.firstIndex(where: { $0.id == comment.id }),
                               prevIdx > 0 {
                                let competitor = chain[prevIdx - 1].authorName
                                if let compVal = playerRecords[competitor] {
                                    val = MockSocialService.oneUpValue(for: compVal, topic: topic)
                                }
                            }
                        }
                    }
                    
                    if let val = val {
                        if let establishedVal = playerRecords[author] {
                            let isBetter = MockSocialService.isRecord(establishedVal, worseThan: val, topic: topic)
                            
                            var isAheadOfCompetitor = false
                            if let prevIdx = chain.firstIndex(where: { $0.id == comment.id }),
                               prevIdx > 0 {
                                let competitor = chain[prevIdx - 1].authorName
                                if let compVal = playerRecords[competitor] {
                                    isAheadOfCompetitor = MockSocialService.isRecord(compVal, worseThan: val, topic: topic)
                                }
                            }
                            
                            let isWorse = MockSocialService.isRecord(val, worseThan: establishedVal, topic: topic)
                            #expect(!isWorse, "Player \(author) claimed value \(val) which is worse than their established record of \(establishedVal) (topic: \(topic), comment: \(comment.text))")
                            if isBetter {
                                playerRecords[author] = val
                            }
                        } else {
                            playerRecords[author] = val
                        }
                    }
                }
            }
        }
        MockSocialService.inMemoryUserPostsOverride = nil
    }

    @Test("Verify that too-low reply is correctly generated when a comment has multiple milestones (e.g. 17ad and 4ad) and target is 17ad")
    func testTooLowReplyWithMultipleMilestonesInComment() {
        let service = MockSocialService()
        
        let commentText = "@Larissa Martins Of course you can't get to 17ad. That's child's play compared to my 4ad XDDDDDDD."
        
        let reply = service.generateContextualReply(to: commentText, message: "Unlocked milestone 17ad.", forceTone: "one_up", speakerValue: "17ad")
        
        #expect(isTooLowMilestoneReply(reply), "Reply should address the lower milestone brag: \(reply)")
    }

    @Test("Verify that 'don't get too comfortable' does not trigger target out-of-reach false positive")
    func testGetTooComfortableDoesNotTriggerOutOfReach() {
        let service = MockSocialService()
        
        let commentText = "@Sofia Nelson I might be lower right now. Don't get too comfortable up there. I will overtake you soon. !!"
        
        let reply = service.generateContextualReply(to: commentText, message: "Unlocked milestone 17ad.", forceTone: "behind", speakerValue: "4ad")
        
        // Since isTargetOutOfReach is false, it shouldn't generate the "If you can't even get to..." out-of-reach reply.
        // It should generate a behind reply instead.
        #expect(!reply.contains("can't even get to"), "Reply should not contain out-of-reach response: \(reply)")
        #expect(!reply.contains("out of reach for you"), "Reply should not contain out-of-reach response: \(reply)")
    }

    @Test("Same milestone replies use rivalry/tie phrasing")
    func sameMilestoneRepliesUseRivalryPhrasing() {
        let service = MockSocialService()
        let commentText = "My 383n is better, you cute."
        let reply = service.generateContextualReply(
            to: commentText,
            message: "Unlocked milestone 383n.",
            forceTone: "one_up",
            speakerValue: "383n"
        )
        
        let isTieReply = reply.contains("tied") || reply.contains("both at 383n") || reply.contains("right there at 383n") || reply.contains("also hit 383n") || reply.contains("sitting at 383n too") || reply.contains("Cute, but irrelevant.")
        #expect(isTieReply, "Expected same-milestone reply to use rivalry/tie phrasing: \(reply)")
    }

    @Test("Same value replies for other topics use rivalry/tie phrasing")
    func sameValueRepliesForOtherTopicsUseRivalryPhrasing() {
        let service = MockSocialService()
        
        // 1. Streaks
        let streakReply = service.generateContextualReply(
            to: "My 10 day streak is better, you cute.",
            message: "Unlocked milestone 10 days.",
            forceTone: "one_up",
            speakerValue: "10"
        )
        let isStreakTie = streakReply.contains("tied") || streakReply.contains("both at 10") || streakReply.contains("right there at 10") || streakReply.contains("also hit 10") || streakReply.contains("sitting at 10") || streakReply.contains("Cute, but irrelevant.") || streakReply.contains("race starts now") || streakReply.contains("breaks it first") || streakReply.contains("without sweating") || streakReply.contains("pulling ahead")
        #expect(isStreakTie, "Expected same-streak reply to use rivalry/tie phrasing: \(streakReply)")
        
        // 2. Time
        let timeReply = service.generateContextualReply(
            to: "I clocked 0:15.",
            message: "timed challenge in 0:15",
            forceTone: "one_up",
            speakerValue: "0:15"
        )
        let isTimeTie = timeReply.contains("tied") || timeReply.contains("both at 0:15") || timeReply.contains("right there at 0:15") || timeReply.contains("also clocked 0:15") || timeReply.contains("Cute, but irrelevant.") || timeReply.contains("race starts now") || timeReply.contains("breaks it first") || timeReply.contains("sitting at 0:15")
        #expect(isTimeTie, "Expected same-time reply to use rivalry/tie phrasing: \(timeReply)")
        
        // 3. HOF
        let hofReply = service.generateContextualReply(
            to: "My 15 infinities is better, you cute.",
            message: "15 infinities count",
            forceTone: "one_up",
            speakerValue: "15"
        )
        let isHofTie = hofReply.contains("tied") || hofReply.contains("both at 15") || hofReply.contains("right there at 15") || hofReply.contains("also reached 15") || hofReply.contains("sitting at 15") || hofReply.contains("Cute, but irrelevant.") || hofReply.contains("race starts now") || hofReply.contains("breaks it first") || hofReply.contains("entries too")
        #expect(isHofTie, "Expected same-HOF reply to use rivalry/tie phrasing: \(hofReply)")
    }

    @Test("Catch-up phrasing is used when speaker is behind")
    func catchUpPhrasingUsedWhenBehind() {
        let service = MockSocialService()
        
        // Behind on milestone
        let milestoneReply = service.generateContextualReply(
            to: "My 383n is better, you cute.",
            message: "Unlocked milestone 383n.",
            forceTone: "behind",
            speakerValue: "32K"
        )
        let isMilestoneBehind = milestoneReply.contains("lower right now") || milestoneReply.contains("ahead for now") || milestoneReply.contains("lead while it lasts") || milestoneReply.contains("catch") || milestoneReply.contains("closing the gap") || milestoneReply.contains("overtake") || milestoneReply.contains("coming for") || milestoneReply.contains("is next") || milestoneReply.contains("temporary")
        #expect(isMilestoneBehind, "Expected behind milestone reply to use catch-up phrasing: \(milestoneReply)")
        
        // Behind on streak
        let streakReply = service.generateContextualReply(
            to: "My 50 day streak is better, you cute.",
            message: "Unlocked milestone 50 days.",
            forceTone: "behind",
            speakerValue: "10"
        )
        let isStreakBehind = streakReply.contains("lose") || streakReply.contains("slip up") || streakReply.contains("break") || streakReply.contains("pass your")
        #expect(isStreakBehind, "Expected behind streak reply to use catch-up phrasing: \(streakReply)")
    }

    @Test("Caught-up replies say they beat the milestone and got ahead")
    func caughtUpRepliesUseBeatPhrasing() {
        let service = MockSocialService()
        
        // 1. Milestone
        let milestoneReply = service.generateContextualReply(
            to: "My 383n is better, you cute.",
            message: "Unlocked milestone 383n.",
            forceTone: "caught_up",
            speakerValue: "4ad"
        )
        let isMilestoneGenericTie = milestoneReply.contains("We are tied now") || milestoneReply.contains("We're tied") || milestoneReply.contains("Finally tied") || milestoneReply.contains("would catch you")
        #expect(milestoneReply.contains("383n") || isMilestoneGenericTie, "Expected caught-up reply to mention commenter record: \(milestoneReply)")
        let isMilestoneBeat = milestoneReply.lowercased().contains("caught up") || milestoneReply.contains("catch up") || milestoneReply.contains("catch you") || milestoneReply.contains("ahead now") || milestoneReply.contains("passed you") || milestoneReply.contains("overtake") || milestoneReply.contains("watch your back") || milestoneReply.contains("beat your")
        #expect(isMilestoneBeat, "Expected milestone caught-up reply to use beat/ahead phrasing: \(milestoneReply)")
        
        // 2. Streak
        let streakReply = service.generateContextualReply(
            to: "My 50 day streak is better, you cute.",
            message: "Unlocked milestone 50 days.",
            forceTone: "caught_up",
            speakerValue: "60"
        )
        let isStreakGenericTie = streakReply.contains("We are tied now") || streakReply.contains("We're tied") || streakReply.contains("Finally tied") || streakReply.contains("would catch you")
        #expect(streakReply.contains("50") || isStreakGenericTie, "Expected caught-up reply to mention commenter record: \(streakReply)")
        let isStreakBeat = streakReply.lowercased().contains("caught up") || streakReply.contains("catch up") || streakReply.contains("catch you") || streakReply.contains("ahead now") || streakReply.contains("passed you") || streakReply.contains("overtake") || streakReply.contains("watch your back") || streakReply.contains("beat your")
        #expect(isStreakBeat, "Expected streak caught-up reply to use beat/ahead phrasing: \(streakReply)")
    }

    @Test("HomeState npcRepliesBadgeCount counts replies from NPCs correctly")
    @MainActor
    func testNpcRepliesBadgeCount() async throws {
        let defaults = UserDefaults.standard
        MockSocialService.clearFileStorageForTests()
        defaults.removeObject(forKey: "profilePlayerName")
        defaults.removeObject(forKey: "player.displayName")
        
        let homeState = HomeState()
        #expect(homeState.npcRepliesBadgeCount == 0)
        
        // Let's mock a user post in socialFeed.userPosts.v3
        let post1 = SocialFeedItem(
            id: UUID(),
            authorName: "Player",
            message: "Just hit 2048!",
            statText: "New tile",
            comments: [
                SocialFeedComment(authorName: "NPC1", text: "Nice work!", createdAt: Date().addingTimeInterval(-60)),
                SocialFeedComment(authorName: "Player", text: "Thanks!", createdAt: Date()),
                // Future comment - should not be counted yet
                SocialFeedComment(authorName: "NPC2", text: "Amazing!", createdAt: Date().addingTimeInterval(3600))
            ]
        )
        
        // Mock an NPC post that the user commented on and got a reply
        let post2 = SocialFeedItem(
            id: UUID(),
            authorName: "NPC3",
            message: "I hit 1024!",
            statText: "New tile",
            comments: [
                SocialFeedComment(authorName: "Player", text: "Nice!", createdAt: Date().addingTimeInterval(-120)),
                SocialFeedComment(authorName: "NPC3", text: "@Player thanks buddy!", createdAt: Date().addingTimeInterval(-60)),
                SocialFeedComment(authorName: "NPC4", text: "Cool", createdAt: Date().addingTimeInterval(-30)) // Does not mention Player, should not count as reply to Player
            ]
        )
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode([post1, post2])
            defaults.set(data, forKey: MockSocialService.userPostsKey)
            print("Successfully encoded mock user posts: \(String(data: data, encoding: .utf8) ?? "")")
        } catch {
            print("Failed to encode mock user posts: \(error)")
        }
        
        homeState.updateNpcRepliesBadgeCount()
        print("After update: \(homeState.npcRepliesBadgeCount)")
        
        // Total should be:
        // From post1 (Player's post):
        // - NPC1 comment (Nice work!): 1 (NPC comment, <= now)
        // - Player comment (Thanks!): 0 (Player comment)
        // - NPC2 comment (Amazing!): 0 (Future comment)
        // From post2 (NPC3's post):
        // - Player comment: 0 (Player comment)
        // - NPC3 comment (@Player thanks buddy!): 1 (NPC comment, mentions @Player, <= now)
        // - NPC4 comment (Cool): 0 (NPC comment, does not mention Player)
        // Total = 1 + 1 = 2
        #expect(homeState.npcRepliesBadgeCount == 2)

        // Verify setting lastViewedDate filters out older comments and resets badge count to 0
        defaults.set(Date(), forKey: "socialFeed.lastViewedDate")
        homeState.updateNpcRepliesBadgeCount()
        #expect(homeState.npcRepliesBadgeCount == 0)
        
        // Clean up
        defaults.removeObject(forKey: MockSocialService.userPostsKey)
        defaults.removeObject(forKey: "socialFeed.lastViewedDate")
    }

    @Test("Verify post weighting at HOF (76% HOF, 15% Time, 9% Streak, 0% Milestone)")
    func testHOFPostWeighting() async throws {
        let defaults = UserDefaults.standard
        MockSocialService.clearFileStorageForTests()
        defaults.removeObject(forKey: MockSocialService.feedDateKey)
        
        MockSocialService.isPlayerAtHOFOverride = true
        MockSocialService.bypassFeedCache = true
        MockSocialService.inMemoryUserPostsOverride = []
        
        let service = MockSocialService()
        let feed = try await service.feed()
        #expect(!feed.isEmpty)
        
        var hofCount = 0
        var streakCount = 0
        var timeCount = 0
        var milestoneCount = 0
        
        let userDisplayName = defaults.string(forKey: "player.displayName") ?? "Player"
        let userProfileName = defaults.string(forKey: "profilePlayerName") ?? "Player"
        
        for item in feed {
            if item.authorName == "Player" || item.authorName == userDisplayName || item.authorName == userProfileName {
                continue
            }
            let msg = item.message.lowercased()
            let stat = item.statText.lowercased()
            
            let isHof = msg.contains("hall of fame") || msg.contains("hof") || msg.contains("infinity") || msg.contains("infinities") || msg.contains("∞") || msg.contains("legend") || stat.contains("hall of fame") || stat.contains("infinity") || stat.contains("legend")
            let isStreak = msg.contains("streak") || msg.contains("days") || msg.contains("consecutive") || stat.contains("streak")
            let isTime = msg.contains("timed") || msg.contains("speed") || msg.contains("clock") || msg.contains(":") || stat.contains("timed") || stat.contains("speed") || stat.contains("challenge") || stat.contains("clock")
            
            if isHof {
                hofCount += 1
            } else if isStreak {
                streakCount += 1
            } else if isTime {
                timeCount += 1
            } else {
                milestoneCount += 1
            }
        }
        
        // With 25 posts, we should expect 0 milestone posts.
        #expect(milestoneCount == 0, "Expected 0 milestone posts at HOF, but got \(milestoneCount)")
        // Since HOF is 76%, at least some HOF posts should exist.
        #expect(hofCount > 0, "Expected HOF posts to be generated")
        
        // Clean up
        MockSocialService.isPlayerAtHOFOverride = nil
        MockSocialService.bypassFeedCache = false
        MockSocialService.inMemoryUserPostsOverride = nil
        MockSocialService.clearFileStorageForTests()
        defaults.removeObject(forKey: MockSocialService.feedDateKey)
    }

    @Test("Verify user replies to comments with name spaces are parsed correctly and do not lower milestones")
    func testAddCommentMentionWithSpaces() async throws {
        let defaults = UserDefaults.standard
        MockSocialService.clearFileStorageForTests()
        defaults.removeObject(forKey: MockSocialService.feedDateKey)
        
        let service = MockSocialService()
        let feed = try await service.feed()
        #expect(!feed.isEmpty)
        
        // Find a competitive milestone post to test on
        guard let itemIndex = feed.firstIndex(where: {
            $0.message.lowercased().contains("tile") && !$0.comments.isEmpty && MockSocialService.determineTopic(message: $0.message) == "milestone"
        }) else {
            return
        }
        
        var item = feed[itemIndex]
        let originalCommentCount = item.comments.count
        
        // Let's force NPC 1 comment author to be "Alessandro Romano" for testing
        item.comments[0].authorName = "Alessandro Romano"
        item.comments[0].text = "@Player I left 21al in the dust. 676al is the new standard."
        
        // Setup in-memory override to isolate this test from concurrent disk writes/clears
        var mockFeed = feed
        mockFeed[itemIndex] = item
        MockSocialService.inMemoryFeedOverride = mockFeed
        
        // Save back
        try await service.addComment(to: item.id, text: "@Alessandro Romano I was just toying with you. I'm actually at 21am.")
        
        // Reload feed and check from raw cache (to bypass future comment filter)
        guard let updatedFeed = MockSocialService.loadFeedCache(),
              let updatedItem = updatedFeed.first(where: { $0.id == item.id }) else {
            #expect(Bool(false), "Could not load feed cache")
            MockSocialService.inMemoryFeedOverride = nil
            return
        }
        
        // We added:
        // 1. User comment: "@Alessandro Romano I was just toying..."
        // 2. Simulated NPC response (and potentially a second response in a row if user beats NPC)
        #expect(updatedItem.comments.count >= originalCommentCount + 2)
        
        guard let playerComment = updatedItem.comments.first(where: {
            $0.text.contains("Alessandro Romano") && ($0.authorName == "Player" || $0.authorName == defaults.string(forKey: "profilePlayerName"))
        }) else {
            #expect(Bool(false), "Could not find player comment in updated comments")
            MockSocialService.inMemoryFeedOverride = nil
            return
        }
        
        guard let npcResponse = updatedItem.comments.first(where: {
            $0.authorName == "Alessandro Romano" && $0.createdAt > playerComment.createdAt
        }) else {
            #expect(Bool(false), "Could not find Alessandro Romano's reply in updated comments")
            MockSocialService.inMemoryFeedOverride = nil
            return
        }
        
        #expect(npcResponse.authorName == "Alessandro Romano", "Expected NPC response author name to match the target comment author name")
        #expect(npcResponse.text.contains("676al"), "Expected NPC response to keep the milestone 676al, but got: \(npcResponse.text)")
        #expect(!npcResponse.text.contains("322aj"), "Expected NPC response to NOT lower milestone to 322aj")
        
        // Clean up
        MockSocialService.inMemoryFeedOverride = nil
        MockSocialService.clearFileStorageForTests()
    }

    @Test("Verify low streak replies do not contain the illogical 'will be higher than' templates")
    func testLowStreakGuard() async throws {
        let service = MockSocialService()
        
        let commentText = "@GilbertGladiator You're bound to lose your 43 day streak."
        let message = "Kept the streak alive at 35 days."
        
        let reply = service.generateContextualReply(
            to: commentText,
            message: message,
            forceTone: "behind",
            speakerValue: "0",
            opponentValue: "43"
        )
        
        #expect(!reply.contains("will be higher than"), "Expected reply to NOT contain illogical 'will be higher than' when speaker has 0 days, got: \(reply)")
        #expect(!reply.contains("0 days will be higher"), "Expected reply to NOT contain '0 days will be higher, got: \(reply)")
        
        let reply2 = service.generateContextualReply(
            to: commentText,
            message: message,
            forceTone: "behind",
            speakerValue: "2",
            opponentValue: "43"
        )
        #expect(!reply2.contains("will be higher than"), "Expected reply to NOT contain illogical 'will be higher than' when speaker has 2 days, got: \(reply2)")
    }

    @Test("Verify that when both have low streaks and speaker is higher, we can get 'lose your streak as well' responses")
    func testOpponentLosesStreakReply() async throws {
        let service = MockSocialService()
        
        let commentText = "@GilbertGladiator Dropped my streak today, down to 0 days."
        let message = "Kept the streak alive at 35 days."
        
        let expectedSubstrings = [
            "Now my 5 days is higher",
            "Now my streak is higher than yours",
            "Now my 5 days is higher than your 0",
            "Now my 5 days dominates yours",
            "But my 5 days is already higher",
            "Now my 5 days is higher anyway",
            "Now my 5 day streak is higher than yours",
            "Now my 5 days is higher than your pathetic 0 days",
            "Now my 5 days sits higher than yours",
            "Now my 5 days completely buries your 0 days"
        ]
        
        var matched = false
        for _ in 0..<50 {
            let reply = service.generateContextualReply(
                to: commentText,
                message: message,
                forceTone: "one_up",
                speakerValue: "5",
                opponentValue: "0"
            )
            if expectedSubstrings.contains(where: { reply.contains($0) }) {
                matched = true
                break
            }
        }
        
        #expect(matched, "Expected reply to eventually select one of the new prediction brag variants")
    }

    @Test("Verify that streak-loss events are generated and generate appropriate comments")
    func testStreakLossEvents() async throws {
        let service = MockSocialService()
        
        let commentText = "Dropped my streak today, down to 0 days."
        let message = "Kept the streak alive at 35 days."
        
        let reply = service.generateContextualReply(
            to: commentText,
            message: message,
            forceTone: "one_up",
            speakerValue: "15",
            opponentValue: "0"
        )
        
        let expectedSubstrings = [
            "15",
            "lose your streak",
            "streak would die",
            "streak died",
            "streak is dead",
            "consistency would break"
        ]
        let matched = expectedSubstrings.contains { reply.lowercased().contains($0.lowercased()) }
        #expect(matched, "Expected reply to be a streak-loss comment mock, but got: \(reply)")
    }

    @Test("Verify that a user who lost their streak does not brag about their lost streak value in subsequent replies")
    func testLostStreakValueDoesNotLinger() async throws {
        let service = MockSocialService()
        
        let rootPost = "Nooo! I forgot to play yesterday and lost my 207-day streak."
        
        // GilbertGladiator says: "Now my 36 days is higher than your 0!"
        // Then ReputationRuler236919 replies. GilbertGladiator is the opponent with 36 days, 
        // and ReputationRuler236919 (the speaker) has 0 days.
        let reply = service.generateContextualReply(
            to: "Now my 36 days is higher than your 0!",
            message: rootPost,
            forceTone: "behind",
            speakerValue: "0",
            opponentValue: "36"
        )
        
        // Assert that the reply does NOT contain "207" because the speaker has 0 days now!
        #expect(!reply.contains("207"), "Expected reply not to claim they still have 207 days, but got: \(reply)")
        // Since they have 0 days and the tone is behind, they should say they will catch up or reset
        let expectedKeywords = ["catch", "lost", "0"]
        let matched = expectedKeywords.contains { reply.lowercased().contains($0) }
        #expect(matched, "Expected reply to indicate a catch up state, but got: \(reply)")
    }

    @Test("Verify that predicted streak loss helper matches templates correctly")
    func testPredictedStreakLossPatternMatching() throws {
        let positiveCases = [
            "Just wait until you lose your 10 day streak.",
            "You'll lose it and my 5 days will pass you.",
            "You're bound to lose your 30 day streak.",
            "but you'll break your 5 day streak before I break mine.",
            "Just wait until you lose your streak.",
            "Dropped to 2 days because I lost my streak. You're bound to lose yours too."
        ]
        
        let negativeCases = [
            "I'm right there at 10 days too. Let's see who breaks it first.",
            "We're tied at 10 days. The real race starts now.",
            "I hit 5 days without sweating. I'm pulling ahead soon.",
            "I've been consistent longer. I'm comfortably sitting at 8 days."
        ]
        
        for text in positiveCases {
            #expect(MockSocialService.commentPredictsStreakLoss(text), "Expected match for: \(text)")
        }
        for text in negativeCases {
            #expect(!MockSocialService.commentPredictsStreakLoss(text), "Expected no match for: \(text)")
        }
    }

    @Test("Verify that when player beats an NPC and the NPC responds with behind, a second reply in a row is added")
    func testSecondReplyInARowWhenNPCBehind() async throws {
        MockSocialService.bypassFeedCache = false
        MockSocialService.inMemoryFeedOverride = []
        defer {
            MockSocialService.bypassFeedCache = false
            MockSocialService.inMemoryFeedOverride = nil
        }
        
        let service = MockSocialService()
        
        // Setup item to have a milestone topic and a base comment
        var item = SocialFeedItem(
            authorName: "Andrew Lee",
            avatarID: "avatar-1",
            createdAt: Date().addingTimeInterval(-3600),
            message: "Just reached milestone 173am!",
            statText: "milestone",
            reactionCount: 0,
            isHearted: false,
            commentCount: 1,
            comments: [],
            reactionTimestamps: nil
        )
        let baseComment = SocialFeedComment(
            authorName: "EnigmaEra765829",
            avatarID: "avatar-1",
            text: "@Player 43am is your ceiling? Try aiming lower. I'm at 173am.",
            createdAt: Date().addingTimeInterval(-600),
            likes: 0
        )
        item.comments = [baseComment]
        
        // Add comment by Player with a much higher milestone
        // Loop up to 15 times to ensure we get a "behind" reply at least once
        var secondReplyFound = false
        for _ in 1...15 {
            let mutableItem = item
            MockSocialService.inMemoryFeedOverride = [mutableItem]
            
            try await service.addComment(
                to: item.id,
                text: "@EnigmaEra765829 Lagging at 173am? I'm coasting at 346am."
            )
            
            guard let updatedItem = MockSocialService.inMemoryFeedOverride?.first else {
                continue
            }
            
            // Check if a second reply was posted in a row by EnigmaEra765829
            if updatedItem.comments.count >= 4 {
                let firstReply = updatedItem.comments[2]
                let secondReply = updatedItem.comments[3]
                if firstReply.authorName == "EnigmaEra765829" && secondReply.authorName == "EnigmaEra765829" {
                    secondReplyFound = true
                    // Assert second reply has the updated milestone
                    let text = secondReply.text
                    let hasValue = text.contains("346am") || text.contains("692am") || text.contains("346") || text.contains("692")
                    #expect(hasValue, "Expected second reply to contain milestone 346am or 692am, but got: \(secondReply.text)")
                    break
                }
            }
        }
        
        #expect(secondReplyFound, "Expected to generate a behind reply followed by a second caught up/one up reply in a row")
    }

    @Test
    func testGetOneUpBragExcludesDuplicates() {
        let first = MockSocialService.getOneUpBrag(metric: "milestone", lower: "2M", higher: "4M")
        
        // Repeatedly request and expect different candidate
        for _ in 0..<20 {
            let second = MockSocialService.getOneUpBrag(metric: "milestone", lower: "2M", higher: "4M", excluding: first)
            #expect(first != second, "Expected getOneUpBrag to exclude first choice: \(first)")
        }
    }
    
    @Test("Verify getOneUpBrag returns a tied response when called with equal values")
    func testGetOneUpBragEqualValuesGuardsAgainstSameValueBrag() {
        let metrics = ["milestone", "time", "streak", "hof"]
        for metric in metrics {
            for _ in 0..<50 {
                let brag = MockSocialService.getOneUpBrag(metric: metric, lower: "883t", higher: "883t")
                // Brags should not contain "beat your" or "beat" or "bypassed" or "clear" or "irrelev" or "joke" alongside 883t in a one-up format
                let lowerBrag = brag.lowercased()
                let hasOneUpKeywords = lowerBrag.contains("beat your") || lowerBrag.contains("easily beat") || lowerBrag.contains("bypassed") || lowerBrag.contains("real record is") || lowerBrag.contains("untouchable") || lowerBrag.contains("ceiling") || lowerBrag.contains("in the dust") || lowerBrag.contains("out of reach")
                #expect(!hasOneUpKeywords, "Expected brag for equal values to not contain one-up keywords: \(brag)")
            }
        }
    }

    @Test("Debug speedrun thread reply")
    func testDebugSpeedrunThread() {
        let service = MockSocialService()
        let commentText = "@GilbertGladiator Your 0:29 was my practice run. I'm down to 0:22 XDDD."
        let message = "timed challenge in 0:22"
        let forceTone = "behind"
        let speakerValue = "0:29"
        let opponentValue = "0:22"
        let previousSelfComment = "@SeaSerpent580469 I cleared 0:29. Your lead is temporary at 0:22."

        let reply = service.generateContextualReply(
            to: commentText,
            message: message,
            forceTone: forceTone,
            speakerValue: speakerValue,
            opponentValue: opponentValue,
            previousSelfComment: previousSelfComment
        )
        print("DEBUG REPLY GENERATED: \(reply)")
        #expect(reply.contains("won't stay ahead") || reply.contains("won't last") || reply.contains("temporary") || reply.contains("closing the gap") || reply.contains("shoulder") || reply.contains("warming up") || reply.contains("safe up there") || reply.contains("view from the top"))
    }

    @Test("Debug simulated thread")
    func testDebugSimulatedThread() {
        let service = MockSocialService()
        let now = Date()
        let message = "Just finished timed challenge in 0:22"
        let topic = "time"
        
        let baseCommentText = "@SeaSerpent580469 I cleared 0:29. Your lead is temporary at 0:22."
        let baseComment = SocialFeedComment(
            authorName: "GilbertGladiator",
            avatarID: "avatar_buddy_bot",
            text: baseCommentText,
            createdAt: now
        )
        
        var lastComment = baseComment
        let npc1 = (name: baseComment.authorName, avatar: baseComment.avatarID)
        var npc2 = (name: "SeaSerpent580469", avatar: "avatar_alien")
        
        let rootValue = "0:22"
        var npc1Value = "0:29"
        var npc2Value: String? = nil
        
        var isNpc2Turn = true
        var npc1PreviousComment: String? = baseComment.text
        var npc2PreviousComment: String? = nil
        
        var comments: [SocialFeedComment] = [baseComment]
        
        for depth in 0..<4 {
            if isNpc2Turn {
                npc2Value = "0:22"
                let isBehind = false
                let isEqual = false
                let toneStr = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                let replyText = "@\(lastComment.authorName) " + service.generateContextualReply(
                    to: lastComment.text,
                    message: message,
                    forceTone: toneStr,
                    speakerValue: npc2Value,
                    opponentValue: npc1Value,
                    previousSelfComment: npc2PreviousComment
                )
                print("DEPTH \(depth) (npc2 turn): replyText = \(replyText)")
                npc2PreviousComment = replyText
                let replyComment = SocialFeedComment(authorName: npc2.name, avatarID: npc2.avatar, text: replyText, createdAt: now)
                comments.append(replyComment)
                lastComment = replyComment
            } else {
                let isBehind = true
                let isEqual = false
                let toneStr = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                let replyText = "@\(lastComment.authorName) " + service.generateContextualReply(
                    to: lastComment.text,
                    message: message,
                    forceTone: toneStr,
                    speakerValue: npc1Value,
                    opponentValue: npc2Value,
                    previousSelfComment: npc1PreviousComment
                )
                print("DEPTH \(depth) (npc1 turn): replyText = \(replyText)")
                npc1PreviousComment = replyText
                let replyComment = SocialFeedComment(authorName: npc1.name, avatarID: npc1.avatar, text: replyText, createdAt: now)
                comments.append(replyComment)
                lastComment = replyComment
            }
            isNpc2Turn.toggle()
        }
    }

    @Test("Verify that an NPC with an established streak does not have their streak lowered in subsequent standard replies")
    func testNPCEstablishedStreakValueNotLowered() async throws {
        let service = MockSocialService()
        
        let message = "Saved a 125-day streak."
        let baseComment = SocialFeedComment(authorName: "BayBoss", text: "Enjoy the lead while it lasts. Just give me a little more time.")
        
        // 1. NPC Evelyn Scott established their streak as 127 in Comment 2
        let comments = [
            baseComment,
            SocialFeedComment(authorName: "Evelyn Scott", text: "@BayBoss My infinite consistency is at 127 days. 125 is a joke XDDDDD.")
        ]
        
        // 2. Scan comments for Evelyn Scott's established value
        let topic = MockSocialService.determineTopic(message: message)
        let speakerVal = MockSocialService.findEstablishedValue(for: "Evelyn Scott", in: comments, topic: topic)
        #expect(speakerVal == "127")
        
        // 3. Generate standard reply by Evelyn Scott to another comment (e.g. text with no numbers / 125)
        let replyToText = "Enjoy the lead while it lasts. My next run is going to crush that."
        let replyText = service.generateContextualReply(to: replyToText, message: message, forceTone: "competitive", speakerValue: speakerVal)
        
        // 4. Verify that the generated reply does not lower the value
        let extractedVal = MockSocialService.extractValue(from: replyText, topic: topic)
        if let val = extractedVal, let intVal = Int(val) {
            #expect(intVal >= 127, "Established streak of 127 should not be lowered to \(intVal) in reply: \(replyText)")
        }
    }

    @Test("Verify post weighting at HOF comments (29% compared to, 57% dominate, 14% safely ahead)")
    func testHOFCommentWeights() async throws {
        let service = MockSocialService()
        
        var countNothingCompared = 0
        var countDominate = 0
        var countSafelyAhead = 0
        
        let iterations = 2000
        for _ in 0..<iterations {
            var usedStats: Set<String> = []
            let result = service.generateDynamicComment(message: "10 infinities count", usedStats: &usedStats, forcedTone: "competitive")
            let text = result.commentText.lowercased()
            
            if text.contains("nothing compared") {
                countNothingCompared += 1
            } else if text.contains("dominate") {
                countDominate += 1
            } else if text.contains("safely ahead") {
                countSafelyAhead += 1
            }
        }
        
        let total = Double(countNothingCompared + countDominate + countSafelyAhead)
        #expect(total > 0)
        
        let pctNothingCompared = Double(countNothingCompared) / total * 100.0
        let pctDominate = Double(countDominate) / total * 100.0
        let pctSafelyAhead = Double(countSafelyAhead) / total * 100.0
        
        print("HOF COMMENT WEIGHTS: nothing compared = \(pctNothingCompared)%, dominate = \(pctDominate)%, safely ahead = \(pctSafelyAhead)%")
        
        // Assert within a reasonable margin of error (e.g. +/- 5.5%)
        #expect(abs(pctNothingCompared - 29.0) <= 5.5, "Expected ~29% nothing compared, got \(pctNothingCompared)%")
        #expect(abs(pctDominate - 57.0) <= 5.5, "Expected ~57% dominate, got \(pctDominate)%")
        #expect(abs(pctSafelyAhead - 14.0) <= 5.5, "Expected ~14% safely ahead, got \(pctSafelyAhead)%")
    }

    @Test("Verify bucket weights in getOneUpBrag (Bucket 1: 21%, Bucket 2: 1%, Bucket 3: 39%, Bucket 4: 39%)")
    func testOneUpBucketWeights() async throws {
        var bucket1Count = 0
        var bucket2Count = 0
        var bucket3Count = 0
        var bucket4Count = 0
        
        let bucket1Templates: Set<String> = [
            "You think 1024 is a big milestone? I'm already coasting at 2048.",
            "Your 1024 is a joke. You'll never catch my 2048.",
            "I easily bypassed 1024 and hit 2048.",
            "I'm laughing from 2048 while you're still at 1024.",
            "Celebrating 1024? I easily cleared 2048.",
            "You're at 1024? Cute. 1024 is completely irrelevant now that I'm at 2048.",
            "Imagine being proud of 1024. My 2048 was completed with ease.",
            "Still at 1024? I already left that behind. 2048 is where the real game is.",
            "Lagging at 1024? I'm coasting at 2048.",
            "Imagine being at 1024 while I dominate at 2048."
        ]
        
        let bucket2Templates: Set<String> = [
            "If you can't even get past 1024, you'll never catch my 2048.",
            "1024 is your ceiling? Try aiming lower. I'm at 2048.",
            "You'll never get past 1024 anyway, let alone my 2048.",
            "If getting past 1024 is impossible for you, my 2048 is untouchable.",
            "Of course you're lagging at 1024. That's child's play compared to my 2048.",
            "You're lagging at 1024? Figures. My record is 2048.",
            "You're completely stuck at 1024. I'm sitting comfortably at 2048.",
            "You're stuck at 1024. My 2048 is light years away from your skill level.",
            "If 1024 is your ceiling, you're not even in the same conversation as my 2048.",
            "Why even mention 1024? My 2048 is completely out of your reach.",
            "You're embarrassing yourself with 1024. You were never going to threaten my 2048 anyway.",
            "You're not built for 1024. Meanwhile, my 2048 was completed with ease."
        ]
        
        let bucket3Templates: Set<String> = [
            "I easily passed your 1024. I'm at 2048.",
            "You thought you had the lead? Your 1024 is nothing. I'm at 2048.",
            "You fell for it. I easily beat your 1024. My real record is 2048.",
            "I was just warming up. Your 1024 is a joke compared to my 2048.",
            "I blew past your 1024 and hit 2048 without even trying.",
            "Your 1024 is a joke compared to my 2048.",
            "I cleared 2048 without trying.",
            "I was just toying with you. I'm actually at 2048."
        ]
        
        let bucket4Templates: Set<String> = [
            "I am ahead of your 1024. I'm at 2048.",
            "I'm way past 1024. I am sitting at 2048.",
            "Your 1024 is nothing compared to my 2048.",
            "I easily passed 1024. I dominate 2048.",
            "Your 1024 is child's play compared to my 2048.",
            "1024 is a joke. I'm already sitting at 2048.",
            "You're celebrating 1024? I already cleared 2048.",
            "I left 1024 in the dust. 2048 is the new standard.",
            "You're bragging about 1024 while my 2048 remains completely out of your reach.",
            "I already hit 2048. 1024 is old news."
        ]
        
        let iterations = 10000
        for _ in 0..<iterations {
            let reply = MockSocialService.getOneUpBrag(metric: "milestone", lower: "1024", higher: "2048")
            
            if reply == "Only at 1024? I easily reached 2048." {
                if Double.random(in: 0..<60.0) < 21.0 {
                    bucket1Count += 1
                } else {
                    bucket3Count += 1
                }
            } else if bucket1Templates.contains(reply) {
                bucket1Count += 1
            } else if bucket2Templates.contains(reply) {
                bucket2Count += 1
            } else if bucket3Templates.contains(reply) {
                bucket3Count += 1
            } else if bucket4Templates.contains(reply) {
                bucket4Count += 1
            } else {
                fatalError("Unknown template returned: \(reply)")
            }
        }
        
        let total = Double(bucket1Count + bucket2Count + bucket3Count + bucket4Count)
        #expect(total == Double(iterations))
        
        let pct1 = Double(bucket1Count) / total * 100.0
        let pct2 = Double(bucket2Count) / total * 100.0
        let pct3 = Double(bucket3Count) / total * 100.0
        let pct4 = Double(bucket4Count) / total * 100.0
        
        print("ONE-UP BUCKET WEIGHTS: Bucket 1 = \(pct1)%, Bucket 2 = \(pct2)%, Bucket 3 = \(pct3)%, Bucket 4 = \(pct4)%")
        
        // Assert within a reasonable margin of error (e.g. +/- 4%)
        #expect(abs(pct1 - 21.0) <= 4.0, "Expected ~21% for Bucket 1, got \(pct1)%")
        #expect(abs(pct2 - 1.0) <= 1.5, "Expected ~1% for Bucket 2, got \(pct2)%")
        #expect(abs(pct3 - 39.0) <= 4.0, "Expected ~39% for Bucket 3, got \(pct3)%")
        #expect(abs(pct4 - 39.0) <= 4.0, "Expected ~39% for Bucket 4, got \(pct4)%")
    }

    @Test("Verify requiredTimeDelay returns scaled time offsets based on gap size")
    func testRequiredTimeDelay() {
        // Milestone diff: 524K to 134M (exponent 19 to exponent 27, which is a diff of 8 milestones)
        let delayMilestones = MockSocialService.requiredTimeDelay(from: "524K", to: "134M", topic: "milestone")
        // Expected: 8 * (60...120) -> between 480.0 and 960.0 seconds
        #expect(delayMilestones >= 480.0 && delayMilestones <= 960.0)

        // HOF diff: 343 to 350 (diff of 7 infinities)
        let delayHOF = MockSocialService.requiredTimeDelay(from: "343", to: "350", topic: "hof")
        // Expected: 7 * (60...180) -> between 420.0 and 1260.0 seconds
        #expect(delayHOF >= 420.0 && delayHOF <= 1260.0)

        // Equal values: same milestones (diff is 0)
        let delayEqual = MockSocialService.requiredTimeDelay(from: "2048", to: "2048", topic: "milestone")
        // Expected: fallback to short delay -> between 60 and 120 seconds
        #expect(delayEqual >= 60.0 && delayEqual <= 120.0)
    }

    @Test("Verify that a competitive thread breaks ties after 2 tie replies")
    func testTieBreakerInCompetitiveThreads() async throws {
        // We will run multiple simulations to verify that in any competitive thread generated,
        // we never have more than 2 consecutive tie replies.
        for _ in 0..<30 {
            let service = MockSocialService()
            try await service.postEvent(message: "Unlocked milestone 1024.", statText: "New tile")
            guard let item = MockSocialService.loadFeedCache()?.first else { continue }
            let comments = item.comments
            
            let topic = "milestone"
            
            func verifyChain(_ chain: [SocialFeedComment]) {
                var tieCount = 0
                var lastVal: String? = nil
                for comment in chain {
                    guard let val = MockSocialService.extractValue(from: comment.text, topic: topic) else { continue }
                    if let prev = lastVal {
                        if val == prev {
                            tieCount += 1
                            #expect(tieCount <= 2, "Found \(tieCount) consecutive ties in chain: \(chain.map { $0.text })")
                        } else {
                            tieCount = 0
                        }
                    }
                    lastVal = val
                }
            }
            
            var currentChain: [SocialFeedComment] = []
            for comment in comments {
                if let last = currentChain.last {
                    if comment.text.hasPrefix("@\(last.authorName)") {
                        currentChain.append(comment)
                    } else {
                        verifyChain(currentChain)
                        currentChain = [comment]
                    }
                } else {
                    currentChain = [comment]
                }
            }
            verifyChain(currentChain)
        }
    }

    @Test("Verify milestone jump weights distribution (1: 5.6%, 2: 7.4%, 3: 11%, 4: 15%, 5: 19%, 6: 15%, 7: 11%, 8: 7.4%, 9: 5.6%, 10: 3%)")
    func testMilestoneJumpDistribution() {
        var counts = [Int: Int]()
        let iterations = 10000
        for _ in 0..<iterations {
            let jump = MockSocialService.randomMilestoneJump()
            counts[jump, default: 0] += 1
        }
        
        let targetWeights: [Int: Double] = [
            1: 5.6, 2: 7.4, 3: 11.0, 4: 15.0, 5: 19.0,
            6: 15.0, 7: 11.0, 8: 7.4, 9: 5.6, 10: 3.0
        ]
        
        for (jump, target) in targetWeights {
            let count = counts[jump] ?? 0
            let percentage = (Double(count) / Double(iterations)) * 100.0
            print("Jump \(jump): target = \(target)%, actual = \(percentage)%")
            #expect(abs(percentage - target) < 1.5, "Jump \(jump) percentage \(percentage)% is too far from target \(target)%")
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
