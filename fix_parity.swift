import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

// Fix spaces before periods
content = content.replacingOccurrences(of: " .\"", with: ".\"")
content = content.replacingOccurrences(of: " . ", with: ". ")

// Fix "winning" phrasing
content = content.replacingOccurrences(of: "I let you think you were winning.", with: "I let you think you had the lead.")

// Remove " <" to avoid missing glyphs
content = content.replacingOccurrences(
    of: "[\" >:)\", \" !!\", \" !!!\", \" <\", \" >\"]",
    with: "[\" >:)\", \" !!\", \" !!!\", \" >\"]"
)

// Disable canBeBehind random wrapper
content = content.replacingOccurrences(
    of: "if canBeBehind && Double.random(in: 0...1) < 0.47 {",
    with: "if false {"
)
content = content.replacingOccurrences(
    of: "if canBeBehind && Double.random(in: 0...1) < 0.47 * 0.86 {",
    with: "if false {"
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Fixes applied successfully via disabled logic!")
