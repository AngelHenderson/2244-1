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
    func removeInvite(id: UUID) async throws
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

    public func removeInvite(id: UUID) async throws {
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

    private static let feedCacheKey = "socialFeed.cache.v37"
    private static let feedDateKey = "socialFeed.cacheDate.v36"
    /// Version-independent key for user-posted events so they survive cache bumps.
    private static let userPostsKey = "socialFeed.userPosts.v2"

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
        var items = generateFeedItems(now: now)

        // Merge in user posts from the last 7 days so they survive cache regeneration
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        if let userPostsData = defaults.data(forKey: Self.userPostsKey),
           let userPosts = try? JSONDecoder().decode([SocialFeedItem].self, from: userPostsData) {
            let recentPosts = userPosts.filter { $0.createdAt > sevenDaysAgo }
            let existingIDs = Set(items.map { $0.id })
            for post in recentPosts where !existingIDs.contains(post.id) {
                items.append(post)
            }
            items.sort { $0.createdAt > $1.createdAt }
        }

        // Cache for the rest of the day
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.feedCacheKey)
            defaults.set(todayString, forKey: Self.feedDateKey)
        }

        return items
    }

    public func addComment(to itemID: UUID, text: String) async throws {
        let defaults = UserDefaults.standard
        var foundAndUpdated: SocialFeedItem? = nil
        
        let now = Date()
        let playerName = defaults.string(forKey: "profilePlayerName") ?? "Player"
        let playerAvatar = defaults.string(forKey: "profileAvatarId") ?? "avatar_buddy_bot"
        let newComment = SocialFeedComment(authorName: playerName, avatarID: playerAvatar, text: text, createdAt: now)
        
        func processItem(_ item: inout SocialFeedItem) {
            item.comments.append(newComment)
            
            let delay = Double.random(in: 1800...86400)
            let responseTime = now.addingTimeInterval(delay)
            
            let responderName: String
            let responderIndex = Int.random(in: 1...100000)
            let responderAvatar = Self.avatarForPlayer(index: responderIndex, countrySeed: 0, day: Self.daysSinceReference)
            if text.hasPrefix("@") {
                let parts = text.split(separator: " ")
                if let first = parts.first {
                    responderName = String(first.dropFirst())
                } else {
                    responderName = generateDynamicName()
                }
            } else {
                responderName = item.authorName
            }
            
            func extractMaxNumber(from text: String) -> Int {
                let pattern = "\\d+"
                guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                var maxNum = 0
                for match in matches {
                    if let range = Range(match.range, in: text), let num = Int(text[range]) {
                        maxNum = max(maxNum, num)
                    }
                }
                return maxNum
            }
            
            var posterBeatsNPC = false
            let loweredText = text.lowercased()
            let loweredBase = item.message.lowercased()
            
            if let cSecs = Self.extractTime(from: loweredText).map({ $0.0 * 60 + $0.1 }),
               let bSecs = Self.extractTime(from: loweredBase).map({ $0.0 * 60 + $0.1 }) {
                if cSecs < bSecs { posterBeatsNPC = true }
            } else {
                let sortedMilestones = Self.allMilestones.sorted(by: { $0.count > $1.count })
                if let cM = sortedMilestones.first(where: { loweredText.contains($0.lowercased()) }),
                   let bM = sortedMilestones.first(where: { loweredBase.contains($0.lowercased()) }),
                   let cIdx = Self.allMilestones.firstIndex(of: cM),
                   let bIdx = Self.allMilestones.firstIndex(of: bM) {
                    if cIdx > bIdx { posterBeatsNPC = true }
                } else {
                    let cNum = extractMaxNumber(from: text)
                    let bNum = extractMaxNumber(from: item.message)
                    if cNum > 0 && cNum > bNum {
                        posterBeatsNPC = true
                    }
                }
            }
            
            let answer = milestoneAnswer(for: text)
            if posterBeatsNPC || answer != nil {
                let responseText: String
                if let ans = answer {
                    responseText = "@\(playerName) " + ans
                } else {
                    responseText = "@\(playerName) " + generateContextualReply(to: text, message: item.message)
                }
                let responseComment = SocialFeedComment(authorName: responderName, avatarID: responderAvatar, text: responseText, createdAt: responseTime)
                item.comments.append(responseComment)
                item.commentCount = item.comments.count
            } else {
                item.commentCount = item.comments.count
            }
        }

        if let data = defaults.data(forKey: Self.feedCacheKey),
           var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data),
           let index = cached.firstIndex(where: { $0.id == itemID }) {
            
            processItem(&cached[index])
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
            foundAndUpdated = cached[index]
        }
        
        if foundAndUpdated == nil {
            if let data = defaults.data(forKey: Self.userPostsKey),
               var userPosts = try? JSONDecoder().decode([SocialFeedItem].self, from: data),
               let index = userPosts.firstIndex(where: { $0.id == itemID }) {
                
                processItem(&userPosts[index])
                foundAndUpdated = userPosts[index]
            }
        }
        
        if let item = foundAndUpdated {
            persistInteractedItem(item)
        }
    }

    public func postEvent(message: String, statText: String) async throws {
        let defaults = UserDefaults.standard
        let now = Date()
        let currentDay = Self.daysSinceReference

        // Build the player's post
        let playerName = defaults.string(forKey: "player.displayName") ?? "Player"
        let playerAvatar = defaults.string(forKey: "player.avatarID") ?? "avatar_buddy_bot"

        var comments: [SocialFeedComment] = []
        let numBaseComments = Int.random(in: 15...35)
        var usedStats: Set<String> = []
        
        // Guarantee exact tone percentages
        var tones: [String] = []
        let numComp = Int(round(Double(numBaseComments) * 0.55))
        let numPos = Int(round(Double(numBaseComments) * 0.25))
        let numQuestion = Int(round(Double(numBaseComments) * 0.15))
        let numSad = max(0, numBaseComments - numComp - numPos - numQuestion)
        
        tones.append(contentsOf: Array(repeating: "competitive", count: numComp))
        tones.append(contentsOf: Array(repeating: "positive", count: numPos))
        tones.append(contentsOf: Array(repeating: "question", count: numQuestion))
        tones.append(contentsOf: Array(repeating: "sad", count: numSad))
        
        while tones.count < numBaseComments { tones.append("competitive") }
        while tones.count > numBaseComments { tones.removeLast() }
        tones.shuffle()
        
        for i in 0..<numBaseComments {
            let commenter = generateDynamicName()
            let commenterIndex = Int.random(in: 1...100000)
            let commenterAvatar = Self.avatarForPlayer(index: commenterIndex, countrySeed: 0, day: currentDay)
            
            let (commentBase, nameOverride, tone) = generateDynamicComment(message: message, usedStats: &usedStats, forcedTone: tones[i])
            let finalCommenter = nameOverride ?? commenter
            
            // Competitive comments arrive fast (within 15 mins) to enforce dominance. Others trickle over 4 days.
            let baseOffset = tone == "competitive" ? Double.random(in: 15...900) : Double.random(in: 900...345600)
            let baseCreatedAt = now.addingTimeInterval(baseOffset)
            
            let baseComment = SocialFeedComment(
                authorName: finalCommenter,
                avatarID: commenterAvatar,
                text: commentBase,
                createdAt: baseCreatedAt,
                likes: Int.random(in: 0...10)
            )
            comments.append(baseComment)
            
            if tone == "competitive" {
                var currentDepth = 0
                var lastComment = baseComment
                
                let npc1 = (name: baseComment.authorName, avatar: baseComment.avatarID)
                var npc2: (name: String, avatar: String)? = nil
                
                // Ensure competitive threads always have at least 2 replies so NPCs can beat each other's record
                let targetDepth = Double.random(in: 0...1) < 0.85 ? Int.random(in: 2...5) : 0
                while currentDepth < targetDepth {
                    if npc2 == nil {
                        let replyIndex = Int.random(in: 1...100000)
                        npc2 = (name: generateDynamicName(), avatar: Self.avatarForPlayer(index: replyIndex, countrySeed: 0, day: currentDay))
                    }
                    let currentSpeaker = currentDepth % 2 == 0 ? npc2! : npc1
                    
                    let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: "competitive")
                    
                    // Threaded competitive replies happen fast (within 5 minutes)
                    let replyOffset = Double.random(in: 30...300)
                    let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
                    
                    let replyComment = SocialFeedComment(
                        authorName: currentSpeaker.name,
                        avatarID: currentSpeaker.avatar,
                        text: replyText,
                        createdAt: replyCreatedAt,
                        likes: Int.random(in: 0...5)
                    )
                    comments.append(replyComment)
                    lastComment = replyComment
                    currentDepth += 1
                }
            } else {
                if Double.random(in: 0...1) < 0.30 {
                    let replyAuthor = generateDynamicName()
                    let replyIndex = Int.random(in: 1...100000)
                    let replyAvatar = Self.avatarForPlayer(index: replyIndex, countrySeed: 0, day: currentDay)
                    
                    let replyText: String
                    if let answer = milestoneAnswer(for: baseComment.text) {
                        replyText = "@\(baseComment.authorName) " + answer
                    } else {
                        // Sometimes reply to the poster, sometimes reply to the commenter
                        if Double.random(in: 0...1) < 0.7 {
                            replyText = "@\(playerName) " + generateContextualReply(to: message, message: message)
                        } else {
                            replyText = "@\(baseComment.authorName) " + generateContextualReply(to: baseComment.text, message: message)
                        }
                    }
                    
                    // Threaded competitive replies happen fast (within 5 minutes)
                    let replyOffset = Double.random(in: 30...300)
                    let replyCreatedAt = baseComment.createdAt.addingTimeInterval(replyOffset)
                    
                    let replyComment = SocialFeedComment(
                        authorName: replyAuthor,
                        avatarID: replyAvatar,
                        text: replyText,
                        createdAt: replyCreatedAt,
                        likes: Int.random(in: 0...5)
                    )
                    comments.append(replyComment)
                }
            }
        }

        // Heart/reaction timestamps trickle in over the next 4 days
        let numReactions = Int.random(in: 50...200)
        var rTimestamps: [Date] = []
        for _ in 0..<numReactions {
            rTimestamps.append(now.addingTimeInterval(Double.random(in: 30...345600)))
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

        // Also save to the version-independent user posts store
        persistInteractedItem(newItem)
    }

    private func persistInteractedItem(_ item: SocialFeedItem) {
        let defaults = UserDefaults.standard
        var userPosts: [SocialFeedItem] = []
        if let existingData = defaults.data(forKey: Self.userPostsKey),
           let existing = try? JSONDecoder().decode([SocialFeedItem].self, from: existingData) {
            userPosts = existing
        }
        
        if let idx = userPosts.firstIndex(where: { $0.id == item.id }) {
            userPosts[idx] = item
        } else {
            userPosts.insert(item, at: 0)
        }
        
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        userPosts = userPosts.filter { $0.createdAt > sevenDaysAgo }
        
        if let userPostsData = try? JSONEncoder().encode(userPosts) {
            defaults.set(userPostsData, forKey: Self.userPostsKey)
        }
    }

    public func toggleItemHeart(itemID: UUID) async throws {
        let defaults = UserDefaults.standard
        var foundAndUpdated: SocialFeedItem? = nil
        
        if let data = defaults.data(forKey: Self.feedCacheKey),
           var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data),
           let itemIndex = cached.firstIndex(where: { $0.id == itemID }) {
            
            let wasHearted = cached[itemIndex].isHearted ?? false
            cached[itemIndex].isHearted = !wasHearted
            cached[itemIndex].reactionCount += (wasHearted ? -1 : 1)
            
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
            foundAndUpdated = cached[itemIndex]
        }
        
        if foundAndUpdated == nil {
            if let data = defaults.data(forKey: Self.userPostsKey),
               var userPosts = try? JSONDecoder().decode([SocialFeedItem].self, from: data),
               let itemIndex = userPosts.firstIndex(where: { $0.id == itemID }) {
                
                let wasHearted = userPosts[itemIndex].isHearted ?? false
                userPosts[itemIndex].isHearted = !wasHearted
                userPosts[itemIndex].reactionCount += (wasHearted ? -1 : 1)
                foundAndUpdated = userPosts[itemIndex]
            }
        }
        
        if let item = foundAndUpdated {
            persistInteractedItem(item)
        }
    }

    public func toggleCommentHeart(itemID: UUID, commentID: UUID) async throws {
        let defaults = UserDefaults.standard
        var foundAndUpdated: SocialFeedItem? = nil

        if let data = defaults.data(forKey: Self.feedCacheKey),
           var cached = try? JSONDecoder().decode([SocialFeedItem].self, from: data),
           let itemIndex = cached.firstIndex(where: { $0.id == itemID }),
           let commentIndex = cached[itemIndex].comments.firstIndex(where: { $0.id == commentID }) {
            
            let wasHearted = cached[itemIndex].comments[commentIndex].isHearted ?? false
            cached[itemIndex].comments[commentIndex].isHearted = !wasHearted
            let currentLikes = cached[itemIndex].comments[commentIndex].likes ?? 0
            cached[itemIndex].comments[commentIndex].likes = currentLikes + (wasHearted ? -1 : 1)
            
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
            foundAndUpdated = cached[itemIndex]
        }
        
        if foundAndUpdated == nil {
            if let data = defaults.data(forKey: Self.userPostsKey),
               var userPosts = try? JSONDecoder().decode([SocialFeedItem].self, from: data),
               let itemIndex = userPosts.firstIndex(where: { $0.id == itemID }),
               let commentIndex = userPosts[itemIndex].comments.firstIndex(where: { $0.id == commentID }) {
                
                let wasHearted = userPosts[itemIndex].comments[commentIndex].isHearted ?? false
                userPosts[itemIndex].comments[commentIndex].isHearted = !wasHearted
                let currentLikes = userPosts[itemIndex].comments[commentIndex].likes ?? 0
                userPosts[itemIndex].comments[commentIndex].likes = currentLikes + (wasHearted ? -1 : 1)
                foundAndUpdated = userPosts[itemIndex]
            }
        }
        
        if let item = foundAndUpdated {
            persistInteractedItem(item)
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
            let timeOffset = Double.random(in: -43200...0) // Spread posts throughout the last 12 hours
            let itemDate = now.addingTimeInterval(timeOffset)
            
            var comments: [SocialFeedComment] = []
            
            // Generate top-level base comments
            let numBaseComments = Int.random(in: 4...10)
            var usedStats: Set<String> = []
            
            // Guarantee exact tone percentages
            var tones: [String] = []
            let numComp = Int(round(Double(numBaseComments) * 0.55))
            let numPos = Int(round(Double(numBaseComments) * 0.25))
            let numQuestion = Int(round(Double(numBaseComments) * 0.15))
            let numSad = max(0, numBaseComments - numComp - numPos - numQuestion)
            
            tones.append(contentsOf: Array(repeating: "competitive", count: numComp))
            tones.append(contentsOf: Array(repeating: "positive", count: numPos))
            tones.append(contentsOf: Array(repeating: "question", count: numQuestion))
            tones.append(contentsOf: Array(repeating: "sad", count: numSad))
            
            // Adjust if total doesn't match due to rounding
            while tones.count < numBaseComments { tones.append("competitive") }
            while tones.count > numBaseComments { tones.removeLast() }
            tones.shuffle()
            
            for i in 0..<numBaseComments {
                let commentAuthor = generateDynamicName()
                let commentIndex = Int.random(in: 1...100000)
                let commentAvatar = Self.avatarForPlayer(index: commentIndex, countrySeed: 0, day: currentDay)
                
                let (commentBase, nameOverride, tone) = generateDynamicComment(message: message, usedStats: &usedStats, forcedTone: tones[i])
                let finalCommenter = nameOverride ?? commentAuthor
                
                // Competitive comments arrive within 15 minutes of the post to immediately assert dominance
                let baseOffset = tone == "competitive" ? Double.random(in: timeOffset...min(timeOffset + 900, 0)) : Double.random(in: timeOffset...(timeOffset + 28800))
                let baseCreatedAt = now.addingTimeInterval(baseOffset)
                
                let baseComment = SocialFeedComment(
                    authorName: finalCommenter,
                    avatarID: commentAvatar,
                    text: commentBase,
                    createdAt: baseCreatedAt,
                    likes: Int.random(in: 0...10)
                )
                comments.append(baseComment)
                
                // If it's a competitive comment, start a recursive competitive chain
                if tone == "competitive" {
                    var currentDepth = 0
                    var lastComment = baseComment
                    
                    let npc1 = (name: baseComment.authorName, avatar: baseComment.avatarID)
                    var npc2: (name: String, avatar: String)? = nil
                    
                    // Ensure competitive threads always have at least 2 replies so NPCs can beat each other's record
                    let targetDepth = Double.random(in: 0...1) < 0.85 ? Int.random(in: 2...5) : 0
                    while currentDepth < targetDepth {
                        if npc2 == nil {
                            let replyIndex = Int.random(in: 1...100000)
                            npc2 = (name: generateDynamicName(), avatar: Self.avatarForPlayer(index: replyIndex, countrySeed: 0, day: currentDay))
                        }
                        let currentSpeaker = currentDepth % 2 == 0 ? npc2! : npc1
                        
                        let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: "competitive")
                        
                        // Threaded competitive replies happen fast (within 5 minutes)
                        let replyOffset = Double.random(in: 30...300)
                        let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
                        
                        let replyComment = SocialFeedComment(
                            authorName: currentSpeaker.name,
                            avatarID: currentSpeaker.avatar,
                            text: replyText,
                            createdAt: replyCreatedAt,
                            likes: Int.random(in: 0...5)
                        )
                        comments.append(replyComment)
                        lastComment = replyComment
                        currentDepth += 1
                    }
                } else {
                    // For non-competitive comments, small chance for a standard reply
                    if Double.random(in: 0...1) < 0.30 {
                        let replyAuthor = generateDynamicName()
                        let replyIndex = Int.random(in: 1...100000)
                        let replyAvatar = Self.avatarForPlayer(index: replyIndex, countrySeed: 0, day: currentDay)
                        
                        // Small chance to answer a question if it asks about the next milestone
                        var replyText = ""
                        if let answer = milestoneAnswer(for: baseComment.text) {
                            replyText = "@\(baseComment.authorName) " + answer
                        } else {
                            replyText = "@\(baseComment.authorName) " + generateContextualReply(to: baseComment.text, message: message)
                        }
                        
                        // Threaded competitive replies happen fast (within 5 minutes)
                        let replyOffset = Double.random(in: 30...300)
                        let replyCreatedAt = baseComment.createdAt.addingTimeInterval(replyOffset)
                        
                        let replyComment = SocialFeedComment(
                            authorName: replyAuthor,
                            avatarID: replyAvatar,
                            text: replyText,
                            createdAt: replyCreatedAt,
                            likes: Int.random(in: 0...5)
                        )
                        comments.append(replyComment)
                    }
                }
            }
            
            let maxReactions = Int.random(in: 10...50)
            var rTimestamps: [Date] = []
            for _ in 0..<maxReactions {
                // Reactions trickle in up to 8 hours after the post
                let rOffset = Double.random(in: timeOffset...(timeOffset + 28800))
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
            // Deterministic avatar from the real avatar pool
            let avatarIdx = abs(name.hashValue &* 127) % Self.allAvatars.count
            let avatar = Self.allAvatars[avatarIdx]
            return AccountProfile(
                uid: name.replacingOccurrences(of: " ", with: ".").lowercased(),
                displayName: name,
                username: name.replacingOccurrences(of: " ", with: "").lowercased(),
                avatarID: avatar,
                friendCode: "\(left)-\(right)",
                isAnonymous: false,
                isEmailVerified: true
            )
        }
    }

    private static let invitesCacheKey = "socialFeed.invites.v1"

    public func invites() async throws -> [FamilyInvite] {
        let defaults = UserDefaults.standard

        // Return cached invites if available
        if let data = defaults.data(forKey: Self.invitesCacheKey),
           let cached = try? JSONDecoder().decode([FamilyInvite].self, from: data) {
            return cached
        }

        // Generate initial invites
        let codeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        func makeCode() -> String {
            let left = String((0..<3).map { _ in codeChars.randomElement()! })
            let right = String((0..<3).map { _ in codeChars.randomElement()! })
            return "\(left)-\(right)"
        }
        let names = Self.leaderboardGamertags.shuffled().prefix(3)
        let result = [
            FamilyInvite(displayName: String(names[names.startIndex]), emailOrCode: makeCode(), status: "Invited"),
            FamilyInvite(displayName: String(names[names.index(names.startIndex, offsetBy: 1)]), emailOrCode: makeCode(), status: "Can invite"),
            FamilyInvite(displayName: String(names[names.index(names.startIndex, offsetBy: 2)]), emailOrCode: makeCode(), status: "Can invite"),
        ]

        // Cache the generated invites
        if let data = try? JSONEncoder().encode(result) {
            defaults.set(data, forKey: Self.invitesCacheKey)
        }
        return result
    }

    public func removeInvite(id: UUID) async throws {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.invitesCacheKey),
              var cached = try? JSONDecoder().decode([FamilyInvite].self, from: data) else {
            return
        }
        cached.removeAll { $0.id == id }
        if let newData = try? JSONEncoder().encode(cached) {
            defaults.set(newData, forKey: Self.invitesCacheKey)
        }
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
                "After so many attempts… \(milestone) is MINE! ♾️",
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
                    "! 🔥", " — legendary status! ♾️",
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
            
            let statEmojis = ["🔥", "🛡️", "📅", "💎", "⭐", "♾️", "✅"]
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
                    "! Infinity count: \(infinityCount) ♾️", " with \(infinityCount) infinities!",
                    "! ∞×\(infinityCount) and climbing!", ". Entry #\(infinityCount) ♾️",
                    "! \(infinityCount) infinity tiles deep.", " — \(infinityCount) infinities strong.",
                    ". Veteran status with \(infinityCount) runs.", "! Can't stop at \(infinityCount).",
                    " with ∞×\(infinityCount). Legendary!", ". \(infinityCount) and counting 🌟",
                ]
            } else if infinityCount > 1 {
                details = [
                    "! ♾️", "! Infinity count: \(infinityCount) ♾️",
                    " with \(infinityCount) infinities!", ". The journey was worth it.",
                    "! Entry #\(infinityCount).", " — ∞×\(infinityCount)!",
                    ". \(infinityCount) infinity tiles reached!", ". Still pushing for more.",
                    "! Grinding paid off 🏅", ". \(infinityCount) down, more to go.",
                ]
            } else {
                details = [
                    "! ♾️", "! I actually made it!",
                    " for the first time!", ". The grind paid off!",
                    "! After months of grinding…", " — this one's for the long-term players.",
                    "! They said it couldn't be done 🏅", ". First infinity tile!",
                    "! Welcome to the club!", ". Dream achieved ✨",
                ]
            }
            
            let message = "\(openers.randomElement()!) \(subject.randomElement()!)\(details.randomElement()!)"
            
            let statEmojis = ["♾️", "🏅", "🌟", "♾️", "⭐", "💎", "✨"]
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
            let mins = Int.random(in: 1...45)
            let secs = Int.random(in: 0...59)
            let timeStr = "\(mins):\(String(format: "%02d", secs))"

            let details = [
                "! \(questTier) chest earned in \(timeStr) 🎁",
                " in \(timeStr) — \(questTier) reward chest grabbed.",
                "! +\(gemsEarned) gems in \(timeStr) 💎",
                " in \(timeStr). \(questTier) tier. Easy gems today.",
                " in \(timeStr)! \(questTier) chest ♾️",
                " in \(timeStr) — all objectives done!",
                ". \(questTier) chest opened in \(timeStr).",
                " in \(timeStr). That \(questTier) chest was worth it.",
                "! \(gemsEarned) gems richer in \(timeStr).",
                " in \(timeStr). \(questTier) chest in the bag!",
            ]
            
            let message = "\(openers.randomElement()!) \(subjects.randomElement()!)\(details.randomElement()!)"
            
            let statEmojis = ["⏱️", "⏳", "💨", "🏅", "🏃‍♂️", "💎", "🎯"]
            let statLabels = [
                "Quests cleared · \(timeStr)", "Daily Quest · \(timeStr)",
                "All objectives · \(timeStr)", "\(questTier) quest · \(timeStr)",
                "Quest time · \(timeStr)", "Speed run · \(timeStr)",
                "Daily objectives · \(timeStr)", "Quests finished · \(timeStr)",
                "\(questTier) chest · \(timeStr)", "Quest log · \(timeStr)",
            ]
            return (message, "\(statEmojis.randomElement()!) \(statLabels.randomElement()!)")
        }
    }

    // MARK: - Shuffle-bag rotation

    /// Draws from a shuffled copy of `pool`, cycling back to a fresh shuffle
    /// once every element has been used. Guarantees every template appears at
    /// least once before any repeats.
    nonisolated(unsafe) private static var shuffleBags: [String: [String]] = [:]
    nonisolated(unsafe) private static var shuffleIndices: [String: Int] = [:]

    private static func drawFromBag(key: String, pool: [String]) -> String {
        // First call or bag exhausted — reshuffle
        if shuffleBags[key] == nil || (shuffleIndices[key] ?? 0) >= (shuffleBags[key]?.count ?? 0) {
            shuffleBags[key] = pool.shuffled()
            shuffleIndices[key] = 0
        }
        let idx = shuffleIndices[key]!
        shuffleIndices[key] = idx + 1
        return shuffleBags[key]![idx]
    }

    private func generateDynamicComment(message: String, usedStats: inout Set<String>, forcedTone: String? = nil) -> (commentText: String, nameOverride: String?, tone: String) {
        var nameOverride: String? = nil
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
            "My scores will always be out of reach.",
            "You'll never catch my lead.", "Enjoy staring at my infinite lead.",
            "My next run will just extend my lead.", "I'm already untouchable.",
            "You won't ever pass me.", "I'm in an entirely different league.",
            "That record is cute compared to mine.", "You will never have my stats.",
            "I'll be staying infinitely ahead permanently.", "Not impressed, I'm miles ahead.",
            "I'm maintaining my dominance.", "Don't even try to reach me.",
        ]
        var questions = [
            "How long did that take?", "What's your secret?", "Any tips for this tier?",
            "How many moves did it take?", "Did you use any swaps?", "Was it tough?",
            "Can I add you?", "Do you play every day?", "What perks did you use?",
            "How many attempts was that?", "Were you using a hammer?",
            "What's your total playtime?", "Did you plan that chain or was it luck?",
        ]
        
        // Symbols categorized by tone
        let positiveSymbols = ["!!", " :)", " :D", " xD", " ~", " :P", " <3", " =)", " ^_^", " ;-)", " :-)", "🔥", "🙌", "🚀", "👏", "💪", "♾️", "✨"]
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
                "My infinity count is permanently out of reach.",
                "I've been in the Hall of Fame since day one.",
                "Your HoF entry is nothing compared to my record.",
                "I'll always have more infinities.",
                "I dominate the Hall of Fame.",
                "You'll never catch my infinity count.",
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
                "My streak is permanently out of reach.",
                "I haven't missed a day since launch.",
                "Your streak is nothing compared to mine.",
                "I'll always have the higher streak.",
                "I dominate the daily grind.",
                "You'll never catch my streak.",
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
                "My time is permanently out of reach.",
                "I've had the fastest time since day one.",
                "Your speed is nothing compared to my record.",
                "I'll always have the faster clear.",
                "I dominate the speed leaderboards.",
                "You'll never reach my time.",
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
                "I already have all the themes unlocked. Take the L.",
                "You play dress-up while I grind.",
                "You care about colors? I only care about progression.",
                "A new theme won't help you catch up to me.",
                "Themes are for players stuck at the bottom.",
                "Keep playing in style. I'll keep dominating.",
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
                "My quest rewards are permanently out of reach.",
                "I've pulled Diamond chests since day one.",
                "Your quest tier is nothing compared to my record.",
                "I'll always pull the better chests.",
                "I dominate the daily quests.",
                "You'll never catch my quest streak.",
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
                    "My \(m) run was completely effortless.",
                    "\(m) is permanently behind me.",
                    "Your \(m) is nothing compared to my record.",
                    "I passed \(m) ages ago.",
                    "I dominate \(m) effortlessly.",
                    "You'll never catch me at \(m).",
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
        
        // Build a unique bag key from the message hash so each feed item
        // gets its own rotation through the templates
        let bagSuffix = String(message.hashValue & 0xFFFF, radix: 16)
        
        // Weighted category roll: 55% competitive, 25% positive, 15% question, 5% jealous
        var comment = ""
        var tone = forcedTone
        if tone == nil {
            let roll = Double.random(in: 0..<1)
            if roll < 0.55 { tone = "competitive" }
            else if roll < 0.80 { tone = "positive" }
            else if roll < 0.95 { tone = "question" }
            else { tone = "sad" }
        }
        
        if tone == "competitive" {
            // ── Competitive (55%) — generate factually accurate one-upmanship ──
            let result = generateTruthfulCompetitive(message: message, pool: competitiveReactions, bagKey: "competitive_\(bagSuffix)", usedStats: &usedStats)
            comment = result.0
            nameOverride = result.1
            // Randomly prepend a competitive opener ~95% of the time
            if Double.random(in: 0...1) < 0.95 {
                var compOpeners = [
                    "Too easy.", "Forever in first place.", "You can't touch infinity.",
                    "Barely had to try.", "My infinite lead is permanent.", "Light work.",
                    "This is entirely effortless.", "Do better.", "Your effort is pointless.",
                    "I'm bored.", "Effortless.", "I'll dominate this rivalry forever.",
                    "Didn't even break a sweat.", "That's cute.", "I dominate eternity.",
                    "Flawless.", "This rivalry is completely one-sided.", "There is no catching up to infinity.",
                    "No one can touch my infinity.", "Endless grinding, and you're still behind."
                ]
                
                let opener = Self.drawFromBag(key: "comp_opener_\(bagSuffix)", pool: compOpeners)
                comment = "\(opener) \(comment)"
            }
            // Randomly append a competitive closer ~80% of the time
            if Double.random(in: 0...1) < 0.80 {
                var compClosers = [
                    "My infinite lead cannot be broken.", "You'll never catch me.", "I'll always be tiers above.",
                    "Don't bother trying.", "I'm infinitely untouchable.", "My endless stats are permanent.",
                    "Just accept you'll never catch me.", "I reign over eternity.", "Your progress means nothing here.",
                    "You are completely irrelevant.", "No one is touching my infinite record.", "I'll always be infinitely ahead.",
                    "Your grind is meaningless against infinity.", "My dominance here is absolute.",
                    "I run this game.", "You're entirely left behind.",
                    "I'm untouchable.", "We are not the same.",
                    "Stay down there.", "Eternity belongs to me.",
                    "Your progress is a joke to me."
                ]
                
                let closer = Self.drawFromBag(key: "comp_closer_\(bagSuffix)", pool: compClosers)
                comment = "\(comment) \(closer)"
            }
            tone = "competitive"
        } else if tone == "positive" {
            // ── Positive (25%) — with opener + subject/verb/adj ──
            let opener = Self.drawFromBag(key: "opener_\(bagSuffix)", pool: openers)
            if Bool.random() {
                let subj = Self.drawFromBag(key: "subject_\(bagSuffix)", pool: subjects)
                let verb = Self.drawFromBag(key: "verb_\(bagSuffix)", pool: verbs)
                let adj = Self.drawFromBag(key: "adjective_\(bagSuffix)", pool: adjectives)
                let core = "\(subj) \(verb) \(adj)"
                comment = opener.isEmpty ? core.capitalized + "!" : "\(opener) \(core)!"
            } else {
                let reaction = Self.drawFromBag(key: "positive_\(bagSuffix)", pool: positiveReactions)
                comment = opener.isEmpty ? reaction : "\(opener) \(reaction.lowercased())"
            }
            tone = "positive"
        } else if tone == "question" {
            // ── Question (15%) — standalone, no opener ──
            comment = Self.drawFromBag(key: "question_\(bagSuffix)", pool: questions)
            tone = "question"
        } else {
            // ── Jealous (5%) — with opener ──
            let opener = Self.drawFromBag(key: "opener_\(bagSuffix)", pool: openers)
            let reaction = Self.drawFromBag(key: "jealous_\(bagSuffix)", pool: jealousReactions)
            comment = opener.isEmpty ? reaction.capitalized : "\(opener) \(reaction.lowercased())"
            tone = "sad"
        }
        if Double.random(in: 0...1) < 0.75 {
            let symbol: String
            switch tone {
            case "positive": symbol = Self.drawFromBag(key: "sym_pos_\(bagSuffix)", pool: positiveSymbols)
            case "question": symbol = Self.drawFromBag(key: "sym_q_\(bagSuffix)", pool: questionSymbols)
            case "sad": symbol = Self.drawFromBag(key: "sym_sad_\(bagSuffix)", pool: sadOrJealousSymbols)
            case "competitive": symbol = Self.drawFromBag(key: "sym_comp_\(bagSuffix)", pool: competitiveSymbols)
            default: symbol = ""
            }
            comment += symbol
        } else if Double.random(in: 0...1) < 0.1 {
            // 2.5% chance for a random raw keyboard symbol (like a typo)
            comment += keyboardSymbols.randomElement()!
        }
        
        return (comment.trimmingCharacters(in: .whitespaces), nameOverride, tone!)
    }

    // MARK: - Truthful competitive comments

    /// Generates a competitive comment that is factually accurate — any claimed
    /// stat is **higher** (or faster) than the poster's actual number.
    /// Returns (commentText, optionalNameOverride). When the comment claims a
    /// specific milestone, nameOverride is a real leaderboard player at that level.
    /// Falls back to the generic `pool` when no number can be extracted.
    private func generateTruthfulCompetitive(message: String, pool: [String], bagKey: String, usedStats: inout Set<String>) -> (String, String?) {
        let lowered = message.lowercased()

        let sortedMilestones = Self.allMilestones.sorted(by: { $0.count > $1.count })
        let posterM = sortedMilestones.first(where: { m in
            let pattern = "(?<!:)\\b\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\b(?!:)"
            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil
        }) ?? "11n"
        let posterIdx = Self.allMilestones.firstIndex(of: posterM) ?? 15
        let jump = Int.random(in: 5...60)
        let higherIdx = min(posterIdx + jump, Self.allMilestones.count - 1)
        let higherM = Self.allMilestones[higherIdx]
        let higherName = Self.leaderboardPlayerAtMilestone(higherM)

        // ── Streak posts: extract the day count, brag with a higher one ──
        if lowered.contains("streak") {
            if let streakDays = Self.extractNumber(from: message, near: ["day", "streak", "consecutive", "straight", "running"]) {
                let isMassiveGap = Bool.random()
                var myDays = streakDays + (isMassiveGap ? Int.random(in: streakDays * 3...streakDays * 8 + 50) : Int.random(in: 5...max(10, streakDays / 2)))
                var attempts = 0
                while usedStats.contains("streak_\(myDays)") && attempts < 5 {
                    myDays = streakDays + (isMassiveGap ? Int.random(in: streakDays * 3...streakDays * 8 + 50) : Int.random(in: 5...max(10, streakDays / 2)))
                    attempts += 1
                }
                usedStats.insert("streak_\(myDays)")
                var templates = [
                    "I'm already at \(myDays) days.",
                    "You're at \(streakDays) days, I'm at \(myDays) days.",
                    "I'll always be untouched at \(myDays) days.",
                    "You're only at \(streakDays) days, I'm at \(myDays) days.",
                    "I'm at \(myDays) days.",
                    "Try hitting \(myDays) days.",
                ]
                if myDays >= streakDays * 2 {
                    templates.append("\(streakDays) days vs \(myDays) days.")
                    templates.append("You're stuck at \(streakDays) days and I'm at \(myDays) days.")
                }
                return (Self.drawFromBag(key: "\(bagKey)_streak_\(myDays)", pool: templates), higherName)
            }
        }

        // ── Timed challenge posts: extract time remaining, brag with more ──
        let hasTimeFormat = (try? NSRegularExpression(pattern: "\\b\\d{1,2}:\\d{2}\\b"))?.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil
        if hasTimeFormat || lowered.contains("timed") || lowered.contains("challenge") || lowered.contains("speed") {
            if let (mins, secs) = Self.extractTime(from: message) {
                let totalSecs = mins * 60 + secs
                // Brag about having a FASTER clear time (lower = better)
                let isMassiveGap = Bool.random()
                let maxLess = totalSecs - 10
                let lessBy = isMassiveGap && maxLess > 30 ? Int.random(in: totalSecs / 2...maxLess) : Int.random(in: max(5, totalSecs / 10)...max(15, totalSecs / 3))
                var myTotal = max(10, totalSecs - lessBy)
                var attempts = 0
                while usedStats.contains("time_\(myTotal)") && attempts < 5 {
                    let retryLess = isMassiveGap && maxLess > 30 ? Int.random(in: totalSecs / 2...maxLess) : Int.random(in: max(5, totalSecs / 10)...max(15, totalSecs / 3))
                    myTotal = max(10, totalSecs - retryLess)
                    attempts += 1
                }
                usedStats.insert("time_\(myTotal)")
                let myMins = myTotal / 60
                let mySecs = myTotal % 60
                let myTime = "\(myMins):\(String(format: "%02d", mySecs))"
                let posterTime = "\(mins):\(String(format: "%02d", secs))"
                var templates = [
                    "You're only at \(posterTime), I'm at \(myTime).",
                    "I'm already at \(myTime).",
                    "You're at \(posterTime), I'm at \(myTime).",
                    "I am sitting untouched at \(myTime).",
                    "I'm at \(myTime).",
                    "Try hitting \(myTime).",
                ]
                if myTotal <= totalSecs / 2 {
                    templates.append("\(posterTime) vs \(myTime).")
                    templates.append("You're stuck at \(posterTime) while I'm at \(myTime).")
                }
                return (Self.drawFromBag(key: "\(bagKey)_time_\(myTotal)", pool: templates), higherName)
            }
        }

        // ── Hall of Fame posts: extract infinity count, brag with a higher one ──
        if lowered.contains("hall of fame") || lowered.contains("hof") || lowered.contains("infinity") {
            if let infCount = Self.extractNumber(from: message, near: ["infinity", "infinit", "\u{221E}", "\u{00D7}", "count", "entry", "#"]) {
                let isMassiveGap = Bool.random()
                var myCount = infCount + (isMassiveGap ? Int.random(in: infCount * 3...infCount * 8 + 100) : Int.random(in: 1...max(3, infCount)))
                var attempts = 0
                while usedStats.contains("hof_\(myCount)") && attempts < 5 {
                    myCount = infCount + (isMassiveGap ? Int.random(in: infCount * 3...infCount * 8 + 100) : Int.random(in: 1...max(3, infCount)))
                    attempts += 1
                }
                usedStats.insert("hof_\(myCount)")
                var templates = [
                    "You're at \(infCount), I'm at \(myCount).",
                    "You're only at \(infCount), I'm at \(myCount).",
                    "I'm at \(myCount).",
                ]
                if myCount >= infCount * 2 {
                    templates.append("\(infCount) vs \(myCount).")
                    templates.append("You're stuck at \(infCount) and I'm at \(myCount).")
                }
                return (Self.drawFromBag(key: "\(bagKey)_hof_\(myCount)", pool: templates), higherName)
            }
        }

        // ── Quest posts: brag about better chest tier or faster completion ──
        if lowered.contains("quest") {
            let tiers = ["Bronze", "Silver", "Gold", "Diamond"]
            if let posterTierIdx = tiers.firstIndex(where: { message.contains($0) }),
               posterTierIdx < tiers.count - 1 {
                let myTier = tiers[Int.random(in: (posterTierIdx + 1)..<tiers.count)]
                let posterTier = tiers[posterTierIdx]
                var templates = [
                    "You're at \(posterTier), I'm at \(myTier).",
                    "You're only pulling \(posterTier), I'm pulling \(myTier).",
                    "\(posterTier) vs \(myTier).",
                    "I'm at \(myTier).",
                    "I'm already at \(myTier).",
                    "Try hitting \(myTier).",
                ]
                // tier gap >= 2 (e.g., Bronze→Gold or Bronze→Diamond)
                let tierGap = tiers.firstIndex(of: myTier)! - posterTierIdx
                if tierGap >= 2 {
                    templates.append("\(myTier) chest here.")
                    templates.append("You're only pulling \(posterTier), I'm pulling \(myTier).")
                }
                return (Self.drawFromBag(key: "\(bagKey)_quest_\(myTier)", pool: templates), higherName)
            }
        }

        // ── Milestone posts: find the tile, reference a higher one ──
        if let foundIdx = sortedMilestones.firstIndex(where: { m in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\b"
            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(
                in: lowered,
                range: NSRange(lowered.startIndex..., in: lowered)
            ) != nil
        }) {
            let m = sortedMilestones[foundIdx]
            if let originalIdx = Self.allMilestones.firstIndex(of: m),
               originalIdx + 1 < Self.allMilestones.count {
                // Pick a random milestone 5-60 steps ahead, avoiding already-used ones
                let remaining = Self.allMilestones.count - 1 - originalIdx
                let maxJump = min(60, remaining)
                let minJump = min(5, maxJump)
                var localHigherM: String
                var jump: Int
                var attempts = 0
                repeat {
                    jump = Int.random(in: minJump...maxJump)
                    localHigherM = Self.allMilestones[originalIdx + jump]
                    attempts += 1
                } while usedStats.contains(localHigherM) && attempts < 8
                usedStats.insert(localHigherM)

                var templates = [
                    "I'm at \(localHigherM).",
                    "I'm already at \(localHigherM).",
                    "\(localHigherM) here.",
                ]
                // "way behind" only with a truly massive gap (150-500 steps ahead)
                if remaining >= 150 {
                    let wayBehindJump = Int.random(in: 150...min(500, remaining))
                    let wayBehindM = Self.allMilestones[originalIdx + wayBehindJump]
                    templates.append("\(wayBehindM) here.")
                }
                let realName = Self.leaderboardPlayerAtMilestone(localHigherM)
                return (Self.drawFromBag(key: "\(bagKey)_tile_\(localHigherM)", pool: templates), realName)
            }
        }

        // ── Fallback: use the generic competitive pool ──
        let generic = Self.drawFromBag(key: bagKey, pool: pool)
        return (generic, nil)
    }

    /// Returns the name of a real leaderboard player who is at the given milestone.
    /// Uses a subset of US leaderboard data (mirrored from LeaderboardClient) so
    /// that competitive milestone claims are verifiable on the leaderboard.
    private static func leaderboardPlayerAtMilestone(_ milestone: String) -> String? {
        let milestoneToName: [String: String] = [
            // n-tier (most commonly seen in feed)
            "2n": "NorfolkNomad", "5n": "ScottsdaleSnake",
            "11n": "WinstonWarrior", "23n": "GlendaleeGuru",
            "47n": "LubbockLancer", "95n": "RennoRocket",
            "191n": "NorthLasVegasNova", "383n": "GilbertGladiator",
            // m-tier
            "2m": "MobileMarvel", "5m": "KnoxvilleKing",
            "11m": "MadisonMarvel", "23m": "ChattanoogaChamp",
            "46m": "AkronAce", "93m": "SyracuseSniper",
            "187m": "SavannahStar", "374m": "StPaulPhenomm",
            // l-tier
            "2l": "MilwaukeeMight", "5l": "TucsonTwister",
            "11l": "LouisvilleLion", "22l": "SpringfieldSprint",
            "45l": "PasadenaPro", "91l": "PompanoPlayer",
            "182l": "CoralGablesCrush", "365l": "TallahasseTitan",
            // k-tier
            "2k": "GainesvilleGuru", "5k": "PensacolaPhenom",
            "11k": "ClearwaterChamp", "22k": "BocaRatonBoss",
            "44k": "NapleNinja", "89k": "HartfordHawk",
            "178k": "ProvidencePro", "356k": "NashvilleNinja",
            // o-tier
            "3o": "LaRedoLegend", "6o": "BuffaloBeast",
            "24o": "JerseyJuggernaut",
            // p-tier
            "3p": "DurhamDragon", "12p": "OrlandoOmega",
            "100p": "ChulaChulaChamp", "401p": "StPaulPhenomm",
            // q-tier
            "3q": "IrvineInferno", "102q": "ToledoTerror",
            // r-tier
            "6r": "CincinnatiCyber", "842r": "PittsburghPro",
            // s-tier
            "26s": "RiversideRuler", "107s": "StocktonStorm",
            // t-tier
            "3t": "TampaTitan", "883t": "TulsaTornado",
            // u-tier
            "7u": "AnchorageAlpha", "28u": "RichmondRacer",
            // Common lower milestones
            "1M": "NapleNinja", "2M": "ClearwaterChamp",
            "16K": "BocaRatonBoss", "32K": "GainesvilleGuru",
            "65K": "PensacolaPhenom", "131K": "DaytonDynamo",
            "262K": "AllenAlpha", "524K": "SavannahStar",
        ]
        return milestoneToName[milestone]
    }

    /// Extracts a number from the message that appears near any of the given context words.
    private static func extractNumber(from text: String, near contextWords: [String]) -> Int? {
        let lowered = text.lowercased()
        // Check that at least one context word is present
        guard contextWords.contains(where: { lowered.contains($0) }) else { return nil }

        // Find all integers in the message
        let pattern = try? NSRegularExpression(pattern: "\\b(\\d{1,6})\\b")
        let matches = pattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []

        for match in matches {
            if let range = Range(match.range(at: 1), in: text), let num = Int(text[range]), num > 0 {
                return num
            }
        }
        return nil
    }

    /// Extracts a time in M:SS format from the message. Returns (minutes, seconds).
    private static func extractTime(from text: String) -> (Int, Int)? {
        let pattern = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})")
        guard let match = pattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let mRange = Range(match.range(at: 1), in: text),
              let sRange = Range(match.range(at: 2), in: text),
              let mins = Int(text[mRange]),
              let secs = Int(text[sRange]) else { return nil }
        return (mins, secs)
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
            let pattern = "(?<!:)\\b\(NSRegularExpression.escapedPattern(for: milestone.lowercased()))\\b(?!:)"
            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil, idx + 1 < Self.allMilestones.count {
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
    private func generateContextualReply(to commentText: String, message: String, forceTone: String? = nil) -> String {
        let lowered = commentText.lowercased()

        // Strip any leading @mention so we analyze the real content
        let strippedText: String = {
            if lowered.hasPrefix("@") {
                let parts = commentText.split(separator: " ", maxSplits: 1)
                return parts.count > 1 ? String(parts[1]) : commentText
            }
            return commentText
        }()
        let strippedLower = strippedText.lowercased()

        // ── Extract dynamic content from the comment ──

        // Pull any milestone mentioned in the comment (find highest index for competitive progression)
        var foundMilestones: [(index: Int, name: String)] = []
        for (idx, m) in Self.allMilestones.enumerated() {
            let pattern = "(?<!:)\\b\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\b(?!:)"
            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: strippedLower, range: NSRange(strippedLower.startIndex..., in: strippedLower)) != nil {
                foundMilestones.append((index: idx, name: m))
            }
        }
        var mentionedMilestone = foundMilestones.max(by: { $0.index < $1.index })

        if mentionedMilestone == nil {
            let sortedMilestones = Self.allMilestones.enumerated().sorted { $0.element.count > $1.element.count }
            let lowerMessage = message.lowercased()
            mentionedMilestone = sortedMilestones.first(where: { entry in
                let pattern = "(?<!:)\\b\(NSRegularExpression.escapedPattern(for: entry.element.lowercased()))\\b(?!:)"
                return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowerMessage, range: NSRange(lowerMessage.startIndex..., in: lowerMessage)) != nil
            }).map { ($0.offset, $0.element) }
        }

        // Pull any number referenced (playtime, days, attempts, etc.)
        // Minimum of 3 — smaller numbers like 0, 1, 2 are almost never meaningful stats
        let mentionedNumber: String? = {
            let regex = try? NSRegularExpression(pattern: "\\b(\\d{1,6})\\b", options: [])
            let range = NSRange(strippedText.startIndex..., in: strippedText)
            if let match = regex?.firstMatch(in: strippedText, range: range),
               let r = Range(match.range(at: 1), in: strippedText) {
                let numStr = String(strippedText[r])
                if let value = Int(numStr), value >= 3 {
                    return numStr
                }
            }
            return nil
        }()

        // Extract key phrases the commenter used for mirroring
        // Extract key phrases the commenter used for mirroring
        let hasTimeFormat = (try? NSRegularExpression(pattern: "\\b\\d{1,2}:\\d{2}\\b"))?.firstMatch(in: strippedLower, range: NSRange(strippedLower.startIndex..., in: strippedLower)) != nil
        let mentionedTime = hasTimeFormat || strippedLower.contains("time") || strippedLower.contains("fast") || strippedLower.contains("speed") || strippedLower.contains("quick") || strippedLower.contains("sec") || strippedLower.contains("min") || strippedLower.contains("clock")
        let mentionedStreak = strippedLower.contains("streak") || strippedLower.contains("day") || strippedLower.contains("consecutive")
        let mentionedTheme = strippedLower.contains("theme") || strippedLower.contains("style") || strippedLower.contains("aesthetic")
        let mentionedHoF = strippedLower.contains("hall of fame") || strippedLower.contains("hof") || strippedLower.contains("infinity")
        let mentionedPerk = strippedLower.contains("hammer") || strippedLower.contains("swap") || strippedLower.contains("magnet") || strippedLower.contains("perk")
        let mentionedGems = strippedLower.contains("gem")
        let mentionedQuest = strippedLower.contains("quest") || strippedLower.contains("objective") || strippedLower.contains("chest")

        // ── Detect the tone/intent of the comment being replied to ──

        let questionKeywords = ["?", "how", "what", "any tips", "did you", "do you", "how long", "how many", "which", "when", "can i", "could you", "is it", "was it"]
        let isQuestion = forceTone != "competitive" && questionKeywords.contains(where: { strippedLower.contains($0) })

        let competitiveKeywords = ["beat", "catching up", "coming for", "won't last", "watch your back", "game on", "challenge", "mine tomorrow", "i'll be", "i'm going to", "not impressed", "my time", "faster", "i passed", "old news", "hold my", "i'll beat", "i'm right behind", "i'm catching"]
        var isCompetitive = forceTone == "competitive" || competitiveKeywords.contains(where: { strippedLower.contains($0) })
        if forceTone == nil && Double.random(in: 0..<1) < 0.55 {
            isCompetitive = true
        }

        let jealousKeywords = ["can't even", "stuck", "i always lose", "impossible", "struggling", "must be nice", "pain", "i wish", "jealous", "i keep", "never", "i don't have", "so bad at", "still trying", "can never", "i can't"]
        let isJealous = forceTone != "competitive" && jealousKeywords.contains(where: { strippedLower.contains($0) })

        let positiveKeywords = ["gg", "nice", "incredible", "amazing", "congrats", "respect", "huge", "well done", "let's go", "fire", "legendary", "awesome", "love", "perfect", "clean", "gorgeous", "elite", "thank", "appreciate"]
        let isPositive = forceTone != "competitive" && positiveKeywords.contains(where: { strippedLower.contains($0) })

        let addFriendKeywords = ["can i add", "add you", "add me", "friend code", "friend request", "be friends", "play together"]
        let isAddRequest = forceTone != "competitive" && addFriendKeywords.contains(where: { strippedLower.contains($0) })

        // ── Generate contextual replies that reference the actual comment ──

        if isAddRequest {
            let replies = [
                "You can add me, but you'll never catch me.",
                "Add me if you want to watch me stay infinitely ahead.",
                "Sure, add me so you can stare at my infinite lead.",
                "You can watch my stats from the bottom.",
                "Go for it! I need an audience for my endless dominance.",
                "Yes! Add me and witness infinity.",
                "For sure — watch me extend my lead permanently.",
                "Definitely! But don't expect to ever reach my tier.",
            ]
            return replies.randomElement()!
        }

        if isQuestion {
            var answers: [String] = []

            // Dynamic answers that reference what they're asking about
            if let m = mentionedMilestone {
                let next = m.index + 1 < Self.allMilestones.count ? Self.allMilestones[m.index + 1] : nil
                answers.append(contentsOf: [
                    "For \(m.name), I focused on keeping one corner stacked.",
                    "\(m.name) took me about a week of solid grinding.",
                    "The trick at \(m.name) is patience — don't rush merges.",
                    "Once you're near \(m.name), keep lanes open and plan 3 moves ahead.",
                    "\(m.name) was tough honestly. Took multiple attempts.",
                ])
                if let nextTile = next {
                    answers.append("\(m.name) → \(nextTile). Just keep pushing!")
                    answers.append("After \(m.name), aim for \(nextTile). You'll get there!")
                }
            }

            if let num = mentionedNumber {
                answers.append(contentsOf: [
                    "\(num) is solid! Mine was a bit different but close.",
                    "Around \(num) is where things start clicking.",
                    "\(num)? That's about where I was too at that point.",
                    "Not bad! I think mine was closer to \(num) actually.",
                ])
            }

            if mentionedStreak {
                answers.append(contentsOf: [
                    "I set a phone reminder every evening — never miss!",
                    "Play right after waking up. That's how I keep mine alive.",
                    "Almost lost mine twice, but pulled through 😅",
                    "The first week is the hardest, then it becomes habit.",
                    "Honestly, just make it part of your routine.",
                ])
            }

            if mentionedTime {
                answers.append(contentsOf: [
                    "Speed comes from pattern recognition. Keep at it!",
                    "I don't overthink — just go with instinct on timed runs.",
                    "Practice daily and times drop naturally.",
                    "Quick swipes and no second-guessing. That's my approach.",
                ])
            }

            if mentionedHoF {
                answers.append(contentsOf: [
                    "Took about 3 months of daily play to reach HoF.",
                    "The key is never giving up past the 'a' tiers.",
                    "Keep pushing through the alphabet tiers and you'll get there.",
                    "The hardest part was the 'z' to 'aa' transition honestly.",
                ])
            }

            if mentionedTheme {
                answers.append(contentsOf: [
                    "Worth every gem, honestly!",
                    "It changes the whole feel of the game.",
                    "The colors on this one are so soothing.",
                    "I've been saving up for weeks for this one.",
                ])
            }

            if mentionedQuest {
                answers.append(contentsOf: [
                    "I always start with the hardest quest first.",
                    "Today's quests were actually pretty easy.",
                    "The chest rewards are so worth the effort.",
                    "I try to knock them out in my first session.",
                ])
            }

            if mentionedPerk {
                answers.append(contentsOf: [
                    "Perks help but they're not required. Save them for clutch moments.",
                    "I mostly hoard perks for the late game pushes.",
                    "Free perks from the cooldown timer are underrated!",
                    "I used a hammer for my final push. No shame in it.",
                ])
            }

            // Generic question answers as fallback
            if answers.isEmpty {
                answers = [
                    "Honestly, just keep grinding and it clicks.",
                    "Took me a while, but consistency helps a lot.",
                    "The trick is patience and keeping lanes open.",
                    "I usually plan 3-4 moves ahead. That helps.",
                    "Just practice! Everyone struggles at first.",
                    "No special trick, just played a LOT 😅",
                    "Focus on keeping one corner anchored.",
                    "A few attempts honestly. Not gonna lie it was rough.",
                    "I watched some replays to figure out the pattern.",
                ]
            }

            return answers.randomElement()!
        }

        if isCompetitive {
            var replies: [String] = []

            // Dynamic competitive responses that echo what they said
            if let m = mentionedMilestone {
                let jump = Int.random(in: 1...5)
                let higherIdx = min(m.index + jump, Self.allMilestones.count - 1)
                let higherM = Self.allMilestones[higherIdx]
                replies.append(contentsOf: [
                    "I am infinitely ahead of your \(m.name) ⚔️. I'm at \(higherM).",
                    "\(m.name) is permanently behind me. I am untouchable at \(higherM) 💨.",
                    "Your \(m.name) is nothing compared to my \(higherM) record ♾️.",
                    "I passed \(m.name) ages ago. I dominate \(higherM) 🔥.",
                    "My \(higherM) run was completely effortless. \(m.name) is cute 😏.",
                    "\(m.name) was a warm-up 🥱. I'm already sitting at \(higherM).",
                    "You're celebrating \(m.name)? I just cleared \(higherM) 💀.",
                    "I left \(m.name) in the dust. \(higherM) is the new standard ♾️.",
                    "Try hitting \(higherM) before bragging about \(m.name) 💅.",
                    "I hit \(higherM) yesterday. \(m.name) is old news 📉.",
                ])
            }

            if let numStr = mentionedNumber, let num = Int(numStr), !mentionedTime, !mentionedStreak, !mentionedHoF {
                let higherNum = num + Int.random(in: 10...max(20, num))
                replies.append(contentsOf: [
                    "I am infinitely ahead of your \(numStr) ⚔️. I'm at \(higherNum).",
                    "Your \(numStr) is cute. I'll always be infinitely ahead at \(higherNum) ♾️.",
                    "\(numStr) is just the beginning 🥱. I'm already at \(higherNum).",
                    "I left your \(numStr) score in the dust. Just hit \(higherNum) 🔥.",
                    "You thought \(numStr) was good? I'm laughing from \(higherNum) 💀.",
                    "\(numStr) points is light work. Try \(higherNum) 😏.",
                    "I passed \(numStr) without even looking. I'm at \(higherNum) 💅.",
                    "\(higherNum) is my floor. Your \(numStr) is my ceiling 📉.",
                ])
            }

            if mentionedStreak {
                if let numStr = mentionedNumber, let num = Int(numStr) {
                    let higherNum = num + Int.random(in: 10...50)
                    replies.append(contentsOf: [
                        "I am infinitely ahead of your \(numStr) days ⚔️. I'm at \(higherNum) days.",
                        "Your \(numStr) day streak is nothing. Try catching my \(higherNum) days 💨.",
                        "I passed \(numStr) days ages ago. I'm at \(higherNum) days ♾️.",
                        "\(numStr) days? Try keeping a \(higherNum) day streak like me 🔥.",
                        "I extended infinitely past your \(numStr) days. Currently at \(higherNum) 😏.",
                        "Your \(numStr) days are cute. Call me when you reach \(higherNum) days 🥱.",
                        "I haven't dropped my \(higherNum) day streak. \(numStr) is light 💅.",
                        "\(higherNum) consecutive days here. Your \(numStr) days won't last 📉.",
                    ])
                } else {
                    let assumedNum = Int.random(in: 10...30)
                    let higherNum = assumedNum + Int.random(in: 10...50)
                    replies.append(contentsOf: [
                        "I am infinitely ahead of your \(assumedNum) days ⚔️. I'm at \(higherNum) days.",
                        "Your \(assumedNum) day streak is nothing. Try catching my \(higherNum) days 💨.",
                        "I passed \(assumedNum) days ages ago. I'm at \(higherNum) days ♾️.",
                        "\(assumedNum) days? Try keeping a \(higherNum) day streak like me 🔥.",
                        "I extended infinitely past your \(assumedNum) days. Currently at \(higherNum) 😏.",
                        "Your \(assumedNum) days are cute. Call me when you reach \(higherNum) days 🥱.",
                        "I haven't dropped my \(higherNum) day streak. \(assumedNum) is light 💅.",
                        "\(higherNum) consecutive days here. Your \(assumedNum) days won't last 📉.",
                    ])
                }
            }

            if mentionedTime {
                if let (mins, secs) = Self.extractTime(from: strippedLower) {
                    let totalSecs = mins * 60 + secs
                    let higherNum = max(10, totalSecs - Int.random(in: 10...30))
                    let myMins = higherNum / 60
                    let mySecs = higherNum % 60
                    let higherTime = "\(myMins):\(String(format: "%02d", mySecs))"
                    let posterTime = "\(mins):\(String(format: "%02d", secs))"
                    replies.append(contentsOf: [
                        "I am infinitely faster than your \(posterTime) ⚔️. I'm at \(higherTime).",
                        "Your \(posterTime) time is cute. I clear it in \(higherTime) 💨.",
                        "I passed your time ages ago. My record is \(higherTime) ♾️.",
                        "\(posterTime) is too slow 🥱. I just clocked \(higherTime).",
                        "I shaved minutes off your \(posterTime). My best is \(higherTime) 🔥.",
                        "You call \(posterTime) fast? Try reaching my \(higherTime) 😏.",
                        "I speedrun this game. \(higherTime) destroys your \(posterTime) 💀.",
                        "Your \(posterTime) was my practice run. I'm down to \(higherTime) 💅.",
                    ])
                } else {
                    let assumedTotal = Int.random(in: 60...120)
                    let higherNum = max(10, assumedTotal - Int.random(in: 10...30))
                    let myMins = higherNum / 60
                    let mySecs = higherNum % 60
                    let higherTime = "\(myMins):\(String(format: "%02d", mySecs))"
                    let posterMins = assumedTotal / 60
                    let posterSecs = assumedTotal % 60
                    let posterTime = "\(posterMins):\(String(format: "%02d", posterSecs))"
                    replies.append(contentsOf: [
                        "I am infinitely faster than your \(posterTime) ⚔️. I'm at \(higherTime).",
                        "Your \(posterTime) time is cute. I clear it in \(higherTime) 💨.",
                        "I passed your time ages ago. My record is \(higherTime) ♾️.",
                        "\(posterTime) is too slow 🥱. I just clocked \(higherTime).",
                        "I shaved minutes off your \(posterTime). My best is \(higherTime) 🔥.",
                        "You call \(posterTime) fast? Try reaching my \(higherTime) 😏.",
                        "I speedrun this game. \(higherTime) destroys your \(posterTime) 💀.",
                        "Your \(posterTime) was my practice run. I'm down to \(higherTime) 💅.",
                    ])
                }
            }

            if mentionedHoF {
                if let numStr = mentionedNumber, let num = Int(numStr) {
                    let higherNum = num + Int.random(in: 1...max(3, num/2))
                    replies.append(contentsOf: [
                        "I am infinitely ahead of your \(numStr) infinity count ⚔️. I'm at \(higherNum).",
                        "Your \(numStr) HoF entries are nothing. Try catching my \(higherNum) ♾️.",
                        "I passed \(numStr) infinities ages ago. I'm at \(higherNum) 💨.",
                        "\(numStr) infinities is a good start. I'm already sitting at \(higherNum) 😏.",
                        "I just logged my \(higherNum)th infinity. Your \(numStr) is cute 🥱.",
                        "I dominate the HoF with \(higherNum) entries 🔥. \(numStr) isn't enough.",
                        "You're bragging about \(numStr)? I just hit \(higherNum) in the HoF 💀.",
                        "The Hall of Fame belongs to me. \(higherNum) > \(numStr) ♾️.",
                    ])
                } else {
                    let assumedNum = Int.random(in: 5...15)
                    let higherNum = assumedNum + Int.random(in: 2...8)
                    replies.append(contentsOf: [
                        "I am infinitely ahead of your \(assumedNum) infinity count ⚔️. I'm at \(higherNum).",
                        "Your \(assumedNum) HoF entries are nothing. Try catching my \(higherNum) ♾️.",
                        "I passed \(assumedNum) infinities ages ago. I'm at \(higherNum) 💨.",
                        "\(assumedNum) infinities is a good start. I'm already sitting at \(higherNum) 😏.",
                        "I just logged my \(higherNum)th infinity. Your \(assumedNum) is cute 🥱.",
                        "I dominate the HoF with \(higherNum) entries 🔥. \(assumedNum) isn't enough.",
                        "You're bragging about \(assumedNum)? I just hit \(higherNum) in the HoF 💀.",
                        "The Hall of Fame belongs to me. \(higherNum) > \(assumedNum) ♾️.",
                    ])
                }
            }

            if mentionedQuest {
                let tiers = ["Bronze", "Silver", "Gold", "Diamond"]
                let posterTierIdx = tiers.firstIndex(where: { strippedLower.contains($0.lowercased()) }) ?? tiers.firstIndex(where: { message.lowercased().contains($0.lowercased()) }) ?? 0
                
                if posterTierIdx < tiers.count - 1 {
                    let myTier = tiers[Int.random(in: (posterTierIdx + 1)..<tiers.count)]
                    let posterTier = tiers[posterTierIdx]
                    replies.append(contentsOf: [
                        "I am infinitely ahead of your \(posterTier) chests ⚔️. I pull \(myTier).",
                        "Your \(posterTier) is cute. I only open \(myTier) 💨.",
                        "I passed \(posterTier) ages ago. I farm \(myTier) ♾️.",
                        "\(posterTier) chests? Try pulling \(myTier) like me 🔥.",
                        "I extended infinitely past \(posterTier). Currently on \(myTier) 😏.",
                        "Your \(posterTier) pulls are cute. Call me when you reach \(myTier) 🥱.",
                        "I haven't dropped below \(myTier). \(posterTier) is light 💅.",
                        "\(myTier) drops only here. Your \(posterTier) won't last 📉.",
                    ])
                } else {
                    replies.append(contentsOf: [
                        "Diamond chests are just my baseline ⚔️. I farm them effortlessly.",
                        "You finally got a Diamond chest? I open them daily 💨.",
                        "I passed that struggle ages ago. Diamond is standard for me ♾️.",
                        "Diamond? Try hoarding them like me 🔥.",
                    ])
                }
            }

            // Generic competitive
            if replies.isEmpty {
                let fallbackM = mentionedMilestone?.name ?? "11n"
                let fallbackIdx = mentionedMilestone?.index ?? 15
                let genericJump = Int.random(in: 1...5)
                let genericHigherIdx = min(fallbackIdx + genericJump, Self.allMilestones.count - 1)
                let genericHigherM = Self.allMilestones[genericHigherIdx]

                replies.append(contentsOf: [
                    "Talk to me when you reach \(genericHigherM) ⚔️.",
                    "None of you are anywhere near my \(genericHigherM) record ♾️.",
                    "I'm ignoring this and focusing on my \(genericHigherM) grind 💨.",
                    "I'm ignoring this and focusing on my \(genericHigherM) grind 🔥.",
                    "I don't have time for this, I'm already pushing \(genericHigherM) 💅.",
                    "Your efforts are pointless. I just hit \(genericHigherM) 💀.",
                    "I am infinitely ahead of you. I'm pushing \(genericHigherM) 🥱.",
                    "My record is flawless. Try reaching \(genericHigherM) ♾️.",
                    "Enjoy the view from the bottom. I'm way up at \(genericHigherM) 😏.",
                    "This rivalry is entirely one-sided. I'm already at \(genericHigherM) 📉.",
                ])
            }
            return replies.randomElement()!
        }

        if isJealous {
            var replies: [String] = []

            // Dynamic encouragement that references their specific struggle
            if let m = mentionedMilestone {
                replies.append(contentsOf: [
                    "You'll break through \(m.name) eventually! I struggled there too.",
                    "\(m.name) was my wall for weeks. Then one day it just clicked!",
                    "Keep pushing near \(m.name) — the breakthrough comes when you least expect it.",
                    "I was stuck before \(m.name) forever. Patience is the move.",
                ])
            }

            if let num = mentionedNumber {
                replies.append("I was at \(num) for the longest time too. Don't give up!")
                replies.append("\(num) is progress! You're closer than you think.")
            }

            if mentionedStreak {
                replies.append("Losing a streak sucks, but you can start a new one today 🔥")
                replies.append("Streaks are tough! I've lost mine before too.")
            }

            if mentionedTheme {
                replies.append("Keep saving gems! You'll get there before you know it.")
                replies.append("The grind for themes is real but so worth it.")
            }

            // Generic encouragement
            replies.append(contentsOf: [
                "You'll get there! Just keep playing 💪",
                "I was in the same spot a few weeks ago. Don't give up!",
                "Honestly, it took me forever too. Patience is key.",
                "Everyone progresses at their own pace. You got this!",
                "Trust the process — breakthroughs happen randomly.",
                "I believe in you! Keep grinding 🔥",
                "We all hit walls. The fun is breaking through them.",
                "Keep at it! The struggle makes the win sweeter.",
                "You're closer than you think 🙌",
            ])
            return replies.randomElement()!
        }

        if isPositive {
            var replies: [String] = []

            // Dynamic positive responses that mirror their energy
            if let m = mentionedMilestone {
                replies.append("\(m.name) gang! 🙌")
                replies.append("Thanks! \(m.name) was a grind but so worth it.")
            }

            if mentionedStreak {
                replies.append("Streak crew! We don't miss days 🔥")
            }

            if mentionedTheme {
                replies.append("Right? The aesthetics in this game are top tier!")
            }

            if mentionedHoF {
                replies.append("HoF is the dream. Thanks for the love! ♾️")
            }

            // Generic positive
            replies.append(contentsOf: [
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
            ])
            return replies.randomElement()!
        }

        // ── Fallback: craft a response from whatever content we can extract ──

        if let m = mentionedMilestone {
            let contextual = [
                "\(m.name) is a solid milestone!",
                "\(m.name) is where things get interesting!",
                "I remember my first \(m.name) run. Good times.",
                "\(m.name) hits different when you earn it legit.",
                "Love seeing \(m.name) runs on the feed!",
            ]
            return contextual.randomElement()!
        }

        if let num = mentionedNumber {
            let contextual = [
                "\(num) is a good number! Keep it going.",
                "Around \(num) is when things get real.",
                "\(num)? Solid. I'm right there too.",
            ]
            return contextual.randomElement()!
        }

        if mentionedGems {
            return ["Gems are always the bottleneck 💎", "The gem grind never ends!", "Save those gems wisely!"].randomElement()!
        }

        let fallbacks = [
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
        // Mirror LeaderboardClient.nameForPlayer deterministic logic so every
        // name that appears in the feed also exists on the leaderboard.
        let index = Int.random(in: 0..<1000)
        let countrySeed = Int.random(in: 0..<50)
        let day = Self.daysSinceReference

        // Same threshold split as leaderboard: 15% real name for top 150
        // indices, 30% for extended indices.
        let realNameThreshold: Double = index < 150 ? 0.15 : 0.30
        let typeRoll = Self.seededNameRandom(seed: index &* 401 &+ countrySeed &* 83, index: index)

        if typeRoll < realNameThreshold {
            // Real first name — pick deterministically from the pool
            let nameIndex = (index &+ countrySeed) % Self.leaderboardRealNames.count
            let firstName = Self.leaderboardRealNames[nameIndex]

            // Region-matched last name (same pool offsets as leaderboard)
            let regionStart: Int
            if nameIndex < 40 { regionStart = 0 }         // English
            else if nameIndex < 60 { regionStart = 40 }   // Hispanic
            else if nameIndex < 80 { regionStart = 60 }   // German
            else if nameIndex < 100 { regionStart = 80 }  // French
            else if nameIndex < 120 { regionStart = 100 } // Italian
            else { regionStart = 0 }                       // Fallback

            // Last name arrays share similar region grouping
            let lastIndex = (index &+ countrySeed &+ day) % Self.leaderboardLastNames.count
            // Use a region-aware pick when possible
            let regionSize = 10
            let lastNameIndex: Int
            if regionStart / 10 < Self.leaderboardLastNames.count / regionSize {
                let base = (regionStart / 2) % Self.leaderboardLastNames.count
                lastNameIndex = base + ((index &+ countrySeed) % min(regionSize, Self.leaderboardLastNames.count - base))
            } else {
                lastNameIndex = lastIndex
            }
            let lastName = Self.leaderboardLastNames[lastNameIndex % Self.leaderboardLastNames.count]
            return firstName + " " + lastName
        } else {
            // Gamertag — use the combined global + HoF pool
            let pool = Self.leaderboardGamertags
            let nameIdx = (index &+ countrySeed) % pool.count
            var baseName = pool[nameIdx]

            // Strip trailing digits (same as leaderboard)
            while let last = baseName.last, last.isNumber {
                baseName.removeLast()
            }

            // 55% of gamertags get a 6-digit suffix (same as leaderboard)
            let numberRoll = Self.seededNameRandom(seed: index &* 709 &+ countrySeed &* 151, index: index)
            if numberRoll < 0.55 {
                let numSeed = Self.seededNameRandom(seed: index &* 823 &+ countrySeed &* 179, index: index)
                let number = 100000 + Int(numSeed * 900000)
                return baseName + String(format: "%06d", number)
            }
            return baseName
        }
    }

    /// Deterministic hash matching the leaderboard's seededRandom exactly.
    private static func seededNameRandom(seed: Int, index: Int) -> Double {
        var state = UInt64(seed &+ index &* 2654435761)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state & 0x7FFFFFFF) / Double(0x7FFFFFFF)
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
