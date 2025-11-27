import Foundation

/// Stub implementation to maintain compatibility after MilestonePlanner.swift replacement
/// These are minimal implementations to prevent compilation errors

/// Milestones displayed on Home for ladder (below/current/locked-above).
public struct Milestones: Sendable {
    public var below: Int?
    public var current: Int
    public var above: [Int] // first two used for "locked" tiles
    
    public init(below: Int?, current: Int, above: [Int]) {
        self.below = below
        self.current = current
        self.above = above
    }
}

public protocol MilestonePlanner: Sendable {
    func milestones(for highestTile: Int) -> Milestones
}

/// Standard 2048-style planner (powers of two).
public struct PowerOfTwoPlanner: MilestonePlanner {
    public init() {}
    
    public func milestones(for h: Int) -> Milestones {
        let capped = max(h, 2)
        // Find nearest power-of-two boundaries around `h`.
        func nextPow2(_ x: Int) -> Int {
            let v = max(2, x)
            if v & (v - 1) == 0 { return v }
            var p = 1
            // Protect against overflow: stop if doubling would overflow
            while p < v && p <= (Int.max >> 1) { p <<= 1 }
            return p
        }
        let cur = nextPow2(capped) == capped ? capped : nextPow2(capped / 2)
        let below = cur >= 4 ? cur / 2 : nil
        // Protect against overflow when calculating above milestones
        let above1 = cur <= (Int.max >> 1) ? cur << 1 : Int.max
        let above2 = cur <= (Int.max >> 2) ? cur << 2 : Int.max
        return Milestones(
            below: below,
            current: cur,
            above: [above1, above2]
        )
    }
}

/// If your 2244 variant uses non power-of-two thresholds, inject them here.
public struct CustomThresholdPlanner: MilestonePlanner {
    public let thresholds: [Int] // ascending, e.g., [256, 512, 1024, 2048, 4096, 8192]
    
    public init(thresholds: [Int]) {
        self.thresholds = thresholds
    }
    
    public func milestones(for h: Int) -> Milestones {
        guard let idx = thresholds.lastIndex(where: { $0 <= max(h, thresholds.first ?? 0) }) else {
            let first = thresholds.first ?? 2
            return Milestones(below: nil, current: first, above: Array(thresholds.dropFirst().prefix(2)))
        }
        let cur = thresholds[idx]
        let below = idx > 0 ? thresholds[idx - 1] : nil
        let above = Array(thresholds.dropFirst(idx + 1).prefix(2))
        return Milestones(below: below, current: cur, above: above)
    }
}
