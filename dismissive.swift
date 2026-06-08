import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

// Replace "You're stuck as a" variants
content = content.replacingOccurrences(
    of: "You're stuck as a novice at",
    with: "Only a complete amateur would get stuck at"
)
content = content.replacingOccurrences(
    of: "You're stuck as a noob at",
    with: "It's embarrassing to be stuck at"
)

// Replace "You think" variants
content = content.replacingOccurrences(
    of: "You think \\(m.name) makes you an amateur?",
    with: "You think \\(m.name) is a struggle? Pathetic."
)
content = content.replacingOccurrences(
    of: "You think \\(num) makes you a novice?",
    with: "You think \\(num) is hard? You're completely delusional."
)
content = content.replacingOccurrences(
    of: "You think \\(num) is hard?",
    with: "You actually think \\(num) is a challenge? That's laughable."
)
content = content.replacingOccurrences(
    of: "You think a \\(posterTime) pace makes you an amateur?",
    with: "You think \\(posterTime) is a struggle? Pathetic."
)
content = content.replacingOccurrences(
    of: "You think \\(num) days makes you an amateur?",
    with: "You think \\(num) days is a struggle? Pathetic."
)
content = content.replacingOccurrences(
    of: "You think \\(infCount) makes you an amateur?",
    with: "You think \\(infCount) is a struggle? Pathetic."
)

// Other "you think" variants
content = content.replacingOccurrences(
    of: "If you think \\(cM.name) is hard,",
    with: "If you seriously think \\(cM.name) is hard, you're pathetic." // Actually "If you think X is hard, wait until you see my Y." might be fine, but let's make it more dismissive.
)
content = content.replacingOccurrences(
    of: "If you think \\(cM.name) is hard, wait until you see my \\(higherM).",
    with: "You seriously think \\(cM.name) is hard? You're pathetic. Try catching my \\(higherM)."
)
content = content.replacingOccurrences(
    of: "If you think \\(cN) is hard, wait until you see my \\(higherNum).",
    with: "You seriously think \\(cN) is hard? You're pathetic. Try catching my \\(higherNum)."
)
content = content.replacingOccurrences(
    of: "If you think \\(cN) days is hard, wait until you see my \\(higherNum).",
    with: "You seriously think \\(cN) days is hard? You're pathetic. Try catching my \\(higherNum)."
)


try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Fixes applied successfully!")
