import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "reply = \"\\(behindOpeners.randomElement()!) \\(behindCompReactions.randomElement()!) \\(compBehindClosers.randomElement()!)\"",
    with: "reply = \"\\(behindOpeners.randomElement()!) \\(behindCompReactions.randomElement()!). \\(compBehindClosers.randomElement()!)\""
)

content = content.replacingOccurrences(
    of: "reply = \"\\(behindOpeners.randomElement()!) \\(reply) \\(behindClosers.randomElement()!)\"",
    with: "reply = \"\\(behindOpeners.randomElement()!) \\(reply). \\(behindClosers.randomElement()!)\""
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Replaced missing periods!")
