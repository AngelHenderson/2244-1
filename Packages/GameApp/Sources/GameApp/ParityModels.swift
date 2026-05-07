import Foundation
import SwiftUI
import Observation
import GameCore
import GameServices

public enum PlayerGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case relax
    case improveStrategy
    case chaseMilestones
    case compete

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .relax: "Relax with a quick board"
        case .improveStrategy: "Improve my merge strategy"
        case .chaseMilestones: "Reach bigger tiles"
        case .compete: "Compete with other players"
        }
    }
}

public struct OnboardingPreferences: Codable, Equatable, Sendable {
    public var goal: PlayerGoal?
    public var dailyPlayGoalMinutes: Int
    public var preferredBoardThemeID: String
    public var wantsAccount: Bool
    public var wantsReminders: Bool
    public var hasSeenWidgetCTA: Bool
    public var completedAt: Date?

    public init(
        goal: PlayerGoal? = nil,
        dailyPlayGoalMinutes: Int = 10,
        preferredBoardThemeID: String = "city_1",
        wantsAccount: Bool = false,
        wantsReminders: Bool = false,
        hasSeenWidgetCTA: Bool = false,
        completedAt: Date? = nil
    ) {
        self.goal = goal
        self.dailyPlayGoalMinutes = dailyPlayGoalMinutes
        self.preferredBoardThemeID = preferredBoardThemeID
        self.wantsAccount = wantsAccount
        self.wantsReminders = wantsReminders
        self.hasSeenWidgetCTA = hasSeenWidgetCTA
        self.completedAt = completedAt
    }
}

public struct ReminderPreferences: Codable, Equatable, Sendable {
    public var practiceReminderEnabled: Bool
    public var streakReminderEnabled: Bool
    public var questReminderEnabled: Bool
    public var smartSchedulingEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int

    public init(
        practiceReminderEnabled: Bool = false,
        streakReminderEnabled: Bool = true,
        questReminderEnabled: Bool = true,
        smartSchedulingEnabled: Bool = true,
        reminderHour: Int = 19,
        reminderMinute: Int = 0
    ) {
        self.practiceReminderEnabled = practiceReminderEnabled
        self.streakReminderEnabled = streakReminderEnabled
        self.questReminderEnabled = questReminderEnabled
        self.smartSchedulingEnabled = smartSchedulingEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    public var displayTime: String {
        let suffix = reminderHour >= 12 ? "PM" : "AM"
        let hour = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        return "\(hour):\(String(format: "%02d", reminderMinute)) \(suffix)"
    }
}

public enum PracticeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case todayReview
    case recentMistakes
    case tileDrills
    case rapidReview
    case timedSprint
    case dailyChallenge
    case customChallenge
    case guidebook
    case proCoach

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .todayReview: "Today's Review"
        case .recentMistakes: "Recent Mistakes"
        case .tileDrills: "Tile Drills"
        case .rapidReview: "Rapid Review"
        case .timedSprint: "Timed Sprint"
        case .dailyChallenge: "Daily Challenge"
        case .customChallenge: "Custom Challenge"
        case .guidebook: "Guidebook"
        case .proCoach: "Pro Coach"
        }
    }

    public var subtitle: String {
        switch self {
        case .todayReview: "Warm up with your current board goals."
        case .recentMistakes: "Replay moves that ended a chain too early."
        case .tileDrills: "Practice target tiles without risking a run."
        case .rapidReview: "Short timed prompts for quick pattern reading."
        case .timedSprint: "Build the biggest tile before time expires."
        case .dailyChallenge: "One curated board objective for today."
        case .customChallenge: "Design a board and prove it is beatable."
        case .guidebook: "Review rules, perks, and valid moves."
        case .proCoach: "Deterministic move explanations and next-step hints."
        }
    }

    public var systemImage: String {
        switch self {
        case .todayReview: "calendar.badge.clock"
        case .recentMistakes: "arrow.uturn.backward.circle.fill"
        case .tileDrills: "square.grid.3x3.fill"
        case .rapidReview: "bolt.circle.fill"
        case .timedSprint: "timer.circle.fill"
        case .dailyChallenge: "flag.checkered.circle.fill"
        case .customChallenge: "slider.horizontal.3"
        case .guidebook: "book.closed.fill"
        case .proCoach: "sparkles"
        }
    }
}

public struct MoveReviewEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var boardSummary: String
    public var moveSummary: String
    public var explanation: String
    public var outcome: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        boardSummary: String,
        moveSummary: String,
        explanation: String,
        outcome: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.boardSummary = boardSummary
        self.moveSummary = moveSummary
        self.explanation = explanation
        self.outcome = outcome
    }
}

public struct YearReviewSummary: Codable, Equatable, Sendable {
    public var year: Int
    public var gamesPlayed: Int
    public var highestTileLabel: String
    public var totalMerges: Int
    public var dailyClaims: Int
    public var bestStreak: Int
    public var rankText: String

    public init(
        year: Int = Calendar.current.component(.year, from: Date()),
        gamesPlayed: Int = 0,
        highestTileLabel: String = "2",
        totalMerges: Int = 0,
        dailyClaims: Int = 0,
        bestStreak: Int = 0,
        rankText: String = "Unranked"
    ) {
        self.year = year
        self.gamesPlayed = gamesPlayed
        self.highestTileLabel = highestTileLabel
        self.totalMerges = totalMerges
        self.dailyClaims = dailyClaims
        self.bestStreak = bestStreak
        self.rankText = rankText
    }
}

public struct AccountProfile: Codable, Equatable, Sendable {
    public var uid: String
    public var displayName: String
    public var username: String
    public var email: String?
    public var phoneNumber: String?
    public var avatarID: String
    public var countryCode: String?
    public var friendCode: String
    public var isAnonymous: Bool
    public var isEmailVerified: Bool

    public init(
        uid: String,
        displayName: String = "Player",
        username: String = "player",
        email: String? = nil,
        phoneNumber: String? = nil,
        avatarID: String = "avatar_buddy_bot",
        countryCode: String? = nil,
        friendCode: String = "2244",
        isAnonymous: Bool = true,
        isEmailVerified: Bool = false
    ) {
        self.uid = uid
        self.displayName = displayName
        self.username = username
        self.email = email
        self.phoneNumber = phoneNumber
        self.avatarID = avatarID
        self.countryCode = countryCode
        self.friendCode = friendCode
        self.isAnonymous = isAnonymous
        self.isEmailVerified = isEmailVerified
    }
}

public enum AccountAuthState: Codable, Equatable, Sendable {
    case signedOut
    case anonymous(AccountProfile)
    case signedIn(AccountProfile)

    public var profile: AccountProfile? {
        switch self {
        case .signedOut: nil
        case .anonymous(let profile), .signedIn(let profile): profile
        }
    }
}

public struct SubscriptionPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var priceText: String
    public var periodText: String
    public var isFamilyPlan: Bool
    public var isRecommended: Bool
    public var benefits: [String]

    public init(
        id: String,
        displayName: String,
        priceText: String,
        periodText: String,
        isFamilyPlan: Bool,
        isRecommended: Bool = false,
        benefits: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.priceText = priceText
        self.periodText = periodText
        self.isFamilyPlan = isFamilyPlan
        self.isRecommended = isRecommended
        self.benefits = benefits
    }

    public static var proPlans: [SubscriptionPlan] {
        [
            SubscriptionPlan(
                id: IAPProduct.proMonthlyProduct.id,
                displayName: IAPProduct.proMonthlyProduct.displayName,
                priceText: IAPProduct.proMonthlyProduct.formattedPrice,
                periodText: "Monthly",
                isFamilyPlan: false,
                benefits: Self.proBenefits
            ),
            SubscriptionPlan(
                id: IAPProduct.proYearlyProduct.id,
                displayName: IAPProduct.proYearlyProduct.displayName,
                priceText: IAPProduct.proYearlyProduct.formattedPrice,
                periodText: "Yearly",
                isFamilyPlan: false,
                isRecommended: true,
                benefits: Self.proBenefits
            ),
            SubscriptionPlan(
                id: IAPProduct.proFamilyMonthlyProduct.id,
                displayName: IAPProduct.proFamilyMonthlyProduct.displayName,
                priceText: IAPProduct.proFamilyMonthlyProduct.formattedPrice,
                periodText: "Family monthly",
                isFamilyPlan: true,
                benefits: Self.familyBenefits
            ),
            SubscriptionPlan(
                id: IAPProduct.proFamilyYearlyProduct.id,
                displayName: IAPProduct.proFamilyYearlyProduct.displayName,
                priceText: IAPProduct.proFamilyYearlyProduct.formattedPrice,
                periodText: "Family yearly",
                isFamilyPlan: true,
                benefits: Self.familyBenefits
            )
        ]
    }

    private static var proBenefits: [String] {
        ["No ads", "Auto-claim boosts", "Premium practice modes", "Move explanations"]
    }

    private static var familyBenefits: [String] {
        ["Everything in Pro", "Apple Family Sharing support", "Family invite hub", "Shared progress celebrations"]
    }
}

public struct FamilyInvite: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var emailOrCode: String
    public var status: String

    public init(
        id: UUID = UUID(),
        displayName: String,
        emailOrCode: String,
        status: String = "Pending"
    ) {
        self.id = id
        self.displayName = displayName
        self.emailOrCode = emailOrCode
        self.status = status
    }
}

public struct SocialFeedComment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var authorName: String
    public var text: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        authorName: String = "Player",
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.createdAt = createdAt
    }
}

public struct SocialFeedItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var authorName: String
    public var avatarID: String
    public var createdAt: Date
    public var message: String
    public var statText: String
    public var reactionCount: Int
    public var commentCount: Int
    public var comments: [SocialFeedComment]

    public init(
        id: UUID = UUID(),
        authorName: String,
        avatarID: String = "avatar_buddy_bot",
        createdAt: Date = Date(),
        message: String,
        statText: String,
        reactionCount: Int = 0,
        commentCount: Int = 0,
        comments: [SocialFeedComment] = []
    ) {
        self.id = id
        self.authorName = authorName
        self.avatarID = avatarID
        self.createdAt = createdAt
        self.message = message
        self.statText = statText
        self.reactionCount = reactionCount
        self.commentCount = commentCount
        self.comments = comments
    }
}

public protocol MoveReviewStorage: Sendable {
    func load() -> [MoveReviewEntry]
    func save(_ entries: [MoveReviewEntry])
}

public struct UserDefaultsMoveReviewStorage: MoveReviewStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "moveReview.entries.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [MoveReviewEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([MoveReviewEntry].self, from: data)
        else { return [] }
        return entries
    }

    public func save(_ entries: [MoveReviewEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
@Observable
public final class MoveReviewStore {
    private let storage: MoveReviewStorage
    public private(set) var entries: [MoveReviewEntry]

    public init(storage: MoveReviewStorage = UserDefaultsMoveReviewStorage()) {
        self.storage = storage
        self.entries = storage.load()
    }

    public func seedIfEmpty(highestTileStep: Int = 0) {
        guard entries.isEmpty else { return }
        entries = [
            MoveReviewEntry(
                boardSummary: "Highest tile step \(max(0, highestTileStep))",
                moveSummary: "Open with a three-tile chain",
                explanation: "A three-tile chain keeps the board flexible and creates a predictable spawn window for the next move.",
                outcome: "Safer board shape"
            ),
            MoveReviewEntry(
                boardSummary: "Low-move recovery",
                moveSummary: "Save a hammer for blocked corners",
                explanation: "Removing a trapped low tile creates more valid paths than spending a swap on the same board.",
                outcome: "Recovered two open lanes"
            )
        ]
        persist()
    }

    public func record(_ entry: MoveReviewEntry) {
        entries.insert(entry, at: 0)
        if entries.count > 25 {
            entries.removeLast(entries.count - 25)
        }
        persist()
    }

    public func clear() {
        entries.removeAll()
        persist()
    }

    private func persist() {
        storage.save(entries)
    }
}

public protocol ReminderPreferenceStorage: Sendable {
    func load() -> ReminderPreferences
    func save(_ preferences: ReminderPreferences)
}

public struct UserDefaultsReminderPreferenceStorage: ReminderPreferenceStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "reminder.preferences.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> ReminderPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(ReminderPreferences.self, from: data)
        else { return ReminderPreferences() }
        return preferences
    }

    public func save(_ preferences: ReminderPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
@Observable
public final class ReminderPreferenceStore {
    private let storage: ReminderPreferenceStorage
    public var preferences: ReminderPreferences {
        didSet { storage.save(preferences) }
    }

    public init(storage: ReminderPreferenceStorage = UserDefaultsReminderPreferenceStorage()) {
        self.storage = storage
        self.preferences = storage.load()
    }

    public func reset() {
        preferences = ReminderPreferences()
    }
}

public protocol AccountService: Sendable {
    func currentState() async -> AccountAuthState
    func signIn(email: String, password: String) async throws -> AccountProfile
    func createAccount(email: String, password: String, displayName: String) async throws -> AccountProfile
    func updateProfile(_ profile: AccountProfile) async throws -> AccountProfile
    func sendPasswordReset(email: String) async throws
    func sendEmailVerification() async throws
    func signOut() async throws
    func deleteAccount() async throws
}

public enum AccountServiceError: LocalizedError, Sendable {
    case invalidEmail
    case missingPassword
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .invalidEmail: "Enter a valid email address."
        case .missingPassword: "Enter a password."
        case .unavailable: "Account service is unavailable right now."
        }
    }
}

public struct LocalAccountService: AccountService, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "account.profile.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func currentState() async -> AccountAuthState {
        guard let profile = loadProfile() else { return .signedOut }
        return profile.isAnonymous ? .anonymous(profile) : .signedIn(profile)
    }

    public func signIn(email: String, password: String) async throws -> AccountProfile {
        try validate(email: email, password: password)
        let profile = AccountProfile(
            uid: email.lowercased(),
            displayName: defaults.string(forKey: "profilePlayerName") ?? "Player",
            username: email.split(separator: "@").first.map(String.init) ?? "player",
            email: email,
            avatarID: defaults.string(forKey: "profileAvatarId") ?? "avatar_buddy_bot",
            countryCode: defaults.string(forKey: "profileCountryCode"),
            friendCode: defaults.string(forKey: "profileFriendCode") ?? "2244",
            isAnonymous: false,
            isEmailVerified: false
        )
        save(profile)
        return profile
    }

    public func createAccount(email: String, password: String, displayName: String) async throws -> AccountProfile {
        try validate(email: email, password: password)
        var profile = try await signIn(email: email, password: password)
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player" : displayName
        save(profile)
        return profile
    }

    public func updateProfile(_ profile: AccountProfile) async throws -> AccountProfile {
        save(profile)
        return profile
    }

    public func sendPasswordReset(email: String) async throws {
        guard email.contains("@") else { throw AccountServiceError.invalidEmail }
    }

    public func sendEmailVerification() async throws {}

    public func signOut() async throws {
        defaults.removeObject(forKey: key)
    }

    public func deleteAccount() async throws {
        defaults.removeObject(forKey: key)
    }

    private func validate(email: String, password: String) throws {
        guard email.contains("@") else { throw AccountServiceError.invalidEmail }
        guard !password.isEmpty else { throw AccountServiceError.missingPassword }
    }

    private func loadProfile() -> AccountProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AccountProfile.self, from: data)
    }

    private func save(_ profile: AccountProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
        defaults.set(profile.displayName, forKey: "profilePlayerName")
        defaults.set(profile.avatarID, forKey: "profileAvatarId")
        defaults.set(profile.friendCode, forKey: "profileFriendCode")
        if let countryCode = profile.countryCode {
            defaults.set(countryCode, forKey: "profileCountryCode")
        }
    }
}

public struct FirebaseBackedAccountService: AccountService, Sendable {
    private let fallback: LocalAccountService

    public init(fallback: LocalAccountService = LocalAccountService()) {
        self.fallback = fallback
    }

    public func currentState() async -> AccountAuthState {
        if let snapshot = FirebaseService.shared.currentAuthUser {
            let profile = AccountProfile(snapshot: snapshot)
            return profile.isAnonymous ? .anonymous(profile) : .signedIn(profile)
        }
        return await fallback.currentState()
    }

    public func signIn(email: String, password: String) async throws -> AccountProfile {
        do {
            let snapshot = try await FirebaseService.shared.signIn(email: email, password: password)
            return AccountProfile(snapshot: snapshot)
        } catch {
            return try await fallback.signIn(email: email, password: password)
        }
    }

    public func createAccount(email: String, password: String, displayName: String) async throws -> AccountProfile {
        do {
            let snapshot = try await FirebaseService.shared.createUser(email: email, password: password, displayName: displayName)
            return AccountProfile(snapshot: snapshot)
        } catch {
            return try await fallback.createAccount(email: email, password: password, displayName: displayName)
        }
    }

    public func updateProfile(_ profile: AccountProfile) async throws -> AccountProfile {
        do {
            try await FirebaseService.shared.updateDisplayName(profile.displayName)
            return profile
        } catch {
            return try await fallback.updateProfile(profile)
        }
    }

    public func sendPasswordReset(email: String) async throws {
        do {
            try await FirebaseService.shared.sendPasswordReset(email: email)
        } catch {
            try await fallback.sendPasswordReset(email: email)
        }
    }

    public func sendEmailVerification() async throws {
        do {
            try await FirebaseService.shared.sendEmailVerification()
        } catch {
            try await fallback.sendEmailVerification()
        }
    }

    public func signOut() async throws {
        do {
            try FirebaseService.shared.signOut()
        } catch {
            try await fallback.signOut()
        }
    }

    public func deleteAccount() async throws {
        do {
            try await FirebaseService.shared.deleteCurrentUser()
        } catch {
            try await fallback.deleteAccount()
        }
    }
}

public protocol SocialService: Sendable {
    func feed() async throws -> [SocialFeedItem]
    func searchFriends(query: String) async throws -> [AccountProfile]
    func invites() async throws -> [FamilyInvite]
}

public struct MockSocialService: SocialService, Sendable {
    public init() {}

    public func feed() async throws -> [SocialFeedItem] {
        let now = Date()
        var items: [SocialFeedItem] = []
        let milestones = ["16K", "32K", "65K", "131K", "262K", "524K", "1M", "2M", "4M", "8M"]
        let messages = [
            "Reached a NEW tile in Endless.",
            "Finished today's timed challenge.",
            "Protected a streak.",
            "Joined the Hall of Fame!",
            "Unlocked a new theme.",
            "Completed the Weekly Quest."
        ]
        
        for _ in 0..<25 {
            let author = generateDynamicName()
            let message = messages.randomElement()!.replacingOccurrences(of: "NEW", with: milestones.randomElement()!)
            let statText = "Update"
            let timeOffset = Double.random(in: -86400...0)
            let itemDate = now.addingTimeInterval(timeOffset)
            
            var comments: [SocialFeedComment] = []
            let numComments = Int.random(in: 0...5)
            for _ in 0..<numComments {
                let commentOffset = Double.random(in: timeOffset...0)
                comments.append(SocialFeedComment(
                    authorName: generateDynamicName(),
                    text: generateDynamicComment(),
                    createdAt: now.addingTimeInterval(commentOffset)
                ))
            }
            
            items.append(SocialFeedItem(
                authorName: author,
                createdAt: itemDate,
                message: message,
                statText: statText,
                reactionCount: Int.random(in: 0...50),
                commentCount: comments.count,
                comments: comments.sorted(by: { $0.createdAt < $1.createdAt })
            ))
        }
        
        return items.sorted(by: { $0.createdAt > $1.createdAt })
    }

    public func searchFriends(query: String) async throws -> [AccountProfile] {
        var names: [String] = []
        for _ in 0..<20 {
            names.append(generateDynamicName())
        }
        if !query.isEmpty {
            names.append(query + String(format: "%04d", Int.random(in: 1000...9999)))
            names.append(generateDynamicName() + query)
        }
        let filtered = names.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
        return filtered.map {
            AccountProfile(
                uid: $0.replacingOccurrences(of: " ", with: ".").lowercased(),
                displayName: $0,
                username: $0.replacingOccurrences(of: " ", with: "").lowercased(),
                friendCode: String($0.prefix(3)).uppercased() + "-2244",
                isAnonymous: false,
                isEmailVerified: true
            )
        }
    }

    public func invites() async throws -> [FamilyInvite] {
        [
            FamilyInvite(displayName: generateDynamicName(), emailOrCode: "CODE-1", status: "Invited"),
            FamilyInvite(displayName: generateDynamicName(), emailOrCode: "CODE-2", status: "Can invite"),
            FamilyInvite(displayName: generateDynamicName(), emailOrCode: "CODE-3", status: "Can invite")
        ]
    }
    
    private func generateDynamicComment() -> String {
        let openers = ["Dude,", "Omg,", "Wow,", "Bro,", "Honestly,", "Crazy,", "Yoo,", ""]
        let subjects = ["that run", "your board", "this milestone", "your progress", "that score", "this setup", "your grid", "the late game"]
        let verbs = ["is", "looks", "feels", "was"]
        let adjectives = ["insane", "amazing", "unreal", "so clean", "mind-blowing", "crazy", "perfect", "solid", "epic", "brilliant", "next level", "flawless"]
        let shortReactions = ["GG!", "Nice!", "Incredible!", "Keep it up!", "So jealous!", "Teach me!", "Let's go!", "Fire!", "Huge!", "Well deserved!", "Too good!"]
        let questions = ["How long did that take?", "What's your secret?", "Any tips for this tier?", "How many moves did it take?", "Did you use any swaps?", "Was it tough?", "Can I add you?"]
        let emojis = ["🔥", "🙌", "🤯", "🚀", "👏", "👀", "💪", "🏆", "✨", ""]
        
        let format = Int.random(in: 0...5)
        var comment = ""
        
        switch format {
        case 0:
            let opener = openers.randomElement()!
            let core = "\(subjects.randomElement()!) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
            comment = opener.isEmpty ? core.capitalized + "!" : "\(opener) \(core)!"
        case 1:
            comment = "\(shortReactions.randomElement()!) \(questions.randomElement()!)"
        case 2:
            let opener = openers.randomElement()!
            let core = "\(subjects.randomElement()!) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
            let sentence = opener.isEmpty ? core.capitalized + "." : "\(opener) \(core)."
            comment = "\(sentence) \(questions.randomElement()!)"
        case 3:
            comment = "\(shortReactions.randomElement()!)"
        case 4:
            comment = "\(subjects.randomElement()!.capitalized) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
        default:
            comment = "\(shortReactions.randomElement()!)"
        }
        
        if Double.random(in: 0...1) < 0.3 {
            let emoji = emojis.randomElement()!
            if !emoji.isEmpty {
                comment += " \(emoji)"
            }
        }
        
        return comment.trimmingCharacters(in: .whitespaces)
    }
    
    private func generateDynamicName() -> String {
        if Double.random(in: 0...1) < 0.25 {
            let realNames = ["James", "Michael", "Robert", "David", "William", "John", "Richard", "Thomas", "Chris", "Daniel", "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Joshua", "Kevin", "Brian", "George", "Emma", "Olivia", "Sophia", "Isabella", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn", "Abigail", "Carlos", "Miguel", "Luis", "Jose", "Juan", "Diego", "Alejandro", "Javier", "Fernando", "Rafael", "Maria", "Carmen", "Rosa", "Ana", "Lucia", "Elena", "Isabel", "Sofia", "Valentina", "Camila", "Hans", "Klaus", "Wolfgang", "Heinrich", "Friedrich"]
            let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Anderson", "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark", "Garcia", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Perez", "Sanchez", "Ramirez", "Torres", "Mueller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann"]
            return realNames.randomElement()! + " " + lastNames.randomElement()!
        } else {
            let baseNames = ["DefenselessMetal", "LopingLemming", "DensePage", "BrittleBelly", "PerfectPirate", "CaramelStamp", "CulturalDerision", "KnownOwner", "SwiftCoder", "PixelMaster", "NeonRacer", "CloudJumper", "StarGazer", "ThunderBolt", "CryptoKing", "MidnightOwl", "SolarFlare", "OceanWave", "MountainPeak", "DesertStorm", "JungleCat", "ArcticFox", "TropicalBird", "CosmicDust", "QuantumLeap", "NebulaStar", "GalaxyRider", "AsteroidHunter", "CometChaser", "MeteorShower", "SaturnRing", "JupiterMoon", "MarsRover", "VenusFlyer", "MercuryDash", "PlutoExplorer", "NeptuneWave", "UranusOrbit", "EarthGuard", "SunBlaze", "MoonWalker", "StarDancer", "SpacePilot", "RocketMan", "LaserBeam", "PhotonBlast", "NeutronStar", "ProtonPower", "ElectronFlow", "AtomSmasher", "MoleculeMix", "CellDivider", "DNAHelix", "RNAStrand", "ProteinFold", "EnzymeCat", "VitaminBoost", "MineralRock", "CrystalClear", "DiamondEdge", "RubyGlow", "SapphireShine", "EmeraldDream", "AmethystMist", "TopazSun", "OpalMoon", "PearlOcean", "JadeForest", "OnyxShadow", "GarnetFire", "TurquoiseSky", "CoralReef", "IvoryTower", "BronzeAge", "SilverLining", "GoldRush", "PlatinumPro", "TitaniumStrong", "CopperGlow", "IronWill", "SteelNerve", "AluminumLight", "ZincShield", "NickelSpin", "CobaltBlue", "ChromeFinish", "TungstenTough", "MolybdenumMax", "VanadiumVibe", "ManganeseMight", "PalladiumPure", "RhodiumRare", "IridiumIntense", "OsmiumOdd", "RheniumRich", "TantalumTwist", "HafniumHigh", "ZirconiumZest", "NiobiumNova", "TokyoTiger", "LondonLion", "ParisPanther", "BerlinBear", "SydneySerpent", "TorontoTornado", "MadridMaverick", "RomeRaider", "SaoPauloStar", "MumbaiMaster", "ShanghaiShark", "MoscowMight", "DubaiDragon", "SingaporeSurge", "HongKongHero", "SeoulSniper", "BangkokBolt", "JakartaJet", "CairoChamp", "LagoosLegend", "NairobiNinja", "CapeTownCrush", "BuenosAiresBoss", "MexicoCityMaster", "LimaaLion", "SantiagoStorm", "BogotaBeast", "CaracasChamp", "HavannaHawk", "KingstonKing", "MontrealMaverick", "VancouverVictor", "MelbourneMight", "AucklandAce", "WellingtonWolf", "OsakaOracle", "KyotoKnight", "NagoyaNinja", "FukuokaaFury", "SapporoStrike", "MunichMaster", "HamburgHero", "FrankfurtFlash", "CologneCrusher", "DusseldorfDragon", "AmsterdamAce", "BrussellsBoss", "ViennaViking", "ZurichZealot", "GenevaGhost"]
            let number = String(format: "%06d", Int.random(in: 100000...999999))
            return baseNames.randomElement()! + number
        }
    }
}

private extension AccountProfile {
    init(snapshot: FirebaseAuthUserSnapshot) {
        self.init(
            uid: snapshot.uid,
            displayName: snapshot.displayName ?? "Player",
            username: (snapshot.email?.split(separator: "@").first.map(String.init) ?? "player"),
            email: snapshot.email,
            phoneNumber: snapshot.phoneNumber,
            friendCode: String(snapshot.uid.prefix(6)).uppercased(),
            isAnonymous: snapshot.isAnonymous,
            isEmailVerified: snapshot.isEmailVerified
        )
    }
}

private struct AccountServiceKey: EnvironmentKey {
    static let defaultValue: any AccountService = FirebaseBackedAccountService()
}

private struct SocialServiceKey: EnvironmentKey {
    static let defaultValue: any SocialService = MockSocialService()
}

public extension EnvironmentValues {
    var accountService: any AccountService {
        get { self[AccountServiceKey.self] }
        set { self[AccountServiceKey.self] = newValue }
    }

    var socialService: any SocialService {
        get { self[SocialServiceKey.self] }
        set { self[SocialServiceKey.self] = newValue }
    }
}
