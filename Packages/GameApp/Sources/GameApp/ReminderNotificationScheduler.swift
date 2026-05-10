import Foundation
import SwiftUI

#if canImport(UserNotifications)
@preconcurrency import UserNotifications
#endif

public enum ReminderNotificationAuthorizationStatus: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unavailable

    public var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied, .unavailable:
            false
        }
    }
}

public enum ReminderNotificationIdentifier {
    public static let practice = "ultimate2244.reminder.practice"
    public static let streak = "ultimate2244.reminder.streak"
    public static let quest = "ultimate2244.reminder.quest"

    public static let all = [practice, streak, quest]
}

public enum ReminderNotificationSchedulerError: LocalizedError, Sendable {
    case permissionDenied
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Notifications are disabled for Ultimate2244. Turn them on in Settings to schedule reminders."
        case .unavailable:
            "Notification reminders are unavailable on this device."
        }
    }
}

public protocol ReminderNotificationScheduler: Sendable {
    func authorizationStatus() async -> ReminderNotificationAuthorizationStatus
    func requestAuthorization() async throws -> ReminderNotificationAuthorizationStatus
    func apply(_ preferences: ReminderPreferences) async throws
    func cancelAll() async
}

public struct NoopReminderNotificationScheduler: ReminderNotificationScheduler, Sendable {
    public init() {}

    public func authorizationStatus() async -> ReminderNotificationAuthorizationStatus {
        .unavailable
    }

    public func requestAuthorization() async throws -> ReminderNotificationAuthorizationStatus {
        throw ReminderNotificationSchedulerError.unavailable
    }

    public func apply(_ preferences: ReminderPreferences) async throws {
        if preferences.hasEnabledReminder {
            throw ReminderNotificationSchedulerError.unavailable
        }
    }

    public func cancelAll() async {}
}

#if canImport(UserNotifications)
public final class LocalReminderNotificationScheduler: ReminderNotificationScheduler, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> ReminderNotificationAuthorizationStatus {
        await center.notificationSettings().authorizationStatus.reminderStatus
    }

    public func requestAuthorization() async throws -> ReminderNotificationAuthorizationStatus {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { return .denied }
        return await authorizationStatus()
    }

    public func apply(_ preferences: ReminderPreferences) async throws {
        let descriptors = ReminderDescriptor.enabledDescriptors(for: preferences)
        guard !descriptors.isEmpty else {
            await cancelAll()
            return
        }

        var status = await authorizationStatus()
        if status == .notDetermined {
            status = try await requestAuthorization()
        }

        guard status.allowsScheduling else {
            await cancelAll()
            throw ReminderNotificationSchedulerError.permissionDenied
        }

        center.removePendingNotificationRequests(withIdentifiers: ReminderNotificationIdentifier.all)

        for descriptor in descriptors {
            var dateComponents = DateComponents()
            dateComponents.hour = preferences.reminderHour
            dateComponents.minute = preferences.reminderMinute

            let content = UNMutableNotificationContent()
            content.title = descriptor.title
            content.body = descriptor.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: descriptor.identifier,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    public func cancelAll() async {
        center.removePendingNotificationRequests(withIdentifiers: ReminderNotificationIdentifier.all)
    }
}

private extension UNAuthorizationStatus {
    var reminderStatus: ReminderNotificationAuthorizationStatus {
        switch self {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorized
        case .provisional:
            .provisional
        case .ephemeral:
            .ephemeral
        @unknown default:
            .unavailable
        }
    }
}
#endif

private struct ReminderDescriptor {
    let identifier: String
    let title: String
    let body: String

    static func enabledDescriptors(for preferences: ReminderPreferences) -> [ReminderDescriptor] {
        var descriptors: [ReminderDescriptor] = []

        if preferences.practiceReminderEnabled {
            descriptors.append(
                ReminderDescriptor(
                    identifier: ReminderNotificationIdentifier.practice,
                    title: "Practice in Ultimate2244",
                    body: "Take a short run and keep your board sense sharp."
                )
            )
        }

        if preferences.streakReminderEnabled {
            descriptors.append(
                ReminderDescriptor(
                    identifier: ReminderNotificationIdentifier.streak,
                    title: "Keep your Ultimate2244 streak",
                    body: "Claim today’s progress before the streak resets."
                )
            )
        }

        if preferences.questReminderEnabled {
            descriptors.append(
                ReminderDescriptor(
                    identifier: ReminderNotificationIdentifier.quest,
                    title: "Daily quests are waiting",
                    body: "Finish today’s Ultimate2244 quests and collect your rewards."
                )
            )
        }

        return descriptors
    }
}

public extension ReminderPreferences {
    var hasEnabledReminder: Bool {
        practiceReminderEnabled || streakReminderEnabled || questReminderEnabled
    }
}

private struct ReminderNotificationSchedulerKey: EnvironmentKey {
    nonisolated static var defaultValue: any ReminderNotificationScheduler {
        NoopReminderNotificationScheduler()
    }
}

public extension EnvironmentValues {
    var reminderNotificationScheduler: any ReminderNotificationScheduler {
        get { self[ReminderNotificationSchedulerKey.self] }
        set { self[ReminderNotificationSchedulerKey.self] = newValue }
    }
}
