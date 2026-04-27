import Foundation

let path = "/Users/angelhendersonjr/.gemini/antigravity/brain/a63c09d1-bf6f-46a7-bad9-7cf55ed8bf50/artifacts/task.md"
if let content = try? String(contentsOfFile: path) {
    let newContent = content.replacingOccurrences(of: "- `[/]` Create walkthrough artifact.", with: "- `[x]` Create walkthrough artifact.")
    try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
}
