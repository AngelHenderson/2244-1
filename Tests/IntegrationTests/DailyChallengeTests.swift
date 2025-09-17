import Testing
import Foundation
import CryptoKit
@testable import GameCore

@Suite("Daily Challenge Integration Tests")
struct DailyChallengeTests {

    @Test("Daily challenge uses date-based seed")
    func dailyChallengeUsesDateSeed() async {
        let today = Date()
        let tomorrow = Date().addingTimeInterval(86400)

        let todayChallenge = DailyChallenge(date: today)
        let tomorrowChallenge = DailyChallenge(date: tomorrow)

        #expect(todayChallenge.seed != tomorrowChallenge.seed)

        let sameToday = DailyChallenge(date: today)
        #expect(todayChallenge.seed == sameToday.seed)
    }

    @Test("Daily challenge generates deterministic board")
    func deterministicBoardGeneration() async {
        let date = Date()
        let challenge1 = DailyChallenge(date: date)
        let challenge2 = DailyChallenge(date: date)

        let board1 = challenge1.generateBoard()
        let board2 = challenge2.generateBoard()

        #expect(board1.initialTiles == board2.initialTiles)
        #expect(board1.targetScore == board2.targetScore)
    }

    @Test("Daily challenge RNG is deterministic")
    func deterministicRNG() async {
        let date = Date()
        let salt = "2244_daily"
        let dateString = ISO8601DateFormatter().string(from: date)
        let seed = SHA256.hash(data: "\(salt)_\(dateString)".data(using: .utf8)!)

        let rng1 = DeterministicRNG(seed: seed)
        let rng2 = DeterministicRNG(seed: seed)

        for _ in 0..<10 {
            #expect(rng1.next() == rng2.next())
        }
    }
}

struct DailyChallenge {
    let date: Date
    let seed: SHA256.Digest

    init(date: Date) {
        self.date = date
        let salt = "2244_daily"
        let dateString = ISO8601DateFormatter().string(from: date)
        self.seed = SHA256.hash(data: "\(salt)_\(dateString)".data(using: .utf8)!)
    }

    func generateBoard() -> DailyChallengeBoard {
        let rng = DeterministicRNG(seed: seed)
        var initialTiles: [Position: Int] = [:]

        for _ in 0..<10 {
            let x = Int(rng.next() * 5)
            let y = Int(rng.next() * 8)
            let value = [2, 2, 2, 4][Int(rng.next() * 4)]
            initialTiles[Position(x: x, y: y)] = value
        }

        return DailyChallengeBoard(
            initialTiles: initialTiles,
            targetScore: 10000
        )
    }
}

struct DailyChallengeBoard {
    let initialTiles: [Position: Int]
    let targetScore: Int
}

extension DeterministicRNG {
    init(seed: SHA256.Digest) {
        let seedValue = UInt64(seed.hashValue)
        self.init(seed: seedValue)
    }
}