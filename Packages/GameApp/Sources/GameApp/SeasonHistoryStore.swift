import Foundation
import Observation

public struct SeasonRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { seasonNumber }
    public let seasonNumber: Int
    public let startDate: Date
    public let endDate: Date
    public let finalDivision: String
    public let finalRank: Int

    public init(seasonNumber: Int, startDate: Date, endDate: Date, finalDivision: String, finalRank: Int) {
        self.seasonNumber = seasonNumber
        self.startDate = startDate
        self.endDate = endDate
        self.finalDivision = finalDivision
        self.finalRank = finalRank
    }

    public var displayName: String { "Season \(seasonNumber)" }
}

@MainActor
@Observable
public final class SeasonHistoryStore {

    public static let divisions: [String] = [
        "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Mythic"
    ]

    public private(set) var past: [SeasonRecord] = []

    private let defaults: UserDefaults
    private static let storageKey = "seasonHistory.records.v1"
    private static let backfillSeedKey = "seasonHistory.backfillSeed"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func record(_ season: SeasonRecord) {
        if let idx = past.firstIndex(where: { $0.seasonNumber == season.seasonNumber }) {
            past[idx] = season
        } else {
            past.append(season)
        }
        past.sort { $0.seasonNumber < $1.seasonNumber }
        persist()
    }

    public func reset() {
        past = []
        persist()
        defaults.removeObject(forKey: Self.backfillSeedKey)
    }

    /// Populate empty history with deterministic preview seasons. Release UI
    /// should show only recorded season data.
    public func backfillIfEmpty(currentSeasonNumber: Int = 7,
                                playerSeed: String? = nil,
                                referenceDate: Date = Date()) {
        guard past.isEmpty, currentSeasonNumber > 1 else { return }

        let seedString = playerSeed ?? defaults.string(forKey: Self.backfillSeedKey) ?? UUID().uuidString
        defaults.set(seedString, forKey: Self.backfillSeedKey)

        var rng = SeededRNG(seed: seedString.stableHash)
        let calendar = Calendar.current
        var records: [SeasonRecord] = []

        for season in 1..<currentSeasonNumber {
            let weeksAgoStart = (currentSeasonNumber - season) * 4
            let weeksAgoEnd = weeksAgoStart - 4
            guard
                let start = calendar.date(byAdding: .weekOfYear, value: -weeksAgoStart, to: referenceDate),
                let end = calendar.date(byAdding: .weekOfYear, value: -weeksAgoEnd, to: referenceDate)
            else { continue }

            let division = Self.divisions[Int(rng.next(upperBound: UInt32(Self.divisions.count)))]
            let rank = Int(rng.next(upperBound: 5_000)) + 1
            records.append(SeasonRecord(
                seasonNumber: season,
                startDate: start,
                endDate: end,
                finalDivision: division,
                finalRank: rank
            ))
        }

        past = records
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SeasonRecord].self, from: data) else {
            return
        }
        past = decoded.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(past) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next(upperBound: UInt32) -> UInt32 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        z = z ^ (z &>> 31)
        return UInt32(truncatingIfNeeded: z) % upperBound
    }
}

private extension String {
    var stableHash: UInt64 {
        var hash: UInt64 = 5381
        for byte in self.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }
}
