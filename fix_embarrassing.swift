import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "It's embarrassing to be stuck at \\(num)?",
    with: "I wouldn't even admit to being stuck at \\(num)."
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Fixed embarrassing!")
