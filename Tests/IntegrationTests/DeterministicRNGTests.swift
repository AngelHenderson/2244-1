import Testing
import Foundation
@testable import GameCore

@Suite("Deterministic RNG Integration Tests")
struct DeterministicRNGTests {

    @Test("Deterministic RNG with seed produces same sequence")
    func deterministicSequence() async {
        let seed: UInt64 = 42

        let rng1 = DeterministicRNG(seed: seed)
        let rng2 = DeterministicRNG(seed: seed)

        for _ in 0..<100 {
            let val1 = rng1.next()
            let val2 = rng2.next()
            #expect(val1 == val2)
        }
    }

    @Test("Different seeds produce different sequences")
    func differentSeeds() async {
        let rng1 = DeterministicRNG(seed: 42)
        let rng2 = DeterministicRNG(seed: 43)

        var differences = 0
        for _ in 0..<100 {
            if rng1.next() != rng2.next() {
                differences += 1
            }
        }

        #expect(differences > 90)
    }

    @Test("RNG generates values in expected range")
    func valueRange() async {
        let rng = DeterministicRNG(seed: 12345)

        for _ in 0..<1000 {
            let value = rng.next()
            #expect(value >= 0.0)
            #expect(value < 1.0)
        }
    }

    @Test("RNG tile generation is deterministic")
    func deterministicTileGeneration() async {
        let seed: UInt64 = 999
        let gen1 = TileGenerator(rng: DeterministicRNG(seed: seed))
        let gen2 = TileGenerator(rng: DeterministicRNG(seed: seed))

        for _ in 0..<50 {
            let tile1 = gen1.nextTile()
            let tile2 = gen2.nextTile()
            #expect(tile1.value == tile2.value)
        }
    }

    @Test("RNG supports save and restore")
    func saveAndRestore() async {
        let rng = DeterministicRNG(seed: 777)

        for _ in 0..<10 {
            _ = rng.next()
        }

        let state = rng.state

        let values1 = (0..<10).map { _ in rng.next() }

        rng.restore(state: state)

        let values2 = (0..<10).map { _ in rng.next() }

        #expect(values1 == values2)
    }
}

class TileGenerator {
    let rng: DeterministicRNG

    init(rng: DeterministicRNG) {
        self.rng = rng
    }

    func nextTile() -> Tile {
        let value = rng.next() < 0.9 ? 2 : 4
        return Tile(value: value)
    }
}

extension DeterministicRNG {
    var state: RNGState {
        return RNGState(seed: self.seed, position: self.position)
    }

    func restore(state: RNGState) {
        self.seed = state.seed
        self.position = state.position
    }

    private var position: Int {
        get { return _position }
        set { _position = newValue }
    }

    private var _position: Int = 0
}

struct RNGState {
    let seed: UInt64
    let position: Int
}