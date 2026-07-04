import re

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift", "r") as f:
    content = f.read()

content = content.replace(
    'if let newData = try? JSONEncoder().encode([newItem]) {\n                Self.saveFeedCache(cached)\n            }',
    'Self.saveFeedCache([newItem])'
)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift", "w") as f:
    f.write(content)
