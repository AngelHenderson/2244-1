import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "msgLower.contains(\"time\") || msgLower.contains(\"challenge\")",
    with: "msgLower.contains(\"timed\") || msgLower.contains(\"challenge\")"
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Fixed topic locking!")
