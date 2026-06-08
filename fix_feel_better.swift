import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "I played along to make you feel better.",
    with: "I was just toying with you."
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Replaced feel better!")
