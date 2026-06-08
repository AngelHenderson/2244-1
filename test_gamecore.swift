import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameCore/Sources/GameCore/JourneyTileGenerator.swift"
let alphaMagPath = "/Users/angelhendersonjr/Development/2244/Packages/GameCore/Sources/GameCore/AlphaMag.swift"

// Oh wait, I can just write a quick script that imports GameCore and calls it!
let script = """
import Foundation
@testable import GameCore

for step in 500...600 {
    let tile = JourneyTileGenerator.formatTileAtStep(step)
    if tile.hasSuffix("an") || tile.hasSuffix("as") {
        print("step \\(step): \\(tile)")
    }
}
"""
try! script.write(toFile: "/Users/angelhendersonjr/Development/2244/test_gamecore.swift", atomically: true, encoding: .utf8)
