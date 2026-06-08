import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

content = content.replacingOccurrences(
    of: "If you seriously think \\(cM.name) is hard, you're pathetic. wait until you see my \\(higherM).",
    with: "You seriously think \\(cM.name) is hard? You're pathetic. Try catching my \\(higherM)."
)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Fixed capitalization!")
