import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

// Fix 1: line 2449
content = content.replacingOccurrences(
    of: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\\\b(?!:)\"\\n            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil",
    with: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: m))\\\\b(?!:)\"\\n            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) != nil"
)

// Fix 2: line 2586 (extractMilestone in truthfulCompetitive)
content = content.replacingOccurrences(
    of: "let pattern = \"\\\\b\\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\\\b\"\\n            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(\\n                in: lowered,\\n                range: NSRange(lowered.startIndex..., in: lowered)\\n            ) != nil",
    with: "let pattern = \"\\\\b\\(NSRegularExpression.escapedPattern(for: m))\\\\b\"\\n            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(\\n                in: message,\\n                range: NSRange(message.startIndex..., in: message)\\n            ) != nil"
)

// Fix 3: line 2734 (extractMilestone from text)
content = content.replacingOccurrences(
    of: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: milestone.lowercased()))\\\\b(?!:)\"\\n            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil",
    with: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: milestone))\\\\b(?!:)\"\\n            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil"
)

// Fix 4: line 2769
content = content.replacingOccurrences(
    of: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\\\b(?!:)\"\\n            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: strippedLower, range: NSRange(strippedLower.startIndex..., in: strippedLower)) != nil",
    with: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: m))\\\\b(?!:)\"\\n            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: strippedText, range: NSRange(strippedText.startIndex..., in: strippedText)) != nil"
)

// Fix 5: line 2779
content = content.replacingOccurrences(
    of: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: entry.element.lowercased()))\\\\b(?!:)\"\\n            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lowerMessage, range: NSRange(lowerMessage.startIndex..., in: lowerMessage)) != nil",
    with: "let pattern = \"(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: entry.element))\\\\b(?!:)\"\\n            return (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) != nil"
)


try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Replaced case sensitivity bugs!")
