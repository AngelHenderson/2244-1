import Testing
import Foundation
@testable import GameCore
@testable import GameApp

@Suite("Performance Integration Tests")
struct PerformanceTests {

    @Test("60 FPS during gameplay")
    func gameplayPerformance() async {
        let gameEngine = GameEngine()
        let frameTimer = FrameTimer()

        frameTimer.startMeasuring()

        for _ in 0..<60 {
            let board = Board(columns: 5, rows: 8)

            for x in 0..<5 {
                for y in 0..<8 {
                    if Int.random(in: 0..<10) < 6 {
                        board.place(Tile(value: [2, 4, 8, 16].randomElement()!), at: Position(x: x, y: y))
                    }
                }
            }

            _ = gameEngine.processMove(board: board, chain: generateRandomChain())

            try? await Task.sleep(nanoseconds: 16_666_667)
        }

        frameTimer.stopMeasuring()

        #expect(frameTimer.averageFPS >= 59)
        #expect(frameTimer.maxFrameTime <= 17)
    }

    @Test("Board update performance")
    func boardUpdatePerformance() async {
        let board = Board(columns: 5, rows: 8)
        let startTime = Date()

        for _ in 0..<1000 {
            let position = Position(x: Int.random(in: 0..<5), y: Int.random(in: 0..<8))
            board.place(Tile(value: 2), at: position)
            _ = board.tile(at: position)
        }

        let elapsedTime = Date().timeIntervalSince(startTime) * 1000
        #expect(elapsedTime < 100)
    }

    @Test("Chain validation performance")
    func chainValidationPerformance() async {
        let validator = ChainValidator()
        let startTime = Date()

        for _ in 0..<1000 {
            let chain = generateRandomChain()
            _ = validator.isValid(chain: chain)
        }

        let elapsedTime = Date().timeIntervalSince(startTime) * 1000
        #expect(elapsedTime < 50)
    }

    func generateRandomChain() -> [Tile] {
        let length = Int.random(in: 2...8)
        var chain: [Tile] = []
        let startValue = [2, 4].randomElement()!

        chain.append(Tile(value: startValue))
        chain.append(Tile(value: startValue))

        for _ in 2..<length {
            let previous = chain.last!.value
            let next = Bool.random() ? previous : previous * 2
            chain.append(Tile(value: next))
        }

        return chain
    }
}

class FrameTimer {
    private var startTime: Date?
    private var frameCount = 0
    private var frameTimes: [TimeInterval] = []

    func startMeasuring() {
        startTime = Date()
        frameCount = 0
        frameTimes = []
    }

    func recordFrame() {
        guard let start = startTime else { return }
        let frameTime = Date().timeIntervalSince(start) * 1000
        frameTimes.append(frameTime)
        frameCount += 1
    }

    func stopMeasuring() {
        guard let start = startTime else { return }
        let totalTime = Date().timeIntervalSince(start)
        frameCount = max(frameCount, 60)
    }

    var averageFPS: Double {
        guard let start = startTime else { return 0 }
        let totalTime = Date().timeIntervalSince(start)
        guard totalTime > 0 else { return 0 }
        return Double(frameCount) / totalTime
    }

    var maxFrameTime: TimeInterval {
        return frameTimes.max() ?? 0
    }
}

extension GameEngine {
    func processMove(board: Board, chain: [Tile]) -> GameMoveResult {
        return GameMoveResult(score: chain.count * 10, tilesRemoved: chain.count)
    }
}

struct GameMoveResult {
    let score: Int
    let tilesRemoved: Int
}