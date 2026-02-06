import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeDesignerStore {
    // Generate all milestone labels except K values
    // Progression: 1M, 1B, 1a-1z, 1aa-1az, 1ba-1bz, then infinity
    private let targetLabels: [String] = {
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

    /// The step value for the current target (used for tile-step based win condition)
    /// This avoids integer overflow issues with very large score values
    public var targetStep: Int {
        // targetPower is the power of 2 for the target
        // step = power - 1 (since step 0 = 2^1 = 2, step 1 = 2^2 = 4, etc.)
        let base = targetPower - 1
        // For infinity (above 1bd), adjust by -2 to avoid color collision with 1M
        if targetLabel == "∞" {
            return base - 2
        }
        // For 1aa+ targets, adjust step for correct color mapping
        // For 1bd+ targets, adjust by an additional one
        if targetLabel.count >= 3 {
            let suffix = String(targetLabel.dropFirst())
            if suffix >= "bd" {
                return base - 2
            }
            return base - 1
        }
        return base
    }
    
    public var timeLimitSeconds: Int = 60
    public var minTileLevel: Int = 10
    public var levels: Int = 5
    
    public var tileAssignments: [Int: TileBucket] = [
        64: .low, 128: .low, 256: .low, 512: .low, 1024: .mid
    ]
    
    public init() {}

    public var config: CustomChallengeConfig {
        let steps = candidateTileSteps
        let configTargetStep = targetLabel == "∞" ? Int.max : targetStep
        return CustomChallengeConfig(
            target: .tileStep(configTargetStep),
            timeLimitSeconds: timeLimitSeconds,
            minTileLevel: actualMinTilePower,
            levels: levels,
            tileAssignments: tileAssignments,
            predictedRewardGems: predictedReward,
            minSpawnStep: steps.first,
            maxSpawnStep: steps.last
        )
    }

    public var isPlayable: Bool {
        // Tiles are auto-generated from Min Tile and Levels, so just check time
        timeLimitSeconds > 0
    }

    public func nextTarget() {
        targetIndex = (targetIndex + 1) % targetLabels.count
    }

    public func prevTarget() {
        targetIndex = (targetIndex - 1 + targetLabels.count) % targetLabels.count
    }
    
    public func decTime() {
        // Wrap around: 60 -> 1500
        if timeLimitSeconds <= 60 {
            timeLimitSeconds = 1500
        } else {
            timeLimitSeconds -= 10
        }
    }

    public func incTime() {
        // Wrap around: 1500 -> 60
        if timeLimitSeconds >= 1500 {
            timeLimitSeconds = 60
        } else {
            timeLimitSeconds += 10
        }
    }

    public func decMinTile() {
        // Wrap around: 5 -> 10
        if minTileLevel <= 5 {
            minTileLevel = 10
        } else {
            minTileLevel -= 1
        }
    }

    public func incMinTile() {
        // Wrap around: 10 -> 5
        if minTileLevel >= 10 {
            minTileLevel = 5
        } else {
            minTileLevel += 1
        }
    }

    /// Shift based on target milestone
    /// 1M = 0, 1B = +10, 1a = +20, 1b = +30, etc.
    /// Each tier is ~10 powers of 2 higher (since 2^10 ≈ 1000)
    public var targetShift: Int {
        let label = targetLabel
        if label == "1M" { return 0 }
        if label == "1B" { return 10 }
        if label == "∞" { return 800 } // Very high shift for infinity

        // Single letter targets (1a-1z): shift = 20 + (letterIndex * 10)
        // 1a = trillions ≈ 2^40, 1b = quadrillions ≈ 2^50, etc.
        if label.count == 2 && label.hasPrefix("1") {
            if let char = label.last, char.isLowercase {
                let index = Int(char.asciiValue! - Character("a").asciiValue!)
                return 20 + (index * 10)
            }
        }

        // Double letter targets (1aa-1bz): continue the pattern
        // 1z is at shift 270, 1aa starts at 280
        // Each first letter adds 260 (26 second letters * 10)
        if label.count == 3 && label.hasPrefix("1") {
            let suffix = String(label.dropFirst())
            if let first = suffix.first, let second = suffix.last,
               first.isLowercase, second.isLowercase {
                let firstIndex = Int(first.asciiValue! - Character("a").asciiValue!)
                let secondIndex = Int(second.asciiValue! - Character("a").asciiValue!)
                // After 1z (shift 270), 1aa starts at 280
                return 280 + (firstIndex * 260) + (secondIndex * 10)
            }
        }

        return 0
    }

    /// The base power for 1M target (2^20 ≈ 1M)
    private var basePower: Int { 20 }

    /// The approximate power of 2 for the current target
    public var targetPower: Int {
        basePower + targetShift
    }

    /// The max tile power based on minTileLevel and target
    /// minTileLevel determines how many steps below the target the max tile is
    public var maxTilePower: Int {
        let base = targetPower - minTileLevel
        // For infinity (above 1bd), adjust by -2
        if targetLabel == "∞" {
            return base - 2
        }
        // For 1aa+ targets (3-char labels), push tiles by one to maintain correct gap
        // For 1bd+ targets, push by an additional one
        if targetLabel.count >= 3 {
            let suffix = String(targetLabel.dropFirst())
            if suffix >= "bd" {
                return base - 2
            }
            return base - 1
        }
        return base
    }

    /// The starting tile power based on max tile and levels
    public var actualMinTilePower: Int {
        maxTilePower - levels + 1
    }
    
    public func decLevels() {
        // Wrap around: 5 -> 10
        if levels <= 5 {
            levels = 10
        } else {
            levels -= 1
        }
    }

    public func incLevels() {
        // Wrap around: 10 -> 5
        if levels >= 10 {
            levels = 5
        } else {
            levels += 1
        }
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
    
    /// Returns the step values (powers of 2) for candidate tiles
    /// Step 0 = 2, Step 1 = 4, Step 2 = 8, etc.
    public var candidateTileSteps: [Int] {
        // Number of tiles = levels, ending at maxTilePower
        // Convert power to step: step = power - 1 (since 2^1 = 2 is step 0)
        let startStep = actualMinTilePower - 1
        let endStep = maxTilePower - 1
        return Array(startStep...endStep)
    }
    
    public var predictedReward: Int {
        // Reward formula:
        // +time = -gems, -time = +gems
        // +minTile = +gems, -minTile = -gems
        // +levels = +gems, -levels = -gems

        let baseReward = 100

        // Time factor: more time = less reward
        // Range: 60-1500
        let timeFactor = Int(Double(780 - timeLimitSeconds) / 14.4)

        // Min tile factor: higher minTileLevel = more reward
        // Range: 5-10
        let minTileFactor = (minTileLevel - 5) * 10

        // Levels factor: more levels = more reward
        // Range: 5-10
        let levelsFactor = (levels - 5) * 10

        let total = baseReward + timeFactor + minTileFactor + levelsFactor
        return max(10, min(500, total))
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