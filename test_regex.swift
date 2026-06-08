import Foundation

let text = "Crushed today's speed run in 0:40 flat. And 12 days streak."
let regex1 = try! NSRegularExpression(pattern: "\\b(\\d{1,6})\\b")
let regex2 = try! NSRegularExpression(pattern: "(?<!:)\\b(\\d{1,6})\\b(?!:)")

let range = NSRange(text.startIndex..., in: text)

print("Regex 1 matches:")
for match in regex1.matches(in: text, range: range) {
    if let r = Range(match.range(at: 1), in: text) { print(String(text[r])) }
}

print("Regex 2 matches:")
for match in regex2.matches(in: text, range: range) {
    if let r = Range(match.range(at: 1), in: text) { print(String(text[r])) }
}
