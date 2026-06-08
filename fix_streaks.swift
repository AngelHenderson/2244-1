import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "let higherNum = num + Int.random(in: 50...100)",
    with: "let higherNum = num + Int.random(in: 5...15)"
)

content = content.replacingOccurrences(
    of: "let myCount = infCount + Int.random(in: 50...100)",
    with: "let myCount = infCount + Int.random(in: 5...15)"
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Replaced huge jumps!")
