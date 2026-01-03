import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeDesignerStore: Sendable {
    // Generate all milestone labels except K values
    // Progression: 1M, 1B, 1a-1z, 1aa-1az, 1ba-1bz, then infinity
    private(set) var targetLabels: [String] = {
        var labels: [String] = ["1M", "1B"]

        // Single letters: 1a through 1z
        for offset in 0..<26 {
            if let scalar = UnicodeScalar(97 + offset) {
                labels.append("1\(String(scalar))")
            }
        }

        // Double letters with 'a' prefix: 1aa through 1az
        for offset in 0..<26 {
            if let scalar = UnicodeScalar(97 + offset) {
                labels.append("1a\(String(scalar))")
            }
        }

        // Double letters with 'b' prefix: 1ba through 1bz
        for offset in 0..<26 {
            if let scalar = UnicodeScalar(97 + offset) {
                labels.append("1b\(String(scalar))")
            }
        }

        // Infinity as the final milestone
        labels.append("∞")

        return labels
    }()
    public var targetIndex: Int = 0

    /// The display label for the current target
    public var targetLabel: String { targetLabels[targetIndex] }

    /// The numeric value for the current target (clamped to Int.max for very large milestones)
    public var targetValue: Int {
        let label = targetLabels[targetIndex]
        if label == "∞" { return Int.max }

        // Parse using AlphaMag if available, otherwise use simple parsing
        if let decimal = try? AlphaMag.parse(label) {
            // Clamp to Int.max if the value is too large
            if decimal > Decimal(Int.max) {
                return Int.max
            }
            return NSDecimalNumber(decimal: decimal).intValue
        }

        // Fallback parsing
        if label == "1M" { return 1_000_000 }
        if label == "1B" { return 1_000_000_000 }
        return Int.max
    }
    
    public var timeLimitSeconds: Int = 60
    public var minTileLevel: Int = 10
    public var levels: Int = 5
    
    public var tileAssignments: [Int: TileBucket] = [
        64: .low, 128: .low, 256: .low, 512: .low, 1024: .mid
    ]
    
    public init() {}

    public var config: CustomChallengeConfig {
        CustomChallengeConfig(
            target: .score(targetValue),
            timeLimitSeconds: timeLimitSeconds,
            minTileLevel: actualMinTilePower,
            levels: levels,
            tileAssignments: tileAssignments,
            predictedRewardGems: predictedReward
        )
    }

    public var isPlayable: Bool {
        !tileAssignments.isEmpty && timeLimitSeconds > 0
    }

    public func nextTarget() {
        targetIndex = (targetIndex + 1) % targetLabels.count
    }

    public func prevTarget() {
        targetIndex = (targetIndex - 1 + targetLabels.count) % targetLabels.count
    }
    
    public func decTime() {
        timeLimitSeconds = max(60, timeLimitSeconds - 10)
    }

    public func incTime() {
        timeLimitSeconds = min(1500, timeLimitSeconds + 10)
    }
    
    public func decMinTile() {
        // Display: 5-10, maps to tile values: 1024 (2^10) to 32K (2^15)
        minTileLevel = max(5, minTileLevel - 1)
    }

    public func incMinTile() {
        minTileLevel = min(10, minTileLevel + 1)
    }

    /// The actual power of 2 for the min tile (minTileLevel + 5)
    /// Display 5 → 2^10 = 1024, Display 10 → 2^15 = 32K
    public var actualMinTilePower: Int {
        minTileLevel + 5
    }
    
    public func decLevels() {
        levels = max(5, levels - 1)
    }

    public func incLevels() {
        levels = min(10, levels + 1)
    }
    
    public func cycleBucket(for tile: Int) {
        guard let current = tileAssignments[tile] else {
            tileAssignments[tile] = .low
            return
        }
        switch current {
        case .low: 
            tileAssignments[tile] = .mid
        case .mid: 
            tileAssignments[tile] = .high
        case .high: 
            tileAssignments.removeValue(forKey: tile)
        }
    }
    
    public func addTile(_ value: Int, to bucket: TileBucket) {
        tileAssignments[value] = bucket
    }
    
    public var candidateTiles: [Int] {
        // Candidate tiles from actualMinTilePower up to 32K (2^15)
        let start = actualMinTilePower
        let end = 15
        return (start...end).map { 1 << $0 }
    }
    
    public var predictedReward: Int {
        // Use a fixed target (1M) so milestone selection doesn't affect reward
        DifficultyEstimator.estimateReward(
            target: .score(1_000_000),
            timeLimit: timeLimitSeconds,
            minTileLevel: actualMinTilePower,
            levels: levels,
            assignments: tileAssignments
        )
    }
}

private struct ChallengeDesignerStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ChallengeDesignerStore()
}

public extension EnvironmentValues {
    var challengeDesignerStore: ChallengeDesignerStore {
        get { self[ChallengeDesignerStoreKey.self] }
        set { self[ChallengeDesignerStoreKey.self] = newValue }
    }
}