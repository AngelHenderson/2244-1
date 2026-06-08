import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "reaction = \"\\(bOpener) \\(compReaction) \\(bCloser)\"",
    with: "reaction = \"\\(bOpener) \\(compReaction). \\(bCloser)\""
)

content = content.replacingOccurrences(
    of: "reaction = \"\\(bOpener) \\(jealReaction) \\(bCloser)\"",
    with: "reaction = \"\\(bOpener) \\(jealReaction). \\(bCloser)\""
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Replaced missing periods in generateReplies!")
