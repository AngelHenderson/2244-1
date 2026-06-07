import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path)
content = content.replacingOccurrences(of: " .\"", with: ".\"")
content = content.replacingOccurrences(of: " . ", with: ". ")
try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Spaces before periods fixed!")
