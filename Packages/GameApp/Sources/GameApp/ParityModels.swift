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
    func addComment(to itemID: UUID, text: String) async throws
    func searchFriends(query: String) async throws -> [AccountProfile]
    func invites() async throws -> [FamilyInvite]
}

public struct MockSocialService: SocialService, Sendable {
    public init() {}

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

    private static let feedCacheKey = "socialFeed.cache.v1"
    private static let feedDateKey = "socialFeed.cacheDate.v1"

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
            let newComment = SocialFeedComment(authorName: "Player", text: text, createdAt: now)
            cached[index].comments.append(newComment)
            
            // Simulate a response from another player (30 mins to 24 hours later)
            let delay = Double.random(in: 1800...86400)
            let responseTime = now.addingTimeInterval(delay)
            
            let responderName: String
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
            
            let responseText = "@Player " + generateDynamicComment(message: cached[index].message)
            let responseComment = SocialFeedComment(authorName: responderName, text: responseText, createdAt: responseTime)
            cached[index].comments.append(responseComment)
            
            cached[index].commentCount = cached[index].comments.count
            if let newData = try? JSONEncoder().encode(cached) {
                defaults.set(newData, forKey: Self.feedCacheKey)
            }
        }
    }

    private func generateFeedItems(now: Date) -> [SocialFeedItem] {
        var items: [SocialFeedItem] = []
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
            
            let randomMilestone: String
            if Double.random(in: 0...1) < 0.8 {
                randomMilestone = Self.allMilestones[Int.random(in: 14..<Self.allMilestones.count)]
            } else {
                randomMilestone = Self.allMilestones.randomElement()!
            }
            
            let rawMessage = messages.randomElement()!
            let message = rawMessage.replacingOccurrences(of: "NEW", with: randomMilestone)
            let statText = "Update"
            let timeOffset = Double.random(in: -86400...0)
            let itemDate = now.addingTimeInterval(timeOffset)
            
            var comments: [SocialFeedComment] = []
            let numComments = Int.random(in: 0...5)
            
            // Keep track of participants to allow for replies
            var participants = [author]
            
            for _ in 0..<numComments {
                let commentOffset = Double.random(in: timeOffset...0)
                let commentAuthor = generateDynamicName()
                var commentText = generateDynamicComment(message: message)
                
                // 30% chance to reply to someone else who has already participated
                if !participants.isEmpty && Double.random(in: 0...1) < 0.3 {
                    let replyingTo = participants.randomElement()!
                    if replyingTo != commentAuthor {
                        commentText = "@\(replyingTo) " + commentText
                    }
                }
                
                comments.append(SocialFeedComment(
                    authorName: commentAuthor,
                    text: commentText,
                    createdAt: now.addingTimeInterval(commentOffset)
                ))
                
                participants.append(commentAuthor)
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
    
    private func generateDynamicComment(message: String) -> String {
        let openers = ["Dude,", "Omg,", "Wow,", "Bro,", "Honestly,", "Crazy,", "Yoo,", ""]
        var subjects = ["that run", "your board", "your progress", "that score", "this setup", "your grid", "the late game"]
        let verbs = ["is", "looks", "feels", "was"]
        let adjectives = ["insane", "amazing", "unreal", "so clean", "mind-blowing", "crazy", "perfect", "solid", "epic", "brilliant", "next level", "flawless"]
        
        var positiveReactions = ["GG!", "Nice!", "Incredible!", "Keep it up!", "Let's go!", "Fire!", "Huge!", "Well deserved!", "Too good!", "Teach me!"]
        var jealousReactions = ["So jealous", "I can't even get past 1M", "My board never looks like that", "How is that even possible", "You make it look so easy", "I'm stuck on the previous tier", "I always lose right here"]
        var competitiveReactions = ["I am going to reach higher milestones than you!", "Watch your back, I'm catching up.", "Enjoy it while it lasts.", "My next run will beat that.", "I'm coming for your spot.", "You won't be ahead for long.", "Game on."]
        var questions = ["How long did that take?", "What's your secret?", "Any tips for this tier?", "How many moves did it take?", "Did you use any swaps?", "Was it tough?", "Can I add you?"]
        
        // Dynamically inject topic-specific terminology based on the feed item's message
        if message.contains("Hall of Fame") {
            subjects.append(contentsOf: ["that HoF entry", "joining the Hall of Fame", "this legendary status", "reaching the end", "that infinity rank"])
            positiveReactions.append(contentsOf: ["Welcome to the Hall of Fame!", "HoF! That's massive.", "See you on the infinity leaderboard!", "Legendary!", "The ultimate achievement!"])
            jealousReactions.append(contentsOf: ["I'll never reach the Hall of Fame", "How long did it take to get to HoF?", "I'm still grinding for HoF"])
            competitiveReactions.append(contentsOf: ["I will join the Hall of Fame and have a higher infinity count than you!", "My infinity count will be bigger than yours.", "I'm coming for your HoF spot."])
            questions.append(contentsOf: ["How many infinity counts do you have?", "Are you going for a high infinity count?", "What's the next goal after HoF?"])
        } else if message.contains("streak") {
            subjects.append(contentsOf: ["that streak", "your daily consistency", "keeping it alive"])
            positiveReactions.append(contentsOf: ["Nice streak!", "Don't lose it!", "Streak master!", "Way to keep the fire going."])
            jealousReactions.append(contentsOf: ["I lost my streak yesterday", "How do you remember every day?", "I can never keep a streak going"])
            competitiveReactions.append(contentsOf: ["My streak is longer than yours.", "I'm catching up to your streak."])
            questions.append(contentsOf: ["How long is your streak now?", "Did you ever use a streak freeze?"])
        } else if message.contains("timed challenge") {
            subjects.append(contentsOf: ["that time", "your speed", "the daily run"])
            positiveReactions.append(contentsOf: ["Fast hands!", "Speed demon!", "Nice clear time!"])
            jealousReactions.append(contentsOf: ["I ran out of time today", "I couldn't beat the clock", "You finished so fast"])
            competitiveReactions.append(contentsOf: ["I bet my time was faster.", "I'll beat your time tomorrow."])
            questions.append(contentsOf: ["What was your exact time?", "Did you pause at all?"])
        } else if message.contains("theme") {
            subjects.append(contentsOf: ["that new theme", "your new aesthetic", "the customization"])
            positiveReactions.append(contentsOf: ["Love that theme!", "Looks so fresh.", "Best theme in the game.", "So pretty."])
            jealousReactions.append(contentsOf: ["I'm still trying to unlock that one", "I want that theme so bad", "I don't have enough gems for it"])
            competitiveReactions.append(contentsOf: ["My theme is better.", "I have all the themes unlocked."])
            questions.append(contentsOf: ["Which theme is that?", "How much did that cost?"])
        } else if message.contains("Quest") {
            subjects.append(contentsOf: ["that quest completion", "finishing the weeklies", "getting those rewards"])
            positiveReactions.append(contentsOf: ["Quest complete!", "Enjoy the rewards!", "Easy gems."])
            jealousReactions.append(contentsOf: ["I'm only halfway done with mine", "Those quests were so hard this week"])
            competitiveReactions.append(contentsOf: ["I finished mine on Tuesday.", "I always finish quests faster."])
            questions.append(contentsOf: ["What did you get from the chest?", "Were your quests hard?"])
        }
        
        // Detect specific milestones if present in the message
        let sortedMilestones = Self.allMilestones.sorted(by: { $0.count > $1.count })
        if let foundMilestone = sortedMilestones.first(where: { message.contains(" \($0) ") }) {
            let m = foundMilestone
            if Double.random(in: 0...1) < 0.6 {
                subjects.append(contentsOf: ["that \(m)", "hitting \(m)", "your \(m)", "this \(m) run"])
                positiveReactions.append(contentsOf: ["GG on \(m)!", "\(m) is huge!", "Congrats on \(m)!"])
                jealousReactions.append(contentsOf: ["I can't even get to \(m)", "How did you get \(m) so fast?", "I always lose before \(m)"])
                competitiveReactions.append(contentsOf: ["I'm getting past \(m) today.", "I'll beat your \(m)."])
                questions.append(contentsOf: ["Any tips for getting \(m)?", "Was \(m) tough?"])
            }
        }
        
        // Symbols categorized by tone
        let positiveSymbols = ["!!", " :)", " :D", " xD", " ~", " :P", " <3", " =)", " ^_^", " ;-)", " :-)", "🔥", "🙌", "🚀", "👏", "💪", "🏆", "✨"]
        let questionSymbols = ["?!", "...", "👀", "🤔", "??", "!!?"]
        let sadOrJealousSymbols = [" :(", " :((", " >:(", " :/", " ;-(", " -_-", " >_<", "...", "😩", "😭", "💀", "🫠"]
        let competitiveSymbols = [" >:)", " 👀", " 😈", " ⚔️", " 🎯", " 😏", " 🏁", " 💨"]
        let keyboardSymbols = ["~", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "-", "=", "{", "}", "[", "]", "|", "\\", ":", ";", "\"", "'", "<", ">", ",", ".", "?", "/"]

        let format = Int.random(in: 0...6)
        var comment = ""
        var tone = "positive"
        
        switch format {
        case 0:
            let opener = openers.randomElement()!
            let core = "\(subjects.randomElement()!) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
            comment = opener.isEmpty ? core.capitalized + "!" : "\(opener) \(core)!"
            tone = "positive"
        case 1:
            comment = "\(positiveReactions.randomElement()!) \(questions.randomElement()!)"
            tone = "question"
        case 2:
            let opener = openers.randomElement()!
            let core = "\(subjects.randomElement()!) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
            let sentence = opener.isEmpty ? core.capitalized + "." : "\(opener) \(core)."
            comment = "\(sentence) \(questions.randomElement()!)"
            tone = "question"
        case 3:
            comment = "\(positiveReactions.randomElement()!)"
            tone = "positive"
        case 4:
            comment = "\(jealousReactions.randomElement()!)"
            tone = "sad"
        case 5:
            comment = "\(competitiveReactions.randomElement()!)"
            tone = "competitive"
        default:
            comment = "\(subjects.randomElement()!.capitalized) \(verbs.randomElement()!) \(adjectives.randomElement()!)"
            tone = "positive"
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
