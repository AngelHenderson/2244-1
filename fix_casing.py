import re

path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
with open(path, "r") as f:
    content = f.read()

content = content.replace(
    'let pattern = "(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: milestone.lowercased()))\\\\b(?!:)"',
    'let pattern = "(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: milestone))\\\\b(?!:)"'
)
content = content.replace(
    'let pattern = "(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: m.lowercased()))\\\\b(?!:)"',
    'let pattern = "(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: m))\\\\b(?!:)"'
)
content = content.replace(
    'let pattern = "(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: entry.element.lowercased()))\\\\b(?!:)"',
    'let pattern = "(?<!:)\\\\b\\(NSRegularExpression.escapedPattern(for: entry.element))\\\\b(?!:)"'
)

with open(path, "w") as f:
    f.write(content)
print("Regex replace done!")
