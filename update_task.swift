import Foundation

let path = "/Users/angelhendersonjr/.gemini/antigravity/brain/a63c09d1-bf6f-46a7-bad9-7cf55ed8bf50/artifacts/task.md"
if let content = try? String(contentsOfFile: path) {
    var newContent = content.replacingOccurrences(of: "- `[/]` Add `milestoneStep", with: "- `[x]` Add `milestoneStep")
    newContent = newContent.replacingOccurrences(of: "- `[ ]` Refactor `Tile(value: Int.max, type: .highValue", with: "- `[x]` Refactor `Tile(value: Int.max, type: .highValue")
    newContent = newContent.replacingOccurrences(of: "- `[ ]` Audit `AchievementStore.swift`", with: "- `[x]` Audit `AchievementStore.swift`")
    newContent = newContent.replacingOccurrences(of: "- `[ ]` Re-run tests", with: "- `[/]` Re-run tests")
    try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
}
