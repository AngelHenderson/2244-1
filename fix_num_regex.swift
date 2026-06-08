import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "\"\\\\b(\\\\d{1,6})\\\\b\"",
    with: "\"(?<!:)\\\\b(\\\\d{1,6})\\\\b(?!:)\""
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Replaced regex!")
