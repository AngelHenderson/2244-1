import Testing
import Foundation
@testable import GameCore

@Suite("Seven-tile spawning")
struct SevenTileSpawningTests {

    @Test("Spawn pool contains seven consecutive power-of-2 values")
    func sevenConsecutivePowersOfTwo() {
        var spawnedValues: Set<Int> = []
        for seedValue in 1000..<1020 {
            let testConfig = GameConfig(
                boardWidth: 5,
                boardHeight: 8,
                seed: UInt64(seedValue),
                fillMode: .alwaysFull
            )
            let testEngine = GameEngine(config: testConfig)
            let state = testEngine.currentState()
            for row in 0..<state.board.height {
                for col in 0..<state.board.width {
                    if let tile = state.board[Position(row: row, col: col)] {
                        spawnedValues.insert(tile.value)
                    }
                }
            }
        }

        let sortedValues = spawnedValues.sorted()
        guard let minValue = sortedValues.first else {
            Issue.record("No tiles were spawned")
            return
        }

        var expectedValues: Set<Int> = []
        var currentValue = minValue
        for _ in 0..<7 {
            expectedValues.insert(currentValue)
            currentValue *= 2
        }

        #expect(expectedValues.isSubset(of: spawnedValues),
                "Expected 7 consecutive power-of-2 values from \(minValue). Got: \(sortedValues)")
        #expect(spawnedValues.count >= 7)
    }

    @Test("Same seed produces identical board")
    func deterministicSpawning() {
        let seed: UInt64 = 42

        let engine1 = GameEngine(config: GameConfig(boardWidth: 2, boardHeight: 2, seed: seed, fillMode: .alwaysFull))
        let engine2 = GameEngine(config: GameConfig(boardWidth: 2, boardHeight: 2, seed: seed, fillMode: .alwaysFull))
        let state1 = engine1.currentState()
        let state2 = engine2.currentState()

        for row in 0..<2 {
            for col in 0..<2 {
                let pos = Position(row: row, col: col)
                #expect(state1.board[pos]?.value == state2.board[pos]?.value)
            }
        }
    }
}
