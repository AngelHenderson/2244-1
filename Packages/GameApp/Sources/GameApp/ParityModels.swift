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
    public var avatarID: String
    public var text: String
    public var createdAt: Date
    public var likes: Int?
    public var isHearted: Bool?

    public init(
        id: UUID = UUID(),
        authorName: String = "Player",
        avatarID: String = "avatar_buddy_bot",
        text: String,
        createdAt: Date = Date(),
        likes: Int? = nil,
        isHearted: Bool? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.avatarID = avatarID
        self.text = text
        self.createdAt = createdAt
        self.likes = likes
        self.isHearted = isHearted
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
    public var isHearted: Bool?
    public var commentCount: Int
    public var comments: [SocialFeedComment]
    public var reactionTimestamps: [Date]?

    public init(
        id: UUID = UUID(),
        authorName: String,
        avatarID: String = "avatar_buddy_bot",
        createdAt: Date = Date(),
        message: String,
        statText: String,
        reactionCount: Int = 0,
        isHearted: Bool? = nil,
        commentCount: Int = 0,
        comments: [SocialFeedComment] = [],
        reactionTimestamps: [Date]? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.avatarID = avatarID
        self.createdAt = createdAt
        self.message = message
        self.statText = statText
        self.reactionCount = reactionCount
        self.isHearted = isHearted
        self.commentCount = commentCount
        self.comments = comments
        self.reactionTimestamps = reactionTimestamps
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
            try? await mirrorPublicProfile(profile)
            return profile.isAnonymous ? .anonymous(profile) : .signedIn(profile)
        }
        return await fallback.currentState()
    }

    public func signIn(email: String, password: String) async throws -> AccountProfile {
        do {
            let snapshot = try await FirebaseService.shared.signIn(email: email, password: password)
            let profile = AccountProfile(snapshot: snapshot)
            try? await mirrorPublicProfile(profile)
            return profile
        } catch {
            return try await fallback.signIn(email: email, password: password)
        }
    }

    public func createAccount(email: String, password: String, displayName: String) async throws -> AccountProfile {
        do {
            let snapshot = try await FirebaseService.shared.createUser(email: email, password: password, displayName: displayName)
            let profile = AccountProfile(snapshot: snapshot)
            try? await mirrorPublicProfile(profile)
            return profile
        } catch {
            return try await fallback.createAccount(email: email, password: password, displayName: displayName)
        }
    }

    public func updateProfile(_ profile: AccountProfile) async throws -> AccountProfile {
        do {
            try await FirebaseService.shared.updateDisplayName(profile.displayName)
            try? await mirrorPublicProfile(profile)
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

    private func mirrorPublicProfile(_ profile: AccountProfile) async throws {
        try await FirebaseService.shared.upsertPublicUserProfile(
            uid: profile.uid,
            displayName: profile.displayName,
            username: profile.username,
            avatarID: profile.avatarID,
            friendCode: profile.friendCode,
            countryCode: profile.countryCode
        )
    }
}

public protocol SocialService: Sendable {
    func feed() async throws -> [SocialFeedItem]
    func addComment(to itemID: UUID, text: String) async throws
    func postEvent(message: String, statText: String) async throws
    func toggleItemHeart(itemID: UUID) async throws
    func toggleCommentHeart(itemID: UUID, commentID: UUID) async throws
    func searchFriends(query: String) async throws -> [AccountProfile]
    func invites() async throws -> [FamilyInvite]
}

public enum SocialServiceError: LocalizedError, Sendable {
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Social features are unavailable right now."
        }
    }
}

public struct UnavailableSocialService: SocialService, Sendable {
    public init() {}

    public func feed() async throws -> [SocialFeedItem] {
        throw SocialServiceError.unavailable
    }

    public func addComment(to itemID: UUID, text: String) async throws {
        throw SocialServiceError.unavailable
    }

    public func postEvent(message: String, statText: String) async throws {
        throw SocialServiceError.unavailable
    }

    public func toggleItemHeart(itemID: UUID) async throws {
        throw SocialServiceError.unavailable
    }

    public func toggleCommentHeart(itemID: UUID, commentID: UUID) async throws {
        throw SocialServiceError.unavailable
    }

    public func searchFriends(query: String) async throws -> [AccountProfile] {
        throw SocialServiceError.unavailable
    }

    public func invites() async throws -> [FamilyInvite] {
        throw SocialServiceError.unavailable
    }
}

public struct MockSocialService: SocialService, Sendable {
    public init() {}

    static let allAvatars: [String] = [
        "avatar_anchor_nautical", "avatar_ancient_scroll", "avatar_astronaut_cat",
        "avatar_baseball_cap", "avatar_bear_grizzly", "avatar_bubble_narwhal",
        "avatar_buddy_bot", "avatar_burger_food", "avatar_chicken_bird",
        "avatar_cosmic_sloth", "avatar_crimson_wyrm", "avatar_dapper_ape",
        "avatar_ember_drake", "avatar_emerald_android", "avatar_frosty_cupcake",
        "avatar_moonlight_wizard", "avatar_nordic_warrior", "avatar_paper_plane",
        "avatar_phoenix_fire", "avatar_professor_bee", "avatar_robot_green",
        "avatar_sea_captain", "avatar_shark_teeth", "avatar_shiba_dog",
        "avatar_skull_crossbones", "avatar_sly_fox", "avatar_soccer_star",
        "avatar_specimen_jar", "avatar_spooky_ghost", "avatar_starfighter",
        "avatar_storm_sword", "avatar_sunny_sunflower", "avatar_toxic_tonic",
        "avatar_treasure_chest", "avatar_warrior_samurai", "avatar_winter_doll"
    ]

    static let allMilestones: [String] = [
        "0", "2", "4", "8", "16", "32", "64", "128", "256", "512",
        "1024", "2048", "4096", "8192", "16K", "32K", "65K", "131K", "262K", "524K",
        "1M", "2M", "4M", "8M", "16M", "33M", "67M", "134M", "268M", "536M",
        "1B", "2B", "4B", "8B", "17B", "34B", "68B", "137B", "274B", "549B",
        "1a", "2a", "4a", "8a", "17a", "35a", "70a", "140a", "281a", "562a",
        "1b", "2b", "4b", "9b", "18b", "36b", "72b", "144b", "288b", "576b",
        "1c", "2c", "4c", "9c", "18c", "36c", "73c", "147c", "295c", "590c",
        "1d", "2d", "4d", "9d", "18d", "37d", "75d", "151d", "302d", "604d",
        "1e", "2e", "4e", "9e", "19e", "38e", "77e", "154e", "309e", "618e",
        "1f", "2f", "4f", "9f", "19f", "39f", "79f", "158f", "316f", "633f",
        "1g", "2g", "5g", "10g", "20g", "40g", "81g", "162g", "324g", "649g",
        "1h", "2h", "5h", "10h", "20h", "41h", "83h", "166h", "332h", "664h",
        "1i", "2i", "5i", "10i", "21i", "42i", "85i", "170i", "340i", "680i",
        "1j", "2j", "5j", "10j", "21j", "43j", "87j", "174j", "348j", "696j",
        "1k", "2k", "5k", "11k", "22k", "44k", "89k", "178k", "356k", "713k",
        "1l", "2l", "5l", "11l", "22l", "45l", "91l", "182l", "365l", "730l",
        "1m", "2m", "5m", "11m", "23m", "46m", "93m", "187m", "374m", "748m",
        "1n", "2n", "5n", "11n", "23n", "47n", "95n", "191n", "383n", "766n",
        "1o", "3o", "6o", "12o", "24o", "49o", "98o", "196o", "392o", "784o",
        "1p", "3p", "6p", "12p", "25p", "50p", "100p", "200p", "401p", "803p",
        "1q", "3q", "6q", "12q", "25q", "51q", "102q", "205q", "411q", "822q",
        "1r", "3r", "6r", "13r", "26r", "52r", "105r", "210r", "421r", "842r",
        "1s", "3s", "6s", "13s", "26s", "53s", "107s", "215s", "431s", "862s",
        "1t", "3t", "6t", "13t", "27t", "55t", "110t", "220t", "441t", "883t",
        "1u", "3u", "7u", "14u", "28u", "56u", "113u", "226u", "452u", "904u",
        "1v", "3v", "7v", "14v", "28v", "57v", "115v", "231v", "463v", "926v",
        "1w", "3w", "7w", "14w", "29w", "59w", "118w", "237w", "474w", "948w",
        "1x", "3x", "7x", "15x", "30x", "60x", "121x", "242x", "485x", "971x",
        "1y", "3y", "7y", "15y", "31y", "62y", "124y", "248y", "497y", "994y",
        "1z", "3z", "7z", "15z", "31z", "63z", "127z", "254z", "509z", "1aa",
        "2aa", "4aa", "8aa", "16aa", "32aa", "65aa", "130aa", "260aa", "521aa", "1ab",
        "2ab", "4ab", "8ab", "16ab", "33ab", "66ab", "133ab", "266ab", "533ab", "1ac",
        "2ac", "4ac", "8ac", "17ac", "34ac", "68ac", "136ac", "273ac", "546ac", "1ad",
        "2ad", "4ad", "8ad", "17ad", "34ad", "69ad", "139ad", "279ad", "559ad", "1ae",
        "2ae", "4ae", "8ae", "17ae", "35ae", "71ae", "143ae", "286ae", "573ae", "1af",
        "2af", "4af", "9af", "18af", "36af", "73af", "146af", "293af", "587af", "1ag",
        "2ag", "4ag", "9ag", "18ag", "37ag", "75ag", "150ag", "300ag", "601ag", "1ah",
        "2ah", "4ah", "9ah", "19ah", "38ah", "76ah", "153ah", "307ah", "615ah", "1ai",
        "2ai", "4ai", "9ai", "19ai", "39ai", "78ai", "157ai", "315ai", "630ai", "1aj",
        "2aj", "5aj", "10aj", "20aj", "40aj", "80aj", "161aj", "322aj", "645aj", "1ak",
        "2ak", "5ak", "10ak", "20ak", "41ak", "82ak", "165ak", "330ak", "661ak", "1al",
        "2al", "5al", "10al", "21al", "42al", "84al", "169al", "338al", "676al", "1am",
        "2am", "5am", "10am", "21am", "43am", "86am", "173am", "346am", "693am", "1an",
        "2an", "5an", "11an", "22an", "44an", "88an", "177an", "354an", "709an", "1ao",
        "2ao", "5ao", "11ao", "22ao", "45ao", "90ao", "181ao", "363ao", "726ao", "1ap",
        "2ap", "5ap", "11ap", "23ap", "46ap", "93ap", "186ap", "372ap", "744ap", "1aq",
        "2aq", "5aq", "11aq", "23aq", "47aq", "95aq", "190aq", "381aq", "762aq", "1ar",
        "3ar", "6ar", "12ar", "24ar", "48ar", "97ar", "195ar", "390ar", "780ar", "1as",
        "3as", "6as", "12as", "24as", "49as", "99as", "199as", "399as", "799as", "1at",
        "3at", "6at", "12at", "25at", "51at", "102at", "204at", "409at", "818at", "1au",
        "3au", "6au", "13au", "26au", "52au", "105au", "209au", "419au", "837au", "1av",
        "3av", "6av", "13av", "27av", "54av", "107av", "214av", "429av", "858av", "1aw",
        "3aw", "6aw", "13aw", "27aw", "55aw", "110aw", "220aw", "439aw", "878aw", "1ax",
        "3ax", "7ax", "14ax", "28ax", "56ax", "112ax", "224ax", "449ax", "899ax", "1ay",
        "3ay", "7ay", "14ay", "28ay", "57ay", "115ay", "230ay", "460ay", "921ay", "1az",
        "3az", "7az", "14az", "29az", "58az", "117az", "235az", "471az", "943az", "1ba",
        "3ba", "7ba", "15ba", "30ba", "60ba", "120ba", "241ba", "483ba", "966ba", "1bb",
        "3bb", "7bb", "15bb", "30bb", "61bb", "123bb", "247bb", "494bb", "989bb", "1bc",
        "3bc", "7bc", "15bc", "31bc", "63bc", "126bc", "253bc", "506bc", "1bd",
        "2bd", "4bd", "8bd", "16bd", "32bd", "64bd", "129bd", "259bd", "518bd", "1be",
        "2be", "4be", "8be", "16be", "33be", "66be", "132be", "265be", "531be", "1bf",
        "2bf", "4bf", "8bf", "16bf", "33bf", "67bf", "135bf", "271bf", "543bf", "1bg",
        "2bg", "4bg", "8bg", "17bg", "34bg", "69bg", "139bg", "278bg", "556bg", "1bh",
        "2bh", "4bh", "8bh", "17bh", "35bh", "71bh", "142bh", "285bh", "570bh", "1bi",
        "2bi", "4bi", "9bi", "18bi", "36bi", "72bi", "145bi", "291bi", "583bi", "1bj",
        "2bj", "4bj", "9bj", "18bj", "37bj", "74bj", "149bj", "299bj", "598bj", "1bk",
        "2bk", "4bk", "9bk", "19bk", "38bk", "76bk", "153bk", "306bk", "612bk", "1bl",
        "2bl", "4bl", "9bl", "19bl", "39bl", "78bl", "156bl", "313bl", "627bl", "1bm",
        "2bm", "5bm", "10bm", "20bm", "40bm", "80bm", "160bm", "321bm", "642bm", "1bn",
        "2bn", "5bn", "10bn", "20bn", "41bn", "82bn", "164bn", "328bn", "657bn", "1bo",
        "2bo", "5bo", "10bo", "21bo", "42bo", "84bo", "168bo", "336bo", "673bo", "1bp",
        "2bp", "5bp", "10bp", "21bp", "43bp", "86bp", "172bp", "344bp", "689bp", "1bq",
        "2bq", "5bq", "11bq", "22bq", "44bq", "88bq", "176bq", "353bq", "706bq", "1br",
        "2br", "5br", "11br", "22br", "45br", "90br", "180br", "361br", "722br", "1bs",
        "2bs", "5bs", "11bs", "23bs", "46bs", "92bs", "185bs", "370bs", "740bs", "1bt",
        "2bt", "5bt", "11bt", "23bt", "47bt", "94bt", "189bt", "379bt", "758bt", "1bu",
        "3bu", "6bu", "12bu", "24bu", "48bu", "97bu", "194bu", "388bu", "776bu", "1bv",
        "3bv", "6bv", "12bv", "24bv", "49bv", "99bv", "198bv", "397bv", "794bv", "1bw",
        "3bw", "6bw", "12bw", "25bw", "50bw", "101bw", "203bw", "406bw", "813bw", "1bx",
        "3bx", "6bx", "13bx", "26bx", "52bx", "104bx", "208bx", "416bx", "833bx", "1by",
        "3by", "6by", "13by", "26by", "53by", "106by", "213by", "426by", "853by", "1bz",
        "3bz", "6bz", "13bz", "27bz", "54bz", "109bz", "218bz", "436bz", "873bz"
    ]

    static var daysSinceReference: Int {
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 20
        let ref = Calendar.current.date(from: components) ?? Date()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfReference = Calendar.current.startOfDay(for: ref)
        return max(0, Calendar.current.dateComponents([.day], from: startOfReference, to: startOfToday).day ?? 0)
    }

    private static func seededRandom(seed: Int, index: Int) -> Double {
        var hasher = Hasher()
        hasher.combine(seed)
        hasher.combine(index)
        let hash = abs(hasher.finalize())
        return Double(hash % 1000000) / 1000000.0
    }

    private static func countryPlayersChangingNameOrAvatar(on day: Int, countrySeed: Int) -> Double {
        let random = seededRandom(seed: countrySeed + 5000, index: day)
        return 0.05 + random * 0.35
    }

    private static func avatarForPlayer(index: Int, countrySeed: Int = 0) -> String {
        let noAvatarRandom = seededRandom(seed: index * 251 + countrySeed * 43, index: index + countrySeed)
        if noAvatarRandom < 0.15 { return "person.crop.circle.fill" } // placeholder
        let seed = index * 131 + countrySeed * 17
        let random = seededRandom(seed: seed, index: index)
        let avatarIndex = Int(random * Double(allAvatars.count))
        return allAvatars[avatarIndex % allAvatars.count]
    }

    static func avatarForPlayer(index: Int, countrySeed: Int, day: Int) -> String {
        let noAvatarRandom = seededRandom(seed: index * 251 + countrySeed * 43, index: index + countrySeed)
        if noAvatarRandom < 0.15 {
            let delayDays = 0.125 + noAvatarRandom / 0.15 * 1.875
            let playerJoinDay = Int(seededRandom(seed: index * 373 + countrySeed * 67, index: index) * Double(max(1, day)))
            if Double(day - playerJoinDay) < delayDays { return "person.crop.circle.fill" }
        }
        var totalChanges: Double = 0
        for d in 0...day { totalChanges += countryPlayersChangingNameOrAvatar(on: d, countrySeed: countrySeed) }
        let changeThreshold = seededRandom(seed: index * 199 + countrySeed * 31, index: index)
        let playerChangeDay = Int(changeThreshold * 200)
        if index < 150 {
            if seededRandom(seed: index * 317 + countrySeed * 59, index: index) > 0.15 {
                return avatarForPlayer(index: index, countrySeed: countrySeed)
            }
        }
        if day >= playerChangeDay && totalChanges > Double(index % 50) * 0.1 {
            let newSeed = index * 131 + countrySeed * 17 + day * 7
            let random = seededRandom(seed: newSeed, index: day)
            let avatarIndex = Int(random * Double(allAvatars.count))
            return allAvatars[avatarIndex % allAvatars.count]
        }
        return avatarForPlayer(index: index, countrySeed: countrySeed)
    }

    private static let feedCacheKey = "socialFeed.cache.v6"
    private static let feedDateKey = "socialFeed.cacheDate.v6"

    public func feed() async throws -> [SocialFeedItem] {
        let now = Date()
        let cal = Calendar.current
        let todayString = cal.dateComponents([.year, .month, .day], from: now)
            .description // deterministic for the same day

        // Return cached feed if it was generated today
        let defaults = UserDefaults.standard
        if let cachedDate = defaults.string(forKey: Self.feedDateKey),
           cachedDate == todayString,
           let data = defaults.data(forKey: Self.feedCacheKey),
           var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data) {
            
            // Filter out future comments so simulated responses arrive naturally
            for i in 0..<cached.count {
                cached[i].comments = cached[i].comments.filter { $0.createdAt <= now }
                cached[i].commentCount = cached[i].comments.count
                if let rts = cached[i].reactionTimestamps {
                    cached[i].reactionCount = rts.filter { $0 <= now }.count
                }
            }
            return cached
        }

        // Generate fresh feed
        let items = generateFeedItems(now: now)

        // Cache for the rest of the day
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.feedCacheKey)
            defaults.set(todayString, forKey: Self.feedDateKey)
        }

        return items
    }

    public func addComment(to itemID: UUID, text: String) async throws {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.feedCacheKey),
              var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data) else {
            return
        }
        if let index = cached.firstIndex(where: { $0.id == itemID }) {
            let now = Date()
            let newComment = SocialFeedComment(authorName: "Player", avatarID: "avatar_buddy_bot", text: text, createdAt: now)
            cached[index].comments.append(newComment)
            
            // Simulate a response from another player (30 mins to 24 hours later)
            let delay = Double.random(in: 1800...86400)
            let responseTime = now.addingTimeInterval(delay)
            
            let responderName: String
            let responderIndex = Int.random(in: 1...100000)
            let responderAvatar = Self.avatarForPlayer(index: responderIndex, countrySeed: 0, day: Self.daysSinceReference)
            if text.hasPrefix("@") {
                let parts = text.split(separator: " ")
                if let first = parts.first {
                    responderName = String(first.dropFirst()) // Reply as the mentioned user
                } else {
                    responderName = generateDynamicName()
                }
            } else {
                responderName = cached[index].authorName // Reply as the post author
            }
            
            let responseText: String
            if let answer = milestoneAnswer(for: text) {
                responseText = "@Player " + answer
            } else {
                responseText = "@Player " + generateContextualReply(to: text, message: cached[index].message)
            }
            let responseComment = SocialFeedComment(authorName: responderName, avatarID: responderAvatar, text: responseText, createdAt: responseTime)
            cached[index].comments.append(responseComment)
            
            cached[index].commentCount = cached[index].comments.count
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
        }
    }

    public func postEvent(message: String, statText: String) async throws {
        let defaults = UserDefaults.standard
        let now = Date()
        let currentDay = Self.daysSinceReference

        // Build the player's post
        let playerName = defaults.string(forKey: "player.displayName") ?? "Player"
        let playerAvatar = defaults.string(forKey: "player.avatarID") ?? "avatar_buddy_bot"

        // Generate 5–30 comments matching the same pattern as mock feed items
        let numTopLevel = Int.random(in: 3...15)
        let numReplies = Int.random(in: 2...15)
        let totalComments = numTopLevel + numReplies

        // Sort offsets so conversation flows chronologically (30 min – 24 hr spread)
        var commentOffsets: [Double] = []
        for _ in 0..<totalComments {
            commentOffsets.append(Double.random(in: -86400...(-120)))
        }
        commentOffsets.sort()

        // Mark which indices are replies to previous comments
        var replyIndices = Set<Int>()
        if totalComments > 1 {
            var available = Array(1..<totalComments)
            available.shuffle()
            for i in 0..<min(numReplies, available.count) {
                replyIndices.insert(available[i])
            }
        }

        var comments: [SocialFeedComment] = []
        var commentAuthors: [String] = []

        for (index, offset) in commentOffsets.enumerated() {
            let commenter = generateDynamicName()
            let commenterIndex = Int.random(in: 1...100000)
            let commenterAvatar = Self.avatarForPlayer(index: commenterIndex, countrySeed: 0, day: currentDay)
            var commentText = generateDynamicComment(message: message)

            // If this is a reply, reference a previous commenter
            if replyIndices.contains(index), !commentAuthors.isEmpty {
                let replyTo = commentAuthors.randomElement()!
                if replyTo != commenter {
                    let previousComment = comments.last(where: { $0.authorName == replyTo })
                    if let prev = previousComment {
                        commentText = "@\(replyTo) " + generateContextualReply(to: prev.text, message: message)
                    } else {
                        commentText = "@\(replyTo) " + commentText
                    }
                }
            }

            comments.append(SocialFeedComment(
                authorName: commenter,
                avatarID: commenterAvatar,
                text: commentText,
                createdAt: now.addingTimeInterval(offset),
                likes: Int.random(in: 0...10)
            ))
            commentAuthors.append(commenter)
        }

        // Heart/reaction timestamps spread over the next 24 hours (10–50, same as mock feed)
        let numReactions = Int.random(in: 10...50)
        var rTimestamps: [Date] = []
        for _ in 0..<numReactions {
            rTimestamps.append(now.addingTimeInterval(Double.random(in: -86400...0)))
        }

        let newItem = SocialFeedItem(
            authorName: playerName,
            avatarID: playerAvatar,
            createdAt: now,
            message: message,
            statText: statText,
            reactionCount: rTimestamps.filter { $0 <= now }.count,
            commentCount: comments.filter { $0.createdAt <= now }.count,
            comments: comments.sorted(by: { $0.createdAt < $1.createdAt }),
            reactionTimestamps: rTimestamps
        )

        // Insert at the top of the cached feed
        if let data = defaults.data(forKey: Self.feedCacheKey),
           var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data) {
            cached.insert(newItem, at: 0)
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
        } else {
            // No existing cache — start a fresh one with just this item
            if let newData = try? JSONEncoder().encode([newItem]) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
        }
    }

    public func toggleItemHeart(itemID: UUID) async throws {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.feedCacheKey),
              var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data) else { return }
        
        if let itemIndex = cached.firstIndex(where: { $0.id == itemID }) {
            let wasHearted = cached[itemIndex].isHearted ?? false
            cached[itemIndex].isHearted = !wasHearted
            cached[itemIndex].reactionCount += (wasHearted ? -1 : 1)
            
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
        }
    }

    public func toggleCommentHeart(itemID: UUID, commentID: UUID) async throws {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.feedCacheKey),
              var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data) else { return }
        
        if let itemIndex = cached.firstIndex(where: { $0.id == itemID }),
           let commentIndex = cached[itemIndex].comments.firstIndex(where: { $0.id == commentID }) {
            
            let wasHearted = cached[itemIndex].comments[commentIndex].isHearted ?? false
            cached[itemIndex].comments[commentIndex].isHearted = !wasHearted
            let currentLikes = cached[itemIndex].comments[commentIndex].likes ?? 0
            cached[itemIndex].comments[commentIndex].likes = currentLikes + (wasHearted ? -1 : 1)
            
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
        }
    }

    private func generateFeedItems(now: Date) -> [SocialFeedItem] {
        var items: [SocialFeedItem] = []
        let currentDay = Self.daysSinceReference
        for _ in 0..<25 {
            let author = generateDynamicName()
            let authorIndex = Int.random(in: 1...100000)
            let authorAvatar = Self.avatarForPlayer(index: authorIndex, countrySeed: 0, day: currentDay)
            
            let randomMilestone: String
            if Double.random(in: 0...1) < 0.8 {
                randomMilestone = Self.allMilestones[Int.random(in: 14..<Self.allMilestones.count)]
            } else {
                randomMilestone = Self.allMilestones.randomElement()!
            }
            
            let (message, statText) = generateDynamicEvent(milestone: randomMilestone)
            let timeOffset = Double.random(in: -86400...0)
            let itemDate = now.addingTimeInterval(timeOffset)
            
            var comments: [SocialFeedComment] = []
            let numTopLevelComments = Int.random(in: 2...8)
            let numResponses = Int.random(in: 3...10)
            let totalComments = numTopLevelComments + numResponses
            
            // Generate and sort offsets so the conversation flows chronologically
            var commentOffsets: [Double] = []
            for _ in 0..<totalComments {
                commentOffsets.append(Double.random(in: timeOffset...0))
            }
            commentOffsets.sort()
            
            var responseIndices = Set<Int>()
            if totalComments > 1 {
                var availableIndices = Array(1..<totalComments)
                availableIndices.shuffle()
                for i in 0..<min(numResponses, availableIndices.count) {
                    responseIndices.insert(availableIndices[i])
                }
            }
            
            var commentAuthors: [String] = []
            
            for (index, offset) in commentOffsets.enumerated() {
                let commentAuthor = generateDynamicName()
                let commentIndex = Int.random(in: 1...100000)
                let commentAvatar = Self.avatarForPlayer(index: commentIndex, countrySeed: 0, day: currentDay)
                var commentText = generateDynamicComment(message: message)
                var commentOffset = offset
                
                // If this index is marked as a response, reply to a previous comment
                if responseIndices.contains(index) && !commentAuthors.isEmpty {
                    let replyingTo = commentAuthors.randomElement()!
                    if replyingTo != commentAuthor {
                        // Check if the comment being replied to asks about the next milestone
                        let previousComment = comments.last(where: { $0.authorName == replyingTo })
                        if let prev = previousComment, let answer = milestoneAnswer(for: prev.text) {
                            commentText = "@\(replyingTo) " + answer
                            // Reply sometime after the question but still in the past
                            let questionOffset = prev.createdAt.timeIntervalSince(now)
                            let maxDelay = max(300, abs(questionOffset) * 0.8)
                            commentOffset = min(questionOffset + Double.random(in: 300...maxDelay), 0)
                        } else if let prev = previousComment {
                            commentText = "@\(replyingTo) " + generateContextualReply(to: prev.text, message: message)
                            // Respond sometime after the comment being replied to, but still in the past
                            let prevOffset = prev.createdAt.timeIntervalSince(now)
                            let maxDelay = max(300, abs(prevOffset) * 0.7)
                            commentOffset = min(prevOffset + Double.random(in: 120...maxDelay), 0)
                        } else {
                            commentText = "@\(replyingTo) " + commentText
                        }
                    }
                }
                
                comments.append(SocialFeedComment(
                    authorName: commentAuthor,
                    avatarID: commentAvatar,
                    text: commentText,
                    createdAt: now.addingTimeInterval(commentOffset),
                    likes: Int.random(in: 0...10)
                ))
                
                commentAuthors.append(commentAuthor)
            }
            
            let maxReactions = Int.random(in: 10...50)
            var rTimestamps: [Date] = []
            for _ in 0..<maxReactions {
                let rOffset = Double.random(in: timeOffset...0)
                rTimestamps.append(now.addingTimeInterval(rOffset))
            }
            
            items.append(SocialFeedItem(
                authorName: author,
                avatarID: authorAvatar,
                createdAt: itemDate,
                message: message,
                statText: statText,
                reactionCount: rTimestamps.filter { $0 <= now }.count,
                commentCount: comments.count,
                comments: comments.sorted(by: { $0.createdAt < $1.createdAt }),
                reactionTimestamps: rTimestamps
            ))
        }
        
        return items.sorted(by: { $0.createdAt > $1.createdAt })
    }

    public func searchFriends(query: String) async throws -> [AccountProfile] {
        // Build a pool of names exclusively from leaderboard data
        let codeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        
        // Full pool: all gamertags + some real name combos
        var fullPool: [String] = Array(Self.leaderboardGamertags)
        for firstName in Self.leaderboardRealNames {
            let lastName = Self.leaderboardLastNames[
                abs(firstName.hashValue) % Self.leaderboardLastNames.count
            ]
            fullPool.append("\(firstName) \(lastName)")
        }

        let filtered: [String]
        if query.isEmpty {
            // Browse mode: show a random sample
            filtered = Array(fullPool.shuffled().prefix(20))
        } else {
            // Search mode: search the full pool
            filtered = fullPool.filter { $0.localizedCaseInsensitiveContains(query) }
        }

        return filtered.map { name in
            // Deterministic code based on name so the same player always has the same code
            var hash = name.hashValue
            let left = String((0..<3).map { _ -> Character in
                let idx = abs(hash) % codeChars.count
                hash = hash &* 31 &+ 7
                return codeChars[codeChars.index(codeChars.startIndex, offsetBy: idx)]
            })
            hash = name.hashValue &* 17
            let right = String((0..<3).map { _ -> Character in
                let idx = abs(hash) % codeChars.count
                hash = hash &* 31 &+ 13
                return codeChars[codeChars.index(codeChars.startIndex, offsetBy: idx)]
            })
            return AccountProfile(
                uid: name.replacingOccurrences(of: " ", with: ".").lowercased(),
                displayName: name,
                username: name.replacingOccurrences(of: " ", with: "").lowercased(),
                friendCode: "\(left)-\(right)",
                isAnonymous: false,
                isEmailVerified: true
            )
        }
    }

    public func invites() async throws -> [FamilyInvite] {
        let codeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        func makeCode() -> String {
            let left = String((0..<3).map { _ in codeChars.randomElement()! })
            let right = String((0..<3).map { _ in codeChars.randomElement()! })
            return "\(left)-\(right)"
        }
        let names = Self.leaderboardGamertags.shuffled().prefix(3)
        return [
            FamilyInvite(displayName: String(names[names.startIndex]), emailOrCode: makeCode(), status: "Invited"),
            FamilyInvite(displayName: String(names[names.index(names.startIndex, offsetBy: 1)]), emailOrCode: makeCode(), status: "Can invite"),
            FamilyInvite(displayName: String(names[names.index(names.startIndex, offsetBy: 2)]), emailOrCode: makeCode(), status: "Can invite"),
        ]
    }
    
    private func generateDynamicEvent(milestone: String) -> (message: String, statText: String) {
        let eventType = Int.random(in: 0...5)
        
        let themeNames = ["Classic", "Simple Sage", "Mellow Yellow", "Relaxed Rust", "Cozy Coral"]
        
        switch eventType {
        case 0:
            // Reached a new tile in Endless
            let templates = [
                "Reached the \(milestone) tile in Endless!",
                "Just hit \(milestone) for the first time! 🎯",
                "NEW personal best — \(milestone) tile unlocked in Endless!",
                "\(milestone) tile reached! The grind never stops.",
                "Finally broke through to \(milestone) in Endless mode!",
                "After so many attempts… \(milestone) is MINE! 🏆",
                "Thought \(milestone) was impossible. Proved myself wrong.",
                "\(milestone) achieved on an absolute marathon run.",
            ]
            let stats = [
                "🧩 New tile · Endless",
                "🏅 Milestone · \(milestone)",
                "📈 Personal best · Endless",
                "🔥 Breakthrough · \(milestone)",
                "⭐ New record · Endless",
                "💎 \(milestone) · First reach",
            ]
            return (templates.randomElement()!, stats.randomElement()!)
            
        case 1:
            // Finished today's timed challenge
            let minutes = Int.random(in: 1...8)
            let seconds = Int.random(in: 0...59)
            let timeStr = "\(minutes):\(String(format: "%02d", seconds))"
            
            let openers = [
                "Finished", "Crushed", "Beat", "Cleared", "Completed",
                "Conquered", "Smashed", "Survived", "Dominated", "Nailed",
            ]
            let subjects = [
                "today's timed challenge", "the daily timed challenge",
                "the timed challenge", "this morning's timed run",
                "today's speed challenge", "the daily speed run",
                "the clock challenge", "today's timed board",
                "the timed gauntlet", "this session's challenge",
            ]
            let details = [
                "in \(timeStr)", "with \(timeStr) clear time",
                "at \(timeStr)", "— \(timeStr) flat",
                "with \(timeStr) on the clock", "clocking \(timeStr)",
                "in just \(timeStr)", "with a \(timeStr) finish",
                "\(timeStr) total", "in \(timeStr) sharp",
            ]
            let closers = [
                "!", " ⏱️", " 🚀", ". New strategy worked perfectly.",
                ". That was INTENSE.", " 💨", ". Clean run.",
                ". Not even close.", " — feels good!", ". Let's go!",
            ]
            
            let message = "\(openers.randomElement()!) \(subjects.randomElement()!) \(details.randomElement()!)\(closers.randomElement()!)"
            
            let statEmojis = ["⏱️", "🏁", "⚡", "🎯", "🕐", "💨", "🔥"]
            let statLabels = [
                "Timed challenge · \(timeStr)", "Daily challenge · Done",
                "Speed clear · \(timeStr)", "Challenge · \(timeStr) finish",
                "Today's challenge · Complete", "Timed run · \(timeStr)",
                "Challenge clear · \(timeStr)", "Speed run · Done",
                "Daily timed · \(timeStr)", "Clock beaten · \(timeStr)",
            ]
            return (message, "\(statEmojis.randomElement()!) \(statLabels.randomElement()!)")
            
        case 2:
            // Protected a streak
            let streakDays = Int.random(in: 3...365)
            
            let openers = [
                "Protected", "Saved", "Kept alive", "Defended",
                "Extended", "Preserved", "Secured", "Maintained",
                "Continued", "Locked in",
            ]
            let streakPhrase = [
                "a \(streakDays)-day streak", "the \(streakDays)-day streak",
                "my \(streakDays)-day streak", "day \(streakDays) of the streak",
                "streak day \(streakDays)", "a \(streakDays)d streak",
                "\(streakDays) days straight", "\(streakDays) consecutive days",
                "the streak at \(streakDays) days", "\(streakDays) days running",
            ]
            let closers: [String]
            if streakDays >= 100 {
                closers = [
                    "! 🔥", " — legendary status! 👑",
                    ". Triple digits and counting!", ". This streak is untouchable.",
                    " 💎 Can't stop now.", ". \(streakDays) days deep!",
                    ". Built different.", " — no breaks, no excuses.",
                    ". The grind never stops 🔥", ". Still going strong 💪",
                ]
            } else if streakDays >= 30 {
                closers = [
                    "! 🔥", ". Dedicated! 💪",
                    ". A whole month and beyond!", ". Consistency pays off.",
                    " — keeping the fire alive!", ". Not stopping now.",
                    ". This streak means everything.", " ✅ Locked in.",
                    ". Steady progress!", ". Day by day 🛡️",
                ]
            } else {
                closers = [
                    "! 🔥", ". Every day counts!",
                    ". Almost forgot today 😅", " — close call!",
                    ". Building momentum!", ". Played at 11:58 PM to save it 😅",
                    " ✅", ". Not losing this one.",
                    ". The habit is forming!", ". Streak: protected.",
                ]
            }
            
            let message = "\(openers.randomElement()!) \(streakPhrase.randomElement()!)\(closers.randomElement()!)"
            
            let statEmojis = ["🔥", "🛡️", "📅", "💎", "⭐", "👑", "✅"]
            let statLabels: [String]
            if streakDays >= 100 {
                statLabels = [
                    "\(streakDays)-day streak · Legend", "Streak protected · \(streakDays) days",
                    "Streak · \(streakDays) days", "Streak royalty · \(streakDays)d",
                    "\(streakDays)d streak · Untouchable", "Streak milestone · \(streakDays)",
                ]
            } else if streakDays >= 30 {
                statLabels = [
                    "\(streakDays)-day streak · Dedicated", "Streak protected · \(streakDays) days",
                    "Streak · \(streakDays) days", "\(streakDays)d streak · Committed",
                    "Streak milestone · \(streakDays)", "Daily streak · \(streakDays)d",
                ]
            } else {
                statLabels = [
                    "\(streakDays)-day streak", "Streak protected · Day \(streakDays)",
                    "Streak · \(streakDays) days", "Day \(streakDays) · Saved",
                    "Streak alive · \(streakDays)d", "Daily streak · \(streakDays)",
                ]
            }
            return (message, "\(statEmojis.randomElement()!) \(statLabels.randomElement()!)")
            
        case 3:
            // Joined the Hall of Fame
            let infinityCount = Int.random(in: 1...50)
            
            let openers = [
                "Joined", "Entered", "Made it into", "Reached",
                "Unlocked", "Earned a spot in", "Broke into",
                "Officially in", "Finally reached", "Achieved",
            ]
            let subject = [
                "the Hall of Fame", "HoF", "the Hall of Fame leaderboard",
                "Hall of Fame status", "the infinity club",
                "the Hall of Fame ranks", "HoF glory",
                "the elite Hall of Fame", "the legends board",
                "the Hall of Fame tier",
            ]
            let details: [String]
            if infinityCount > 10 {
                details = [
                    "! Infinity count: \(infinityCount) 👑", " with \(infinityCount) infinities!",
                    "! ∞×\(infinityCount) and climbing!", ". Entry #\(infinityCount) 🏆",
                    "! \(infinityCount) infinity tiles deep.", " — \(infinityCount) infinities strong.",
                    ". Veteran status with \(infinityCount) runs.", "! Can't stop at \(infinityCount).",
                    " with ∞×\(infinityCount). Legendary!", ". \(infinityCount) and counting 🌟",
                ]
            } else if infinityCount > 1 {
                details = [
                    "! 🏆", "! Infinity count: \(infinityCount) 👑",
                    " with \(infinityCount) infinities!", ". The journey was worth it.",
                    "! Entry #\(infinityCount).", " — ∞×\(infinityCount)!",
                    ". \(infinityCount) infinity tiles reached!", ". Still pushing for more.",
                    "! Grinding paid off 🏅", ". \(infinityCount) down, more to go.",
                ]
            } else {
                details = [
                    "! 🏆", "! I actually made it!",
                    " for the first time!", ". The grind paid off!",
                    "! After months of grinding…", " — this one's for the long-term players.",
                    "! They said it couldn't be done 🏅", ". First infinity tile!",
                    "! Welcome to the club!", ". Dream achieved ✨",
                ]
            }
            
            let message = "\(openers.randomElement()!) \(subject.randomElement()!)\(details.randomElement()!)"
            
            let statEmojis = ["🏆", "🏅", "🌟", "👑", "⭐", "💎", "✨"]
            let statLabels: [String]
            if infinityCount > 10 {
                statLabels = [
                    "Hall of Fame · ∞×\(infinityCount)", "HoF veteran · \(infinityCount) infinities",
                    "Legendary · ∞×\(infinityCount)", "HoF · \(infinityCount) runs",
                    "Infinity club · ×\(infinityCount)", "Hall of Fame · \(infinityCount) entries",
                ]
            } else if infinityCount > 1 {
                statLabels = [
                    "Hall of Fame · ∞×\(infinityCount)", "HoF · \(infinityCount) infinities",
                    "Hall of Fame entry", "HoF · ×\(infinityCount)",
                    "Infinity reached · ×\(infinityCount)", "Hall of Fame · Active",
                ]
            } else {
                statLabels = [
                    "Hall of Fame · First entry!", "HoF · Welcome!",
                    "Hall of Fame · ∞ achieved", "First infinity · HoF",
                    "Hall of Fame · Debut", "HoF · Entry #1",
                ]
            }
            return (message, "\(statEmojis.randomElement()!) \(statLabels.randomElement()!)")
            
        case 4:
            // Unlocked a new theme
            let theme = themeNames.randomElement()!
            
            let openers = [
                "Unlocked", "Grabbed", "Activated", "Equipped",
                "Switched to", "Just got", "Earned", "Picked up",
                "Finally unlocked", "Snagged",
            ]
            let subjects = [
                "the \(theme) theme", "\(theme)", "the \(theme) board theme",
                "the \(theme) look", "the \(theme) style",
                "the \(theme) aesthetic", "\(theme) vibes",
                "the \(theme) board", "a fresh \(theme) theme",
                "the \(theme) color palette",
            ]
            let closers = [
                "! 🎨", ". The board looks amazing!",
                " — time to play in style.", "! Worth every gem.",
                " and it changes the whole vibe 🌈", ". Even better than I expected!",
                " 🔔 Fresh look alert!", ". New look, who dis?",
                ". So clean!", " — best theme in the game.",
            ]
            
            let message = "\(openers.randomElement()!) \(subjects.randomElement()!)\(closers.randomElement()!)"
            
            let statEmojis = ["🎨", "✨", "🖌️", "💫", "🎭", "🌈", "🔔"]
            let statLabels = [
                "Theme unlocked · \(theme)", "New theme · \(theme)",
                "Customization · \(theme)", "\(theme) · Unlocked",
                "New style · \(theme)", "Board theme · \(theme)",
                "Theme equipped · \(theme)", "Fresh look · \(theme)",
                "\(theme) · Activated", "Style update · \(theme)",
            ]
            return (message, "\(statEmojis.randomElement()!) \(statLabels.randomElement()!)")
            
        default:
            // Completed the Daily Quest
            let questTier = ["Bronze", "Silver", "Gold", "Diamond"].randomElement()!
            let gemsEarned = [50, 100, 150, 200, 250, 300, 500].randomElement()!
            
            let openers = [
                "Completed", "Finished", "Cleared", "Knocked out",
                "Wrapped up", "Crushed", "Done with", "Conquered",
                "Smashed through", "Swept",
            ]
            let subjects = [
                "the Daily Quest", "today's quests", "all daily quests",
                "today's Daily Quest", "every quest objective",
                "the daily objectives", "today's quest log",
                "the full quest line", "all three quests",
                "the daily mission set",
            ]
            let details = [
                "! \(questTier) chest earned 🎁",
                " — \(questTier) reward chest grabbed.",
                "! +\(gemsEarned) gems 💎",
                ". \(questTier) tier. Easy gems today.",
                " before lunch! \(questTier) chest 🏆",
                " — all objectives done!",
                ". \(questTier) chest opened for \(gemsEarned) gems.",
                ". That \(questTier) chest was worth it.",
                "! \(gemsEarned) gems richer now.",
                ". \(questTier) chest in the bag!",
            ]
            
            let message = "\(openers.randomElement()!) \(subjects.randomElement()!)\(details.randomElement()!)"
            
            let statEmojis = ["📋", "🎁", "✅", "🏅", "📦", "💎", "🎯"]
            let statLabels = [
                "Daily Quest · \(questTier)", "Quest complete · +\(gemsEarned) 💎",
                "Daily Quest · Done", "\(questTier) quest · Complete",
                "Quest chest · \(questTier)", "Quests cleared · \(questTier)",
                "Daily objectives · Done", "Quest rewards · \(gemsEarned) 💎",
                "\(questTier) chest · Opened", "Quest log · Cleared",
            ]
            return (message, "\(statEmojis.randomElement()!) \(statLabels.randomElement()!)")
        }
    }
    
    private func generateDynamicComment(message: String) -> String {
        let openers = [
            "Dude,", "Omg,", "Wow,", "Bro,", "Honestly,", "Crazy,", "Yoo,",
            "No way,", "Wait,", "Bruh,", "Sheesh,", "Yo,", "Ngl,", "Ayo,",
            "",
        ]
        var subjects = [
            "that run", "your board", "your progress", "that score", "this setup",
            "your grid", "the late game", "your strategy", "that chain", "this result",
            "your merge path", "this endgame", "your tile placement",
        ]
        let verbs = [
            "is", "looks", "feels", "was", "seems", "hits different",
            "sounds", "turned out", "ended up", "came out",
        ]
        let adjectives = [
            "insane", "amazing", "unreal", "so clean", "mind-blowing", "crazy",
            "perfect", "solid", "epic", "brilliant", "next level", "flawless",
            "wild", "godly", "legendary", "nuts", "chef's kiss", "top tier",
        ]
        
        var positiveReactions = [
            "GG!", "Nice!", "Incredible!", "Keep it up!", "Let's go!", "Fire!",
            "Huge!", "Well deserved!", "Too good!", "Teach me!", "What a play!",
            "Respect!", "Built different.", "Massive W!", "That's elite!",
        ]
        var jealousReactions = [
            "So jealous", "I can't even get past 1M", "My board never looks like that",
            "How is that even possible", "You make it look so easy",
            "I'm stuck on the previous tier", "I always lose right here",
            "Meanwhile I'm still struggling", "Must be nice",
            "I wish my runs went like that", "Pain. Just pain.",
            "I keep choking at this point", "Why can't I do this",
        ]
        var competitiveReactions = [
            "I am going to reach higher milestones than you!",
            "Watch your back, I'm catching up.", "Enjoy it while it lasts.",
            "My next run will beat that.", "I'm coming for your spot.",
            "You won't be ahead for long.", "Game on.",
            "Challenge accepted.", "That record is mine tomorrow.",
            "I'll be posting my own soon.", "Not impressed, I'm right behind you.",
            "Hold my tiles.", "Say less, I'm locking in.",
        ]
        var questions = [
            "How long did that take?", "What's your secret?", "Any tips for this tier?",
            "How many moves did it take?", "Did you use any swaps?", "Was it tough?",
            "Can I add you?", "Do you play every day?", "What perks did you use?",
            "How many attempts was that?", "Were you using a hammer?",
            "What's your total playtime?", "Did you plan that chain or was it luck?",
        ]
        
        // Symbols categorized by tone
        let positiveSymbols = ["!!", " :)", " :D", " xD", " ~", " :P", " <3", " =)", " ^_^", " ;-)", " :-)", "🔥", "🙌", "🚀", "👏", "💪", "🏆", "✨"]
        let questionSymbols = ["?!", "...", "👀", "🤔", "??", "!!?"]
        let sadOrJealousSymbols = [" :(", " :((", " >:(", " :/", " ;-(", " -_-", " >_<", "...", "😩", "😭", "💀", "🫠"]
        let competitiveSymbols = [" >:)", " 👀", " 😈", " ⚔️", " 🎯", " 😏", " 🏁", " 💨"]
        let keyboardSymbols = ["~", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "-", "=", "{", "}", "[", "]", "|", "\\", ":", ";", "\"", "'", "<", ">", ",", ".", "?", "/"]
        
        // Dynamically inject topic-specific subjects based on the feed item's message
        if message.contains("Hall of Fame") {
            subjects.append(contentsOf: [
                "that HoF entry", "joining the Hall of Fame", "this legendary status",
                "reaching the end", "that infinity rank", "your HoF grind",
                "the infinity milestone", "that Hall of Fame badge", "becoming a legend",
                "this HoF moment",
            ])
        } else if message.contains("streak") {
            subjects.append(contentsOf: [
                "that streak", "your daily consistency", "keeping it alive",
                "that commitment", "your dedication", "the streak grind",
                "never missing a day", "your login streak", "that daily discipline",
                "showing up every day",
            ])
        } else if message.contains("timed challenge") {
            subjects.append(contentsOf: [
                "that time", "your speed", "the daily run", "that clear time",
                "your reaction speed", "the clutch finish", "that speedrun",
                "your timed performance", "beating the clock", "that pace",
            ])
        } else if message.contains("theme") {
            subjects.append(contentsOf: [
                "that new theme", "your new aesthetic", "the customization",
                "the new board look", "your style choice", "that color palette",
                "the fresh vibes", "that theme swap", "the new visual",
                "your board makeover",
            ])
        } else if message.contains("Quest") {
            subjects.append(contentsOf: [
                "that quest completion", "finishing the dailies", "getting those rewards",
                "clearing all objectives", "that quest grind", "the daily hustle",
                "knocking out quests", "that chest pull", "completing every quest",
                "the quest speedrun",
            ])
        }
        
        // Dynamically inject topic-specific reactions based on the feed item's message
        if message.contains("Hall of Fame") {
            positiveReactions.append(contentsOf: [
                "Welcome to the Hall of Fame!", "HoF! That's massive.",
                "See you on the infinity leaderboard!", "Legendary!",
                "The ultimate achievement!", "HoF gang!",
                "You earned that spot.", "Top of the mountain!",
                "That's endgame right there.", "Hall of Fame royalty!",
            ])
            jealousReactions.append(contentsOf: [
                "I'll never reach the Hall of Fame", "How long did it take to get to HoF?",
                "I'm still grinding for HoF", "HoF feels so far away for me",
                "I dream about reaching HoF", "One day I'll join you there",
                "Still so many tiles between me and HoF",
                "I've been trying to reach HoF for months",
                "That's literally my end goal", "HoF is my white whale",
            ])
            competitiveReactions.append(contentsOf: [
                "I will join the Hall of Fame and have a higher infinity count than you!",
                "My infinity count will be bigger than yours.",
                "I'm coming for your HoF spot.", "I'll have more infinities by next week.",
                "Just wait until I get my HoF entry.",
                "I'll be right behind you in the rankings.",
                "My HoF push starts today.", "I'm going to pass your infinity count.",
                "See you on the leaderboard soon.", "That HoF record won't last.",
            ])
            questions.append(contentsOf: [
                "How many infinity counts do you have?",
                "Are you going for a high infinity count?",
                "What's the next goal after HoF?",
                "How many runs did it take to reach HoF?",
                "What was the hardest part of the HoF grind?",
                "Did you use any perks on the final push?",
                "What tile were you stuck on the longest?",
                "How long have you been playing to reach HoF?",
                "Any advice for someone aiming for HoF?",
                "What's your infinity count goal?",
            ])
        } else if message.contains("streak") {
            positiveReactions.append(contentsOf: [
                "Nice streak!", "Don't lose it!", "Streak master!",
                "Way to keep the fire going.", "Day by day!",
                "Consistency is key!", "That's real dedication.",
                "Streak warrior!", "Keep that flame alive!",
                "Unbreakable streak energy!",
            ])
            jealousReactions.append(contentsOf: [
                "I lost my streak yesterday", "How do you remember every day?",
                "I can never keep a streak going", "My longest streak was like 5 days",
                "I keep forgetting to log in", "Streaks stress me out",
                "I lost a 30-day streak last week", "My streak always dies on weekends",
                "I wish I had that consistency", "I'm so bad at maintaining streaks",
            ])
            competitiveReactions.append(contentsOf: [
                "My streak is longer than yours.", "I'm catching up to your streak.",
                "I haven't missed a day in months.", "My streak will outlast yours.",
                "That's cute, check mine.",
                "My streak started before yours.", "I'm never breaking my streak.",
                "Wait until you see my streak count.", "Streak vs streak, let's go.",
            ])
            questions.append(contentsOf: [
                "How long is your streak now?", "Did you ever use a streak freeze?",
                "Have you ever lost a long streak?", "What's your all-time best streak?",
                "Do you set a reminder?", "What time do you usually play?",
                "Has the streak ever been in danger?", "Do you play first thing in the morning?",
                "What keeps you motivated for the streak?", "Ever almost forgot?",
            ])
        } else if message.contains("timed challenge") {
            positiveReactions.append(contentsOf: [
                "Fast hands!", "Speed demon!", "Nice clear time!",
                "Lightning fast!", "That's a blazing time!",
                "Clock demolished!", "Speedrunner vibes!",
                "Time is no obstacle for you!", "Built for speed!",
                "That pace is unreal!",
            ])
            jealousReactions.append(contentsOf: [
                "I ran out of time today", "I couldn't beat the clock",
                "You finished so fast", "I always choke under pressure",
                "Timed challenges stress me out", "I need like double that time",
                "My hands aren't fast enough", "I panic when the timer starts",
                "I can never think that quickly", "Time pressure is my worst enemy",
            ])
            competitiveReactions.append(contentsOf: [
                "I bet my time was faster.", "I'll beat your time tomorrow.",
                "My PB is lower than that.", "I'm the real speed king.",
                "That time is beatable.", "I'll sub that time easy.",
                "Tomorrow I'm going for the record.", "My clear was cleaner.",
                "I shaved 30 seconds off my best today.", "Speed challenge accepted.",
            ])
            questions.append(contentsOf: [
                "What was your exact time?", "Did you pause at all?",
                "What's your fastest ever?", "Did you use a hammer during the run?",
                "How do you plan moves so fast?", "Do you practice speed runs?",
                "What's your average clear time?", "Any speed tips?",
                "Do you go for speed or safety?", "Was that your first attempt today?",
            ])
        } else if message.contains("theme") {
            positiveReactions.append(contentsOf: [
                "Love that theme!", "Looks so fresh.", "Best theme in the game.",
                "So pretty.", "That theme hits different.", "Clean aesthetic!",
                "Your board looks amazing now!", "Perfect choice!",
                "That theme is gorgeous.", "10/10 theme pick!",
            ])
            jealousReactions.append(contentsOf: [
                "I'm still trying to unlock that one", "I want that theme so bad",
                "I don't have enough gems for it", "That's the theme I've been saving for",
                "Why do the best themes cost so much", "I'm still on the default theme",
                "Gem grind for that theme is real", "I need more gems for themes",
                "Saving every gem for that exact theme", "I keep spending gems on perks instead",
            ])
            competitiveReactions.append(contentsOf: [
                "My theme is better.", "I have all the themes unlocked.",
                "I had that theme ages ago.", "Wait until you see mine.",
                "I unlocked every theme already.", "That's my second favorite theme.",
                "I switch themes every week.", "My collection is complete.",
                "I unlocked that one first day.", "Try collecting them all like me.",
            ])
            questions.append(contentsOf: [
                "Which theme is that?", "How much did that cost?",
                "How many gems was it?", "Is that your favorite theme?",
                "Do you switch themes often?", "Which theme do you use most?",
                "How many themes have you unlocked?", "Was it worth the gems?",
                "What's the rarest theme?", "Does it change the tile colors too?",
            ])
        } else if message.contains("Quest") {
            positiveReactions.append(contentsOf: [
                "Quest complete!", "Enjoy the rewards!", "Easy gems.",
                "Clean sweep!", "Dailies crushed!", "Nice haul!",
                "Quest master!", "That chest was earned!",
                "Objectives demolished!", "Well played on the quests!",
            ])
            jealousReactions.append(contentsOf: [
                "I'm only halfway done with mine", "Those quests were so hard today",
                "I never finish all the quests", "My quests are always impossible",
                "I got stuck on the last objective", "I keep running out of time for quests",
                "The quest RNG hates me", "I got the hardest quests today",
                "I can never finish before reset", "Wish my quests were that easy",
            ])
            competitiveReactions.append(contentsOf: [
                "I finished mine hours ago.", "I always finish quests faster.",
                "I had those done by breakfast.", "My chest was better.",
                "I got Diamond tier today.", "Quests are too easy honestly.",
                "I speed-clear quests every day.", "I've finished every quest this month.",
                "My quest streak is untouched.", "I finish dailies on my first game.",
            ])
            questions.append(contentsOf: [
                "What did you get from the chest?", "Were your quests hard?",
                "What tier chest was it?", "How long did the quests take?",
                "Do you do quests first thing?", "Which quest was the hardest?",
                "Did you get any good gems?", "What's the best chest you've ever pulled?",
                "Do you always finish all three?", "Any quest tips for new players?",
            ])
        }
        
        // Detect specific milestones if present in the message
        let sortedMilestones = Self.allMilestones.sorted(by: { $0.count > $1.count })
        if let foundMilestone = sortedMilestones.first(where: { message.contains(" \($0) ") }) {
            let m = foundMilestone
            if Double.random(in: 0...1) < 0.6 {
                subjects.append(contentsOf: [
                    "that \(m)", "hitting \(m)", "your \(m)", "this \(m) run",
                    "reaching \(m)", "the \(m) grind", "breaking into \(m)",
                    "your \(m) push", "that \(m) breakthrough", "landing \(m)",
                ])
                positiveReactions.append(contentsOf: [
                    "GG on \(m)!", "\(m) is huge!", "Congrats on \(m)!",
                    "\(m)! Let's go!", "Massive \(m) hit!", "Big \(m) energy!",
                    "\(m) club!", "Welcome to \(m)!", "\(m) earned!",
                    "\(m) is no joke, well done!",
                ])
                jealousReactions.append(contentsOf: [
                    "I can't even get to \(m)", "How did you get \(m) so fast?",
                    "I always lose before \(m)", "I've been stuck before \(m) forever",
                    "\(m) feels impossible for me", "I choke right before \(m)",
                    "My board always falls apart near \(m)",
                    "I keep dying one tile before \(m)",
                    "\(m) is my wall right now", "Maybe someday I'll reach \(m)",
                ])
                competitiveReactions.append(contentsOf: [
                    "I'm getting past \(m) today.", "I'll beat your \(m).",
                    "I passed \(m) last week.", "My \(m) run was cleaner.",
                    "\(m) is old news for me.", "I'll be past \(m) by tonight.",
                    "Already beyond \(m) personally.", "My \(m) time was faster.",
                    "I hit \(m) without any perks.", "\(m)? I'm aiming higher.",
                ])
                questions.append(contentsOf: [
                    "Any tips for getting \(m)?", "Was \(m) tough?",
                    "How many tries for \(m)?", "What's the strategy near \(m)?",
                    "Did you use perks at \(m)?", "How long to reach \(m)?",
                    "What comes after \(m)?", "Is \(m) a big wall?",
                    "What tile was hardest before \(m)?", "Any perk recommendations for \(m)?",
                ])
            }
        }
        
        // Weighted category roll: 55% competitive, 25% positive, 15% question, 5% jealous
        var comment = ""
        var tone = "positive"
        let roll = Double.random(in: 0..<1)
        
        if roll < 0.55 {
            // ── Competitive (55%) — standalone, no opener ──
            comment = competitiveReactions.randomElement()!
            tone = "competitive"
        } else if roll < 0.80 {
            // ── Positive (25%) — with opener + subject/verb/adj ──
            let opener = openers.randomElement()!
            if Bool.random() {
                let core = "\(subjects.randomElement()!) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
                comment = opener.isEmpty ? core.capitalized + "!" : "\(opener) \(core)!"
            } else {
                let reaction = positiveReactions.randomElement()!
                comment = opener.isEmpty ? reaction : "\(opener) \(reaction.lowercased())"
            }
            tone = "positive"
        } else if roll < 0.95 {
            // ── Question (15%) — standalone, no opener ──
            comment = questions.randomElement()!
            tone = "question"
        } else {
            // ── Jealous (5%) — with opener ──
            let opener = openers.randomElement()!
            let reaction = jealousReactions.randomElement()!
            comment = opener.isEmpty ? reaction.capitalized : "\(opener) \(reaction.lowercased())"
            tone = "sad"
        }
        
        if Double.random(in: 0...1) < 0.75 {
            let symbol: String
            switch tone {
            case "positive": symbol = positiveSymbols.randomElement()!
            case "question": symbol = questionSymbols.randomElement()!
            case "sad": symbol = sadOrJealousSymbols.randomElement()!
            case "competitive": symbol = competitiveSymbols.randomElement()!
            default: symbol = ""
            }
            comment += symbol
        } else if Double.random(in: 0...1) < 0.1 {
            // 2.5% chance for a random raw keyboard symbol (like a typo)
            comment += keyboardSymbols.randomElement()!
        }
        
        return comment.trimmingCharacters(in: .whitespaces)
    }
    
    /// Returns a milestone-aware answer if the text asks "what comes after [milestone]".
    private func milestoneAnswer(for text: String) -> String? {
        let lowered = text.lowercased()
        guard lowered.contains("what comes after") || lowered.contains("what's after")
              || lowered.contains("whats after") || lowered.contains("what is after") else {
            return nil
        }
        // Search longest-first to avoid partial matches (e.g. "2" inside "262K")
        let sorted = Self.allMilestones.enumerated().sorted { $0.element.count > $1.element.count }
        for (idx, milestone) in sorted {
            if text.contains(milestone), idx + 1 < Self.allMilestones.count {
                let next = Self.allMilestones[idx + 1]
                let templates = [
                    "\(next) comes after \(milestone).",
                    "After \(milestone) it's \(next)!",
                    "The next tile after \(milestone) is \(next).",
                    "\(milestone) → \(next). Keep pushing!",
                    "\(next)! That's what's after \(milestone).",
                ]
                return templates.randomElement()!
            }
        }
        return nil
    }

    /// Generates a contextual reply that responds to what the previous comment actually said.
    private func generateContextualReply(to commentText: String, message: String) -> String {
        let lowered = commentText.lowercased()

        // Strip any leading @mention from the comment so we analyze the real content
        let strippedText: String = {
            if lowered.hasPrefix("@") {
                let parts = commentText.split(separator: " ", maxSplits: 1)
                return parts.count > 1 ? String(parts[1]) : commentText
            }
            return commentText
        }()
        let strippedLower = strippedText.lowercased()

        // ── Detect the tone/intent of the comment being replied to ──

        let questionKeywords = ["?", "how", "what", "any tips", "did you", "do you", "how long", "how many", "which", "when", "can i", "could you", "is it", "was it"]
        let isQuestion = questionKeywords.contains(where: { strippedLower.contains($0) })

        let competitiveKeywords = ["beat", "catching up", "coming for", "won't last", "watch your back", "game on", "challenge", "mine tomorrow", "i'll be", "i'm going to", "not impressed", "my time", "faster", "i passed", "old news", "hold my"]
        let isCompetitive = competitiveKeywords.contains(where: { strippedLower.contains($0) })

        let jealousKeywords = ["can't even", "stuck", "i always lose", "impossible", "struggling", "must be nice", "pain", "i wish", "jealous", "i keep", "never", "i don't have", "so bad at", "still trying", "can never"]
        let isJealous = jealousKeywords.contains(where: { strippedLower.contains($0) })

        let positiveKeywords = ["gg", "nice", "incredible", "amazing", "congrats", "respect", "huge", "well done", "let's go", "fire", "legendary", "awesome", "love", "perfect", "clean", "gorgeous", "elite"]
        let isPositive = positiveKeywords.contains(where: { strippedLower.contains($0) })

        let addFriendKeywords = ["can i add", "add you", "add me", "friend code", "friend request", "be friends", "play together"]
        let isAddRequest = addFriendKeywords.contains(where: { strippedLower.contains($0) })

        // ── Generate contextual replies based on detected intent ──

        if isAddRequest {
            let replies = [
                "Sure! My code is in my profile 🤝",
                "Absolutely, add me anytime!",
                "Yeah let's link up! Check my profile.",
                "Of course! Always looking for friends 😊",
                "Go for it! More competition is always fun.",
                "Yes! Send me a friend request 🎮",
                "For sure — the more the merrier!",
                "Definitely! Let's compete together.",
            ]
            return replies.randomElement()!
        }

        if isQuestion {
            // Reply with an answer-style response
            var answers = [
                "Honestly, just keep grinding and it clicks.",
                "Took me a while, but consistency helps a lot.",
                "The trick is patience and keeping lanes open.",
                "I usually plan 3-4 moves ahead. That helps.",
                "Just practice! Everyone struggles at first.",
                "No special trick, just played a LOT 😅",
                "Focus on keeping one corner anchored.",
                "Perks help but they're not required.",
                "A few attempts honestly. Not gonna lie it was rough.",
                "I watched some replays to figure out the pattern.",
            ]
            // Topic-specific answers
            if message.contains("Hall of Fame") {
                answers.append(contentsOf: [
                    "Took about 3 months of daily play to get to HoF.",
                    "The key is never giving up once you're past the 'a' tiers.",
                    "Keep pushing through the alphabet tiers and you'll get there.",
                    "Honestly the hardest part was the 'z' to 'aa' transition.",
                ])
            } else if message.contains("streak") {
                answers.append(contentsOf: [
                    "I set a phone reminder every evening.",
                    "Play right after waking up — never miss!",
                    "Almost lost it twice, but pulled through 😅",
                    "The first week is the hardest, then it becomes habit.",
                ])
            } else if message.contains("timed") || message.contains("speed") {
                answers.append(contentsOf: [
                    "Speed comes from pattern recognition. Keep at it!",
                    "I don't overthink — just go with instinct.",
                    "Practice the daily challenge every day, times drop naturally.",
                    "Quick swipes and no second-guessing. That's my style.",
                ])
            } else if message.contains("theme") {
                answers.append(contentsOf: [
                    "Worth every gem, honestly!",
                    "I've been saving up for weeks for this one.",
                    "It changes the whole feel of the game.",
                    "The colors on this theme are so soothing.",
                ])
            } else if message.contains("Quest") || message.contains("quest") {
                answers.append(contentsOf: [
                    "I always start with the hardest quest first.",
                    "Today's quests were actually pretty easy.",
                    "The chest rewards are so worth it.",
                    "I try to knock them out in my first session.",
                ])
            }
            return answers.randomElement()!
        }

        if isCompetitive {
            // Reply to competitive trash talk
            let replies = [
                "Bring it on 😏",
                "We'll see about that 👀",
                "Talk is cheap — show me the screenshot 📸",
                "I'll be waiting at the top 🏔️",
                "Lol good luck with that 😂",
                "Respect the confidence! Let's see it.",
                "Actions speak louder than comments 💪",
                "Keep that same energy next week 😈",
                "I love the competition honestly!",
                "You're on. May the best player win.",
                "Haha alright, consider this a rivalry.",
                "Come find me on the leaderboard then 🎯",
            ]
            return replies.randomElement()!
        }

        if isJealous {
            // Reply encouragingly to jealous/struggling comments
            let replies = [
                "You'll get there! Just keep playing 💪",
                "I was in the same spot a few weeks ago. Don't give up!",
                "Honestly, it took me forever too. Patience is key.",
                "Everyone progresses at their own pace. You got this!",
                "Trust the process — breakthroughs happen randomly.",
                "I believe in you! Keep grinding 🔥",
                "We all hit walls. The fun is breaking through them.",
                "It'll click eventually. Happened to me too!",
                "Keep at it! The struggle makes the win sweeter.",
                "Don't worry, half the fun is the journey.",
                "Seriously, I almost quit before my breakthrough. Stay with it.",
                "You're closer than you think 🙌",
            ]
            return replies.randomElement()!
        }

        if isPositive {
            // Reply to compliments/positive reactions
            let replies = [
                "Thanks! 🙌",
                "Appreciate it! 😊",
                "Right back at you!",
                "Thanks, means a lot!",
                "Haha thanks! Keep grinding too!",
                "Thank you! We're all in this together 🔥",
                "❤️ appreciate the love!",
                "Thanks! Your turn next!",
                "Cheers! Good luck on your runs!",
                "Ty! See you on the leaderboard!",
                "So kind! Thank you 😄",
                "Aww thanks! This community is the best.",
            ]
            return replies.randomElement()!
        }

        // ── Fallback: generic but still conversational ──
        let fallbacks = [
            "Honestly, your grid was perfect. Can I add you? 🤝",
            "Facts. That's exactly how I see it too.",
            "Couldn't have said it better myself.",
            "Haha right? This game is something else.",
            "For real though! 💯",
            "Completely agree with this.",
            "Yo same energy over here 😄",
            "That's what I'm saying!",
            "Big facts! 🔥",
            "We need more of this in the feed honestly.",
            "Love seeing this kind of energy.",
            "This right here. 👆",
        ]
        return fallbacks.randomElement()!
    }

    // Gamertags from the global leaderboard (exact match to LeaderboardClient.globalNames)
    private static let leaderboardGamertags = [
        "DefenselessMetal113090", "LopingLemming366775", "DensePage606454", "BrittleBelly378166", "PerfectPirate002198",
        "CaramelStamp540035", "Player006362", "CulturalDerision125825", "KnownOwner816617", "SwiftCoder159607",
        "PixelMaster748740", "NeonRacer607539", "CloudJumper689506", "StarGazer002024", "ThunderBolt507614",
        "CryptoKing712740", "MidnightOwl188137", "SolarFlare036196", "OceanWave878869", "MountainPeak660972",
        "DesertStorm875175", "JungleCat510460", "ArcticFox939275", "TropicalBird570541", "CosmicDust555331",
        "QuantumLeap035256", "NebulaStar541366", "GalaxyRider213281", "AsteroidHunter307929", "CometChaser943999",
        "MeteorShower490180", "SaturnRing106251", "JupiterMoon945882", "MarsRover652511", "VenusFlyer746976",
        "MercuryDash434165", "PlutoExplorer378313", "NeptuneWave575300", "UranusOrbit060276", "EarthGuard724482",
        "SunBlaze762087", "MoonWalker401411", "StarDancer746126", "SpacePilot446429", "RocketMan803508",
        "LaserBeam193628", "PhotonBlast369925", "NeutronStar967846", "ProtonPower572084", "ElectronFlow288169",
        "AtomSmasher302943", "MoleculeMix835494", "CellDivider926550", "DNAHelix431818", "RNAStrand123317",
        "ProteinFold990603", "EnzymeCat244951", "VitaminBoost636173", "MineralRock121189", "CrystalClear873097",
        "DiamondEdge628696", "RubyGlow895754", "SapphireShine479114", "EmeraldDream535535", "AmethystMist642606",
        "TopazSun210254", "OpalMoon281552", "PearlOcean894781", "JadeForest723448", "OnyxShadow478670",
        "GarnetFire754374", "TurquoiseSky641687", "CoralReef948207", "IvoryTower682707", "BronzeAge633030",
        "SilverLining743365", "GoldRush682418", "PlatinumPro917381", "TitaniumStrong231738", "CopperGlow256951",
        "IronWill317193", "SteelNerve121543", "AluminumLight184188", "ZincShield809081", "NickelSpin810647",
        "CobaltBlue134447", "ChromeFinish771732", "TungstenTough258394", "MolybdenumMax376493", "VanadiumVibe172034",
        "ManganeseMight774509", "PalladiumPure453084", "RhodiumRare101269", "IridiumIntense672277", "OsmiumOdd233561",
        "RheniumRich695253", "TantalumTwist258498", "HafniumHigh509980", "ZirconiumZest230030", "NiobiumNova237940",
        "TokyoTiger778294", "LondonLion245602", "ParisPanther498589", "BerlinBear008218", "SydneySerpent634772",
        "TorontoTornado515976", "MadridMaverick983643", "RomeRaider184724", "SaoPauloStar483164", "MumbaiMaster482711",
        "ShanghaiShark890139", "MoscowMight810148", "DubaiDragon354547", "SingaporeSurge500873", "HongKongHero351162",
        "SeoulSniper578452", "BangkokBolt182848", "JakartaJet643384", "CairoChamp081350", "LagoosLegend866099",
        "NairobiNinja892405", "CapeTownCrush621130", "BuenosAiresBoss725008", "MexicoCityMaster392481", "LimaaLion485983",
        "SantiagoStorm444097", "BogotaBeast471443", "CaracasChamp147285", "HavannaHawk401550", "KingstonKing737312",
        "MontrealMaverick378582", "VancouverVictor981419", "MelbourneMight815557", "AucklandAce491276", "WellingtonWolf315877",
        "OsakaOracle255633", "KyotoKnight377863", "NagoyaNinja611040", "FukuokaaFury815070", "SapporoStrike777002",
        "MunichMaster942913", "HamburgHero964803", "FrankfurtFlash676648", "CologneCrusher742603", "DusseldorfDragon908503",
        "AmsterdamAce262368", "BrussellsBoss822873", "ViennaViking160358", "ZurichZealot419278", "GenevaGhost254315",
        // Hall of Fame gamertags (exact match to LeaderboardClient.hallOfFameNames)
        "InfinityMaster462572", "EndlessVoyager", "BeyondLimits422678", "EternalChamp", "UltimatePlayer",
        "LegendaryGamer", "InfiniteWinner", "CosmicConqueror", "SupremeVictor", "DivinePlayer",
        "MythicalHero", "TranscendentOne", "OmnipotentGamer", "CelestialKing", "ImmortalPlayer",
        "UnstoppableForce", "PerfectScore571450", "FlawlessVictory", "AbsoluteChamp", "MaxLevelPro",
        "GodTierPlayer", "EliteInfinity", "MasterOfAll", "ChampOfChamps", "NumberOneForever",
        "SkillMaxed367578", "TopDogForever", "KingOfKings", "QueenSupreme", "UltimateVictory",
        "BeyondPerfect", "EndgameBoss", "FinalFormPro", "MaxPowerUser", "InfiniteGlory",
        "EternalVictory", "LimitBreaker661070", "BoundlessSkill", "NeverEndingWin", "ForeverFirst",
        "AlphaOmega531681", "ZenithReached", "ApexPredator099366", "PinnaclePlayer", "SummitSeeker",
        "VanguardVictor", "ParagonPrime", "SupremeSeeker", "TitanTamer", "OlympianOne",
        "PhoenixRisen", "DragonSlayer864745", "ThunderGod795666", "StormBringer", "LightningLord",
        "ShadowMaster", "VoidWalker214877", "CosmicRuler", "GalacticKing", "UniversalChamp",
        "StarForger112263", "NebulaNinja", "QuantumKing911350", "DimensionLord", "RealityBender",
        "SpeedStar545327", "FastFury575123", "QuickQueen", "RapidRuler", "SwiftStar",
        "WolfWarrior218074", "FoxFury352370", "BearBoss", "TigerTitan", "LionLord",
    ]

    // Real names from the leaderboard (exact match to LeaderboardClient.realNames)
    private static let leaderboardRealNames = [
        "James", "Michael", "Robert", "David", "William", "John", "Richard", "Thomas", "Chris", "Daniel",
        "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Joshua", "Kevin", "Brian", "George",
        "Emma", "Olivia", "Sophia", "Isabella", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn", "Abigail",
        "Emily", "Elizabeth", "Sofia", "Avery", "Ella", "Scarlett", "Grace", "Chloe", "Victoria", "Riley",
        "Carlos", "Miguel", "Luis", "Jose", "Juan", "Diego", "Alejandro", "Javier", "Fernando", "Rafael",
        "Maria", "Carmen", "Rosa", "Ana", "Lucia", "Elena", "Isabel", "Sofia", "Valentina", "Camila",
        "Hans", "Klaus", "Wolfgang", "Heinrich", "Friedrich", "Dieter", "Helmut", "Werner", "Gerhard", "Manfred",
        "Pierre", "Jean", "Jacques", "François", "Michel", "Philippe", "Alain", "Bernard", "Christophe", "Thierry",
        "Marco", "Giuseppe", "Giovanni", "Francesco", "Antonio", "Alessandro", "Andrea", "Luca", "Matteo", "Lorenzo",
        "Hiroshi", "Takeshi", "Kenji", "Yuki", "Haruto", "Sota", "Ren", "Kaito", "Asahi", "Minato",
        "Minho", "Jiwon", "Seojun", "Dohyun", "Hajun", "Junwoo", "Siwoo", "Yejun", "Jiho", "Junseo",
        "Wei", "Fang", "Lei", "Jun", "Ming", "Tao", "Hao", "Chen", "Lin", "Jian",
        "Raj", "Amit", "Vikram", "Rahul", "Arjun", "Aditya", "Rohan", "Karan", "Nikhil", "Sanjay",
        "Pedro", "Lucas", "Gabriel", "Matheus", "Guilherme", "Bruno", "Felipe", "Gustavo", "Leonardo",
        "Ivan", "Dmitri", "Alexei", "Sergei", "Nikolai", "Viktor", "Andrei", "Pavel", "Mikhail", "Oleg",
        "Ahmed", "Mohamed", "Ali", "Omar", "Hassan", "Yusuf", "Ibrahim", "Khalid", "Tariq", "Nasser",
        "Erik", "Lars", "Anders", "Magnus", "Olaf", "Bjorn", "Sven", "Gunnar", "Harald", "Leif",
    ]

    // Last names from the leaderboard (exact match to LeaderboardClient.lastNames)
    private static let leaderboardLastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Anderson",
        "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark",
        "Lewis", "Robinson", "Walker", "Hall", "Young", "King", "Wright", "Hill", "Scott", "Green",
        "Garcia", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Perez", "Sanchez", "Ramirez", "Torres",
        "Mueller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann",
        "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau",
        "Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco",
        "Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato",
        "Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim",
        "Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou",
        "Sharma", "Patel", "Singh", "Kumar", "Gupta", "Verma", "Reddy", "Joshi", "Rao", "Mehta",
        "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes",
        "Ivanov", "Smirnov", "Kuznetsov", "Popov", "Vasiliev", "Petrov", "Sokolov", "Mikhailov", "Fedorov", "Morozov",
        "Al-Rashid", "Al-Farsi", "Al-Hassan", "Al-Mansour", "Al-Nasser", "Al-Hamad", "Al-Salem", "Al-Khalid",
        "Andersen", "Hansen", "Johansen", "Larsen", "Olsen", "Pedersen", "Nilsen", "Kristiansen", "Jensen", "Karlsen",
    ]

    private func generateDynamicName() -> String {
        // Use only names from the leaderboard — no random or invented names
        if Double.random(in: 0...1) < 0.25 {
            // 25%: real name + last name (matching leaderboard players)
            return Self.leaderboardRealNames.randomElement()! + " " + Self.leaderboardLastNames.randomElement()!
        } else {
            // 75%: leaderboard gamertags
            return Self.leaderboardGamertags.randomElement()!
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
    static let defaultValue: any SocialService = UnavailableSocialService()
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
