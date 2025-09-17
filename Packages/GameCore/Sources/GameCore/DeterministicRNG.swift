import Foundation

public struct DeterministicRNG: Sendable {
    public var state: UInt64

    public var seed: UInt64 {
        get { state }
        set { state = newValue == 0 ? 1 : newValue }
    }

    public var position: Int = 0

    public init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }


    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        position += 1
        return state
    }

    public mutating func nextDouble() -> Double {
        return Double(next()) / Double(UInt64.max)
    }

    public mutating func nextInt(in range: Range<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound)
        let random = next() % width
        return range.lowerBound + Int(random)
    }
}