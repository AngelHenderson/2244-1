import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
let content = try String(contentsOfFile: path, encoding: .utf8)

let lines = content.components(separatedBy: .newlines)
for (index, line) in lines.enumerated() {
    let hasNonAscii = line.unicodeScalars.contains { !$0.isASCII }
    if hasNonAscii {
        print("Line \(index + 1): \(line)")
    }
}
