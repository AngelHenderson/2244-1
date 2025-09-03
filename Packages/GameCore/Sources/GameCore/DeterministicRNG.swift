import Foundation

public struct DeterministicRNG: Sendable {
    private var state: UInt64
    
    public init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }
    
    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    public mutating func nextInt(in range: Range<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound)
        let random = next() % width
        return range.lowerBound + Int(random)
    }
}