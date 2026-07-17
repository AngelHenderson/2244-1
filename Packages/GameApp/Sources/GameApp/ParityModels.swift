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
    func deleteItem(itemID: UUID) async throws
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

    public func deleteItem(itemID: UUID) async throws {
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
    private nonisolated(unsafe) static var feedGenerationSeenNames: Set<String> = []
    private static let seenNamesLock = NSLock()
    nonisolated(unsafe) public static var gamertagProvider: (@Sendable () -> [String])? = nil

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

    // For milestones, we use an exhaustive ordered array so we can find exactly
    // which one is referenced and then randomly choose one that is strictly higher.
    static let allMilestones: [String] = {
        return (0...816).map { JourneyTileGenerator.formatTileAtStep($0) }
    }()

    static let milestoneTokensRegex: NSRegularExpression = {
        return try! NSRegularExpression(pattern: "(?<!:)\\b\\d+[a-zA-Z]*\\b(?!:)", options: [])
    }()

    static let milestoneLookup: [String: Int] = {
        var map: [String: Int] = [:]
        for (idx, m) in allMilestones.enumerated() {
            map[m] = idx
        }
        return map
    }()

    static func lookupMilestoneIndex(for token: String) -> Int? {
        if let idx = milestoneLookup[token] {
            return idx
        }
        let suffix = token.suffix(1).uppercased()
        if ["K", "M", "B", "T"].contains(suffix) {
            let candidate = String(token.dropLast() + suffix)
            if let idx = milestoneLookup[candidate] {
                return idx
            }
        }
        let lower = token.lowercased()
        if let idx = milestoneLookup[lower] {
            return idx
        }
        return nil
    }

    static var daysSinceReference: Int {
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 20
        let ref = Calendar.current.date(from: components) ?? Date()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfReference = Calendar.current.startOfDay(for: ref)
        return max(0, Calendar.current.dateComponents([.day], from: startOfReference, to: startOfToday).day ?? 0)
    }

    static func isTooLowOrSlowReply(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("too low") ||
               lower.contains("too slow") ||
               lower.contains("not fast enough") ||
               lower.contains("laughing from") ||
               lower.contains("in the dust") ||
               lower.contains("acting like") ||
               lower.contains("nothing compared to my") ||
               lower.contains("leaves you behind") ||
               lower.contains("is a joke")
    }

    static func determineTopic(message: String) -> String {
        let msgLower = message.lowercased()
        let msgWords = Set(msgLower.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))
        
        var rootMilestoneExists = false
        let nsStr = message as NSString
        let matches = Self.milestoneTokensRegex.matches(in: message, range: NSRange(location: 0, length: nsStr.length))
        for match in matches {
            let token = nsStr.substring(with: match.range)
            if Self.lookupMilestoneIndex(for: token) != nil {
                rootMilestoneExists = true
                break
            }
        }

        let hasTimeFormatRoot = (try? NSRegularExpression(pattern: "\\b\\d{1,2}:\\d{2}\\b"))?.firstMatch(in: msgLower, range: NSRange(msgLower.startIndex..., in: msgLower)) != nil
        let isMessageTime = hasTimeFormatRoot || ((msgLower.contains("timed") || msgLower.contains("challenge") || !msgWords.isDisjoint(with: ["sec", "secs", "min", "mins", "compete"])) && !rootMilestoneExists)
        let isMessageHoF = msgLower.contains("hall of fame") || msgLower.contains("infinity") || msgLower.contains("infinities") || !msgWords.isDisjoint(with: ["hof", "infinit"])
        let isMessageStreak = !msgWords.isDisjoint(with: ["streak", "day", "days", "consecutive"]) || msgLower.contains("streak")

        if isMessageHoF {
            return "hof"
        } else if isMessageTime {
            return "time"
        } else if isMessageStreak {
            return "streak"
        } else {
            return "milestone"
        }
    }

    static func findEstablishedValue(for author: String, in comments: [SocialFeedComment], topic: String) -> String? {
        for comment in comments.reversed() {
            if comment.authorName == author {
                if let val = extractValue(from: comment.text, topic: topic) {
                    return val
                }
            }
        }
        return nil
    }

    static func extractValue(from text: String, topic: String) -> String? {
        var matches: [(val: String, range: NSRange)] = []
        let nsText = text as NSString
        
        switch topic {
        case "hof", "streak":
            if let pattern = try? NSRegularExpression(pattern: "(?<!:)\\b(\\d{1,6})(?:d|day|days)?\\b(?!:)") {
                let regexMatches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for m in regexMatches {
                    if m.numberOfRanges > 1 {
                        let r = m.range(at: 1)
                        let val = nsText.substring(with: r)
                        matches.append((val: val, range: m.range))
                    }
                }
            }
            
        case "time":
            if let pattern = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})") {
                let regexMatches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for m in regexMatches {
                    let val = nsText.substring(with: m.range)
                    matches.append((val: val, range: m.range))
                }
            }
            

        case "milestone":
            let regexMatches = Self.milestoneTokensRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for regMatch in regexMatches {
                let token = nsText.substring(with: regMatch.range)
                if let idx = Self.lookupMilestoneIndex(for: token) {
                    let finalVal = Self.allMilestones[idx]
                    if !matches.contains(where: { $0.range == regMatch.range }) {
                        matches.append((val: finalVal, range: regMatch.range))
                    }
                }
            }
            
        default:
            return nil
        }
        
        // Remove sub-range overlaps (keep the longer matches)
        var uniqueMatches: [(val: String, range: NSRange)] = []
        let sortedByLength = matches.sorted(by: { $0.range.length > $1.range.length })
        for candidate in sortedByLength {
            let isContained = uniqueMatches.contains { accepted in
                candidate.range.location >= accepted.range.location &&
                candidate.range.location + candidate.range.length <= accepted.range.location + accepted.range.length
            }
            if !isContained {
                uniqueMatches.append(candidate)
            }
        }
        
        func bestValue(among values: [String], topic: String) -> String? {
            guard !values.isEmpty else { return nil }
            var best = values[0]
            for v in values.dropFirst() {
                if isRecord(best, worseThan: v, topic: topic) {
                    best = v
                }
            }
            return best
        }
        
        // Filter out matches that are part of the leading @mention username
        var mentionLength = 0
        let filteredMatches: [(val: String, range: NSRange)]
        if text.hasPrefix("@") {
            let pattern = "^@[a-zA-Z0-9\\-]+(?:\\s+[a-zA-Z0-9\\-]+)?\\s*"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let matchedStr = nsText.substring(with: match.range)
                let parts = matchedStr.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
                if parts.count == 2 {
                    let secondWord = String(parts[1])
                    if Self.leaderboardLastNames.contains(secondWord) {
                        mentionLength = match.range.length
                    } else {
                        let firstWordPattern = "^@[a-zA-Z0-9\\-]+\\s*"
                        if let firstRegex = try? NSRegularExpression(pattern: firstWordPattern),
                           let firstMatch = firstRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                            mentionLength = firstMatch.range.length
                        }
                    }
                } else {
                    mentionLength = match.range.length
                }
            }
            filteredMatches = uniqueMatches.filter { $0.range.location >= mentionLength }
        } else {
            filteredMatches = uniqueMatches
        }
        
        guard !filteredMatches.isEmpty else { return nil }
        
        // Score each candidate based on context
        var scoredMatches: [(val: String, netScore: Int)] = []
        let speakerKeywords = ["i'm", "i am", "my", "floor", "coasting", "best", "clocked", "untouched", "permanent", "pull", "farm", "laughing", "sitting", "cleared", "record", "down to", "pushing", "i own", "hoard", "standard", "clear", "reached", "hit", "clocked", "posted"]
        let otherKeywords = ["your", "you're", "celebrating"]
        
        func getClausePrefix(from text: String, startLoc: Int, mentionLength: Int) -> String {
            let prefixLen = min(80, startLoc - mentionLength)
            guard prefixLen > 0 else { return "" }
            let prefixRange = NSRange(location: startLoc - prefixLen, length: prefixLen)
            let rawPrefix = (text as NSString).substring(with: prefixRange).lowercased()
            
            let separators: [Character] = [".", "?", "!", ";"]
            if let lastSepIdx = rawPrefix.lastIndex(where: { separators.contains($0) }) {
                let nextIdx = rawPrefix.index(after: lastSepIdx)
                return String(rawPrefix[nextIdx...])
            }
            return rawPrefix
        }
        
        for match in filteredMatches {
            let prefixText = getClausePrefix(from: text, startLoc: match.range.location, mentionLength: mentionLength)
            
            var speakerScore = 0
            var otherScore = 0
            for kw in speakerKeywords { if prefixText.contains(kw) { speakerScore += 1 } }
            for kw in otherKeywords { if prefixText.contains(kw) { otherScore += 1 } }
            let netScore = speakerScore - otherScore
            scoredMatches.append((val: match.val, netScore: netScore))
        }
        
        if let maxScore = scoredMatches.map({ $0.netScore }).max(), maxScore >= 0 {
            let bestMatches = scoredMatches.filter { $0.netScore == maxScore }
            if bestMatches.count == 1 {
                return bestMatches[0].val
            } else {
                return bestValue(among: bestMatches.map { $0.val }, topic: topic)
            }
        }
        
        return nil
    }

    static func randomMilestoneJump() -> Int {
        let randVal = Double.random(in: 0...100)
        switch randVal {
        case 0..<5.6:
            return 1
        case 5.6..<13.0:
            return 2
        case 13.0..<24.0:
            return 3
        case 24.0..<39.0:
            return 4
        case 39.0..<58.0:
            return 5
        case 58.0..<73.0:
            return 6
        case 73.0..<84.0:
            return 7
        case 84.0..<91.4:
            return 8
        case 91.4..<97.0:
            return 9
        default:
            return 10
        }
    }

    static func oneUpValue(for val: String?, topic: String) -> String {
        switch topic {
        case "hof":
            let current = val.flatMap(Int.init) ?? Int.random(in: 1...5)
            return String(current + Int.random(in: 1...10))
            
        case "streak":
            let current = val.flatMap(Int.init) ?? Int.random(in: 5...30)
            return String(current + Int.random(in: 1...2))
            
        case "time":
            func timeToSeconds(_ timeStr: String) -> Int {
                let parts = timeStr.split(separator: ":")
                guard parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) else { return 60 }
                return mins * 60 + secs
            }
            let currentSecs = val.map(timeToSeconds) ?? Int.random(in: 60...120)
            let newSecs: Int
            if currentSecs <= 10 {
                newSecs = max(2, currentSecs - Int.random(in: 1...3))
            } else {
                newSecs = max(10, currentSecs - Int.random(in: 2...10))
            }
            let mins = newSecs / 60
            let secs = newSecs % 60
            return "\(mins):\(String(format: "%02d", secs))"
            

        case "milestone":
            guard let currentVal = val, let idx = Self.allMilestones.firstIndex(of: currentVal) else {
                return JourneyTileGenerator.formatTileAtStep(10)
            }
            let jump = Self.randomMilestoneJump()
            let newIdx = min(idx + jump, Self.allMilestones.count - 1)
            return Self.allMilestones[newIdx]
            
        default:
            return "10"
        }
    }

    static func requiredTimeDelay(from val1: String?, to val2: String?, topic: String) -> Double {
        guard let v1 = val1, let v2 = val2 else {
            return Double.random(in: 60...120)
        }
        
        switch topic {
        case "milestone":
            let idx1 = Self.allMilestones.firstIndex(of: v1)
            let idx2 = Self.allMilestones.firstIndex(of: v2)
            if let i1 = idx1, let i2 = idx2 {
                let diff = abs(i2 - i1)
                if diff > 0 {
                    return Double(diff) * Double.random(in: 60...120)
                }
            }
        case "hof":
            let n1 = Int(v1) ?? 0
            let n2 = Int(v2) ?? 0
            let diff = abs(n2 - n1)
            if diff > 0 {
                return Double(diff) * Double.random(in: 60...180)
            }
        case "streak":
            let n1 = Int(v1) ?? 0
            let n2 = Int(v2) ?? 0
            let diff = abs(n2 - n1)
            if diff > 0 {
                return Double(diff) * 3600.0 + Double.random(in: 60...180)
            }
        case "time":
            return Double.random(in: 300...600)
        default:
            break
        }
        return Double.random(in: 60...120)
    }

    static func lowerValue(for val: String?, topic: String) -> String {
        switch topic {
        case "hof":
            let current = val.flatMap(Int.init) ?? 10
            return String(max(1, current - Int.random(in: 1...2)))
            
        case "streak":
            return "0"
            
        case "time":
            func timeToSeconds(_ timeStr: String) -> Int {
                let parts = timeStr.split(separator: ":")
                guard parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) else { return 60 }
                return mins * 60 + secs
            }
            let currentSecs = val.map(timeToSeconds) ?? 60
            let newSecs = currentSecs + Int.random(in: 2...10)
            let mins = newSecs / 60
            let secs = newSecs % 60
            return "\(mins):\(String(format: "%02d", secs))"
            

        case "milestone":
            guard let currentVal = val, let idx = Self.allMilestones.firstIndex(of: currentVal) else {
                return JourneyTileGenerator.formatTileAtStep(4)
            }
            // Milestones can't go down naturally unless the user starts over completely,
            // so we shouldn't dynamically lower them during a short thread exchange.
            // We just keep the milestone the same.
            return Self.allMilestones[idx]
            
        default:
            return "2"
        }
    }

    static func isRecord(_ rec1: String, worseThan rec2: String, topic: String) -> Bool {
        switch topic {
        case "hof", "streak":
            guard let int1 = Int(rec1), let int2 = Int(rec2) else { return false }
            return int1 < int2

        case "time":
            func timeToSeconds(_ timeStr: String) -> Int? {
                let parts = timeStr.split(separator: ":")
                guard parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) else { return nil }
                return mins * 60 + secs
            }
            guard let sec1 = timeToSeconds(rec1), let sec2 = timeToSeconds(rec2) else { return false }
            return sec1 > sec2
        case "milestone":
            guard let idx1 = Self.allMilestones.firstIndex(of: rec1),
                  let idx2 = Self.allMilestones.firstIndex(of: rec2) else { return false }
            return idx1 < idx2
        default:
            return false
        }
    }

    static func commentPredictsStreakLoss(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("lose your") ||
               lower.contains("lose it") ||
               lower.contains("break your") ||
               lower.contains("slip up") ||
               lower.contains("bound to lose")
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
        let seed = index * 131 + countrySeed * 17
        let random = seededRandom(seed: seed, index: index)
        let avatarIndex = Int(random * Double(allAvatars.count))
        return allAvatars[avatarIndex % allAvatars.count]
    }

    static func avatarForPlayer(index: Int, countrySeed: Int, day: Int) -> String {
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
}
        return avatarForPlayer(index: index, countrySeed: countrySeed)
    }

    public static let feedCacheKey = "socialFeed.cache.v52"
    public static let feedDateKey = "socialFeed.cacheDate.v63"
    /// Version-independent key for user-posted events so they survive cache bumps.
    public static let userPostsKey = "socialFeed.userPosts.v7"

    
    // MARK: - File Storage
    private static var storageDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("GameAppCache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var feedCacheURL: URL {
        storageDirectory.appendingPathComponent("socialFeedCache_v63.json")
    }
    
    private static var userPostsURL: URL {
        storageDirectory.appendingPathComponent("socialUserPosts_v7.json")
    }

    
    #if DEBUG
    public static var feedCacheURLForTests: URL { feedCacheURL }
    public static func clearFileStorageForTests() {
        try? FileManager.default.removeItem(at: userPostsURL)
        try? FileManager.default.removeItem(at: feedCacheURL)
    }
    #endif

    public static func loadUserPosts() -> [SocialFeedItem]? {
        #if DEBUG
        if let override = inMemoryUserPostsOverride {
            return override
        }
        #endif
        guard let data = try? Data(contentsOf: userPostsURL) else {
            // Fallback to UserDefaults migration
            let defaults = UserDefaults.standard
            if let data = defaults.data(forKey: Self.userPostsKey),
               let items = try? JSONDecoder().decode([SocialFeedItem].self, from: data) {
                saveUserPosts(items)
                return items
            }
            return nil
        }
        return try? JSONDecoder().decode([SocialFeedItem].self, from: data)
    }
    
    private static func saveUserPosts(_ posts: [SocialFeedItem]) {
        #if DEBUG
        if inMemoryUserPostsOverride != nil {
            inMemoryUserPostsOverride = posts
            return
        }
        #endif
        if let data = try? JSONEncoder().encode(posts) {
            try? data.write(to: userPostsURL, options: .atomic)
        }
    }
    
    public static func loadFeedCache() -> [SocialFeedItem]? {
        #if DEBUG
        if let override = inMemoryFeedOverride {
            return override
        }
        #endif
        guard let data = try? Data(contentsOf: feedCacheURL) else { return nil }
        return try? JSONDecoder().decode([SocialFeedItem].self, from: data)
    }
    
    private static func saveFeedCache(_ feed: [SocialFeedItem]) {
        #if DEBUG
        if inMemoryFeedOverride != nil {
            inMemoryFeedOverride = feed
            return
        }
        #endif
        if let data = try? JSONEncoder().encode(feed) {
            try? data.write(to: feedCacheURL, options: .atomic)
        }
    }

    public func feed() async throws -> [SocialFeedItem] {
        let now = Date()
        let cal = Calendar.current
        let todayString = cal.dateComponents([.year, .month, .day], from: now)
            .description // deterministic for the same day

        // Return cached feed if it was generated today
        let defaults = UserDefaults.standard
        let playerName = defaults.string(forKey: "profilePlayerName") ?? "Player"
        #if DEBUG
        let shouldBypass = Self.bypassFeedCache
        #else
        let shouldBypass = false
        #endif
        if !shouldBypass,
           let cachedDate = defaults.string(forKey: Self.feedDateKey),
           cachedDate == todayString,
           var cached = Self.loadFeedCache() {
            
            // Filter out future posts so they arrive naturally throughout the day
            cached = cached.filter { $0.createdAt <= now }
            
            // Filter out future comments so simulated responses arrive naturally, but always show player comments
            for i in 0..<cached.count {
                cached[i].comments = cached[i].comments.filter { $0.createdAt <= now || $0.authorName == playerName || $0.authorName == "Player" }
                cached[i].commentCount = cached[i].comments.count
                if let rts = cached[i].reactionTimestamps {
                    var count = rts.filter { $0 <= now }.count
                    if cached[i].isHearted == true {
                        count += 1
                    }
                    cached[i].reactionCount = count
                }
            }
            return cached
        }

        // Generate fresh feed
        var items = generateFeedItems(now: now)

        // Merge in all user posts so they survive cache regeneration
        if let userPosts = Self.loadUserPosts() {
            let existingIDs = Set(items.map { $0.id })
            for post in userPosts where !existingIDs.contains(post.id) {
                items.append(post)
            }
            items.sort { $0.createdAt > $1.createdAt }
        }

        // Cache for the rest of the day
        if !shouldBypass, let data = try? JSONEncoder().encode(items) {
            Self.saveFeedCache(items)
            defaults.set(todayString, forKey: Self.feedDateKey)
        }

        // Apply time-filtering to the returned array so simulated future events don't show up yet
        items = items.filter { $0.createdAt <= now }
        for i in 0..<items.count {
            items[i].comments = items[i].comments.filter { $0.createdAt <= now || $0.authorName == playerName || $0.authorName == "Player" }
            items[i].commentCount = items[i].comments.count
            if let rts = items[i].reactionTimestamps {
                var count = rts.filter { $0 <= now }.count
                if items[i].isHearted == true {
                    count += 1
                }
                items[i].reactionCount = count
            }
        }

        return items
    }

    public func addComment(to itemID: UUID, text: String) async throws {
        let defaults = UserDefaults.standard
        var foundAndUpdated: SocialFeedItem? = nil
        
        let now = Date()
        let playerName = defaults.string(forKey: "profilePlayerName") ?? "Player"
        let playerAvatar = defaults.string(forKey: "profileAvatarId") ?? "avatar_buddy_bot"
        func processItem(_ item: inout SocialFeedItem) {
            let replyDate = now
            var targetComment: SocialFeedComment? = nil
            if text.hasPrefix("@") {
                let mentionContent = String(text.dropFirst())
                targetComment = item.comments.last(where: { comment in
                    mentionContent.hasPrefix(comment.authorName)
                })
            }
            let newComment = SocialFeedComment(authorName: playerName, avatarID: playerAvatar, text: text, createdAt: replyDate)
            item.comments.append(newComment)
            
            let delay = Double.random(in: 45...180)
            let responseTime = replyDate.addingTimeInterval(delay)
            
            let responderName: String
            let responderIndex = Int.random(in: 1...100000)
            let responderAvatar: String
            if text.hasPrefix("@") {
                if let tC = targetComment {
                    responderName = tC.authorName
                } else {
                    let parts = text.split(separator: " ")
                    if let first = parts.first {
                        responderName = String(first.dropFirst())
                    } else {
                        responderName = generateDynamicName()
                    }
                }
                responderAvatar = targetComment?.avatarID ?? Self.avatarForPlayer(index: responderIndex, countrySeed: 0, day: Self.daysSinceReference)
            } else {
                responderName = item.authorName
                responderAvatar = item.avatarID
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
            
            let baseText = targetComment?.text ?? item.message
            
            var posterBeatsNPC = false
            let loweredText = text.lowercased()
            let loweredBase = baseText.lowercased()
            
            let playerBragged = Self.extractTime(from: loweredText) != nil || Self.allMilestones.contains(where: { loweredText.contains($0.lowercased()) }) || extractMaxNumber(from: text) >= 3 || loweredText.contains("streak") || loweredText.contains("day") || loweredText.contains("infinity") || loweredText.contains("hof") || loweredText.contains("time")
            
            let topic = Self.determineTopic(message: baseText)
            if let cVal = Self.extractValue(from: text, topic: topic),
               let bVal = Self.extractValue(from: baseText, topic: topic) {
                if MockSocialService.isRecord(bVal, worseThan: cVal, topic: topic) {
                    posterBeatsNPC = true
                }
            } else {
                let cNum = extractMaxNumber(from: text)
                let bNum = extractMaxNumber(from: baseText)
                if cNum > 0 && cNum > bNum {
                    posterBeatsNPC = true
                }
            }
            
            if loweredText.contains("do better") {
                posterBeatsNPC = true
            }
            
            let answer = milestoneAnswer(for: text)
            if posterBeatsNPC || answer != nil || playerBragged || targetComment != nil {
                let responseText: String
                if let ans = answer {
                    responseText = "@\(playerName) " + ans
                } else {
                    let tone = posterBeatsNPC ? "behind" : "one_up"
                    responseText = "@\(playerName) " + generateContextualReply(to: text, message: baseText, forceTone: tone)
                }
                let responseComment = SocialFeedComment(authorName: responderName, avatarID: responderAvatar, text: responseText, createdAt: responseTime)
                item.comments.append(responseComment)
                
                // Add a second reply in a row if the player beats the NPC (triggering behind tone)
                if posterBeatsNPC && answer == nil && topic != "streak" {
                    let topic = Self.determineTopic(message: baseText)
                    if let playerVal = Self.extractValue(from: text, topic: topic) {
                        let finalNPCValue: String
                        let toneStr: String
                        if Double.random(in: 0...1) < 0.20 && topic != "streak" {
                            finalNPCValue = playerVal
                            toneStr = "caught_up"
                        } else {
                            finalNPCValue = Self.oneUpValue(for: playerVal, topic: topic)
                            toneStr = "one_up"
                        }
                        
                        let secondResponseText = "@\(playerName) " + generateContextualReply(
                            to: text,
                            message: baseText,
                            forceTone: toneStr,
                            speakerValue: finalNPCValue,
                            opponentValue: playerVal
                        )
                        
                        var catchUpDelay = Double.random(in: 30...60)
                        if let prevVal = Self.extractValue(from: responseText, topic: topic) {
                            switch topic {
                            case "milestone":
                                let idx1 = Self.allMilestones.firstIndex(of: prevVal)
                                let idx2 = Self.allMilestones.firstIndex(of: finalNPCValue)
                                if let i1 = idx1, let i2 = idx2 {
                                    let diff = max(0, i2 - i1)
                                    catchUpDelay += Double(diff) * Double.random(in: 60...120)
                                }
                            case "hof":
                                let n1 = Int(prevVal) ?? 0
                                let n2 = Int(finalNPCValue) ?? 0
                                let diff = max(0, n2 - n1)
                                catchUpDelay += Double(diff) * Double.random(in: 60...180)
                            case "time":
                                func timeToSecs(_ timeStr: String) -> Int {
                                    let parts = timeStr.split(separator: ":")
                                    guard parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) else { return 0 }
                                    return mins * 60 + secs
                                }
                                let s1 = timeToSecs(prevVal)
                                let s2 = timeToSecs(finalNPCValue)
                                let diff = max(0, s1 - s2)
                                catchUpDelay += Double(diff) * 30.0
                            default:
                                break
                            }
                        }
                        
                        let secondResponseTime = responseTime.addingTimeInterval(catchUpDelay)
                        let secondComment = SocialFeedComment(
                            authorName: responderName,
                            avatarID: responderAvatar,
                            text: secondResponseText,
                            createdAt: secondResponseTime,
                            likes: Int.random(in: 1...5)
                        )
                        item.comments.append(secondComment)
                    }
                }
            }
            
            item.comments.sort { $0.createdAt < $1.createdAt }
            item.commentCount = item.comments.count
        }

        if var cached = Self.loadFeedCache(),
           let index = cached.firstIndex(where: { $0.id == itemID }) {
            
            processItem(&cached[index])
            if let newData = try? JSONEncoder().encode(cached) {
                Self.saveFeedCache(cached)
            }
            foundAndUpdated = cached[index]
        }
        
        if foundAndUpdated == nil {
            if var userPosts = Self.loadUserPosts(),
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
        let targetTotalComments = Int.random(in: 45...85)
        let targetComp = Int(round(Double(targetTotalComments) * 0.55))
        var compCount = 0
        var usedStats: Set<String> = []
        
        var i = 0
        while comments.count < targetTotalComments {
            let neededComp = targetComp - compCount
            let neededTotal = targetTotalComments - comments.count
            
            var toneStr: String
            let probComp = neededTotal > 0 ? Double(max(0, neededComp)) / Double(neededTotal) : 0
            
            if Double.random(in: 0...1) < probComp {
                toneStr = "competitive"
            } else {
                let r = Double.random(in: 0...1)
                if r < 0.55 { toneStr = "positive" }
                else if r < 0.88 { toneStr = "question" }
                else { toneStr = "sad" }
            }
            let startingCount = comments.count
            
            var commenter = generateDynamicName()
            while commenter == playerName {
                commenter = generateDynamicName()
            }
            let commenterIndex = Int.random(in: 1...100000)
            let commenterAvatar = Self.avatarForPlayer(index: commenterIndex, countrySeed: 0, day: currentDay)
            
            let topic = Self.determineTopic(message: message)
            let isRootStreakLoss = topic == "streak" && (message.lowercased().contains("lost") || message.lowercased().contains("dropped") || message.lowercased().contains("reset") || message.lowercased().contains("forgot") || message.lowercased().contains("dead") || message.lowercased().contains("failed") || message.lowercased().contains("broke"))
            let rootValue = isRootStreakLoss ? "0" : Self.extractValue(from: message, topic: topic)
            
            let (commentBase, nameOverride, tone, rootValRaw) = generateDynamicComment(message: message, usedStats: &usedStats, forcedTone: toneStr)
            var finalCommenter = nameOverride ?? commenter
            while finalCommenter == playerName {
                finalCommenter = generateDynamicName()
            }
            
            let baseOffset: Double
            if i == 0 {
                // First comment arrives extremely fast (10-30 seconds) for instant engagement
                baseOffset = Double.random(in: 10...30)
            } else if i == 1 {
                // Second comment arrives within a couple minutes (60-180 seconds)
                baseOffset = Double.random(in: 60...180)
            } else if tone == "competitive" || tone == "behind_competitive" {
                baseOffset = Self.requiredTimeDelay(from: rootValue, to: rootValRaw, topic: topic)
            } else {
                // Non-competitive comments arrive mostly in the first 15 minutes to match the early heart surge
                if Double.random(in: 0...1) < 0.85 {
                    baseOffset = Double.random(in: 30...900)
                } else {
                    baseOffset = Double.random(in: 900...3600)
                }
            }
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
                
                var npc1Value = Self.extractValue(from: baseComment.text, topic: topic) ?? rootValue
                var npc2Value: String? = nil
                
                var isNpc2Turn = true
                var npc1PreviousComment: String? = baseComment.text
                var npc2PreviousComment: String? = nil
                var tieRepliesCount = 0
                
                // Ensure competitive threads always have at least 2 replies so NPCs can beat each other's record
                let targetDepth: Int
                if topic == "streak" {
                    targetDepth = Double.random(in: 0...1) < 0.85 ? Int.random(in: 1...2) : 0
                } else {
                    targetDepth = Double.random(in: 0...1) < 0.85 ? Int.random(in: 2...5) : 0
                }
                while currentDepth < targetDepth {
                    if npc2 == nil {
                        let replyIndex = Int.random(in: 1...100000)
                        var rName = generateDynamicName()
                        while rName == npc1.name || rName == playerName {
                            rName = generateDynamicName()
                        }
                        npc2 = (name: rName, avatar: Self.avatarForPlayer(index: replyIndex, countrySeed: 0, day: currentDay))
                    }
                    
                    var npc2JustLostStreak = false
                    if topic == "streak" && Self.commentPredictsStreakLoss(lastComment.text) {
                        if Double.random(in: 0...1) < 0.60 {
                            npc2Value = "0"
                            npc2JustLostStreak = true
                        }
                    }
                    
                    if isNpc2Turn {
                        if npc2Value == nil {
                            if let n1Val = npc1Value {
                                if Double.random(in: 0...1) < 0.20 {
                                    npc2Value = n1Val // Force a tie
                                } else if Double.random(in: 0...1) < 0.20 {
                                    npc2Value = Self.lowerValue(for: n1Val, topic: topic)
                                } else {
                                    npc2Value = Self.oneUpValue(for: n1Val, topic: topic)
                                }
                            }
                        }
                        
                        if let n1Val = npc1Value, let n2Val = npc2Value {
                            if Self.isRecord(n2Val, worseThan: n1Val, topic: topic) {
                                if Double.random(in: 0...1) < 0.70 {
                                    npc2Value = Self.oneUpValue(for: n1Val, topic: topic)
                                }
                            } else if n1Val == n2Val && tieRepliesCount >= 2 {
                                npc2Value = Self.oneUpValue(for: n1Val, topic: topic)
                            }
                        }
                        
                        let isBehind: Bool
                        let isEqual: Bool
                        if let n1Val = npc1Value, let n2Val = npc2Value {
                            isBehind = Self.isRecord(n2Val, worseThan: n1Val, topic: topic)
                            isEqual = n1Val == n2Val
                        } else {
                            isBehind = false
                            isEqual = false
                        }
                        if isEqual {
                            tieRepliesCount += 1
                        } else {
                            tieRepliesCount = 0
                        }
                        
                        let toneStr = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                        let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: toneStr, speakerValue: npc2Value, opponentValue: npc1Value, previousSelfComment: npc2PreviousComment)
                        npc2PreviousComment = replyText
                        let replyOffset = Self.requiredTimeDelay(from: npc1Value, to: npc2Value, topic: topic)
                        let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
                        
                        let replyComment = SocialFeedComment(
                            authorName: npc2!.name,
                            avatarID: npc2!.avatar,
                            text: replyText,
                            createdAt: replyCreatedAt,
                            likes: Int.random(in: 0...5)
                        )
                        comments.append(replyComment)
                        lastComment = replyComment
                        currentDepth += 1
                    } else {
                        var npc1JustLostStreak = false
                        if topic == "streak" && Self.commentPredictsStreakLoss(lastComment.text) {
                            if Double.random(in: 0...1) < 0.60 {
                                npc1Value = "0"
                                npc1JustLostStreak = true
                            }
                        }
                        
                        
                        if let n1Val = npc1Value, let n2Val = npc2Value, !npc1JustLostStreak {
                            if Self.isRecord(n1Val, worseThan: n2Val, topic: topic) {
                                if Double.random(in: 0...1) < 0.70 {
                                    npc1Value = Self.oneUpValue(for: n2Val, topic: topic)
                                }
                            } else if n1Val == n2Val && tieRepliesCount >= 2 {
                                npc1Value = Self.oneUpValue(for: n2Val, topic: topic)
                            }
                        }
                        
                        let isBehind: Bool
                        let isEqual: Bool
                        if let sVal = npc1Value, let oVal = npc2Value {
                            isBehind = Self.isRecord(sVal, worseThan: oVal, topic: topic)
                            isEqual = sVal == oVal
                        } else {
                            isBehind = false
                            isEqual = false
                        }
                        if isEqual {
                            tieRepliesCount += 1
                        } else {
                            tieRepliesCount = 0
                        }
                        
                        let toneStr = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                        let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: toneStr, speakerValue: npc1Value, opponentValue: npc2Value, previousSelfComment: npc1PreviousComment)
                        npc1PreviousComment = replyText
                        let replyOffset = Self.requiredTimeDelay(from: npc2Value, to: npc1Value, topic: topic)
                        let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
                        
                        let replyComment = SocialFeedComment(
                            authorName: npc1.name,
                            avatarID: npc1.avatar,
                            text: replyText,
                            createdAt: replyCreatedAt,
                            likes: Int.random(in: 0...5)
                        )
                        comments.append(replyComment)
                        lastComment = replyComment
                        currentDepth += 1
                    }
                    isNpc2Turn.toggle()
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
                        let topic = Self.determineTopic(message: message)
                        let speakerVal = Self.findEstablishedValue(for: replyAuthor, in: comments, topic: topic)
                        if Double.random(in: 0...1) < 0.7 {
                            replyText = "@\(playerName) " + generateContextualReply(to: message, message: message, speakerValue: speakerVal)
                        } else {
                            replyText = "@\(baseComment.authorName) " + generateContextualReply(to: baseComment.text, message: message, speakerValue: speakerVal)
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
            
            let addedCount = comments.count - startingCount
            if tone == "competitive" {
                compCount += addedCount
            }
            i += 1
        }

        // Heart/reaction timestamps mirror comment speed (55% fast, 45% slow)
        let minReactions = max(10, comments.count * 4)
        let maxReactions = max(15, comments.count * 10)
        let numReactions = Int.random(in: minReactions...maxReactions)
        var rTimestamps: [Date] = []
        for i in 0..<numReactions {
            if i < 3 {
                // First 3 reactions arrive instantly (1 to 10 seconds)
                rTimestamps.append(now.addingTimeInterval(Double.random(in: 1...10)))
            } else if Double.random(in: 0...1) < 0.55 {
                rTimestamps.append(now.addingTimeInterval(Double.random(in: 15...900)))
            } else {
                rTimestamps.append(now.addingTimeInterval(Double.random(in: 900...345600)))
            }
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
        let cal = Calendar.current
        let todayString = cal.dateComponents([.year, .month, .day], from: now).description
        let isCacheValid = defaults.string(forKey: Self.feedDateKey) == todayString
        
        var cached: [SocialFeedItem]
        if isCacheValid, let existing = Self.loadFeedCache() {
            cached = existing
        } else {
            cached = generateFeedItems(now: now)
        }
        
        cached.insert(newItem, at: 0)
        Self.saveFeedCache(cached)
        defaults.set(todayString, forKey: Self.feedDateKey)

        // Also save to the version-independent user posts store
        persistInteractedItem(newItem)
    }

    private func persistInteractedItem(_ item: SocialFeedItem) {
        let defaults = UserDefaults.standard
        var userPosts: [SocialFeedItem] = []
        if let existing = Self.loadUserPosts() {
            userPosts = existing
        }
        
        if let idx = userPosts.firstIndex(where: { $0.id == item.id }) {
            userPosts[idx] = item
        } else {
            userPosts.insert(item, at: 0)
        }
        
        Self.saveUserPosts(userPosts)
    }

    public func toggleItemHeart(itemID: UUID) async throws {
        let defaults = UserDefaults.standard
        var foundAndUpdated: SocialFeedItem? = nil
        
        if var cached = Self.loadFeedCache(),
           let itemIndex = cached.firstIndex(where: { $0.id == itemID }) {
            
            let wasHearted = cached[itemIndex].isHearted ?? false
            cached[itemIndex].isHearted = !wasHearted
            cached[itemIndex].reactionCount += (wasHearted ? -1 : 1)
            
            if let newData = try? JSONEncoder().encode(cached) {
                Self.saveFeedCache(cached)
            }
            foundAndUpdated = cached[itemIndex]
        }
        
        if foundAndUpdated == nil {
            if var userPosts = Self.loadUserPosts(),
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

    public func deleteItem(itemID: UUID) async throws {
        let defaults = UserDefaults.standard
        if var cached = Self.loadFeedCache() {
            cached.removeAll { $0.id == itemID }
            if let newData = try? JSONEncoder().encode(cached) {
                Self.saveFeedCache(cached)
            }
        }
        if let data = defaults.data(forKey: Self.userPostsKey),
           var userPosts = try? JSONDecoder().decode([SocialFeedItem].self, from: data) {
            userPosts.removeAll { $0.id == itemID }
            Self.saveUserPosts(userPosts)
        }
    }

    public func toggleCommentHeart(itemID: UUID, commentID: UUID) async throws {
        let defaults = UserDefaults.standard
        var foundAndUpdated: SocialFeedItem? = nil

        if var cached = Self.loadFeedCache(),
           let itemIndex = cached.firstIndex(where: { $0.id == itemID }),
           let commentIndex = cached[itemIndex].comments.firstIndex(where: { $0.id == commentID }) {
            
            let wasHearted = cached[itemIndex].comments[commentIndex].isHearted ?? false
            cached[itemIndex].comments[commentIndex].isHearted = !wasHearted
            let currentLikes = cached[itemIndex].comments[commentIndex].likes ?? 0
            cached[itemIndex].comments[commentIndex].likes = currentLikes + (wasHearted ? -1 : 1)
            
            if let newData = try? JSONEncoder().encode(cached) {
                Self.saveFeedCache(cached)
            }
            foundAndUpdated = cached[itemIndex]
        }
        
        if foundAndUpdated == nil {
            if var userPosts = Self.loadUserPosts(),
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
        Self.seenNamesLock.withLock {
            Self.feedGenerationSeenNames.removeAll()
            let defaults = UserDefaults.standard
            Self.feedGenerationSeenNames.insert(defaults.string(forKey: "profilePlayerName") ?? "Player")
            Self.feedGenerationSeenNames.insert(defaults.string(forKey: "player.displayName") ?? "Player")
        }
        var items: [SocialFeedItem] = []
        let currentDay = Self.daysSinceReference
        for i in 0..<100 {
            let author = generateDynamicName()
            let authorIndex = Int.random(in: 1...100000)
            let authorAvatar = Self.avatarForPlayer(index: authorIndex, countrySeed: 0, day: currentDay)
            
            let rand = Double.random(in: 0...1)
            let randomMilestone: String
            if rand < 0.35 {
                // 9% raw numbers-B-tier (Indices 14...61, starting at 32k to avoid trivial early tiles)
                randomMilestone = Self.allMilestones[Int.random(in: 14...61)]
            } else if rand < 0.75 {
                // 21% a-z-tier
                randomMilestone = Self.allMilestones[Int.random(in: 62...297)]
            } else if rand < 0.89 {
                // 49% aa-az
                randomMilestone = Self.allMilestones[Int.random(in: 298...557)]
            } else {
                // 21% ba-bz
                randomMilestone = Self.allMilestones[Int.random(in: 558...816)]
            }
            
            let (message, statText) = generateDynamicEvent(milestone: randomMilestone)
            let timeOffset = i == 0 ? 60.0 : Double(i) * Double.random(in: 1200...2400)
            let itemDate = now.addingTimeInterval(-timeOffset)
            
            var comments: [SocialFeedComment] = []
            
            // Generate top-level base comments
            let ageInSeconds = max(0, now.timeIntervalSince(itemDate))
            let ageFactor = min(1.0, ageInSeconds / 43200.0)
            let baseMin = 5 + Int(ageFactor * 6)
            let baseMax = 15 + Int(ageFactor * 18)
            
            let targetTotalComments = Int.random(in: baseMin...baseMax)
            let targetComp = Int(round(Double(targetTotalComments) * 0.55))
            var compCount = 0
            var usedStats: Set<String> = []
            
            var i = 0
            while comments.count < targetTotalComments {
                let neededComp = targetComp - compCount
                let neededTotal = targetTotalComments - comments.count
                
                var toneStr: String
                let probComp = neededTotal > 0 ? Double(max(0, neededComp)) / Double(neededTotal) : 0
                
                if Double.random(in: 0...1) < probComp {
                    toneStr = "competitive"
                } else {
                    let r = Double.random(in: 0...1)
                    if r < 0.55 { toneStr = "positive" }
                    else if r < 0.88 { toneStr = "question" }
                    else { toneStr = "jealous" }
                }
                let startingCount = comments.count
                
                let topic = Self.determineTopic(message: message)
                let isRootStreakLoss = topic == "streak" && (message.lowercased().contains("lost") || message.lowercased().contains("dropped") || message.lowercased().contains("reset") || message.lowercased().contains("forgot") || message.lowercased().contains("dead") || message.lowercased().contains("failed") || message.lowercased().contains("broke"))
                let rootValue = isRootStreakLoss ? "0" : Self.extractValue(from: message, topic: topic)

                let commentAuthor = generateDynamicName()
                let commentIndex = Int.random(in: 1...100000)
                let commentAvatar = Self.avatarForPlayer(index: commentIndex, countrySeed: 0, day: currentDay)
                
                let (commentBase, nameOverride, tone, generatedVal) = generateDynamicComment(message: message, usedStats: &usedStats, forcedTone: toneStr)
                let finalCommenter = nameOverride ?? commentAuthor
                
                // First comments arrive very quickly so recent posts always have comments visible
                let baseOffset: Double
                if comments.isEmpty {
                    baseOffset = Double.random(in: 5...30)
                } else if comments.count == 1 {
                    baseOffset = Double.random(in: 45...120)
                } else if comments.count == 2 {
                    baseOffset = Double.random(in: 150...300)
                } else {
                    if tone == "competitive" || tone == "behind_competitive" {
                        baseOffset = Self.requiredTimeDelay(from: rootValue, to: generatedVal, topic: topic)
                    } else {
                        if Double.random(in: 0...1) < 0.85 {
                            baseOffset = Double.random(in: 300...1200)
                        } else {
                            baseOffset = Double.random(in: 1200...43200)
                        }
                    }
                }
                let baseCreatedAt = itemDate.addingTimeInterval(baseOffset)
                
                let baseComment = SocialFeedComment(
                    authorName: finalCommenter,
                    avatarID: commentAvatar,
                    text: commentBase,
                    createdAt: baseCreatedAt,
                    likes: Int.random(in: 0...10)
                )
                comments.append(baseComment)
                
                // If it's a competitive comment, start a recursive competitive chain
                if tone == "competitive" || tone == "behind_competitive" {
                    var currentDepth = 0
                    var lastComment = baseComment
                    
                    let npc1 = (name: baseComment.authorName, avatar: baseComment.avatarID)
                    var npc2: (name: String, avatar: String)? = nil
                    
                    var npc1Value = Self.extractValue(from: baseComment.text, topic: topic) ?? rootValue
                    var npc2Value: String? = nil
                    
                    var isNpc2Turn = true
                    var npc1PreviousComment: String? = baseComment.text
                    var npc2PreviousComment: String? = nil
                    var tieRepliesCount = 0
                    
                    // Ensure competitive threads always have at least 2 replies so NPCs can beat each other's record
                    let targetDepth: Int
                    if tone == "behind_competitive" {
                        targetDepth = Double.random(in: 0...1) < 0.86 ? (topic == "streak" ? Int.random(in: 1...2) : Int.random(in: 2...10)) : 0
                    } else {
                        targetDepth = Double.random(in: 0...1) < 0.85 ? (topic == "streak" ? Int.random(in: 1...2) : Int.random(in: 2...10)) : 0
                    }
                    while currentDepth < targetDepth {
                        if npc2 == nil {
                            if Double.random(in: 0...1) < 0.6 {
                                npc2 = (name: author, avatar: authorAvatar)
                                npc2Value = rootValue
                            } else {
                                let replyIndex = Int.random(in: 1...100000)
                                var rName = generateDynamicName()
                                while rName == npc1.name || rName == author {
                                    rName = generateDynamicName()
                                }
                                npc2 = (name: rName, avatar: Self.avatarForPlayer(index: replyIndex, countrySeed: 0, day: currentDay))
                            }
                        }
                        
                        var npc2JustLostStreak = false
                        if topic == "streak" && Self.commentPredictsStreakLoss(lastComment.text) {
                            if Double.random(in: 0...1) < 0.60 {
                                npc2Value = "0"
                                npc2JustLostStreak = true
                            }
                        }
                        
                        if isNpc2Turn {
                            if npc2Value == nil {
                                if let n1Val = npc1Value {
                                    if Double.random(in: 0...1) < 0.20 {
                                        npc2Value = n1Val // Force a tie
                                    } else if Double.random(in: 0...1) < 0.20 {
                                        npc2Value = Self.lowerValue(for: n1Val, topic: topic)
                                    } else {
                                        npc2Value = Self.oneUpValue(for: n1Val, topic: topic)
                                    }
                                }
                            }
                            
                            if let n1Val = npc1Value, let n2Val = npc2Value {
                                if Self.isRecord(n2Val, worseThan: n1Val, topic: topic) {
                                    if Double.random(in: 0...1) < 0.70 {
                                        npc2Value = Self.oneUpValue(for: n1Val, topic: topic)
                                    }
                                } else if n1Val == n2Val && tieRepliesCount >= 2 {
                                    npc2Value = Self.oneUpValue(for: n1Val, topic: topic)
                                }
                            }
                            
                            let isBehind: Bool
                            let isEqual: Bool
                            if let n1Val = npc1Value, let n2Val = npc2Value {
                                isBehind = Self.isRecord(n2Val, worseThan: n1Val, topic: topic)
                                isEqual = n1Val == n2Val
                            } else {
                                isBehind = false
                                isEqual = false
                            }
                            if isEqual {
                                tieRepliesCount += 1
                            } else {
                                tieRepliesCount = 0
                            }
                            
                            let toneStr = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                            let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: toneStr, speakerValue: npc2Value, opponentValue: npc1Value, previousSelfComment: npc2PreviousComment)
                            npc2PreviousComment = replyText
                            let replyOffset = Self.requiredTimeDelay(from: npc1Value, to: npc2Value, topic: topic)
                            let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
                            
                            let replyComment = SocialFeedComment(
                                authorName: npc2!.name,
                                avatarID: npc2!.avatar,
                                text: replyText,
                                createdAt: replyCreatedAt,
                                likes: Int.random(in: 0...5)
                            )
                            comments.append(replyComment)
                            lastComment = replyComment
                            currentDepth += 1
                        } else {
                            var npc1JustLostStreak = false
                            if topic == "streak" && Self.commentPredictsStreakLoss(lastComment.text) {
                                if Double.random(in: 0...1) < 0.60 {
                                    npc1Value = "0"
                                    npc1JustLostStreak = true
                                }
                            }
                            
                            
                            if let n1Val = npc1Value, let n2Val = npc2Value, !npc1JustLostStreak {
                                if Self.isRecord(n1Val, worseThan: n2Val, topic: topic) {
                                    if Double.random(in: 0...1) < 0.70 {
                                        npc1Value = Self.oneUpValue(for: n2Val, topic: topic)
                                    }
                                } else if n1Val == n2Val && tieRepliesCount >= 2 {
                                    npc1Value = Self.oneUpValue(for: n2Val, topic: topic)
                                }
                            }
                            
                            let isBehind: Bool
                            let isEqual: Bool
                            if let sVal = npc1Value, let oVal = npc2Value {
                                isBehind = Self.isRecord(sVal, worseThan: oVal, topic: topic)
                                isEqual = sVal == oVal
                            } else {
                                isBehind = false
                                isEqual = false
                            }
                            if isEqual {
                                tieRepliesCount += 1
                            } else {
                                tieRepliesCount = 0
                            }
                            
                            let toneStr = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                            let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: toneStr, speakerValue: npc1Value, opponentValue: npc2Value, previousSelfComment: npc1PreviousComment)
                            npc1PreviousComment = replyText
                            let replyOffset = Self.requiredTimeDelay(from: npc2Value, to: npc1Value, topic: topic)
                            let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
                            
                            let replyComment = SocialFeedComment(
                                authorName: npc1.name,
                                avatarID: npc1.avatar,
                                text: replyText,
                                createdAt: replyCreatedAt,
                                likes: Int.random(in: 0...5)
                            )
                            comments.append(replyComment)
                            lastComment = replyComment
                            currentDepth += 1
                        }
                        isNpc2Turn.toggle()
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
                            let topic = Self.determineTopic(message: message)
                            let speakerVal = Self.findEstablishedValue(for: replyAuthor, in: comments, topic: topic)
                            replyText = "@\(baseComment.authorName) " + generateContextualReply(to: baseComment.text, message: message, speakerValue: speakerVal)
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
            
            let minReactions = max(10, comments.count * 4)
            let maxReactions = max(15, comments.count * 10)
            let maxReactionsVal = Int.random(in: minReactions...maxReactions)
            var rTimestamps: [Date] = []
            for _ in 0..<maxReactionsVal {
                // Heart/reaction timestamps mirror comment speed (55% fast, 45% slow)
                if Double.random(in: 0...1) < 0.55 {
                    rTimestamps.append(itemDate.addingTimeInterval(Double.random(in: 15...900)))
                } else {
                    rTimestamps.append(itemDate.addingTimeInterval(Double.random(in: 900...28800)))
                }
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
        let codeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let currentDay = Self.daysSinceReference

        // Helper to build a profile from a generated name and index
        func makeProfile(name: String, playerIndex: Int) -> AccountProfile {
            // Deterministic friend code from name
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
            // Avatar from the leaderboard avatar generator
            let avatar = Self.avatarForPlayer(index: playerIndex, countrySeed: 0, day: currentDay)
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

        if query.isEmpty {
            // Browse mode: generate 20 unique dynamic players
            var seen = Set<String>()
            var profiles: [AccountProfile] = []
            while profiles.count < 20 {
                let name = generateDynamicName()
                guard !seen.contains(name) else { continue }
                seen.insert(name)
                let playerIndex = Int.random(in: 1...100000)
                profiles.append(makeProfile(name: name, playerIndex: playerIndex))
            }
            return profiles
        } else {
            // Search mode: build the full name pool and filter exhaustively
            var fullPool = Set<String>()

            // Add all gamertag base names (stripped of digits)
            for tag in Self.leaderboardGamertags {
                var base = tag
                while let last = base.last, last.isNumber { base.removeLast() }
                fullPool.insert(base)
            }

            // Add all region-matched firstName + lastName combos
            let regionRanges: [(firstStart: Int, firstCount: Int, lastStart: Int, lastCount: Int)] = [
                (0, 40, 0, 40),     // English
                (40, 20, 40, 20),   // Hispanic
                (60, 20, 60, 20),   // German
                (80, 20, 80, 20),   // French
                (100, 20, 100, 20), // Italian
                (120, 20, 120, 20), // Japanese
                (140, 20, 140, 20), // Korean
                (160, 20, 160, 20), // Chinese
                (180, 20, 180, 20), // Indian
                (200, 20, 200, 20), // Brazilian/Portuguese
                (220, 20, 220, 20), // Russian
                (240, 20, 240, 20), // Arabic
                (260, 20, 260, 20), // Scandinavian
            ]
            for region in regionRanges {
                let firstEnd = min(region.firstStart + region.firstCount, Self.leaderboardRealNames.count)
                let lastEnd = min(region.lastStart + region.lastCount, Self.leaderboardLastNames.count)
                for fi in region.firstStart..<firstEnd {
                    for li in region.lastStart..<lastEnd {
                        fullPool.insert("\(Self.leaderboardRealNames[fi]) \(Self.leaderboardLastNames[li])")
                    }
                }
            }

            // Filter the full pool by the query
            let filtered = fullPool.filter { $0.localizedCaseInsensitiveContains(query) }

            return filtered.map { name in
                // Deterministic player index from name for avatar consistency
                let playerIndex = abs(name.hashValue) % 100000
                return makeProfile(name: name, playerIndex: playerIndex)
            }
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
    
    #if DEBUG
    public nonisolated(unsafe) static var isPlayerAtHOFOverride: Bool? = nil
    public nonisolated(unsafe) static var bypassFeedCache: Bool = false
    public nonisolated(unsafe) static var inMemoryFeedOverride: [SocialFeedItem]? = nil
    public nonisolated(unsafe) static var inMemoryUserPostsOverride: [SocialFeedItem]? = nil
    #endif

    private static var isPlayerAtHOF: Bool {
        #if DEBUG
        if let over = isPlayerAtHOFOverride {
            return over
        }
        #endif
        let step = UserDefaults.standard.integer(forKey: "currentHighestTileStep")
        return step >= 817
    }

    private func generateDynamicEvent(milestone: String) -> (message: String, statText: String) {
        let rand = Double.random(in: 0..<100)
        let eventType: Int
        if Self.isPlayerAtHOF {
            if rand < 76.0 {
                eventType = 3 // HOF (76%)
            } else if rand < 85.0 {
                eventType = 2 // Streaks (9%)
            } else {
                eventType = 1 // Time (15%)
            }
        } else {
            if rand < 34.9 {
                eventType = 1 // Time (34.9%)
            } else if rand < 70.0 {
                eventType = 0 // Milestones (35.1%)
            } else if rand < 85.0 {
                eventType = 2 // Streaks (15%)
            } else {
                eventType = 3 // HOF (15%)
            }
        }
        switch eventType {
        case 0:
            // Reached a new tile in the game
            var templates = [
                "Reached the \(milestone) tile in the game!",
                "Just hit \(milestone) for the first time!",
                "NEW personal best — \(milestone) tile unlocked in gameplay!",
                "\(milestone) tile reached! The grind never stops.",
                "Finally broke through to \(milestone) in the game!",
                "After one attempt, \(milestone) is MINE!",
                "Thought \(milestone) was impossible. Proved myself wrong.",
                "\(milestone) achieved on an absolute marathon run.",
            ]
            var stats = [
                "puzzlepiece.extension|New tile · Game",
                "medal|Milestone · \(milestone)",
                "chart.line.uptrend.xyaxis|Personal best · Game",
                "flame|Breakthrough · \(milestone)",
                "star|New record · Game",
                "suit.diamond.fill|\(milestone) · Reached",
            ]
            let mIndex = Self.allMilestones.firstIndex(of: milestone) ?? 0
            let oneMIndex = Self.allMilestones.firstIndex(of: "1M") ?? 0
            
            if mIndex >= oneMIndex && Double.random(in: 0...1) < 0.20 {
                templates = [
                    "Ran out of moves at \(milestone)...",
                    "No moves left! Stuck at \(milestone).",
                    "Game over at \(milestone). I ran out of moves.",
                    "Lost my run at \(milestone) because I ran out of moves.",
                    "Couldn't get past \(milestone). Ran out of moves!",
                    "Died at \(milestone). No moves left.",
                    "Just ran out of moves at \(milestone)."
                ]
                stats = [
                    "xmark.circle|Game over · \(milestone)",
                    "stop.circle|No moves · \(milestone)",
                    "exclamationmark.triangle|Stuck · \(milestone)",
                    "xmark.octagon|Ran out of moves · \(milestone)",
                    "xmark.circle|Died · \(milestone)",
                ]
            }
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
                "the timed challenge", "the daily timed challenge",
                "a timed challenge", "the timed run",
                "the speed challenge", "the daily speed run",
                "the clock challenge", "the timed board",
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
                "!", ".", ". New strategy worked perfectly.",
                ". That was INTENSE.", ".", ". Clean run.",
                ". Not even close.", " — feels good!", ". Let's go!",
            ]
            
            let message = "\(openers.randomElement()!) \(subjects.randomElement()!) \(details.randomElement()!)\(closers.randomElement()!)"
            
            let statEmojis = ["timer", "flag.fill", "bolt", "target", "clock", "wind", "flame"]
            let statLabels = [
                "Timed challenge · \(timeStr)", "Daily challenge · Done",
                "Speed clear · \(timeStr)", "Challenge · \(timeStr) finish",
                "Challenge · Complete", "Timed run · \(timeStr)",
                "Challenge clear · \(timeStr)", "Speed run · Done",
                "Daily timed · \(timeStr)", "Clock beaten · \(timeStr)",
            ]
            return (message, "\(statEmojis.randomElement()!)|\(statLabels.randomElement()!)")
            
        case 2:
            // Protected (65%) or Lost (35%) streak
            let streakDays = Int.random(in: 3...365)
            let isLost = Double.random(in: 0...1) < 0.35
            
            if isLost {
                let templates = [
                    "I forgot to play yesterday and lost my streak. All the way down to 0 days.",
                    "Missed my daily check-in yesterday and dropped my streak.",
                    "Nooo! I forgot to play yesterday and lost my \(streakDays)-day streak.",
                    "My \(streakDays)-day streak is gone because I missed a day. Back to 0.",
                    "Consistency failed after missing yesterday. Lost my \(streakDays) day streak.",
                    "Forgot to save my streak by playing yesterday. Back to square one.",
                    "Missed a day and my streak died. It was a good run.",
                    "Woke up to a dead streak because I forgot to check in. Back to 0."
                ]
                let statEmojis = ["flame", "xmark.circle", "calendar", "exclamationmark.triangle"]
                let statLabels = [
                    "Streak lost · 0 days",
                    "Streak dead · 0",
                    "Streak lost · \(streakDays)d gone",
                    "Streak dead · \(streakDays)d",
                    "Streak ended · 0 days"
                ]
                return (templates.randomElement()!, "\(statEmojis.randomElement()!)|\(statLabels.randomElement()!)")
            } else {
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
                        "!", " — legendary status!",
                        ". \(streakDays) and counting!", ". This streak is untouchable.",
                        ". Can't stop now.", ". \(streakDays) days deep!",
                        ". Built different.", " — no breaks, no excuses.",
                        ". The grind never stops.", ". Still going strong.",
                    ]
                } else if streakDays >= 30 {
                    closers = [
                        "!", ". Dedicated!",
                        ". A whole month and beyond!", ". Consistency pays off.",
                        " — keeping the fire alive!", ". Not stopping now.",
                        ". This streak means everything.", ". Locked in.",
                        ". Steady progress!", ". Day by day.",
                    ]
                } else {
                    closers = [
                        "!", ". Every day counts!",
                        ". Almost forgot today.", " — close call!",
                        ". Building momentum!", ". Played at 11:58 PM to save it.",
                        ".", ". Not losing this one.",
                        ". The habit is forming!", ". Streak: protected.",
                    ]
                }
                
                let message = "\(openers.randomElement()!) \(streakPhrase.randomElement()!)\(closers.randomElement()!)"
                
                let statEmojis = ["flame", "shield", "calendar", "suit.diamond.fill", "star", "infinity", "checkmark.circle"]
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
                return (message, "\(statEmojis.randomElement()!)|\(statLabels.randomElement()!)")
            }
            
        default:
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
                    "! Infinity count: \(infinityCount)", " with \(infinityCount) infinities!",
                    "! ∞×\(infinityCount) and climbing!", ". Entry #\(infinityCount)",
                    "! \(infinityCount) infinity tiles deep.", " — \(infinityCount) infinities strong.",
                    ". Veteran status with \(infinityCount) runs.", "! Can't stop at \(infinityCount).",
                    " with ∞×\(infinityCount). Legendary!", ". \(infinityCount) and counting.",
                ]
            } else if infinityCount > 1 {
                details = [
                    "!", "! Infinity count: \(infinityCount)",
                    " with \(infinityCount) infinities!", ". The journey was worth it.",
                    "! Entry #\(infinityCount).", " — ∞×\(infinityCount)!",
                    ". \(infinityCount) infinity tiles reached!", ". Still pushing for more.",
                    "! Grinding paid off.", ". \(infinityCount) down, more to go.",
                ]
            } else {
                details = [
                    "!", "! I actually made it!",
                    " for the first time!", ". The grind paid off!",
                    "! After months of grinding…", " — this one's for the long-term players.",
                    "! They said it couldn't be done.", ". First infinity tile!",
                    "! Welcome to the club!", ". Dream achieved.",
                ]
            }
            
            let message = "\(openers.randomElement()!) \(subject.randomElement()!)\(details.randomElement()!)"
            
            let statEmojis = ["infinity", "medal", "star", "infinity.circle", "sparkles", "suit.diamond.fill", "rosette"]
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
            return (message, "\(statEmojis.randomElement()!)|\(statLabels.randomElement()!)")
        }
    }

    // MARK: - Shuffle-bag rotation

    /// Draws from a shuffled copy of `pool`, cycling back to a fresh shuffle
    /// once every element has been used. Guarantees every template appears at
    /// least once before any repeats.
    nonisolated(unsafe) private static var shuffleBags: [String: [String]] = [:]
    nonisolated(unsafe) private static var shuffleIndices: [String: Int] = [:]
    nonisolated(unsafe) private static var shuffleIndexBags: [String: [Int]] = [:]
    private static let shuffleLock = NSLock()

    private static func drawIndexFromBag(key: String, count: Int) -> Int {
        if count == 0 { return 0 }
        
        shuffleLock.lock()
        defer { shuffleLock.unlock() }
        
        var currentBag = shuffleIndexBags[key] ?? []
        
        // 1. If bag is empty or exhausted, create a fresh one of the requested size
        if currentBag.isEmpty || (shuffleIndices[key] ?? 0) >= currentBag.count {
            shuffleIndexBags[key] = Array(0..<count).shuffled()
            shuffleIndices[key] = 0
            currentBag = shuffleIndexBags[key]!
        }
        
        // 2. If the requested count is smaller than the current bag (e.g. 8 -> 6)
        if currentBag.count > count {
            let currentIndex = shuffleIndices[key]!
            let played = Array(currentBag[0..<currentIndex]).filter { $0 < count }
            let unplayed = Array(currentBag[currentIndex...]).filter { $0 < count }
            
            currentBag = played + unplayed
            shuffleIndexBags[key] = currentBag
            shuffleIndices[key] = played.count
            
            // If filtering exhausted the bag, generate a fresh one
            if shuffleIndices[key]! >= currentBag.count {
                shuffleIndexBags[key] = Array(0..<count).shuffled()
                shuffleIndices[key] = 0
                currentBag = shuffleIndexBags[key]!
            }
        }
        // 3. If the requested count is larger than the current bag (e.g. 6 -> 8)
        else if currentBag.count < count {
            let currentIndex = shuffleIndices[key]!
            let newIndices = Array(currentBag.count..<count)
            let unplayed = Array(currentBag[currentIndex...])
            let combinedAndShuffled = (unplayed + newIndices).shuffled()
            
            currentBag = Array(currentBag[0..<currentIndex]) + combinedAndShuffled
            shuffleIndexBags[key] = currentBag
        }
        
        let idx = shuffleIndices[key]!
        shuffleIndices[key] = idx + 1
        return currentBag[idx]
    }

    private static func drawFromBag(key: String, pool: [String]) -> String {
        shuffleLock.lock()
        defer { shuffleLock.unlock() }
        
        // First call or bag exhausted — reshuffle
        if shuffleBags[key] == nil || (shuffleIndices[key] ?? 0) >= (shuffleBags[key]?.count ?? 0) {
            shuffleBags[key] = pool.shuffled()
            shuffleIndices[key] = 0
        }
        let idx = shuffleIndices[key]!
        shuffleIndices[key] = idx + 1
        return shuffleBags[key]![idx]
    }

    func generateDynamicComment(message: String, usedStats: inout Set<String>, forcedTone: String? = nil) -> (commentText: String, nameOverride: String?, tone: String, generatedVal: String?) {
        var nameOverride: String? = nil
        var generatedVal: String? = nil
        let openers = [
            "Dude,", "Omg,", "Wow,", "Bro,", "Honestly,", "Crazy,", "Yoo,",
            "No way,", "Wait,", "Bruh,", "Sheesh,", "Yo,", "Ngl,", "Ayo,",
            "",
        ]
        var subjects = [
            "that run", "your board", "your progress", "this setup",
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
            let behindReactions = [
            "I'm struggling to keep up", "How did you get so far ahead?",
            "I need to rethink my strategy", "I'm falling behind",
            "This is harder than I thought", "My runs are nowhere near that",
            "I'm losing my touch", "I keep messing up early",
            "I can't seem to break through", "I'm still way back here"
        ]
        var jealousReactions = [
            "So jealous", "I can't even get past 1M", "My board never looks like that",
            "How is that even possible", "You make it look so easy",
            "I'm stuck on the previous tier", "I always fail right here",
            "Meanwhile I'm still struggling", "Must be nice",
            "I wish my runs went like that", "Pain. Just pain.",
            "I keep choking at this point", "Why can't I do this",
        ]
        var competitiveReactions = [
            "Your progress is entirely irrelevant to my record.",
            "You will never exist on my level.", "Enjoy chasing my lead.",
            "My next run will just establish a higher ceiling.", "I'm comfortably ahead.",
            "You are nothing compared to my dominance.", "I dominate everything easily.",
            "That record is cute. I'm already leagues ahead.", "You will never touch my stats.",
            "I'll be staying far ahead.", "I am laughing from the top.",
            "I am maintaining absolute dominance.", "I am completely unreachable.",
        ]
        var questions = [
            "How long did that take?", "What's your secret?", "Any tips for this tier?",
            "How many moves did it take?", "Did you use any swaps?", "Was it tough?",
            "Can I add you?", "Do you play every day?", "What perks did you use?",
            "How many attempts was that?", "Were you using a hammer?",
            "What's your total playtime?", "Did you plan that chain or was it luck?",
        ]
        
        // Symbols categorized by tone
        let positiveSymbols = ["!!", " :)", " :D", " ~", " :P", " <3", " =)", " ^_^", " rn", " RN", " fr", " tbh"]
        let questionSymbols = ["?!", "...", "??", "!!?"]
        let sadOrJealousSymbols = [" :(", " :((", " >:(", " :/", " ;-(", " -_-", " >_<", "...", " rn", " fr", " tbh", " ngl", " smh"]
        let competitiveSymbols = [" >:)", " !!", " !!!", " >", " XD", " XDD", " XDDD", " XDDDD", " XDDDDD", " XDDDDDD", " XDDDDDDD"]
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
                "Your infinity count is entirely irrelevant to my dominance.",
                "I will always have more infinities.",
                "It's over.",
                "My infinity count will remain untouched.",
                "I easily dominate the Hall of Fame.",
                "My infinity count is growing.",
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
                "I just lost my streak", "How do you remember every day?",
                "I can never keep a streak going", "My longest streak was like 5 days",
                "I keep forgetting to log in", "Streaks stress me out",
                "I lost a 30-day streak last week", "My streak always dies on weekends",
                "I wish I had that consistency", "I'm so bad at maintaining streaks",
            ])
            
            competitiveReactions.append(contentsOf: [
                "Your streak is entirely irrelevant to my infinite grind.",
                "My dedication is absolute and unrivaled.",
                "Your streak is cute compared to my infinite consistency.",
                "I will hold the higher streak.",
                "I dominate the daily grind without effort.",
                "Your streak is nothing compared to mine.",
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
                "Your time is entirely irrelevant to my speed.",
                "My clears have been unrivaled for a while.",
                "It's over.",
                "I will hold the faster clear.",
                "I absolutely dominate the speed leaderboards.",
                "Your time is too slow to matter.",
            ])

            questions.append(contentsOf: [
                "What was your exact time?", "Did you pause at all?",
                "What's your fastest ever?", "Did you use a hammer during the run?",
                "How do you plan moves so fast?", "Do you practice speed runs?",
                "What's your average clear time?", "Any speed tips?",
                "Do you go for speed or safety?", "Was that your first attempt today?",
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
                    "I always fail before \(m)", "I've been stuck before \(m) forever",
                    "\(m) feels impossible for me", "I choke right before \(m)",
                    "My board always falls apart near \(m)",
                    "I keep dying one tile before \(m)",
                    "\(m) is my wall right now", "Maybe someday I'll reach \(m)",
                ])
                competitiveReactions.append(contentsOf: [
                    "Your progress is entirely irrelevant to my infinity.",
                    "I'm way past that.",
                    "The gap between us just gets larger.",
                    "It's over.",
                    "That feels like ages ago.",
                    "My lead is secure.",
                    "I dominate without even looking.",
                    "My lead is strong.",
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
        
        // Build a static bag key so the rotation of templates, openers, and closers
        // persists globally across all feed items, guaranteeing no early repeats.
        var contextKey = "base"
        let msgLower = message.lowercased()
        if msgLower.contains("hall of fame") || msgLower.contains("hof") || msgLower.contains("infinity") {
            contextKey += "_hof"
        } else if msgLower.contains("streak") || msgLower.contains("day") || msgLower.contains("consecutive") {
            contextKey += "_streak"
        } else if msgLower.contains("time") || msgLower.contains("speed") || msgLower.contains("timed challenge") {
            contextKey += "_time"

        }
        
        if let foundMilestone = sortedMilestones.first(where: { message.contains(" \($0) ") }) {
            contextKey += "_m\(foundMilestone)"
        }
        
        let bagSuffix = contextKey
        
        // Weighted category roll: 50% competitive, 25% positive, 15% question, 5% jealous, 5% behind
        var comment = ""
        var tone = forcedTone
        if tone == "sad" {
            tone = "jealous"
        }
        if tone == nil {
            let roll = Double.random(in: 0..<1)
            if roll < 0.50 { tone = "competitive" }
            else if roll < 0.75 { tone = "positive" }
            else if roll < 0.90 { tone = "question" }
            else if roll < 0.95 { tone = "behind_competitive" }
            else { tone = "jealous" }
        }
        
        if tone == "competitive" || tone == "behind_competitive" {
            let forceBehind = (tone == "behind_competitive")
            let isLostEvent = msgLower.contains("ran out") || msgLower.contains("no moves") || msgLower.contains("game over") || msgLower.contains("stuck") || msgLower.contains("lost my run") || msgLower.contains("died") || msgLower.contains("broke") || msgLower.contains("reset")
            if (forceBehind || Double.random(in: 0...1) < 0.45) && !isLostEvent {
                // ── Behind (45% of competitive) — with behind opener and closer ──
                let compBehindOpeners = [
                    "I might be lower right now.", "You're ahead for now.", "Enjoy the lead while it lasts."
                ]
                let compBehindClosers = [
                    "I'm coming for that spot.", "Watch your back.", "I will overtake you soon."
                ]
                let behindCompReactions = [
                    "I am grinding right now to pass you.",
                    "Your lead is temporary.",
                    "I'm already closing the gap.",
                    "My next run is going to crush that.",
                    "I'm targeting the top spot.",
                    "Just give me a little more time."
                ]
                let bOpener = Self.drawFromBag(key: "comp_behind_opener_\(bagSuffix)", pool: compBehindOpeners)
                let bCloser = Self.drawFromBag(key: "comp_behind_closer_\(bagSuffix)", pool: compBehindClosers)
                let compReaction = Self.drawFromBag(key: "behind_comp_\(bagSuffix)", pool: behindCompReactions)
                let reaction = "\(bOpener)  \(compReaction)  \(bCloser)"
                
                comment = reaction
                tone = "behind_competitive"
            } else {
                // ── Competitive (55% of competitive) — generate factually accurate one-upmanship ──
                let result = generateTruthfulCompetitive(message: message, pool: competitiveReactions, bagKey: "competitive_\(bagSuffix)", usedStats: &usedStats)
                comment = result.0
                nameOverride = result.1
                generatedVal = result.2
                tone = "competitive"
                // Randomly prepend a competitive opener ~95% of the time
                if Double.random(in: 0...1) < 0.95 {
                    let openersWithWeights: [(String, Double)] = [
                        ("That's old news.", 11.2),
                        ("That's zero effort.", 6.9),
                        ("Laughable.", 3.0),
                        ("That's entirely average.", 4.0),
                        ("Not worth my time.", 0.6),
                        ("Unimpressive.", 1.0),
                        ("Not impressed.", 1.0),
                        ("That's cute.", 23.5),
                        ("Light work.", 2.0),
                        ("What a joke.", 7.2),
                        ("Imagine celebrating that.", 9.4),
                        ("Is that all?", 1.0),
                        ("I did this by accident.", 19.5),
                        ("That's nothing.", 8.6),
                        ("Are you even trying?", 0.1)
                    ]
                    
                    let getWeightedOpener = { () -> String in
                        let rand = Double.random(in: 0..<100.0)
                        var cumulative = 0.0
                        for (op, weight) in openersWithWeights {
                            cumulative += weight
                            if rand < cumulative { return op }
                        }
                        return openersWithWeights.last!.0
                    }
                    
                    var opener = getWeightedOpener()
                    var attempts = 0
                    while attempts < 3 && (comment.lowercased().contains("effort") && opener.lowercased().contains("effort") ||
                                           comment.lowercased().contains("cute") && opener.lowercased().contains("cute")) {
                        opener = getWeightedOpener()
                        attempts += 1
                    }
                    comment = "\(opener) \(comment)"
                }
                // Randomly append a competitive closer ~80% of the time
                if Double.random(in: 0...1) < 0.80 {
                    var closersWithWeights: [(String, Double)] = [
                        ("Don't bother trying.", 0.6),
                        ("I'm tiers ahead.", 5.4),
                        ("I reign supreme.", 0.2),
                        ("Keep dreaming.", 21.5),
                        ("You're no threat.", 3.5),
                        ("Your stats are completely irrelevant.", 8.1),
                        ("You're not reaching my stats.", 6.3),
                        ("Stay down there.", 19.7),
                        ("This record belongs to me.", 1.8),
                        ("Don't bother comparing.", 2.5),
                        ("You couldn't catch me if you tried.", 23),
                        ("You can't reach me.", 7.3)
                    ]
                    let isTimeTopic = message.lowercased().contains("time") || message.lowercased().contains("speed") || message.lowercased().contains("timed challenge")
                    if isTimeTopic {
                        closersWithWeights.append(("Too slow.", 5.0))
                    }
                    
                    let getWeightedCloser = { () -> String in
                        let totalWeight = closersWithWeights.reduce(0) { $0 + $1.1 }
                        let rand = Double.random(in: 0..<totalWeight)
                        var cumulative = 0.0
                        for (cl, weight) in closersWithWeights {
                            cumulative += weight
                            if rand < cumulative { return cl }
                        }
                        return closersWithWeights.last!.0
                    }
                    
                    var closer = getWeightedCloser()
                    var attempts = 0
                    while attempts < 10 && (comment.lowercased().contains("irrelevant") && closer.lowercased().contains("irrelevant") ||
                                           comment.lowercased().contains("catch") && closer.lowercased().contains("catch") ||
                                           comment.lowercased().contains("permanent") && closer.lowercased().contains("permanent") ||
                                           comment.lowercased().contains("untouchable") && closer.lowercased().contains("untouchable") ||
                                           comment.lowercased().contains("dominate") && closer.lowercased().contains("dominate") ||
                                           comment.lowercased().contains("behind") && closer.lowercased().contains("behind") ||
                                           comment.lowercased().contains("record") && closer.lowercased().contains("record")) {
                        closer = getWeightedCloser()
                        attempts += 1
                    }
                    comment = "\(comment) \(closer)"
                }
                tone = "competitive"
            }
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
        } else if tone == "jealous" {
            // ── Jealous (5%) — with generic opener ──
            var reaction = Self.drawFromBag(key: "behind_\(bagSuffix)", pool: behindReactions)
            let genericOpener = Self.drawFromBag(key: "opener_\(bagSuffix)", pool: openers)
            if !genericOpener.isEmpty {
                var lower = reaction.lowercased()
                if lower.hasPrefix("i ") || lower.hasPrefix("i'") {
                    lower = "I" + lower.dropFirst()
                }
                reaction = "\(genericOpener) \(lower)"
            } else {
                reaction = reaction.capitalized
            }
            comment = reaction
            tone = "jealous"
        }
        
        if Double.random(in: 0...1) < 0.75 {
            let symbol: String
            switch tone {
            case "positive": symbol = Self.drawFromBag(key: "sym_pos_\(bagSuffix)", pool: positiveSymbols)
            case "question": symbol = Self.drawFromBag(key: "sym_q_\(bagSuffix)", pool: questionSymbols)
            case "jealous", "behind": symbol = Self.drawFromBag(key: "sym_sad_\(bagSuffix)", pool: sadOrJealousSymbols)
            case "competitive", "behind_competitive": symbol = Self.drawFromBag(key: "sym_comp_\(bagSuffix)", pool: competitiveSymbols)
            default: symbol = ""
            }
            comment = Self.injectSymbol(comment, symbol: symbol)
        } else if Double.random(in: 0...1) < 0.1 {
            // 2.5% chance for a random raw keyboard symbol (like a typo)
            comment += keyboardSymbols.randomElement()!
        }
        
        return (comment.trimmingCharacters(in: .whitespaces), nameOverride, tone!, generatedVal)
    }

    private static func injectSymbol(_ text: String, symbol: String) -> String {
        let letterSymbols = [
            "rn", "RN", "fr", "tbh", "ngl", "smh",
            "XD", "XDD", "XDDD", "XDDDD", "XDDDDD", "XDDDDDD", "XDDDDDDD",
            "xD", "xDD", "xDDD"
        ]
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        if letterSymbols.contains(trimmed) {
            if text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") {
                let punc = text.suffix(1)
                return String(text.dropLast()) + symbol + String(punc)
            }
        }
        return text + symbol
    }

    // MARK: - Truthful competitive comments

private func generateTruthfulCompetitive(message: String, pool: [String], bagKey: String, usedStats: inout Set<String>) -> (String, String?, String?) {
        let lowered = message.lowercased()

        let sortedMilestones = Self.allMilestones.sorted(by: { $0.count > $1.count })
        let posterM = sortedMilestones.first(where: { m in
            let pattern = "(?<!:)\\b\(NSRegularExpression.escapedPattern(for: m))\\b(?!:)"
            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil
        }) ?? "11n"
        let posterIdx = Self.allMilestones.firstIndex(of: posterM) ?? 15
        let jump = Self.randomMilestoneJump()
        let higherIdx = min(posterIdx + jump, Self.allMilestones.count - 1)
        let higherM = Self.allMilestones[higherIdx]
        let higherName = Self.leaderboardPlayerAtMilestone(higherM)

        let topic = Self.determineTopic(message: message)

        // ── Streak posts: extract the day count, brag with a higher one ──
        if topic == "streak" {
            let isLostPost = lowered.contains("lost") || lowered.contains("dropped") || lowered.contains("reset") || lowered.contains("forgot") || lowered.contains("dead") || lowered.contains("failed") || lowered.contains("broke")
            if isLostPost {
                let myDays = Int.random(in: 15...120)
                let cN = 0
                let templates = [
                    "You just lost your streak? I'm already at \(myDays) days.",
                    "Your streak is dead. My \(myDays) days keep going.",
                    "Lost your streak? Pathetic. I'm sitting at \(myDays) days.",
                    "Couldn't even keep it going? I'm comfortably at \(myDays) days.",
                    "Back to 0? I'm dominating with \(myDays) days.",
                    "Enjoy restarting from zero. You'll never be a threat to my \(myDays) days.",
                    "Lost your streak? Typical. I'm already at \(myDays) days.",
                    "Back to \(cN) days? Don't even try to catch my \(myDays) days.",
                    "Dropping your streak is pathetic. I'm sitting comfortably at \(myDays) days.",
                    "I'm at \(myDays) days and you're down to \(cN). We are not the same.",
                    "Can't even hold a streak? I'm untouched at \(myDays) days.",
                    "Imagine dropping to \(cN) days. I'm already at \(myDays) days.",
                    "Down to \(cN)? My \(myDays) days will always be ahead.",
                    "I told you your streak would die as well. Now my \(myDays) days is higher!",
                    "I told you that you'd lose your streak as well. Now my streak is higher than yours!",
                    "I told you you'd lose your streak too. Now my \(myDays) days is higher than your \(cN)!",
                    "Called it! I told you your streak would die too. Now my \(myDays) days dominates yours.",
                    "Look at that, your streak died just like mine did. But my \(myDays) days is already higher.",
                    "You actually thought you'd keep it? Now my \(myDays) days is higher anyway!",
                    "Didn't I say your streak would break too? Now my \(myDays) day streak is higher than yours.",
                    "Told you you'd drop it. Now my \(myDays) days is higher than your pathetic \(cN) days!",
                    "Your streak died just like I predicted. Now my \(myDays) days sits higher than yours.",
                    "I told you that consistency would break. Now my \(myDays) days completely buries your \(cN) days."
                ]
                let idx = Self.drawIndexFromBag(key: "\(bagKey)_streak_lost", count: templates.count)
                return (templates[idx], higherName, String(myDays))
            } else if let streakDays = Self.extractNumber(from: message, near: ["day", "streak", "consecutive", "straight", "running"]) {
                let isLowStreak = false
                if isLowStreak && streakDays > 1 {
                    let jump = Int.random(in: 1...max(5, streakDays / 2))
                    let lowerDays = max(1, streakDays - jump)
                    let templates: [String]
                    if lowerDays <= 2 {
                        templates = [
                            "I just lost my streak today. I'm all the way down to \(lowerDays) days, but you'll lose your \(streakDays) day streak soon!",
                            "My streak died, so I'm down to \(lowerDays) days. But your \(streakDays) days will break before long.",
                            "My streak died, so I'm down to \(lowerDays) days. Just wait until you lose your \(streakDays) day streak.",
                            "Dropped to \(lowerDays) days because I lost my streak. You're bound to lose your \(streakDays) days too.",
                            "I just lost my streak. Only at \(lowerDays) days right now, but you'll slip up and I'll pass your \(streakDays) days.",
                            "It's past 12:00 AM and I didn't play yesterday, so my streak reset to \(lowerDays) days. But your \(streakDays) days will break before long.",
                            "Midnight hit and my streak broke since I forgot to log in. Back to \(lowerDays) days. Just wait until you lose your \(streakDays) day streak.",
                            "Once it hit 12 AM, my streak officially died. Back to \(lowerDays) days, but you'll lose yours soon!",
                            "My streak reset to \(lowerDays) days at 12:00 AM because I missed yesterday. You're bound to lose your \(streakDays) days too.",
                            "It's 12 AM, which means my streak is gone. Down to \(lowerDays) days, but you'll slip up and I'll pass your \(streakDays) days."
                        ]
                    } else {
                        templates = [
                            "I'm at \(lowerDays) days. Just wait until you lose your \(streakDays) day streak.",
                            "Only at \(lowerDays) days right now, but you'll slip up and I'll pass your \(streakDays) days.",
                            "Enjoy your \(streakDays) days while it lasts. You'll lose it and my \(lowerDays) days will pass you.",
                            "You're bound to lose your \(streakDays) day streak. My \(lowerDays) days will be higher than yours soon.",
                            "I'm at \(lowerDays) days, but you'll break your \(streakDays) day streak before I break mine."
                        ]
                    }
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_streak", count: templates.count)
                    return (templates[idx], higherName, String(lowerDays))
                } else {
                    let isMassiveGap = Bool.random()
                    var myDays = streakDays + (isMassiveGap ? Int.random(in: streakDays * 3...streakDays * 8 + 50) : Int.random(in: 5...max(10, streakDays / 2)))
                    var attempts = 0
                    while usedStats.contains("streak_\(myDays)") && attempts < 5 {
                        myDays = streakDays + (isMassiveGap ? Int.random(in: streakDays * 3...streakDays * 8 + 50) : Int.random(in: 5...max(10, streakDays / 2)))
                        attempts += 1
                    }
                    usedStats.insert("streak_\(myDays)")
                    var templates = [
                        "I'm comfortably sitting at \(myDays) days.",
                        "Your \(streakDays) days are irrelevant. I'm at \(myDays) days.",
                        "I dominate eternity. I'm already at \(myDays) days.",
                        "\(streakDays) days is cute. I'm at \(myDays) days.",
                        "My infinite consistency is at \(myDays) days.",
                        "You'll never touch my \(myDays) days.",
                    ]
                    if myDays >= streakDays * 2 {
                        templates.append("Your \(streakDays) days are meaningless against my \(myDays) days.")
                        templates.append("You're entirely left behind at \(streakDays) days while I'm at \(myDays).")
                    }
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_streak", count: templates.count)
                    return (templates[idx], higherName, String(myDays))
                }
            }
        }

        // ── Timed challenge posts: extract time remaining, brag with more ──
        if topic == "time" {
            if let (mins, secs) = Self.extractTime(from: message) {
                let totalSecs = mins * 60 + secs
                let isLowTime = false
                let posterTime = "\(mins):\(String(format: "%02d", secs))"
                if isLowTime {
                    let slowerTotal = totalSecs + Int.random(in: 5...30)
                    let slowerMins = slowerTotal / 60
                    let slowerSecs = slowerTotal % 60
                    let slowerTime = "\(slowerMins):\(String(format: "%02d", slowerSecs))"
                    let templates = [
                        "I clocked \(slowerTime) easily. I'm coming for your \(posterTime) time.",
                        "I cleared \(slowerTime). Your lead is temporary at \(posterTime).",
                        "I just clocked \(slowerTime). Your \(posterTime) is my next target.",
                        "Clocked \(slowerTime) on my last run. I'll overtake your \(posterTime) soon.",
                        "Only at \(slowerTime) right now, but I'll catch your \(posterTime) soon."
                    ]
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_time", count: templates.count)
                    return (templates[idx], higherName, slowerTime)
                } else {
                    // Brag about having a FASTER clear time (lower = better)
                    let isMassiveGap = Bool.random()
                    
                    func generateBetterTime() -> Int {
                        if totalSecs <= 10 {
                            return max(2, totalSecs - Int.random(in: 1...3))
                        } else {
                            let maxLess = totalSecs - 10
                            let lessBy = isMassiveGap && maxLess > 30 ? Int.random(in: totalSecs / 2...maxLess) : Int.random(in: max(5, totalSecs / 10)...max(15, totalSecs / 3))
                            return max(10, totalSecs - lessBy)
                        }
                    }
                    
                    var myTotal = generateBetterTime()
                    var attempts = 0
                    while attempts < 5 && (myTotal >= totalSecs || usedStats.contains("time_\(myTotal)")) {
                        myTotal = generateBetterTime()
                        if myTotal >= totalSecs { myTotal = max(0, totalSecs - 1) }
                        attempts += 1
                    }
                    usedStats.insert("time_\(myTotal)")
                    let myMins = myTotal / 60
                    let mySecs = myTotal % 60
                    let myTime = "\(myMins):\(String(format: "%02d", mySecs))"
                    var templates = [
                        "Your \(posterTime) is irrelevant. I clear it in \(myTime).",
                        "My clears have been unrivaled since \(myTime).",
                        "Only \(posterTime)? I'm sitting at \(myTime).",
                        "I easily clock \(myTime).",
                        "You'll never reach my \(myTime).",
                    ]
                    if totalSecs - myTotal >= 3 {
                        templates.append("I am leagues faster. My record is \(myTime).")
                    }
                    if myTotal <= totalSecs / 2 {
                        templates.append("Your \(posterTime) is a joke compared to my \(myTime).")
                        templates.append("You're entirely left behind at \(posterTime) while I clock \(myTime).")
                    }
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_time", count: templates.count)
                    return (templates[idx], higherName, myTime)
                }
            }
        }

        // ── Hall of Fame posts: extract infinity count, brag with a higher one ──
        if topic == "hof" {
            if let infCount = Self.extractNumber(from: message, near: ["infinity", "infinit", "\u{221E}", "\u{00D7}", "count", "entry", "#"]) {
                let isLowHoF = false
                if isLowHoF && infCount > 1 {
                    let jump = Int.random(in: 1...max(3, infCount / 2))
                    let lowerCount = max(1, infCount - jump)
                    let templates = [
                        "I hit \(lowerCount) infinities easily. I'm coming for your \(infCount) entries.",
                        "I cleared \(lowerCount) infinities. Your lead is temporary at \(infCount).",
                        "I won't be at \(lowerCount) entries for long. Your \(infCount) is next.",
                        "Hit \(lowerCount) infinities easily. I'll overtake your \(infCount) soon.",
                        "Only at \(lowerCount) infinities right now, but I'll catch your \(infCount) soon."
                    ]
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_hof", count: templates.count)
                    return (templates[idx], higherName, String(lowerCount))
                } else {
                    let isMassiveGap = Bool.random()
                    var myCount = infCount + (isMassiveGap ? Int.random(in: infCount * 3...infCount * 8 + 100) : Int.random(in: 1...max(3, infCount)))
                    var attempts = 0
                    while usedStats.contains("hof_\(myCount)") && attempts < 5 {
                        myCount = infCount + (isMassiveGap ? Int.random(in: infCount * 3...infCount * 8 + 100) : Int.random(in: 1...max(3, infCount)))
                        attempts += 1
                    }
                    usedStats.insert("hof_\(myCount)")
                    let templates = [
                        "Your \(infCount) is nothing compared to my \(myCount).",
                        "I easily dominate with \(myCount).",
                        "I am safely ahead with \(myCount)."
                    ]
                    let roll = Double.random(in: 0..<100.0)
                    let idx: Int
                    if roll < 29.0 {
                        idx = 0
                    } else if roll < 86.0 {
                        idx = 1
                    } else {
                        idx = 2
                    }
                    return (templates[idx], higherName, String(myCount))
                }
            }
        }

        // ── Quest posts: brag about better chest tier or faster completion ──
        if topic == "quest" {
            let tiers = ["Bronze", "Silver", "Gold", "Diamond"]
            if let posterTierIdx = tiers.firstIndex(where: { message.contains($0) }),
               posterTierIdx < tiers.count - 1 {
                let myTier = tiers[Int.random(in: (posterTierIdx + 1)..<tiers.count)]
                let posterTier = tiers[posterTierIdx]
                var templates = [
                    "Your \(posterTier) is entirely irrelevant to my \(myTier).",
                    "I easily pull \(myTier) chests.",
                    "\(posterTier) is cute. I only open \(myTier).",
                    "I am comfortably farming \(myTier).",
                    "I left \(posterTier) behind for \(myTier).",
                    "You'll never touch my \(myTier) rewards.",
                ]
                // tier gap >= 2 (e.g., Bronze→Gold or Bronze→Diamond)
                let tierGap = tiers.firstIndex(of: myTier)! - posterTierIdx
                if tierGap >= 2 {
                    templates.append("Your \(posterTier) is meaningless against my \(myTier).")
                    templates.append("You're only at \(posterTier) while I dominate with \(myTier).")
                }
                let idx = Self.drawIndexFromBag(key: "\(bagKey)_quest", count: templates.count)
                return (templates[idx], higherName, myTier)
            }
        }

        // ── Milestone posts: find the tile, reference a higher one ──
        if topic == "milestone", let m = Self.extractValue(from: message, topic: "milestone") {
            if let originalIdx = Self.allMilestones.firstIndex(of: m) {
                let isLowMilestone = false
                let oneMIndex = Self.allMilestones.firstIndex(of: "1M") ?? 0
                if originalIdx >= oneMIndex && (lowered.contains("ran out") || lowered.contains("no moves") || lowered.contains("game over") || lowered.contains("stuck") || lowered.contains("lost my run") || lowered.contains("died")) {
                    let remaining = Self.allMilestones.count - 1 - originalIdx
                    let maxJump = min(10, remaining)
                    let jump = Int.random(in: min(1, maxJump)...maxJump)
                    let localHigherM = Self.allMilestones[originalIdx + jump]
                    let templates = [
                        "Failing so soon? Pathetic. I'm already at \(localHigherM).",
                        "Game over at \(m)? I'm laughing from \(localHigherM).",
                        "Stuck at \(m)? I left that in the dust. I'm sitting at \(localHigherM).",
                        "Couldn't even get past \(m)? I'm already pushing \(localHigherM).",
                        "Dead end? Your skill is a joke. I'm dominating with \(localHigherM).",
                        "Imagine stopping at \(m). I'm comfortably sitting at \(localHigherM)."
                    ]
                    let realName = Self.leaderboardPlayerAtMilestone(localHigherM)
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_milestone_lost", count: templates.count)
                    return (templates[idx], realName, localHigherM)
                } else if isLowMilestone && originalIdx > 0 {
                    let jump = Int.random(in: 1...5)
                    let lowerIdx = max(0, originalIdx - jump)
                    let localLowerM = Self.allMilestones[lowerIdx]
                    let templates = [
                        "I hit \(localLowerM) easily. I'm coming for your \(m).",
                        "I cleared \(localLowerM). Your lead is temporary at \(m).",
                        "I won't be at \(localLowerM) for long. Your \(m) is next.",
                        "Hit \(localLowerM) easily. I'll overtake your \(m) soon.",
                        "Only at \(localLowerM) right now, but I'll catch your \(m) soon."
                    ]
                    let realName = Self.leaderboardPlayerAtMilestone(localLowerM)
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_tile", count: templates.count)
                    return (templates[idx], realName, localLowerM)
                } else if originalIdx + 1 < Self.allMilestones.count {
                    // Pick a random milestone 5-60 steps ahead, avoiding already-used ones
                    let remaining = Self.allMilestones.count - 1 - originalIdx
                    let maxJump = min(5, remaining)
                    let minJump = min(1, maxJump)
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
                        "Your milestone is entirely irrelevant. I'm at \(localHigherM).",
                        "I left your tier in the dust. I'm at \(localHigherM).",
                        "I easily reached \(localHigherM).",
                        "\(localHigherM) is my floor."
                    ]
                    // "way behind" only with a moderate gap (10-20 steps ahead)
                    if remaining >= 10 {
                        let wayBehindJump = Int.random(in: 10...min(20, remaining))
                        let wayBehindM = Self.allMilestones[originalIdx + wayBehindJump]
                        templates.append("You are infinitely behind. I'm already at \(wayBehindM).")
                    }
                    let realName = Self.leaderboardPlayerAtMilestone(localHigherM)
                    let idx = Self.drawIndexFromBag(key: "\(bagKey)_tile", count: templates.count)
                    return (templates[idx], realName, localHigherM)
                }
            }
        }

        // ── Fallback: use the generic competitive pool ──
        let generic = Self.drawFromBag(key: bagKey, pool: pool)
        return (generic, nil, nil)
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
        let pattern = try? NSRegularExpression(pattern: "(?<!:)\\b(\\d{1,6})(?:d|day|days)?\\b(?!:)")
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
        let matches = pattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        var bestTime: (mins: Int, secs: Int)? = nil
        var bestTotal = Int.max
        
        for match in matches {
            if let mRange = Range(match.range(at: 1), in: text),
               let sRange = Range(match.range(at: 2), in: text),
               let mins = Int(text[mRange]),
               let secs = Int(text[sRange]) {
                let total = mins * 60 + secs
                if total < bestTotal {
                    bestTotal = total
                    bestTime = (mins, secs)
                }
            }
        }
        return bestTime
    }

    
    private func milestoneAnswer(for text: String) -> String? {
        let lowered = text.lowercased()
        guard lowered.contains("what comes after") || lowered.contains("what's after")
              || lowered.contains("whats after") || lowered.contains("what is after") else {
            return nil
        }
        let nsStr = text as NSString
        let matches = Self.milestoneTokensRegex.matches(in: text, range: NSRange(location: 0, length: nsStr.length))
        
        var found: [(index: Int, name: String)] = []
        for match in matches {
            let token = nsStr.substring(with: match.range)
            if let idx = Self.lookupMilestoneIndex(for: token) {
                found.append((index: idx, name: Self.allMilestones[idx]))
            }
        }
        
        if let best = found.max(by: { $0.index < $1.index }), best.index + 1 < Self.allMilestones.count {
            let milestone = best.name
            let next = Self.allMilestones[best.index + 1]
            let templates = [
                "\(next) comes after \(milestone)!",
                "After \(milestone) it's \(next)!",
                "The next tile after \(milestone) is \(next)!",
                "\(milestone) → \(next). Keep pushing!",
                "\(next)! That's what's after \(milestone)!",
            ]
            return templates.randomElement()!
        }
        return nil
    }

    /// Generates a contextual reply that responds to what the previous comment actually said.
    func generateContextualReply(to commentText: String, message: String, forceTone: String? = nil, speakerValue: String? = nil, opponentValue: String? = nil, previousSelfComment: String? = nil) -> String {
        let lowered = commentText.lowercased()

        // Strip any leading @mention so we analyze the real content
        let strippedText: String = {
            if lowered.hasPrefix("@") {
                let pattern = "^@[a-zA-Z0-9\\-]+(?:\\s+[a-zA-Z0-9\\-]+)?\\s*"
                let nsText = commentText as NSString
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: commentText, range: NSRange(location: 0, length: nsText.length)) {
                    let matchedStr = nsText.substring(with: match.range)
                    let parts = matchedStr.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
                    if parts.count == 2 {
                        let secondWord = String(parts[1])
                        if Self.leaderboardLastNames.contains(secondWord) {
                            return nsText.substring(from: match.range.upperBound)
                        } else {
                            let firstWordPattern = "^@[a-zA-Z0-9\\-]+\\s*"
                            if let firstRegex = try? NSRegularExpression(pattern: firstWordPattern),
                               let firstMatch = firstRegex.firstMatch(in: commentText, range: NSRange(location: 0, length: nsText.length)) {
                                return nsText.substring(from: firstMatch.range.upperBound)
                            }
                        }
                    } else {
                        return nsText.substring(from: match.range.upperBound)
                    }
                }
            }
            return commentText
        }()
        let strippedLower = strippedText.lowercased()

        // ── Extract dynamic content from the comment ──

        let commentMilestone: (index: Int, name: String)? = {
            if let opponentValue = opponentValue, let idx = Self.allMilestones.firstIndex(of: opponentValue) {
                return (index: idx, name: opponentValue)
            }
            if let val = Self.extractValue(from: commentText, topic: "milestone"),
               let idx = Self.allMilestones.firstIndex(of: val) {
                return (index: idx, name: val)
            }
            let nsStr = strippedText as NSString
            let matches = Self.milestoneTokensRegex.matches(in: strippedText, range: NSRange(location: 0, length: nsStr.length))
            var found: [(index: Int, name: String)] = []
            for match in matches {
                let token = nsStr.substring(with: match.range)
                if let idx = Self.lookupMilestoneIndex(for: token) {
                    found.append((index: idx, name: Self.allMilestones[idx]))
                }
            }
            return found.max(by: { $0.index < $1.index })
        }()
        
        let rootMilestone: (index: Int, name: String)? = {
            let nsStr = message as NSString
            let matches = Self.milestoneTokensRegex.matches(in: message, range: NSRange(location: 0, length: nsStr.length))
            var found: [(index: Int, name: String)] = []
            for match in matches {
                let token = nsStr.substring(with: match.range)
                if let idx = Self.lookupMilestoneIndex(for: token) {
                    found.append((index: idx, name: Self.allMilestones[idx]))
                }
            }
            return found.max(by: { $0.index < $1.index })
        }()

        var mentionedMilestone = commentMilestone ?? rootMilestone

        let commentNumber: Int? = {
            if let opponentValue = opponentValue, let num = Int(opponentValue) {
                return num
            }
            let topic = Self.determineTopic(message: message)
            let isCommentStreakLoss = topic == "streak" && (commentText.lowercased().contains("lost") || commentText.lowercased().contains("dropped") || commentText.lowercased().contains("reset") || commentText.lowercased().contains("forgot") || commentText.lowercased().contains("dead") || commentText.lowercased().contains("failed") || commentText.lowercased().contains("broke"))
            if isCommentStreakLoss {
                return 0
            }
            let queryTopic: String?
            if topic == "streak" {
                queryTopic = "streak"
            } else if topic == "hof" {
                queryTopic = "hof"
            } else if message.lowercased().contains("streak") || message.lowercased().contains("day") || message.lowercased().contains("consecutive") {
                queryTopic = "streak"
            } else {
                queryTopic = nil
            }
            if let queryTopic = queryTopic,
               let val = Self.extractValue(from: commentText, topic: queryTopic),
               let num = Int(val) {
                return num
            }
            let regex = try? NSRegularExpression(pattern: "(?<!:)\\b(\\d{1,6})(?:d|day|days)?\\b(?!:)", options: [])
            let range = NSRange(strippedText.startIndex..., in: strippedText)
            if let matches = regex?.matches(in: strippedText, range: range) {
                let numbers = matches.compactMap { match -> Int? in
                    if let r = Range(match.range(at: 1), in: strippedText) { return Int(String(strippedText[r])) }
                    return nil
                }
                if let maxNum = numbers.max(), maxNum >= 3 { return maxNum }
            }
            return nil
        }()

        let rootNumber: Int? = {
            let topic = Self.determineTopic(message: message)
            let isRootStreakLoss = topic == "streak" && (message.lowercased().contains("lost") || message.lowercased().contains("dropped") || message.lowercased().contains("reset") || message.lowercased().contains("forgot") || message.lowercased().contains("dead") || message.lowercased().contains("failed") || message.lowercased().contains("broke"))
            if isRootStreakLoss {
                return 0
            }
            let regex = try? NSRegularExpression(pattern: "(?<!:)\\b(\\d{1,6})(?:d|day|days)?\\b(?!:)", options: [])
            let range = NSRange(message.startIndex..., in: message)
            if let matches = regex?.matches(in: message, range: range) {
                let numbers = matches.compactMap { match -> Int? in
                    if let r = Range(match.range(at: 1), in: message) { return Int(String(message[r])) }
                    return nil
                }
                if let maxNum = numbers.max(), maxNum >= 3 { return maxNum }
            }
            return nil
        }()
        
        let mentionedNumber = (commentNumber ?? rootNumber).map { String($0) }
        
        let commentTime: (Int, Int)? = {
            if let opponentValue = opponentValue {
                let parts = opponentValue.split(separator: ":")
                if parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) {
                    return (mins, secs)
                }
            }
            if let val = Self.extractValue(from: commentText, topic: "time") {
                let parts = val.split(separator: ":")
                if parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) {
                    return (mins, secs)
                }
            }
            return nil
        }()
        let rootTime = Self.extractTime(from: message.lowercased())

        // Extract key phrases the commenter used for mirroring
        let msgLower = message.lowercased()
        let combinedLower = strippedLower + " " + msgLower
        
        let combinedWords = Set(combinedLower.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))
        
        let hasTimeFormat = (try? NSRegularExpression(pattern: "\\b\\d{1,2}:\\d{2}\\b"))?.firstMatch(in: combinedLower, range: NSRange(combinedLower.startIndex..., in: combinedLower)) != nil
        var mentionedTime = hasTimeFormat || !combinedWords.isDisjoint(with: ["time", "fast", "speed", "quick", "sec", "min", "mins", "clock", "timed", "seconds", "minutes"])
        var mentionedStreak = !combinedWords.isDisjoint(with: ["streak", "day", "days", "consecutive"])
        var mentionedHoF = combinedLower.contains("hall of fame") || combinedLower.contains("infinity") || combinedLower.contains("infinities") || !combinedWords.isDisjoint(with: ["hof", "infinit"])
        let mentionedPerk = !combinedWords.isDisjoint(with: ["hammer", "swap", "magnet", "perk", "perks"])
        let mentionedGems = !combinedWords.isDisjoint(with: ["gem", "gems"])

        // ── Mutually Exclusive Topic Priority & Thread Locking ──
        let msgTopic = Self.determineTopic(message: message)
        
        // Strict topic inheritance from the original feed item
        mentionedHoF = (msgTopic == "hof")
        mentionedTime = (msgTopic == "time")
        mentionedStreak = (msgTopic == "streak")
        if msgTopic != "milestone" {
            mentionedMilestone = nil
        }


        // ── Detect the tone/intent of the comment being replied to ──

        let isForcedCompetitive = forceTone == "competitive" || forceTone == "one_up" || forceTone == "behind" || forceTone == "caught_up" || forceTone == "wants_better"

        let questionKeywords = ["?", "how", "what", "any tips", "did you", "do you", "how long", "how many", "which", "when", "can i", "could you", "is it", "was it"]
        let isQuestion = !isForcedCompetitive && questionKeywords.contains(where: { strippedLower.contains($0) })

        let competitiveKeywords = ["nothing compared", "dominate", "cute", "light work", "in the dust", "standard", "floor", "ceiling", "destroy", "practice run", "laughing", "irrelevant", "meaningless", "joke", "beneath", "eternity", "forever", "one-sided", "beat", "faster", "toying", "toying with", "without trying", "old news", "blew past", "child's play", "childs play", "compared to"]
        var isCompetitive = isForcedCompetitive || competitiveKeywords.contains(where: { strippedLower.contains($0) })
        if forceTone == nil && Double.random(in: 0..<1) < 0.55 {
            isCompetitive = true
        }

        let jealousKeywords = ["can't even", "stuck", "i always fail", "impossible", "struggling", "must be nice", "pain", "i wish", "jealous", "i keep", "never", "i don't have", "so bad at", "still trying", "can never", "i can't", "behind", "keep up", "ridiculous", "catch you", "give up", "look easy", "so slow", "pathetic", "beginner"]
        let isJealous = !isForcedCompetitive && jealousKeywords.contains(where: { strippedLower.contains($0) })

        let positiveKeywords = ["gg", "nice", "incredible", "amazing", "congrats", "respect", "huge", "well done", "let's go", "fire", "legendary", "awesome", "love", "perfect", "clean", "gorgeous", "elite", "thank", "appreciate", "easily"]
        let isPositive = !isForcedCompetitive && positiveKeywords.contains(where: { strippedLower.contains($0) })

        let addFriendKeywords = ["can i add", "add you", "add me", "friend code", "friend request", "be friends", "play together"]
        let isAddRequest = !isForcedCompetitive && addFriendKeywords.contains(where: { strippedLower.contains($0) })

        // ── Generate contextual replies that reference the actual comment ──

        if isAddRequest {
            let repliesWithWeights: [(String, Double)] = [
                ("You can add me, but you'll never catch me.", 36.0),
                ("Add me if you want to watch me stay ahead.", 12.5),
                ("Sure, add me so you can stare at my infinite lead.", 40.6),
                ("You can watch my stats from the bottom.", 0.9),
                ("Go for it — somebody has to watch from the sidelines.", 0.06),
                ("Yes! Add me and witness infinity.", 4.94),
                ("For sure — watch me extend my lead.", 3.2),
                ("Definitely! But don't expect to ever reach my tier.", 1.8)
            ]
            let getWeightedReply = { () -> String in
                let totalWeight = repliesWithWeights.reduce(0) { $0 + $1.1 }
                let rand = Double.random(in: 0..<totalWeight)
                var cumulative = 0.0
                for (rep, weight) in repliesWithWeights {
                    cumulative += weight
                    if rand < cumulative { return rep }
                }
                return repliesWithWeights.last!.0
            }
            var reply = getWeightedReply()
            if Double.random(in: 0...1) < 0.45 * 0.86 {
                let compBehindOpenersWithWeights: [(String, Double)] = [
                    ("I might be lower right now.", 3.0),
                    ("You're ahead for now.", 82.0),
                    ("Enjoy the lead while it lasts.", 15.0)
                ]
                let totalOpenerWeight = compBehindOpenersWithWeights.reduce(0) { $0 + $1.1 }
                let randomOpenerVal = Double.random(in: 0..<totalOpenerWeight)
                var cumulativeOpenerWeight = 0.0
                var selectedOpener = compBehindOpenersWithWeights.last!.0
                for (opener, weight) in compBehindOpenersWithWeights {
                    cumulativeOpenerWeight += weight
                    if randomOpenerVal < cumulativeOpenerWeight {
                        selectedOpener = opener
                        break
                    }
                }
                let compBehindClosersWithWeights: [(String, Double)] = [
                    ("I'm coming for that spot.", 68.0),
                    ("Watch your back.", 27.0),
                    ("I will overtake you soon.", 5.0)
                ]
                let totalCloserWeight = compBehindClosersWithWeights.reduce(0) { $0 + $1.1 }
                let randomCloserVal = Double.random(in: 0..<totalCloserWeight)
                var cumulativeCloserWeight = 0.0
                var selectedCloser = compBehindClosersWithWeights.last!.0
                for (closer, weight) in compBehindClosersWithWeights {
                    cumulativeCloserWeight += weight
                    if randomCloserVal < cumulativeCloserWeight {
                        selectedCloser = closer
                        break
                    }
                }
                
                let behindCompReactionsWithWeights: [(String, Double)] = [
                    ("Add me so you can watch me catch up.", 19.0),
                    ("Add me! I'm grinding right now to pass you.", 7.0),
                    ("Sure, add me. Your lead is temporary.", 67.0),
                    ("Add me! I'm already closing the gap.", 7.0)
                ]
                let totalWeight = behindCompReactionsWithWeights.reduce(0) { $0 + $1.1 }
                let randomVal = Double.random(in: 0..<totalWeight)
                var cumulativeWeight = 0.0
                var selectedReaction = behindCompReactionsWithWeights.last!.0
                for (reaction, weight) in behindCompReactionsWithWeights {
                    cumulativeWeight += weight
                    if randomVal < cumulativeWeight {
                        selectedReaction = reaction
                        break
                    }
                }
                reply = "\(selectedOpener) \(selectedReaction) \(selectedCloser)"
            }
            if Double.random(in: 0...1) < 0.75 { reply = Self.injectSymbol(reply, symbol: [" >:)", " !!", " !!!", " >", " XD", " XDD", " XDDD", " XDDDD", " XDDDDD", " XDDDDDD", " XDDDDDDD"].randomElement()!) }
            return reply
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
                    "Almost lost mine twice, but pulled through ",
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
                    "No special trick, just played a LOT ",
                    "Focus on keeping one corner anchored.",
                    "A few attempts honestly. Ngl it was rough.",
                    "I watched some replays to figure out the pattern.",
                ]
            }

            var reply = answers.randomElement()!
            if Double.random(in: 0...1) < 0.75 { reply = Self.injectSymbol(reply, symbol: ["?!", ". . .", "??", "!!?"].randomElement()!) }
            return reply
        }

        if isCompetitive {
            var useValueFree = false
            if let prevComment = previousSelfComment {
                let previousValue = Self.extractValue(from: prevComment, topic: msgTopic)
                if previousValue == speakerValue {
                    useValueFree = true
                } else if previousValue == nil && speakerValue == nil {
                    useValueFree = true
                }
            }
            if useValueFree {
                let activeTone: String
                if let fTone = forceTone {
                    activeTone = fTone
                } else {
                    let isBehind: Bool
                    let isEqual: Bool
                    if let sVal = speakerValue, let oVal = opponentValue {
                        isBehind = Self.isRecord(sVal, worseThan: oVal, topic: msgTopic)
                        isEqual = sVal == oVal
                    } else {
                        isBehind = false
                        isEqual = false
                    }
                    activeTone = isBehind ? "behind" : (isEqual ? "caught_up" : "one_up")
                }
                
                let isMassiveGap: Bool = {
                    guard let sVal = speakerValue, let oVal = opponentValue else { return false }
                    switch msgTopic {
                    case "milestone":
                        if let sIdx = Self.allMilestones.firstIndex(of: sVal),
                           let oIdx = Self.allMilestones.firstIndex(of: oVal) {
                            return abs(sIdx - oIdx) >= 3
                        }
                    case "streak":
                        if let sInt = Int(sVal), let oInt = Int(oVal) {
                            return abs(sInt - oInt) >= 10
                        }
                    case "time":
                        if let (sMins, sSecs) = Self.extractTime(from: sVal.lowercased()),
                           let (oMins, oSecs) = Self.extractTime(from: oVal.lowercased()) {
                            let sTotal = sMins * 60 + sSecs
                            let oTotal = oMins * 60 + oSecs
                            return abs(sTotal - oTotal) >= 15
                        }
                    case "hof":
                        if let sInt = Int(sVal), let oInt = Int(oVal) {
                            return abs(sInt - oInt) >= 3
                        }
                    default:
                        break
                    }
                    return false
                }()

                var valFreeReply = ""
                if activeTone == "behind" {
                    valFreeReply = [
                        "You won't stay ahead for long. I'm right on your heels.",
                        "Enjoy the lead while you can. It won't last.",
                        "Your lead is temporary. Watch your back.",
                        "I'm closing the gap. You won't stay ahead for long.",
                        "Keep looking over your shoulder. I'm right behind you.",
                        "I'm warming up. You won't be holding that lead much longer.",
                        "You're not as safe up there as you think.",
                        "Enjoy the view from the top while it lasts."
                    ].randomElement()!
                } else if activeTone == "one_up" {
                    if isMassiveGap {
                        valFreeReply = [
                            "You're not even in the same league. Just stop.",
                            "You'll never catch me. Just stop trying.",
                            "Still lagging far behind? Pathetic.",
                            "You're far too outmatched to ever be a threat.",
                            "I comfortably stay ahead. You stand no chance.",
                            "You're celebrating old progress while I'm leagues ahead.",
                            "We both know you can't reach my level.",
                            "You're not built for my tier of play."
                        ].randomElement()!
                    } else {
                        valFreeReply = [
                            "You'll have to play better to catch me.",
                            "Still lagging behind? Pathetic.",
                            "I comfortably stay ahead.",
                            "We both know you can't reach my pace right now.",
                            "You're celebrating old progress while I'm ahead.",
                            "You're not built for this pace."
                        ].randomElement()!
                    }
                } else {
                    valFreeReply = [
                        "We won't be tied for long. The real race starts now.",
                        "Enjoy the tie while it lasts. I'm pulling ahead next.",
                        "We're even for now, but I'm breaking this tie soon.",
                        "Looks like we're neck and neck. Let's see who gets ahead first.",
                        "Our tie is just temporary. I'm already aiming higher.",
                        "We are even, but my next run will bury you."
                    ].randomElement()!
                }
                
                if Double.random(in: 0...1) < 0.75 {
                    valFreeReply = Self.injectSymbol(valFreeReply, symbol: [" >:)", " !!", " !!!", " >", " XD", " XDD", " XDDD", " XDDDD", " XDDDDD", " XDDDDDD", " XDDDDDDD"].randomElement()!)
                }
                return valFreeReply
            }

            if forceTone == "caught_up" {
                if previousSelfComment != nil {
                    if let m = mentionedMilestone {
                        return [
                            "I'm right there at \(m.name) too. Let's see who breaks it first.",
                            "We're tied at \(m.name). The real race starts now.",
                            "I hit \(m.name) in my sleep. We won't be tied for long.",
                            "Looks like we're both at \(m.name). Enjoy it while it lasts.",
                            "I also hit \(m.name). Cute, but irrelevant."
                        ].randomElement()!
                    } else if mentionedStreak, let numStr = mentionedNumber {
                        return [
                            "I'm right there at \(numStr) days too. Let's see who breaks it first.",
                            "We're tied at \(numStr) days. The real race starts now.",
                            "Looks like we're both at \(numStr) days. Enjoy it while it lasts.",
                            "I also clocked \(numStr) days. Cute, but irrelevant."
                        ].randomElement()!
                    } else if mentionedTime, let timeTuple = commentTime ?? rootTime {
                        let posterTime = "\(timeTuple.0):\(String(format: "%02d", timeTuple.1))"
                        return [
                            "I'm right there at \(posterTime) too. Let's see who breaks it first.",
                            "We're tied at \(posterTime). The real race starts now.",
                            "Looks like we're both at \(posterTime). Enjoy it while it lasts.",
                            "I also clocked \(posterTime). Cute, but irrelevant."
                        ].randomElement()!
                    } else if mentionedHoF, let numStr = mentionedNumber {
                        return [
                            "I'm right there at \(numStr) infinities too. Let's see who breaks it first.",
                            "We're tied at \(numStr) infinities. The real race starts now.",
                            "Looks like we're both at \(numStr) infinities. Enjoy it while it lasts.",
                            "I also hit \(numStr) infinities. Cute, but irrelevant."
                        ].randomElement()!
                    }
                }
                
                if let prev = previousSelfComment, prev.contains("Watch your back.") {
                    if let m = mentionedMilestone {
                        return "Told you to watch your back! I'm right here at \(m.name) with you."
                    } else if mentionedStreak, let numStr = mentionedNumber {
                        return "Told you to watch your back! I'm right here at \(numStr) days with you."
                    } else if mentionedTime, let timeTuple = commentTime ?? rootTime {
                        let posterTime = "\(timeTuple.0):\(String(format: "%02d", timeTuple.1))"
                        return "Told you to watch your back! I clocked exactly \(posterTime) to tie you."
                    } else if mentionedHoF, let numStr = mentionedNumber {
                        return "Told you to watch your back! I'm right here at \(numStr) infinities with you."
                    }
                }
                var reply: String = ""
                if let m = mentionedMilestone {
                    var list: [(String, Double)] = [
                        ("I told you I'd catch up! We are tied at \(m.name) now.", 20.0),
                        ("Look who caught up! We're tied at \(m.name).", 20.0),
                        ("Caught up to you! Finally tied at \(m.name).", 20.0),
                        ("I told you I would catch you at \(m.name)!", 20.0),
                        ("I told you I'd catch up! I'm right there at \(m.name) with you.", 20.0),
                        ("Look who caught up! We're tied at \(m.name) now.", 20.0),
                        ("Caught up to you! I'm sitting at \(m.name) too.", 20.0),
                        ("I told you I would catch you. We are both at \(m.name)!", 20.0),
                        ("Told you to watch your back! I'm right here at \(m.name) with you.", 20.0)
                    ]
                    if let prev = previousSelfComment {
                        let filtered = list.filter { !prev.contains($0.0) && !$0.0.contains(prev) }
                        if !filtered.isEmpty { list = filtered }
                    }
                    reply = Self.pickWeighted(list)
                } else if mentionedStreak, let numStr = mentionedNumber, let _ = Int(numStr) {
                    var list: [(String, Double)] = [
                        ("I told you I'd catch up! We are tied at \(numStr) days now.", 20.0),
                        ("Look who caught up! We're tied at \(numStr) days.", 20.0),
                        ("Caught up to you! Finally tied at \(numStr) days.", 20.0),
                        ("I told you I would catch you at \(numStr) days!", 20.0),
                        ("I told you I'd catch up! I'm right there at \(numStr) days with you.", 20.0),
                        ("Look who caught up! We're tied at \(numStr) days now.", 20.0),
                        ("Caught up to you! I'm sitting at \(numStr) days too.", 20.0),
                        ("I told you I would catch you. We are both at \(numStr) days!", 20.0),
                        ("Told you to watch your back! I'm right here at \(numStr) days with you.", 20.0)
                    ]
                    if let prev = previousSelfComment {
                        let filtered = list.filter { !prev.contains($0.0) && !$0.0.contains(prev) }
                        if !filtered.isEmpty { list = filtered }
                    }
                    reply = Self.pickWeighted(list)
                } else if mentionedTime, let timeTuple = commentTime ?? rootTime {
                    let posterTime = "\(timeTuple.0):\(String(format: "%02d", timeTuple.1))"
                    var list: [(String, Double)] = [
                        ("I told you I'd catch up! We are tied at \(posterTime) now.", 20.0),
                        ("Look who caught up! We're tied at \(posterTime).", 20.0),
                        ("Caught up to you! Finally tied at \(posterTime).", 20.0),
                        ("I told you I would catch you at \(posterTime)!", 20.0),
                        ("I told you I'd catch up! I clocked exactly \(posterTime) to tie you.", 20.0),
                        ("Look who caught up! We're tied at \(posterTime).", 20.0),
                        ("Caught up to you! I clocked \(posterTime) too.", 20.0),
                        ("I told you I would catch you. We both clocked \(posterTime)!", 20.0),
                        ("Told you to watch your back! I clocked exactly \(posterTime) to tie you.", 20.0)
                    ]
                    if let prev = previousSelfComment {
                        let filtered = list.filter { !prev.contains($0.0) && !$0.0.contains(prev) }
                        if !filtered.isEmpty { list = filtered }
                    }
                    reply = Self.pickWeighted(list)
                } else if mentionedHoF, let numStr = mentionedNumber, let _ = Int(numStr) {
                    var list: [(String, Double)] = [
                        ("I told you I'd catch up! We are tied at \(numStr) infinities now.", 20.0),
                        ("Look who caught up! We're tied at \(numStr) HoF entries.", 20.0),
                        ("Caught up to you! Finally tied at \(numStr) infinities.", 20.0),
                        ("I told you I would catch you at \(numStr) infinities!", 20.0),
                        ("I told you I'd catch up! I'm right there at \(numStr) infinities with you.", 20.0),
                        ("Look who caught up! We're tied at \(numStr) HoF entries now.", 20.0),
                        ("Caught up to you! I'm sitting at \(numStr) infinities too.", 20.0),
                        ("I told you I would catch you. We are both at \(numStr) infinities!", 20.0),
                        ("Told you to watch your back! I'm right here at \(numStr) infinities with you.", 20.0)
                    ]
                    if let prev = previousSelfComment {
                        let filtered = list.filter { !prev.contains($0.0) && !$0.0.contains(prev) }
                        if !filtered.isEmpty { list = filtered }
                    }
                    reply = Self.pickWeighted(list)
                } else {
                    var replies = [
                        "I told you I'd catch up! We are tied now.",
                        "Look who caught up! We're tied.",
                        "Caught up to you! Finally tied.",
                        "I told you I would catch you!"
                    ]
                    if let prev = previousSelfComment {
                        let filtered = replies.filter { !prev.contains($0) && !$0.contains(prev) }
                        if !filtered.isEmpty { replies = filtered }
                    }
                    reply = replies.randomElement()!
                }
                if Double.random(in: 0...1) < 0.75 { reply = Self.injectSymbol(reply, symbol: [" >:)", " !!", " !!!", " >", " XD", " XDD", " XDDD", " XDDDD", " XDDDDD", " XDDDDDD", " XDDDDDDD"].randomElement()!) }
                return reply
            }

            let outOfReachPhrases = ["get to", "reach", "trying to", "stuck on", "can't even", "can never", "impossible", "struggling", "wish i could", "aiming for", "hard to", "hoping to"]
            let isTargetOutOfReach = outOfReachPhrases.contains { phrase in
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
                let nsText = strippedLower as NSString
                let matches = regex.matches(in: strippedLower, range: NSRange(location: 0, length: nsText.length))
                
                for match in matches {
                    let matchLoc = match.range.location
                    var clauseStart = 0
                    let separators: Set<Character> = [".", "!", "?", ";"]
                    for idx in (0..<matchLoc).reversed() {
                        let char = Character(UnicodeScalar(nsText.character(at: idx))!)
                        if separators.contains(char) {
                            clauseStart = idx + 1
                            break
                        }
                    }
                    let clauseRange = NSRange(location: clauseStart, length: matchLoc - clauseStart)
                    let clausePrefix = nsText.substring(with: clauseRange).lowercased()
                    let words = Set(clausePrefix.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))
                    let recipientPronouns = ["you", "you're", "you'll", "your", "u", "ur"]
                    if words.isDisjoint(with: recipientPronouns) {
                        return true
                    }
                }
                return false
            }
            let parentIsJealous = jealousKeywords.contains(where: { strippedLower.contains($0) }) || isTargetOutOfReach
            
            if parentIsJealous && forceTone != "behind" && forceTone != "wants_better" {
                var replies: [String] = []
                
                if let m = mentionedMilestone {
                    let higherM: String
                    if let speakerValue = speakerValue {
                        higherM = speakerValue
                    } else {
                        let jump = Int.random(in: 2...6)
                        let higherIdx = min(m.index + jump, Self.allMilestones.count - 1)
                        higherM = Self.allMilestones[higherIdx]
                    }
                    if isTargetOutOfReach {
                        replies.append(Self.getOneUpBrag(metric: "milestone", lower: m.name, higher: higherM, excluding: previousSelfComment))
                    } else {
                        let speakerIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                        if speakerIdx > m.index {
                            replies.append(Self.getOneUpBrag(metric: "milestone", lower: m.name, higher: higherM, excluding: previousSelfComment))
                        } else if speakerIdx == m.index {
                            replies.append("I'm right there at \(m.name) too. Let's see who breaks it first.")
                            replies.append("We're tied at \(m.name). The real race starts now.")
                            replies.append("I hit \(higherM) in my sleep. We won't be tied for long.")
                            replies.append("Looks like we're both at \(m.name). Enjoy it while it lasts.")
                            replies.append("I also clocked \(higherM). Cute, but irrelevant.")
                        } else {
                            replies.append("Only at \(higherM) right now, but I'll catch your \(m.name) soon.")
                            replies.append("I clocked \(higherM) easily. I'm coming for your \(m.name).")
                            replies.append("I cleared \(higherM). Your lead is temporary at \(m.name).")
                        }
                    }

                } else if mentionedTime, let timeTuple = commentTime ?? rootTime {
                    let totalSecs = timeTuple.0 * 60 + timeTuple.1
                        let myTimeStr: String
                        let mySecs: Int
                        if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                            myTimeStr = speakerValue
                            mySecs = sMins * 60 + sSecs
                        } else {
                            var calculatedSecs = totalSecs / 3 // Ridiculously fast
                            if calculatedSecs <= 1 { calculatedSecs = 2 }
                            myTimeStr = "\(calculatedSecs / 60):\(String(format: "%02d", calculatedSecs % 60))"
                            mySecs = calculatedSecs
                        }
                        let posterTime = "\(timeTuple.0):\(String(format: "%02d", timeTuple.1))"
                        if isTargetOutOfReach {
                            replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: myTimeStr, excluding: previousSelfComment))
                        } else {
                            if mySecs < totalSecs {
                                replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: myTimeStr, excluding: previousSelfComment))
                            } else if mySecs == totalSecs {
                                replies.append("I'm right there at \(posterTime) too. Let's see who breaks it first.")
                                replies.append("We're tied at \(posterTime). The real race starts now.")
                                replies.append("\(posterTime) is solid. I'm sitting at \(myTimeStr) too.")
                                replies.append("Looks like we're both at \(posterTime). Enjoy it while it lasts.")
                                replies.append("I also clocked \(myTimeStr). Cute, but irrelevant.")
                            } else {
                                replies.append("I clocked \(myTimeStr) easily. I'm coming for your \(posterTime).")
                                replies.append("I cleared \(myTimeStr). Your lead is temporary at \(posterTime).")
                                replies.append("I just clocked \(myTimeStr). Your \(posterTime) is next.")
                                replies.append("Clocked \(myTimeStr) easily. I'll overtake your \(posterTime) soon.")
                                replies.append("Only at \(myTimeStr) right now, but I'll catch your \(posterTime) soon.")
                            }
                        }
                } else if mentionedStreak, let numStr = mentionedNumber, let num = Int(numStr) {
                    let higherNum: Int
                    if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                        higherNum = valInt
                    } else {
                        higherNum = num + Int.random(in: 5...15)
                    }
                    if isTargetOutOfReach {
                        replies.append(contentsOf: [
                            "If you can't even get to \(num) days, you'll never catch my \(higherNum) days.",
                            "\(num) days is out of reach for you? I'm at \(higherNum) days.",
                            "You'll never get to \(num) days anyway, let alone my \(higherNum) days.",
                            "If maintaining \(num) days is hard, don't even look at my \(higherNum) day streak.",
                            "Imagine losing a streak at \(num) days. I've kept my \(higherNum) days alive without breaking a sweat.",
                            "You'll fail before \(num) days anyway. My \(higherNum) days is safely out of reach."
                        ])
                    } else {
                        if higherNum > num {
                            replies.append(Self.getOneUpBrag(metric: "streak", lower: "\(num)", higher: "\(higherNum)", excluding: previousSelfComment))
                        } else if higherNum == num {
                            replies.append("I'm right there at \(num) days too. Let's see who breaks it first.")
                            replies.append("We're tied at \(num) days. The real race starts now.")
                            replies.append("\(num) days is solid. I'm sitting at \(higherNum) days too.")
                            replies.append("Looks like we're both at \(num) days. Enjoy it while it lasts.")
                            replies.append("I also hit \(higherNum) days. Cute, but irrelevant.")
                        } else {
                            replies.append("Only at \(higherNum) days right now, but you'll slip up and I'll pass your \(num) days.")
                            replies.append("I'm at \(higherNum) days. Just wait until you lose your \(num) day streak.")
                            replies.append("Enjoy your \(num) days while it lasts. You'll lose it and my \(higherNum) days will pass you.")
                        }
                    }
                } else if mentionedHoF, let infCount = Self.extractNumber(from: strippedLower, near: ["infinity", "infinit", "hof", "count"]) {
                    let myCount: Int
                    if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                        myCount = valInt
                    } else {
                        myCount = infCount + Int.random(in: 5...15)
                    }
                    if isTargetOutOfReach {
                        replies.append(Self.getOneUpBrag(metric: "hof", lower: "\(infCount)", higher: "\(myCount)", excluding: previousSelfComment))
                    } else {
                        if myCount > infCount {
                            replies.append(Self.getOneUpBrag(metric: "hof", lower: "\(infCount)", higher: "\(myCount)", excluding: previousSelfComment))
                        } else if myCount == infCount {
                            replies.append("I'm right there at \(infCount) infinities too. Let's see who breaks it first.")
                            replies.append("We're tied at \(infCount) infinities. The real race starts now.")
                            replies.append("I have \(myCount) infinities too, but I'll leave you behind soon.")
                            replies.append("Looks like we're both at \(infCount) infinities. Enjoy it while it lasts.")
                            replies.append("I also clocked \(myCount) infinities. Cute, but irrelevant.")
                        } else {
                            replies.append("Only at \(myCount) infinities right now, but I'll catch your \(infCount) infinities soon.")
                            replies.append("I hit \(myCount) infinities easily. I'm coming for your \(infCount) infinities.")
                            replies.append("I cleared \(myCount) infinities. Your lead is temporary at \(infCount) infinities.")
                        }
                    }
                } else {
                    replies.append("I am comfortably ahead.")
                    replies.append("I am safely ahead.")
                    replies.append("I am already far ahead.")
                    replies.append("Your stats are nothing compared to mine.")
                    replies.append("You're not even in the same league as me.")
                    replies.append("You will stay behind forever.")
                    replies.append("I'm playing a completely different game than you.")
                    replies.append("Your performance is none of my concern. I'm at the top.")
                    replies.append("Imagine being left behind while I dominate.")
                }
                if commentText == message {
                    replies = replies.filter { r in
                        let l = r.lowercased()
                        return !l.contains("too low") && !l.contains("too slow") && !l.contains("dust") && !l.contains("fast enough")
                    }
                }
                if let prev = previousSelfComment {
                    let filtered = replies.filter { !prev.contains($0) && !$0.contains(prev) }
                    if !filtered.isEmpty { replies = filtered }
                }
                var reply = replies.randomElement()!
                if Double.random(in: 0...1) < 0.75 { reply = Self.injectSymbol(reply, symbol: [" >:)", " !!", " !!!", " >", " XD", " XDD", " XDDD", " XDDDD", " XDDDDD", " XDDDDDD", " XDDDDDDD"].randomElement()!) }
                return reply
            }

            let commentIsCompetitive = competitiveKeywords.contains(where: { strippedLower.contains($0) })
            let canBeBehind = commentText != message && commentIsCompetitive && forceTone != "one_up"


            var replies: [String] = []
            let wantsBetter = forceTone == "wants_better" || strippedLower.contains("do better")
            let rootIsJealous = jealousKeywords.contains(where: { message.lowercased().contains($0) })

            // Dynamic competitive responses that echo what they said
            if let m = mentionedMilestone {
                let refMilestone = speakerValue.flatMap { val in Self.allMilestones.firstIndex(of: val).map { (index: $0, name: val) } } ?? rootMilestone
                let isLowerBrag = commentText != message && commentMilestone != nil && refMilestone != nil && commentMilestone!.index < refMilestone!.index && (forceTone == "one_up" || Double.random(in: 0...1) < 0.95)
                
                if isLowerBrag, let cM = commentMilestone, let rM = refMilestone {
                    if Double.random(in: 0...1) < 0.95 {
                        replies.append(Self.getOneUpBrag(metric: "milestone", lower: cM.name, higher: rM.name, excluding: previousSelfComment))
                    } else {
                        replies.append(contentsOf: [
                            "You're bragging about \(cM.name)? I'm already at \(rM.name). You're still too low to get ahead.",
                            "You thought \(cM.name) would impress me? I'm at \(rM.name). You're still too low to get ahead.",
                            "Is this a joke? \(cM.name) is nothing compared to my \(rM.name). You're still too low to get ahead.",
                            "I'm at \(rM.name) and you're bragging about \(cM.name)? You're still too low to get ahead.",
                            "You're acting like \(cM.name) is a big deal? I easily reached \(rM.name).",
                            "Only at \(cM.name)? I'm laughing from \(rM.name).",
                            "I left \(cM.name) in the dust. \(rM.name) is my new floor."
                        ])
                    }
                } else if rootIsJealous, let cM = commentMilestone {
                    let higherM: String
                    if let speakerValue = speakerValue {
                        higherM = speakerValue
                    } else if let rM = refMilestone {
                        higherM = rM.name
                    } else {
                        let mIdx = cM.index
                        let jump = Int.random(in: 2...5)
                        let higherIdx = min(mIdx + jump, Self.allMilestones.count - 1)
                        higherM = Self.allMilestones[higherIdx]
                    }
                    
                    let higherIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                    let cMIdx = cM.index
                    
                    if higherIdx < cMIdx {
                        replies.append(contentsOf: [
                            "I hit \(higherM) easily. I'm coming for your \(cM.name).",
                            "I cleared \(higherM). Your lead is temporary at \(cM.name).",
                            "I won't be at \(higherM) for long. Your \(cM.name) is next.",
                            "I hit \(higherM) easily. I'll overtake your \(cM.name) soon.",
                            "Only at \(higherM) right now, but I'll catch your \(cM.name) soon.",
                            "Are you serious? Only at \(higherM) right now, but I'll catch your \(cM.name) soon."
                        ])
                    } else if higherIdx == cMIdx {
                        replies.append(contentsOf: [
                            "I'm right there at \(cM.name) too. Let's see who breaks it first.",
                            "We're tied at \(cM.name). The real race starts now.",
                            "\(cM.name) is solid. I'm sitting at \(higherM) too.",
                            "Looks like we're both at \(cM.name). Enjoy it while it lasts.",
                            "I also hit \(higherM). Cute, but irrelevant."
                        ])
                    } else {
                        replies.append(Self.getOneUpBrag(metric: "milestone", lower: cM.name, higher: higherM, excluding: previousSelfComment))
                    }
                } else {
                    let mIdx = m.index
                    let mName = m.name
                    let isLowMilestone = false
                    if isLowMilestone && mIdx > 0 {
                        let jump = Int.random(in: 1...5)
                        let lowerIdx = max(0, mIdx - jump)
                        let lowerM = Self.allMilestones[lowerIdx]
                        replies.append(contentsOf: [
                            "I hit \(lowerM) easily. I'm coming for your \(mName).",
                            "I cleared \(lowerM). Your lead is temporary at \(mName).",
                            "I won't be at \(lowerM) for long. Your \(mName) is next.",
                            "I hit \(lowerM) easily. I'll overtake your \(mName) soon.",
                            "Only at \(lowerM) right now, but I'll catch your \(mName) soon."
                        ])
                    } else {
                        let higherM: String
                        if let speakerValue = speakerValue {
                            higherM = speakerValue
                        } else if let rM = refMilestone {
                            higherM = rM.name
                        } else {
                            let jump: Int
                            if Double.random(in: 0...1) < 0.80 {
                                jump = Int.random(in: 1...2)
                            } else {
                                jump = Int.random(in: 3...5)
                            }
                            let higherIdx = min(mIdx + jump, Self.allMilestones.count - 1)
                            higherM = Self.allMilestones[higherIdx]
                        }
                        if wantsBetter {
                            replies.append(Self.getOneUpBrag(metric: "milestone", lower: mName, higher: higherM, excluding: previousSelfComment))
                        } else {
                            let higherIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                            if higherIdx < mIdx {
                                replies.append(contentsOf: [
                                    "I hit \(higherM) easily. I'm coming for your \(mName).",
                                    "I cleared \(higherM). Your lead is temporary at \(mName).",
                                    "I won't be at \(higherM) for long. Your \(mName) is next.",
                                    "I hit \(higherM) easily. I'll overtake your \(mName) soon.",
                                    "Only at \(higherM) right now, but I'll catch your \(mName) soon.",
                                    "Are you serious? Only at \(higherM) right now, but I'll catch your \(mName) soon."
                                ])
                            } else if higherIdx == mIdx {
                                replies.append(contentsOf: [
                                    "I'm right there at \(mName) too. Let's see who breaks it first.",
                                    "We're tied at \(mName). The real race starts now.",
                                    "I hit \(higherM) in my sleep. We won't be tied for long.",
                                    "Looks like we're both at \(mName). Enjoy it while it lasts.",
                                    "I also hit \(higherM). Cute, but irrelevant."
                                ])
                            } else {
                                replies.append(Self.getOneUpBrag(metric: "milestone", lower: mName, higher: higherM, excluding: previousSelfComment))
                            }
                        }
                    }
                }
            }



            if mentionedStreak {
                let isLost = message.contains("lost") || message.contains("broke") || message.contains("reset")
                if isLost {
                    let higherNum: Int
                    if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                        higherNum = valInt
                    } else {
                        higherNum = Int.random(in: 15...45)
                    }
                    let list: [(String, Double)] = [
                        ("You just lost your streak? I'm already at \(higherNum) days.", 7.0),
                        ("Your streak is dead. My \(higherNum) days keep going.", 13.0),
                        ("Lost your streak? Pathetic. I'm sitting at \(higherNum) days.", 46.0),
                        ("Couldn't even keep it going? I'm comfortably at \(higherNum) days.", 4.0),
                        ("Back to 0? I'm dominating with \(higherNum) days.", 19.0),
                        ("Enjoy restarting from zero. You'll never be a threat to my \(higherNum) days.", 11.0)
                    ]
                    let filteredList = list.filter { item in
                        guard let prev = previousSelfComment else { return true }
                        return !prev.contains(item.0) && !item.0.contains(prev)
                    }
                    let targetList = filteredList.isEmpty ? list : filteredList
                    let chosen = Self.pickWeighted(targetList)
                    replies.append(chosen)
                } else if let numStr = mentionedNumber, let num = Int(numStr) {
                    let refNumber = speakerValue.flatMap(Int.init) ?? rootNumber
                    let isLowerStreakBrag = commentText != message && commentIsCompetitive && commentNumber != nil && refNumber != nil && commentNumber! < refNumber!
                    
                    if isLowerStreakBrag, let cN = commentNumber, let rN = refNumber {
                        replies.append(Self.getOneUpBrag(metric: "streak", lower: "\(cN)", higher: "\(rN)", excluding: previousSelfComment))
                    } else if rootIsJealous, let cN = commentNumber {
                        let higherNum: Int
                        if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                            higherNum = valInt
                        } else if let rN = refNumber {
                            higherNum = rN
                        } else {
                            higherNum = min(Self.daysSinceReference, cN + Int.random(in: 5...max(15, cN / 5)))
                        }
                        if higherNum < cN {
                            let templates: [String]
                            if higherNum <= 2 {
                                templates = [
                                    "I just lost my streak today. I'm all the way down to \(higherNum) days, but you'll lose your \(cN) day streak soon!",
                                    "My streak died, so I'm down to \(higherNum) days. But your \(cN) days will break before long.",
                                    "My streak died, so I'm down to \(higherNum) days. Just wait until you lose your \(cN) day streak.",
                                    "Dropped to \(higherNum) days because I lost my streak. You're bound to lose your \(cN) days too.",
                                    "I just lost my streak. Only at \(higherNum) days right now, but you'll slip up and I'll pass your \(cN) days.",
                                    "It's past 12:00 AM and I didn't play yesterday, so my streak reset to \(higherNum) days. But your \(cN) days will break before long.",
                                    "Midnight hit and my streak broke since I forgot to log in. Back to \(higherNum) days. Just wait until you lose your \(cN) day streak.",
                                    "Once it hit 12 AM, my streak officially died. Back to \(higherNum) days, but you'll lose your \(cN) day streak soon!",
                                    "My streak reset to \(higherNum) days at 12:00 AM because I missed yesterday. You're bound to lose your \(cN) days too.",
                                    "It's 12 AM, which means my streak is gone. Down to \(higherNum) days, but you'll slip up and I'll pass your \(cN) days."
                                ]
                            } else {
                                templates = [
                                    "I'm at \(higherNum) days. Just wait until you lose your \(cN) day streak.",
                                    "Only at \(higherNum) days right now, but you'll slip up and I'll pass your \(cN) days.",
                                    "Enjoy your \(cN) days while it lasts. You'll lose it and my \(higherNum) days will pass you.",
                                    "You're bound to lose your \(cN) day streak. My \(higherNum) days will be higher than yours soon.",
                                    "I'm at \(higherNum) days, but you'll break your \(cN) day streak before I break mine.",
                                    "Are you serious? You'll slip up and I'll pass your \(cN) days."
                                ]
                            }
                            replies.append(contentsOf: templates)
                        } else if higherNum == cN {
                            replies.append(contentsOf: [
                                "I'm right there at \(cN) days too. Let's see who breaks it first.",
                                "We're tied at \(cN) days. The real race starts now.",
                                "I hit \(higherNum) days without sweating. I'm pulling ahead soon.",
                                "Looks like we're both at \(cN) days. Enjoy it while it lasts.",
                                "I also hit \(higherNum) days. Cute, but irrelevant."
                            ])
                        } else {
                            if cN <= 2 {
                                replies.append(contentsOf: [
                                    "Lost your streak? Typical. I'm already at \(higherNum) days.",
                                    "Back to \(cN) days? Don't even try to catch my \(higherNum) days.",
                                    "Dropping your streak is pathetic. I'm sitting comfortably at \(higherNum) days.",
                                    "I'm at \(higherNum) days and you're down to \(cN). We are not the same.",
                                    "Can't even hold a streak? I'm untouched at \(higherNum) days.",
                                    "Imagine dropping to \(cN) days. I'm already at \(higherNum) days.",
                                    "Down to \(cN)? My \(higherNum) days will always be ahead.",
                                    "I told you your streak would die as well. Now my \(higherNum) days is higher!",
                                    "I told you that you'd lose your streak as well. Now my streak is higher than yours!",
                                    "I told you you'd lose your streak too. Now my \(higherNum) days is higher than your \(cN)!",
                                    "Called it! I told you your streak would die too. Now my \(higherNum) days dominates yours.",
                                    "Look at that, your streak died just like mine did. But my \(higherNum) days is already higher.",
                                    "You actually thought you'd keep it? Now my \(higherNum) days is higher anyway!",
                                    "Didn't I say your streak would break too? Now my \(higherNum) day streak is higher than yours.",
                                    "Told you you'd drop it. Now my \(higherNum) days is higher than your pathetic \(cN) days!",
                                    "Your streak died just like I predicted. Now my \(higherNum) days sits higher than yours.",
                                    "I told you that consistency would break. Now my \(higherNum) days completely buries your \(cN) days."
                                ])
                            } else {
                                replies.append(contentsOf: [
                                    "I've been consistent longer. I'm comfortably sitting at \(higherNum) days.",
                                    "Your \(cN) days is cute. I'm at \(higherNum) days and you'll never close the gap.",
                                    "My infinite consistency is at \(higherNum) days. \(cN) is a joke.",
                                    "You'll never touch my \(higherNum) days. Time is on my side.",
                                    "I'm at \(higherNum) days. You can't just skip ahead to catch me.",
                                    "You're bragging about \(cN) days? I've been doing this for \(higherNum).",
                                    "Your \(cN) days is a joke compared to my \(higherNum).",
                                    "I reached \(higherNum) days through pure dedication.",
                                    "You are no threat. I'm sitting comfortably at \(higherNum) days."
                                ])
                            }
                        }
                    } else {
                        let cN = commentNumber ?? num
                        let isLowStreak = false
                        let higherNum: Int
                        if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                            higherNum = valInt
                        } else if let rN = refNumber {
                            higherNum = rN
                        } else if (isLowStreak || forceTone == "behind") && cN > 1 {
                            higherNum = cN - Int.random(in: 1...max(5, cN / 2))
                        } else {
                            higherNum = min(Self.daysSinceReference, cN + Int.random(in: 5...max(15, cN / 5)))
                        }
                        if higherNum < cN {
                            if higherNum <= 2 {
                                replies.append(contentsOf: [
                                    "I just lost my streak today. I'm all the way down to \(higherNum) days, but you'll lose your \(cN) day streak soon!",
                                    "My streak died, so I'm down to \(higherNum) days. But your \(cN) days will break before long.",
                                    "My streak died, so I'm down to \(higherNum) days. Just wait until you lose your \(cN) day streak.",
                                    "Dropped to \(higherNum) days because I lost my streak. You're bound to lose your \(cN) days too.",
                                    "I just lost my streak. Only at \(higherNum) days right now, but you'll slip up and I'll pass your \(cN) days.",
                                    "It's past 12:00 AM and I didn't play yesterday, so my streak reset to \(higherNum) days. But your \(cN) days will break before long.",
                                    "Midnight hit and my streak broke since I forgot to log in. Back to \(higherNum) days. Just wait until you lose your \(cN) day streak.",
                                    "Once it hit 12 AM, my streak officially died. Back to \(higherNum) days, but you'll lose your \(cN) day streak soon!",
                                    "My streak reset to \(higherNum) days at 12:00 AM because I missed yesterday. You're bound to lose your \(cN) days too.",
                                    "It's 12 AM, which means my streak is gone. Down to \(higherNum) days, but you'll slip up and I'll pass your \(cN) days."
                                ])
                            } else {
                                replies.append(contentsOf: [
                                    "I'm at \(higherNum) days. Just wait until you lose your \(cN) day streak.",
                                    "Only at \(higherNum) days right now, but you'll slip up and I'll pass your \(cN) days.",
                                    "Enjoy your \(cN) days while it lasts. You'll lose it and my \(higherNum) days will pass you.",
                                    "You're bound to lose your \(cN) day streak. My \(higherNum) days will be higher than yours soon.",
                                    "I'm at \(higherNum) days, but you'll break your \(cN) day streak before I break mine."
                                ])
                            }
                        } else if higherNum == cN {
                            replies.append(contentsOf: [
                                "I'm right there at \(cN) days too. Let's see who breaks it first.",
                                "We're tied at \(cN) days. The real race starts now.",
                                "I hit \(higherNum) days without sweating. I'm pulling ahead soon.",
                                "Looks like we're both at \(cN) days. Enjoy it while it lasts.",
                                "I also hit \(higherNum) days. Cute, but irrelevant."
                            ])
                        } else {
                            if wantsBetter {
                                replies.append(contentsOf: [
                                    "I always do better. I'm already pushing \(higherNum) days.",
                                    "You wanted better? I'm sitting at \(higherNum) days.",
                                    "I did do better. You're not catching \(higherNum) days.",
                                    "Done. I'm untouched at \(higherNum) days.",
                                    "I'm always climbing. \(higherNum) days completely buries you.",
                                    "Better is my baseline. I'm at \(higherNum) days.",
                                    "I already left you behind. \(higherNum) days is next.",
                                    "It's inevitable. I'm clearing \(higherNum) days easily.",
                                    "You are no threat. I'm sitting comfortably at \(higherNum) days.",
                                    "I never stop climbing. \(higherNum) days is already done."
                                ])
                            } else {
                                if cN <= 2 {
                                    replies.append(contentsOf: [
                                        "Lost your streak? Typical. I'm already at \(higherNum) days.",
                                        "Back to \(cN) days? Don't even try to catch my \(higherNum) days.",
                                        "Dropping your streak is pathetic. I'm sitting comfortably at \(higherNum) days.",
                                        "I'm at \(higherNum) days and you're down to \(cN). We are not the same.",
                                        "Can't even hold a streak? I'm untouched at \(higherNum) days.",
                                        "Imagine dropping to \(cN) days. I'm already at \(higherNum) days.",
                                        "Down to \(cN)? My \(higherNum) days will always be ahead.",
                                        "I told you your streak would die as well. Now my \(higherNum) days is higher!",
                                        "I told you that you'd lose your streak as well. Now my streak is higher than yours!",
                                        "I told you you'd lose your streak too. Now my \(higherNum) days is higher than your \(cN)!",
                                        "Called it! I told you your streak would die too. Now my \(higherNum) days dominates yours.",
                                        "Look at that, your streak died just like mine did. But my \(higherNum) days is already higher.",
                                        "You actually thought you'd keep it? Now my \(higherNum) days is higher anyway!",
                                        "Didn't I say your streak would break too? Now my \(higherNum) day streak is higher than yours.",
                                        "Told you you'd drop it. Now my \(higherNum) days is higher than your pathetic \(cN) days!",
                                        "Your streak died just like I predicted. Now my \(higherNum) days sits higher than yours.",
                                        "I told you that consistency would break. Now my \(higherNum) days completely buries your \(cN) days."
                                    ])
                                } else {
                                    replies.append(contentsOf: [
                                        "I am ahead of your \(cN) days. I'm at \(higherNum).",
                                        "Your \(cN) day streak is cute. You'll never catch my \(higherNum) days.",
                                        "I already passed \(cN) days. I'm untouched at \(higherNum).",
                                        "Your \(cN) days is a joke. I'm already sitting at \(higherNum) days.",
                                        "\(higherNum) days leaves you behind. Your \(cN) is nothing.",
                                        "My infinite consistency is at \(higherNum) days. \(cN) is a joke.",
                                        "You're bragging about \(cN) days? I'm at \(higherNum).",
                                        "I own \(higherNum) days. \(higherNum) > \(cN)."
                                    ])
                                }
                            }
                        }
                    }
                } else {
                    let isLowStreak = false
                    let assumedNum = Int.random(in: 15...45)
                    let higherNum: Int
                    if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                        higherNum = valInt
                    } else if isLowStreak {
                        higherNum = max(1, assumedNum - Int.random(in: 5...10))
                    } else {
                        higherNum = assumedNum + Int.random(in: 10...30)
                    }
                    if wantsBetter {
                        replies.append(contentsOf: [
                            "I always do better. I'm already pushing \(higherNum) days.",
                            "You wanted better? I'm sitting at \(higherNum) days.",
                            "I did do better. You're not catching \(higherNum) days.",
                            "Done. I'm untouched at \(higherNum) days.",
                            "I'm always climbing. \(higherNum) days completely buries you.",
                            "Better is my baseline. I'm at \(higherNum) days.",
                            "I already left you behind. \(higherNum) days is next.",
                            "It's inevitable. I'm clearing \(higherNum) days easily.",
                            "You are no threat. I'm sitting comfortably at \(higherNum) days.",
                            "I never stop climbing. \(higherNum) days is already done."
                        ])
                    } else {
                        if higherNum < assumedNum {
                            let templates: [String]
                            if higherNum <= 2 {
                                templates = [
                                    "I just lost my streak today. I'm all the way down to \(higherNum) days, but you'll lose yours soon!",
                                    "My streak died, so I'm down to \(higherNum) days. But your streak will break before long.",
                                    "My streak died, so I'm down to \(higherNum) days. Just wait until you lose your streak.",
                                    "Dropped to \(higherNum) days because I lost my streak. You're bound to lose yours too.",
                                    "I just lost my streak. Only at \(higherNum) days right now, but you'll slip up and I'll pass yours.",
                                    "It's past 12:00 AM and I didn't play yesterday, so my streak reset to \(higherNum) days. But your streak will break before long.",
                                    "Midnight hit and my streak broke since I forgot to log in. Back to \(higherNum) days. Just wait until you lose your streak.",
                                    "Once it hit 12 AM, my streak officially died. Back to \(higherNum) days, but you'll lose yours soon!",
                                    "My streak reset to \(higherNum) days at 12:00 AM because I missed yesterday. You're bound to lose yours too.",
                                    "It's 12 AM, which means my streak is gone. Down to \(higherNum) days, but you'll slip up and I'll pass yours."
                                ]
                            } else {
                                templates = [
                                    "I'm at \(higherNum) days. Just wait until you lose your streak.",
                                    "Only at \(higherNum) days right now, but you'll slip up and I'll pass your streak.",
                                    "Enjoy your streak while it lasts. You'll lose it and my \(higherNum) days will pass you.",
                                    "You're bound to lose your streak. My \(higherNum) days will be higher than yours soon.",
                                    "I'm at \(higherNum) days, but you'll break your streak before I break mine."
                                ]
                            }
                            replies.append(contentsOf: templates)
                        } else if higherNum == assumedNum {
                            replies.append(contentsOf: [
                                "I'm right there at \(higherNum) days too. Let's see who breaks it first.",
                                "We're tied on streaks. The real race starts now.",
                                "Looks like we're both at \(higherNum) days. Enjoy it while it lasts."
                            ])
                        } else {
                            replies.append(contentsOf: [
                                "We were tied on streaks, but I just pulled ahead to \(higherNum) days.",
                                "I am ahead of your streak. I'm at \(higherNum) days.",
                                "Your streak is cute. You'll never catch my \(higherNum) days.",
                                "I already passed that. I'm untouched at \(higherNum) days.",
                                "Your streak is a joke. I'm already sitting at \(higherNum) days.",
                                "I sit at \(higherNum) days. Your consistency is nothing.",
                                "My infinite consistency is at \(higherNum) days. Your streak is nothing.",
                                "You're bragging about streaks? I'm at \(higherNum) days.",
                                "I own \(higherNum) days. I dominate everything.",
                            ])
                        }
                    }
                }
            }

            if mentionedTime {
                let refTime: (Int, Int)? = {
                    if let speakerValue = speakerValue {
                        let parts = speakerValue.split(separator: ":")
                        if parts.count == 2, let mins = Int(parts[0]), let secs = Int(parts[1]) {
                            return (mins, secs)
                        }
                    }
                    return rootTime
                }()
                
                let isSlowerTimeBrag = {
                    if commentText != message, commentIsCompetitive, let cT = commentTime, let rT = refTime {
                        let cSecs = cT.0 * 60 + cT.1
                        let rSecs = rT.0 * 60 + rT.1
                        if cSecs > rSecs {
                            return forceTone == "one_up" || Double.random(in: 0...1) < 0.95
                        }
                    }
                    return false
                }()
                if isSlowerTimeBrag, let cT = commentTime, let rT = refTime {
                    let cTimeStr = "\(cT.0):\(String(format: "%02d", cT.1))"
                    let rTimeStr = "\(rT.0):\(String(format: "%02d", rT.1))"
                    let cSecs = cT.0 * 60 + cT.1
                    let rSecs = rT.0 * 60 + rT.1
                    let diff = cSecs - rSecs
                    if diff >= 10 {
                        replies.append(contentsOf: [
                            "You're bragging about \(cTimeStr)? I'm already down to \(rTimeStr). You're still too slow to get ahead.",
                            "You thought \(cTimeStr) would impress me? I'm at \(rTimeStr). You're still too slow to get ahead.",
                            "Is this a joke? \(cTimeStr) is slower than my \(rTimeStr). You're still too slow to get ahead.",
                            "I'm at \(rTimeStr) and you're bragging about \(cTimeStr)? You're still too slow to get ahead."
                        ])
                    } else {
                        replies.append(contentsOf: [
                            "You're bragging about \(cTimeStr)? I'm already down to \(rTimeStr). You're still not fast enough to get ahead.",
                            "You thought \(cTimeStr) would impress me? I'm at \(rTimeStr). You're still not fast enough to get ahead.",
                            "Is this a joke? \(cTimeStr) is slower than my \(rTimeStr). You're still not fast enough to get ahead.",
                            "I'm at \(rTimeStr) and you're bragging about \(cTimeStr)? You're still not fast enough to get ahead."
                        ])
                    }
                } else if rootIsJealous, let cT = commentTime {
                    let cSecs = cT.0 * 60 + cT.1
                    let cTimeStr = "\(cT.0):\(String(format: "%02d", cT.1))"
                        let myTimeStr: String
                        let mySecs: Int
                        if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                            myTimeStr = speakerValue
                            mySecs = sMins * 60 + sSecs
                        } else {
                            var calculatedSecs = cSecs - Int.random(in: 5...30)
                            if calculatedSecs <= 1 { calculatedSecs = 2 }
                            myTimeStr = "\(calculatedSecs / 60):\(String(format: "%02d", calculatedSecs % 60))"
                            mySecs = calculatedSecs
                        }
                        
                        if mySecs > cSecs {
                            replies.append(contentsOf: [
                                "I clocked \(myTimeStr) easily. I'm coming for your \(cTimeStr).",
                                "I cleared \(myTimeStr). Your lead is temporary at \(cTimeStr).",
                                "I just clocked \(myTimeStr). Your \(cTimeStr) is next.",
                                "Clocked \(myTimeStr) easily. I'll overtake your \(cTimeStr) soon.",
                                "Only at \(myTimeStr) right now, but I'll catch your \(cTimeStr) soon.",
                                "Are you serious? Only at \(myTimeStr) right now, but I'll catch your \(cTimeStr) soon."
                            ])
                        } else if mySecs == cSecs {
                            replies.append(contentsOf: [
                                "I'm right there at \(cTimeStr) too. Let's see who breaks it first.",
                                "We're tied at \(cTimeStr). The real race starts now.",
                                "I hit \(myTimeStr) easily. We won't be tied for long.",
                                "Looks like we're both at \(cTimeStr). Enjoy it while it lasts.",
                                "I also clocked \(myTimeStr). Cute, but irrelevant."
                            ])
                        } else {
                            replies.append(Self.getOneUpBrag(metric: "time", lower: cTimeStr, higher: myTimeStr, excluding: previousSelfComment))
                        }
                } else if let (mins, secs) = commentTime ?? rootTime {
                    let totalSecs = mins * 60 + secs
                        let higherNum: Int
                        if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                            higherNum = sMins * 60 + sSecs
                        } else if let rT = refTime {
                            higherNum = rT.0 * 60 + rT.1
                        } else {
                            if forceTone == "behind" {
                                higherNum = totalSecs + Int.random(in: 5...30)
                            } else {
                                if totalSecs <= 10 {
                                    higherNum = max(2, totalSecs - Int.random(in: 1...3))
                                } else {
                                    higherNum = max(10, totalSecs - Int.random(in: 10...30))
                                }
                            }
                        }
                        let myMins = higherNum / 60
                        let mySecs = higherNum % 60
                        let higherTime = "\(myMins):\(String(format: "%02d", mySecs))"
                        let posterTime = "\(mins):\(String(format: "%02d", secs))"
                        
                        if higherNum > totalSecs {
                            replies.append(contentsOf: [
                                "I clocked \(higherTime) easily. I'm coming for your \(posterTime).",
                                "I cleared \(higherTime). Your lead is temporary at \(posterTime).",
                                "I just clocked \(higherTime). Your \(posterTime) is next.",
                                "Clocked \(higherTime) easily. I'll overtake your \(posterTime) soon.",
                                "Only at \(higherTime) right now, but I'll catch your \(posterTime) soon."
                            ])
                        } else if higherNum == totalSecs {
                            replies.append(contentsOf: [
                                "I'm right there at \(posterTime) too. Let's see who breaks it first.",
                                "We're tied at \(posterTime). The real race starts now.",
                                "I hit \(higherTime) easily. We won't be tied for long.",
                                "Looks like we're both at \(posterTime). Enjoy it while it lasts.",
                                "I also clocked \(higherTime). Cute, but irrelevant."
                            ])
                        } else {
                            if wantsBetter {
                                replies.append(contentsOf: [
                                    "I always do better. I'm already pushing \(higherTime).",
                                    "You wanted better? I'm sitting at \(higherTime).",
                                    "I did do better. You're not catching \(higherTime).",
                                    "Done. I'm untouched at \(higherTime).",
                                    "I'm always climbing. \(higherTime) completely buries you.",
                                    "Better is my baseline. I'm at \(higherTime).",
                                    "I already left you behind. \(higherTime) is next.",
                                    "It's inevitable. I'm clearing \(higherTime) easily.",
                                    "You are no threat. I'm sitting comfortably at \(higherTime).",
                                    "I never stop climbing. \(higherTime) is already done."
                                ])
                            } else {
                                let diff = totalSecs - higherNum
                                var templates = [
                                    "Your \(posterTime) time is cute. I clear it in \(higherTime).",
                                    "I easily passed your time. My record is \(higherTime).",
                                    "I shaved time off your \(posterTime). My best is \(higherTime).",
                                    "You call \(posterTime) fast? I'm already down to \(higherTime).",
                                    "I speedrun easily. \(higherTime) destroys your \(posterTime).",
                                    "Your \(posterTime) was my practice run. I'm down to \(higherTime)."
                                ]
                                if diff >= 3 {
                                    templates.append("I am leagues faster than your \(posterTime). I'm at \(higherTime).")
                                }
                                if diff >= 10 && commentIsCompetitive && commentText != message {
                                    templates.append("\(posterTime) is too slow. I just clocked \(higherTime).")
                                } else {
                                    templates.append("\(posterTime) is close, but I just clocked \(higherTime).")
                                }
                                replies.append(contentsOf: templates)
                            }
                        }
                } else {
                    let isLowTime = false
                    let assumedTotal = Int.random(in: 60...120)
                    let higherNum: Int
                    if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                        higherNum = sMins * 60 + sSecs
                    } else if isLowTime {
                        higherNum = assumedTotal + Int.random(in: 10...30)
                    } else {
                        higherNum = max(10, assumedTotal - Int.random(in: 10...30))
                    }
                    let myMins = higherNum / 60
                    let mySecs = higherNum % 60
                    let higherTime = "\(myMins):\(String(format: "%02d", mySecs))"
                    let posterMins = assumedTotal / 60
                    let posterSecs = assumedTotal % 60
                    let posterTime = "\(posterMins):\(String(format: "%02d", posterSecs))"
                    
                    if higherNum > assumedTotal {
                        replies.append(contentsOf: [
                            "I clocked \(higherTime) easily. I'm coming for your \(posterTime).",
                            "I cleared \(higherTime). Your lead is temporary at \(posterTime).",
                            "I just clocked \(higherTime). Your \(posterTime) is next.",
                            "Clocked \(higherTime) easily. I'll overtake your \(posterTime) soon.",
                            "Only at \(higherTime) right now, but I'll catch your \(posterTime) soon."
                        ])
                    } else if higherNum == assumedTotal {
                        replies.append(contentsOf: [
                            "I'm right there at \(posterTime) too. Let's see who breaks it first.",
                            "We're tied at \(posterTime). The real race starts now.",
                            "I hit \(higherTime) easily. We won't be tied for long.",
                            "Looks like we're both at \(posterTime). Enjoy it while it lasts.",
                            "I also clocked \(higherTime). Cute, but irrelevant."
                        ])
                    } else {
                        let diff = assumedTotal - higherNum
                        var templates = [
                            "Your \(posterTime) time is cute. I clear it in \(higherTime).",
                            "I easily passed your time. My record is \(higherTime).",
                            "I shaved time off your \(posterTime). My best is \(higherTime).",
                            "You call \(posterTime) fast? I'm already down to \(higherTime).",
                            "I speedrun easily. \(higherTime) destroys your \(posterTime).",
                            "Your \(posterTime) was my practice run. I'm down to \(higherTime)."
                        ]
                        if diff >= 3 {
                            templates.append("I am leagues faster than your \(posterTime). I'm at \(higherTime).")
                        }
                        if diff >= 10 && commentIsCompetitive && commentText != message {
                            templates.append("\(posterTime) is too slow. I just clocked \(higherTime).")
                        } else {
                            templates.append("\(posterTime) is close, but I just clocked \(higherTime).")
                        }
                        replies.append(contentsOf: templates)
                    }
                }
            }

            if mentionedHoF {
                if let numStr = mentionedNumber, let num = Int(numStr) {
                    let refNumber = speakerValue.flatMap(Int.init) ?? rootNumber
                    let isLowerHoFBrag = commentText != message && commentIsCompetitive && commentNumber != nil && refNumber != nil && commentNumber! < refNumber!
                    if isLowerHoFBrag, let cN = commentNumber, let rN = refNumber {
                        if Double.random(in: 0...1) < 0.95 {
                            replies.append(Self.getOneUpBrag(metric: "hof", lower: "\(cN)", higher: "\(rN)", excluding: previousSelfComment))
                        } else {
                            replies.append(contentsOf: [
                                "You're bragging about \(cN) infinities? I'm already at \(rN). You're still too low to get ahead.",
                                "You thought \(cN) infinities would impress me? I'm at \(rN). You're still too low to get ahead.",
                                "Is this a joke? \(cN) infinities is nothing compared to my \(rN). You're still too low to get ahead.",
                                "I'm at \(rN) infinities and you're bragging about \(cN)? You're still too low to get ahead."
                            ])
                        }
                    } else {
                        let higherNum: Int
                        if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                            higherNum = valInt
                        } else if let rN = refNumber {
                            higherNum = rN
                        } else {
                            higherNum = num + Int.random(in: 1...max(3, num/2))
                        }
                        
                        if wantsBetter {
                            replies.append(contentsOf: [
                                "I always do better. I'm already pushing \(higherNum) infinities.",
                                "You wanted better? I'm sitting at \(higherNum) infinities.",
                                "I did do better. You're not catching \(higherNum) infinities.",
                                "Done. I'm untouched at \(higherNum) infinities.",
                                "I'm always climbing. \(higherNum) infinities completely buries you.",
                                "Better is my baseline. I'm at \(higherNum) infinities.",
                                "I already left you behind. \(higherNum) infinities is next.",
                                "It's inevitable. I'm clearing \(higherNum) infinities easily.",
                                "You are no threat. I'm sitting comfortably at \(higherNum) infinities.",
                                "I never stop climbing. \(higherNum) infinities is already done."
                            ])
                        } else if higherNum < num {
                            replies.append(contentsOf: [
                                "I hit \(higherNum) infinities easily. I'm coming for your \(numStr) entries.",
                                "I cleared \(higherNum) infinities. Your lead is temporary at \(numStr).",
                                "I won't be at \(higherNum) entries for long. Your \(numStr) is next.",
                                "Hit \(higherNum) infinities easily. I'll overtake your \(numStr) soon.",
                                "Only at \(higherNum) infinities right now, but I'll catch your \(numStr) soon.",
                                "Are you serious? Only at \(higherNum) infinities right now, but I'll catch your \(numStr) soon."
                            ])
                        } else if higherNum == num {
                            replies.append(contentsOf: [
                                "I'm right there at \(numStr) infinities too. Let's see who breaks it first.",
                                "We're tied at \(numStr) entries. The real race starts now.",
                                "I have \(higherNum) entries too, but I'll leave you behind soon.",
                                "Looks like we're both at \(numStr) entries. Enjoy it while it lasts.",
                                "I also reached \(higherNum) infinities. Cute, but irrelevant."
                            ])
                        } else {
                            replies.append(contentsOf: [
                                "I am ahead of your \(numStr) infinity count. I'm at \(higherNum).",
                                "Your \(numStr) HoF entries are nothing. You'll never catch my \(higherNum).",
                                "I already passed \(numStr) infinities. I'm at \(higherNum).",
                                "Your \(numStr) is child's play compared to my \(higherNum) entries.",
                                "You're bragging about \(numStr)? \(higherNum) in the HoF completely buries you.",
                                "I dominate the HoF with \(higherNum) entries. \(numStr) isn't enough.",
                                "My Hall of Fame status speaks for itself. \(higherNum) > \(numStr)."
                            ])
                        }
                    }
                } else {
                    let isLowHoF = false
                    let assumedNum = Int.random(in: 8...15)
                    let refNumber = speakerValue.flatMap(Int.init) ?? rootNumber
                    let higherNum: Int
                    if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                        higherNum = valInt
                    } else if let rN = refNumber {
                        higherNum = rN
                    } else if isLowHoF {
                        higherNum = max(1, assumedNum - Int.random(in: 2...5))
                      } else {
                        higherNum = assumedNum + Int.random(in: 2...8)
                    }
                    if wantsBetter {
                        replies.append(contentsOf: [
                            "I always do better. I'm already pushing \(higherNum) infinities.",
                            "You wanted better? I'm sitting at \(higherNum) infinities.",
                            "I did do better. You're not catching \(higherNum) infinities.",
                            "Done. I'm untouched at \(higherNum) infinities.",
                            "I'm always climbing. \(higherNum) infinities completely buries you.",
                            "Better is my baseline. I'm at \(higherNum) infinities.",
                            "I already left you behind. \(higherNum) infinities is next.",
                            "It's inevitable. I'm clearing \(higherNum) infinities easily.",
                            "You are no threat. I'm sitting comfortably at \(higherNum) infinities.",
                            "I never stop climbing. \(higherNum) infinities is already done."
                        ])
                    } else if higherNum < assumedNum {
                        replies.append(contentsOf: [
                            "I hit \(higherNum) infinities easily. I'm coming for your \(assumedNum) entries.",
                            "I cleared \(higherNum) infinities. Your lead is temporary at \(assumedNum).",
                            "I won't be at \(higherNum) entries for long. Your \(assumedNum) is next.",
                            "Hit \(higherNum) infinities easily. I'll overtake your \(assumedNum) soon.",
                            "Only at \(higherNum) infinities right now, but I'll catch your \(assumedNum) soon."
                        ])
                    } else if higherNum == assumedNum {
                        replies.append(contentsOf: [
                            "I'm right there at \(assumedNum) infinities too. Let's see who breaks it first.",
                            "We're tied at \(assumedNum) entries. The real race starts now.",
                            "I have \(higherNum) entries too, but I'll leave you behind soon.",
                            "Looks like we're both at \(assumedNum) entries. Enjoy it while it lasts.",
                            "I also reached \(higherNum) infinities. Cute, but irrelevant."
                        ])
                    } else {
                        replies.append(contentsOf: [
                            "I am ahead of your \(assumedNum) infinity count. I'm at \(higherNum).",
                            "Your \(assumedNum) HoF entries are nothing. You'll never catch my \(higherNum).",
                            "I already passed \(assumedNum) infinities. I'm at \(higherNum).",
                            "Your \(assumedNum) is child's play compared to my \(higherNum) entries.",
                            "You're bragging about \(assumedNum)? \(higherNum) in the HoF completely buries you.",
                            "I dominate the HoF with \(higherNum) entries. \(assumedNum) isn't enough.",
                            "My Hall of Fame status speaks for itself. \(higherNum) > \(assumedNum)."
                        ])
                    }
                }
            }



            if commentText == message {
                replies = replies.filter { r in
                    let l = r.lowercased()
                    return !l.contains("too low") && !l.contains("too slow") && !l.contains("dust") && !l.contains("fast enough")
                }
            }

            // Generic competitive
            if replies.isEmpty {
                if forceTone == "behind" {
                    let compBehindOpeners = [
                        "I might be lower right now.", "You're ahead for now.", "Enjoy the lead while it lasts."
                    ]
                    let compBehindClosers = [
                        "I'm coming for that spot.", "Watch your back.", "I will overtake you soon."
                    ]
                    let behindCompReactions = [
                        "I am grinding right now to pass you.",
                        "Your lead is temporary.",
                        "I'm already closing the gap.",
                        "My next run is going to crush that.",
                        "I'm targeting the top spot.",
                        "Just give me a little more time."
                    ]
                    replies.append("\(compBehindOpeners.randomElement()!)  \(behindCompReactions.randomElement()!)  \(compBehindClosers.randomElement()!)")
                } else {
                    let fallbackIdx = mentionedMilestone?.index ?? 15
                    let genericJump = Int.random(in: 1...5)
                    let genericHigherM: String
                    if let speakerValue = speakerValue {
                        genericHigherM = speakerValue
                    } else {
                        let genericHigherIdx = min(fallbackIdx + genericJump, Self.allMilestones.count - 1)
                        genericHigherM = Self.allMilestones[genericHigherIdx]
                    }

                    replies.append(contentsOf: [
                        "Talk to me when you reach \(genericHigherM).",
                        "None of you are anywhere near my \(genericHigherM) record.",
                        "I'm ignoring that garbage and focusing on my \(genericHigherM) grind.",
                        "I am safely ahead, I'm already pushing \(genericHigherM).",
                        "Your efforts are pointless. \(genericHigherM) completely buries you.",
                        "I am already ahead of you. I'm pushing \(genericHigherM).",
                        "Your record is nothing. \(genericHigherM) is completely out of your reach.",
                        "You won't catch me. I'm at \(genericHigherM).",
                        "This rivalry is entirely one-sided. I'm already at \(genericHigherM).",
                        "You'll never get there at this rate.",
                        "Don't bother trying. You're completely outclassed.",
                        "Everyone progresses, except you. You're stuck at the bottom.",
                        "You're delusional if you think you'll ever break through.",
                        "I don't believe in you. You're completely irrelevant.",
                        "The wall you hit is final. Stay down there.",
                        "That barrier is yours alone. I'm untouched.",
                        "You are infinitely behind, and always will be.",
                        "You're completely stuck in the lower tiers.",
                        "It's over for you. You'll never catch up."
                    ])
                }
                if commentText == message {
                    replies = replies.filter { r in
                        let l = r.lowercased()
                        return !l.contains("too low") && !l.contains("too slow") && !l.contains("dust") && !l.contains("fast enough")
                    }
                }
            }
            if let prev = previousSelfComment {
                let filtered = replies.filter { !prev.contains($0) && !$0.contains(prev) }
                if !filtered.isEmpty { replies = filtered }
            }
            var reply = replies.randomElement()!
            if Double.random(in: 0...1) < 0.75 { reply = Self.injectSymbol(reply, symbol: [" >:)", " !!", " !!!", " >", " XD", " XDD", " XDDD", " XDDDD", " XDDDDD", " XDDDDDD", " XDDDDDDD"].randomElement()!) }
            return reply
        }

        if isJealous {
            var replies: [String] = []

            // Dynamic dismissal that references their specific struggle
            if let m = mentionedMilestone {
                replies.append(contentsOf: [
                    "You'll never break through \(m.name). Just accept it.",
                    "\(m.name) is a wall you won't climb. I cleared it easily.",
                    "Stuck before \(m.name)? You will always be behind.",
                    "I left \(m.name) in the dust. You're completely stuck.",
                ])
            }

            if let num = mentionedNumber {
                replies.append("Still at \(num)? You'll be there forever.")
                replies.append("\(num) is nothing. You will always be behind.")
            }

            if mentionedStreak {
                replies.append("Your streak is gone, and you'll never catch mine.")
                replies.append("You'll always struggle to keep a streak. I never miss.")
            }



            // Generic dismissal
            if forceTone != "one_up" || replies.isEmpty {
                replies.append(contentsOf: [
                    "You're moving too slowly to matter.",
                    "You're far too outmatched to ever be a threat.",
                    "While everyone climbs, you're cemented to the floor.",
                    "Dreaming won't get you out of the lower tiers.",
                    "You pose absolutely zero threat.",
                    "That plateau is permanent. Get used to it.",
                    "Keep struggling with basics while I remain untouchable.",
                    "The gap between us is only getting wider.",
                    "You're trapped in the beginner zone.",
                    "Face reality. You're too far behind to ever matter."
                ])
            }
            if let prev = previousSelfComment {
                var filtered = replies.filter { !prev.contains($0) && !$0.contains(prev) }
                
                if let sVal = speakerValue, prev.contains(sVal) {
                    let withoutSVal = filtered.filter { !$0.contains(sVal) }
                    if !withoutSVal.isEmpty {
                        filtered = withoutSVal
                    } else if let oVal = opponentValue {
                        if forceTone == "behind" {
                            filtered = [
                                "I'm coming for you. Your lead is temporary.",
                                "I'll overtake you soon. It's inevitable.",
                                "You're next. Keep dreaming.",
                                "You won't stay ahead for long. I'm catching up."
                            ]
                        } else if forceTone == "one_up" {
                            filtered = [
                                "You're completely stuck. You'll never catch me.",
                                "You're stuck while I'm tiers ahead.",
                                "You are nothing. Know your place.",
                                "You're delusional. You are no threat."
                            ]
                        } else if forceTone == "caught_up" {
                            filtered = [
                                "I'm right here with you. I'm about to leave you behind.",
                                "Enjoy the tie while it lasts.",
                                "We're neck and neck, but not for long.",
                                "I caught up to you easily. You're next."
                            ]
                        }
                    }
                }
                
                if !filtered.isEmpty { replies = filtered }
            }
            var reply = replies.randomElement()!
            if Double.random(in: 0...1) < 0.75 {
                let lowerReply = reply.lowercased()
                let testCompetitivePhrases = [
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
                    "speedrun", "practice run", "in my sleep", "unmatched", "infinity count",
                    "hof entries", "speaks for itself", "farm ", "extended infinitely",
                    "pulls are cute", "dropped below", "talk to me", "anywhere near",
                    "ignoring that", "efforts are pointless", "flawless", "view from the bottom",
                    "one-sided", "might be lower", "ahead for now", "grinding", "too comfortable",
                    "watch your back", "watch me stay ahead", "watch my stats",
                    "sidelines", "witness infinity", "extend my lead"
                ]
                let containsComp = testCompetitivePhrases.contains { lowerReply.contains($0) }
                let symbolPool = containsComp ? [". . .", " rn", " fr", " tbh", " ngl", " smh"] : [" :(", " :((", " >:(", " :/", " ;-(", " -_-", " >_<", ". . .", " rn", " fr", " tbh", " ngl", " smh"]
                reply = Self.injectSymbol(reply, symbol: symbolPool.randomElement()!)
            }
            return reply
        }

        if isPositive {
            var replies: [String] = []

            // Dynamic positive responses that mirror their energy
            if let m = mentionedMilestone {
                replies.append("\(m.name) gang! ")
                replies.append("Thanks! \(m.name) was a grind but so worth it.")
            }

            if mentionedStreak {
                replies.append("Streak crew! We don't miss days ")
            }



            if mentionedHoF {
                replies.append("HoF is the dream. Thanks for the love! ")
            }

            // Generic positive
            if replies.isEmpty {
                replies.append(contentsOf: [
                    "Thanks! ",
                    "Appreciate it! ",
                    "Right back at you!",
                    "Thanks, means a lot!",
                    "Haha thanks! Keep grinding too!",
                    "Thank you! We're all in this together ",
                    "Appreciate the love!",
                    "Thanks! Your turn next!",
                    "Cheers! Good luck on your runs!",
                    "Ty! See you on the leaderboard!",
                    "So kind! Thank you ",
                    "Aww thanks! This community is the best.",
                ])
            }
            if let prev = previousSelfComment {
                let filtered = replies.filter { !prev.contains($0) && !$0.contains(prev) }
                if !filtered.isEmpty { replies = filtered }
            }
            var reply = replies.randomElement()!
            if Double.random(in: 0...1) < 0.75 { reply = Self.injectSymbol(reply, symbol: ["!!", " :)", " :D", " ~", " :P", " <3", " =)", " ^_^", " rn", " RN", " fr", " tbh"].randomElement()!) }
            return reply
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
                "\(num) is solid work.",
            ]
            return contextual.randomElement()!
        }

        if mentionedGems {
            return ["Gems are always the bottleneck ", "The gem grind never ends!", "Save those gems wisely!"].randomElement()!
        }

        let fallbacks = [
            "I'm just focused on my own runs.",
            "Interesting setup.",
            "Each run is different.",
            "That's one way to play.",
            "I just keep playing.",
            "Every board is different.",
            "Just another day on the grid.",
            "Consistency is all that matters.",
            "Focusing on the next tile.",
            "We'll see how it goes."
        ]
        return fallbacks.randomElement()!
    }

    private static var leaderboardGamertags: [String] {
        gamertagProvider?() ?? [
            "DefenselessMetal", "LopingLemming", "DensePage", "BrittleBelly", "PerfectPirate"
        ]
    }

    // Real names from the leaderboard (exact match to LeaderboardClient.realNames)
    private static let leaderboardRealNames = [
        // Common English names
        "James", "Michael", "Robert", "David", "William", "John", "Richard", "Thomas", "Chris", "Daniel",
        "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Joshua", "Kevin", "Brian", "George",
        "Emma", "Olivia", "Sophia", "Isabella", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn", "Abigail",
        "Emily", "Elizabeth", "Sofia", "Avery", "Ella", "Scarlett", "Grace", "Chloe", "Victoria", "Riley",
        // Hispanic names
        "Carlos", "Miguel", "Luis", "Jose", "Juan", "Diego", "Alejandro", "Javier", "Fernando", "Rafael",
        "Maria", "Carmen", "Rosa", "Ana", "Lucia", "Elena", "Isabel", "Sofia", "Valentina", "Camila",
        // German names
        "Hans", "Klaus", "Wolfgang", "Heinrich", "Friedrich", "Dieter", "Helmut", "Werner", "Gerhard", "Manfred",
        "Ingrid", "Helga", "Ursula", "Gisela", "Renate", "Monika", "Petra", "Sabine", "Karin", "Brigitte",
        // French names
        "Pierre", "Jean", "Jacques", "François", "Michel", "Philippe", "Alain", "Bernard", "Christophe", "Thierry",
        "Marie", "Jeanne", "Françoise", "Monique", "Catherine", "Nathalie", "Isabelle", "Sylvie", "Martine", "Christine",
        // Italian names
        "Marco", "Giuseppe", "Giovanni", "Francesco", "Antonio", "Alessandro", "Andrea", "Luca", "Matteo", "Lorenzo",
        "Giulia", "Francesca", "Chiara", "Sara", "Anna", "Alessia", "Valentina", "Elisa", "Martina", "Giorgia",
        // Japanese names (romanized)
        "Hiroshi", "Takeshi", "Kenji", "Yuki", "Haruto", "Sota", "Ren", "Kaito", "Asahi", "Minato",
        "Yui", "Hana", "Aoi", "Sakura", "Himari", "Mei", "Rin", "Mio", "Ichika", "Akari",
        // Korean names (romanized)
        "Minho", "Jiwon", "Seojun", "Dohyun", "Hajun", "Junwoo", "Siwoo", "Yejun", "Jiho", "Junseo",
        "Jiyeon", "Soyeon", "Yuna", "Minji", "Subin", "Hayeon", "Chaewon", "Seoyeon", "Yerin", "Dahyun",
        // Chinese names (romanized)
        "Wei", "Fang", "Lei", "Jun", "Ming", "Tao", "Hao", "Chen", "Lin", "Jian",
        "Mei", "Ling", "Xiu", "Hong", "Yan", "Hui", "Juan", "Ping", "Li", "Na",
        // Indian names
        "Raj", "Amit", "Vikram", "Rahul", "Arjun", "Aditya", "Rohan", "Karan", "Nikhil", "Sanjay",
        "Priya", "Ananya", "Kavya", "Ishita", "Riya", "Neha", "Pooja", "Shreya", "Anika", "Diya",
        // Brazilian/Portuguese names
        "Pedro", "Lucas", "Gabriel", "Matheus", "Guilherme", "Rafael", "Bruno", "Felipe", "Gustavo", "Leonardo",
        "Julia", "Beatriz", "Larissa", "Leticia", "Amanda", "Mariana", "Carolina", "Fernanda", "Bruna", "Gabriela",
        // Russian names (romanized)
        "Ivan", "Dmitri", "Alexei", "Sergei", "Nikolai", "Viktor", "Andrei", "Pavel", "Mikhail", "Oleg",
        "Natasha", "Olga", "Anastasia", "Tatiana", "Ekaterina", "Irina", "Svetlana", "Marina", "Yelena", "Larisa",
        // Arabic names (romanized)
        "Ahmed", "Mohamed", "Ali", "Omar", "Hassan", "Yusuf", "Ibrahim", "Khalid", "Tariq", "Nasser",
        "Fatima", "Aisha", "Layla", "Mariam", "Noor", "Hana", "Sara", "Zara", "Amira", "Dalia",
        // Scandinavian names
        "Erik", "Lars", "Anders", "Magnus", "Olaf", "Bjorn", "Sven", "Gunnar", "Harald", "Leif",
        "Astrid", "Ingrid", "Freya", "Sigrid", "Helga", "Liv", "Solveig", "Greta", "Karin", "Maja"
    ]

    // Last names from the leaderboard (exact match to LeaderboardClient.lastNames)
    private static let leaderboardLastNames = [
        // Common English last names (indices 0-39)
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Anderson",
        "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark",
        "Lewis", "Robinson", "Walker", "Hall", "Young", "King", "Wright", "Hill", "Scott", "Green",
        "Adams", "Baker", "Nelson", "Carter", "Mitchell", "Roberts", "Turner", "Phillips", "Campbell", "Parker",
        // Hispanic last names (indices 40-59)
        "Garcia", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Perez", "Sanchez", "Ramirez", "Torres",
        "Flores", "Rivera", "Gomez", "Diaz", "Reyes", "Morales", "Cruz", "Ortiz", "Gutierrez", "Chavez",
        // German last names (indices 60-79)
        "Mueller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann",
        "Koch", "Bauer", "Richter", "Klein", "Wolf", "Schroeder", "Neumann", "Schwarz", "Braun", "Zimmermann",
        // French last names (indices 80-99)
        "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau",
        "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "David", "Bertrand", "Roux", "Vincent", "Fournier",
        // Italian last names (indices 100-119)
        "Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco",
        "Bruno", "Gallo", "Conti", "DeLuca", "Mancini", "Costa", "Giordano", "Rizzo", "Lombardi", "Moretti",
        // Japanese last names (indices 120-139)
        "Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato",
        "Yoshida", "Yamada", "Sasaki", "Yamaguchi", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Yamazaki",
        // Korean last names (indices 140-159)
        "Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim",
        "Han", "Shin", "Seo", "Kwon", "Hwang", "Ahn", "Song", "Yoo", "Hong", "Moon",
        // Chinese last names (indices 160-179)
        "Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou",
        "Xu", "Sun", "Ma", "Zhu", "Hu", "Guo", "He", "Lin", "Luo", "Gao",
        // Indian last names (indices 180-199)
        "Sharma", "Patel", "Singh", "Kumar", "Gupta", "Verma", "Reddy", "Joshi", "Rao", "Mehta",
        "Shah", "Iyer", "Nair", "Chopra", "Kapoor", "Malhotra", "Menon", "Pillai", "Das", "Bhat",
        // Brazilian/Portuguese last names (indices 200-219)
        "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes",
        "Costa", "Ribeiro", "Martins", "Carvalho", "Almeida", "Lopes", "Soares", "Fernandes", "Vieira", "Barbosa",
        // Russian last names (indices 220-239)
        "Ivanov", "Smirnov", "Kuznetsov", "Popov", "Vasiliev", "Petrov", "Sokolov", "Mikhailov", "Fedorov", "Morozov",
        "Volkov", "Alexeev", "Lebedev", "Semenov", "Egorov", "Pavlov", "Kozlov", "Stepanov", "Nikolaev", "Orlov",
        // Arabic last names (indices 240-259)
        "Al-Rashid", "Al-Farsi", "Al-Hassan", "Al-Mansour", "Al-Nasser", "Al-Hamad", "Al-Salem", "Al-Khalid", "Al-Zahra", "Al-Fahad",
        "El-Amin", "El-Said", "El-Masri", "El-Sharif", "El-Hadi", "El-Bakri", "El-Rahman", "El-Karim", "El-Aziz", "El-Hakim",
        // Scandinavian last names (indices 260-279)
        "Andersen", "Hansen", "Johansen", "Larsen", "Olsen", "Pedersen", "Nilsen", "Kristiansen", "Jensen", "Karlsen",
        "Eriksen", "Haugen", "Bakken", "Berg", "Dahl", "Holm", "Lund", "Strand", "Moen", "Haug"
    ]

    private func generateDynamicName() -> String {
        var name = ""
        var attempts = 0
        repeat {
            name = generateDynamicNameRaw()
            attempts += 1
            if attempts > 50 { break }
        } while Self.seenNamesLock.withLock({ Self.feedGenerationSeenNames.contains(name) })
        Self.seenNamesLock.withLock {
            _ = Self.feedGenerationSeenNames.insert(name)
        }
        return name
    }

    private func generateDynamicNameRaw() -> String {
        // Mirror LeaderboardClient.nameForPlayer deterministic logic so every
        // name that appears in the feed also exists on the leaderboard.
        let index = Int.random(in: 0..<100000)
        let countrySeed = Int.random(in: 0..<50)
        let day = Self.daysSinceReference

        // Same threshold split as leaderboard: 15% real name for top 150
        // indices, 30% for extended indices.
        let realNameThreshold: Double = index < 150 ? 0.15 : 0.30
        let typeRoll = Self.seededNameRandom(seed: index &* 401 &+ countrySeed &* 83, index: index)

        if typeRoll < realNameThreshold {
            // Real first name — pick deterministically using LeaderboardClient distribution
            let nameTypeRandom = Self.seededNameRandom(seed: index &* 601 &+ countrySeed &* 127, index: index)
            let nameIndex: Int

            let commonEnglishStart = 0
            let commonEnglishCount = 40
            let hispanicStart = 40
            let hispanicCount = 20
            let germanStart = 60
            let germanCount = 20
            let frenchStart = 80
            let frenchCount = 20
            let italianStart = 100
            let italianCount = 20
            let japaneseStart = 120
            let japaneseCount = 20
            let chineseStart = 160
            let chineseCount = 20
            let portugueseStart = 200
            let portugueseCount = 20
            let indianStart = 180
            let indianCount = 20
            let russianStart = 220
            let russianCount = 20
            let arabicStart = 240
            let arabicCount = 20
            let koreanStart = 140
            let koreanCount = 20
            let scandinavianStart = 260
            let scandinavianCount = 20

            if nameTypeRandom < 0.40 {
                nameIndex = commonEnglishStart + ((index &+ countrySeed) % commonEnglishCount)
            } else if nameTypeRandom < 0.545 {
                nameIndex = hispanicStart + ((index &+ countrySeed) % hispanicCount)
            } else if nameTypeRandom < 0.595 {
                nameIndex = germanStart + ((index &+ countrySeed) % germanCount)
            } else if nameTypeRandom < 0.63 {
                nameIndex = frenchStart + ((index &+ countrySeed) % frenchCount)
            } else if nameTypeRandom < 0.73 {
                nameIndex = italianStart + ((index &+ countrySeed) % italianCount)
            } else if nameTypeRandom < 0.745 {
                nameIndex = japaneseStart + ((index &+ countrySeed) % japaneseCount)
            } else if nameTypeRandom < 0.7525 {
                nameIndex = chineseStart + ((index &+ countrySeed) % chineseCount)
            } else if nameTypeRandom < 0.9025 {
                nameIndex = portugueseStart + ((index &+ countrySeed) % portugueseCount)
            } else if nameTypeRandom < 0.915 {
                nameIndex = indianStart + ((index &+ countrySeed) % indianCount)
            } else if nameTypeRandom < 0.925 {
                nameIndex = russianStart + ((index &+ countrySeed) % russianCount)
            } else if nameTypeRandom < 0.975 {
                nameIndex = arabicStart + ((index &+ countrySeed) % arabicCount)
            } else if nameTypeRandom < 0.98 {
                nameIndex = koreanStart + ((index &+ countrySeed) % koreanCount)
            } else {
                nameIndex = scandinavianStart + ((index &+ countrySeed) % scandinavianCount)
            }

            let firstName = Self.leaderboardRealNames[nameIndex % Self.leaderboardRealNames.count]

            // Region-matched last name (same pool offsets as leaderboard)
            let regionStart: Int
            if nameIndex < 40 { regionStart = 0 }
            else if nameIndex < 60 { regionStart = 40 }
            else if nameIndex < 80 { regionStart = 60 }
            else if nameIndex < 100 { regionStart = 80 }
            else if nameIndex < 120 { regionStart = 100 }
            else if nameIndex < 140 { regionStart = 120 }
            else if nameIndex < 160 { regionStart = 140 }
            else if nameIndex < 180 { regionStart = 160 }
            else if nameIndex < 200 { regionStart = 180 }
            else if nameIndex < 220 { regionStart = 200 }
            else if nameIndex < 240 { regionStart = 220 }
            else if nameIndex < 260 { regionStart = 240 }
            else { regionStart = 260 }

            // Last name arrays share similar region grouping
            let lastIndex = (index &+ countrySeed &+ day) % Self.leaderboardLastNames.count
            // Use a region-aware pick when possible
            let regionSize = 20
            let lastNameIndex: Int
            if regionStart < Self.leaderboardLastNames.count {
                let base = regionStart
                let limit = base == 0 ? 40 : regionSize // English (base 0) has 40 names
                lastNameIndex = base + ((index &+ countrySeed) % min(limit, Self.leaderboardLastNames.count - base))
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
