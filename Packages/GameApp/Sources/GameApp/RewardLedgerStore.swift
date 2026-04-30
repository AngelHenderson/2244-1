import Foundation
import Observation

public struct RewardLedgerEntry: Codable, Equatable, Identifiable, Sendable {
    public enum Source: String, Codable, CaseIterable, Sendable {
        case achievement
        case dailyClaim
        case dailyQuest
        case gift
        case challenge
        case purchase
        case ad
        case spinWheel
        case boost
        case journey
        case manual
    }

    public enum ItemType: String, Codable, CaseIterable, Sendable {
        case gems
        case hammer
        case swap
        case magnet
        case undo
        case shuffle
        case double
        case spin
        case multiplier2x
        case multiplier3x
        case multiplier4x
        case adFree
        case theme
        case subscription
    }

    public enum SyncStatus: String, Codable, CaseIterable, Sendable {
        case localOnly
        case pending
        case synced
        case failed
    }

    public let id: UUID
    public let source: Source
    public let itemType: ItemType
    public let amount: Int
    public let timestamp: Date
    public let idempotencyKey: String
    public var syncStatus: SyncStatus
    public var serverID: String?

    public init(
        id: UUID = UUID(),
        source: Source,
        itemType: ItemType,
        amount: Int,
        timestamp: Date = Date(),
        idempotencyKey: String,
        syncStatus: SyncStatus = .localOnly,
        serverID: String? = nil
    ) {
        self.id = id
        self.source = source
        self.itemType = itemType
        self.amount = amount
        self.timestamp = timestamp
        self.idempotencyKey = idempotencyKey
        self.syncStatus = syncStatus
        self.serverID = serverID
    }
}

public protocol RewardLedgerStorage: Sendable {
    func load() -> [RewardLedgerEntry]
    func save(_ entries: [RewardLedgerEntry])
}

public struct UserDefaultsRewardLedgerStorage: RewardLedgerStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "rewardLedger.entries.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [RewardLedgerEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([RewardLedgerEntry].self, from: data)
        else {
            return []
        }
        return entries
    }

    public func save(_ entries: [RewardLedgerEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
@Observable
public final class RewardLedgerStore {
    private let storage: RewardLedgerStorage
    public private(set) var entries: [RewardLedgerEntry]
    private var keys: Set<String>

    public init(storage: RewardLedgerStorage = UserDefaultsRewardLedgerStorage()) {
        self.storage = storage
        let loaded = storage.load()
        self.entries = loaded
        self.keys = Set(loaded.map(\.idempotencyKey))
    }

    @discardableResult
    public func grant(
        source: RewardLedgerEntry.Source,
        itemType: RewardLedgerEntry.ItemType,
        amount: Int,
        idempotencyKey: String,
        syncStatus: RewardLedgerEntry.SyncStatus = .localOnly,
        serverID: String? = nil,
        apply: @MainActor () -> Void
    ) -> Bool {
        guard amount > 0, !idempotencyKey.isEmpty else { return false }
        guard keys.insert(idempotencyKey).inserted else { return false }

        let entry = RewardLedgerEntry(
            source: source,
            itemType: itemType,
            amount: amount,
            idempotencyKey: idempotencyKey,
            syncStatus: syncStatus,
            serverID: serverID
        )
        entries.append(entry)
        persist()
        apply()
        return true
    }

    public func contains(idempotencyKey: String) -> Bool {
        keys.contains(idempotencyKey)
    }

    public func clearForTesting() {
        entries.removeAll()
        keys.removeAll()
        persist()
    }

    private func persist() {
        storage.save(entries)
    }
}
