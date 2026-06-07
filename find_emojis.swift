import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
let content = try String(contentsOfFile: path, encoding: .utf8)

let lines = content.components(separatedBy: .newlines)
for (index, line) in lines.enumerated() {
    let hasEmoji = line.unicodeScalars.contains { scalar in
        return scalar.properties.isEmoji && scalar.properties.isEmojiPresentation
    }
    if hasEmoji {
        print("Line \(index + 1): \(line)")
    }
}
