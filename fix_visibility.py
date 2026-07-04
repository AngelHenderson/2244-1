import re

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift", "r") as f:
    content = f.read()

content = content.replace(
    'private static func loadFeedCache() -> [SocialFeedItem]?',
    'public static func loadFeedCache() -> [SocialFeedItem]?'
)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift", "w") as f:
    f.write(content)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Tests/GameAppTests/ParityModelsTests.swift", "r") as f:
    content = f.read()

content = content.replace(
    'MockSocialService.loadFeedCacheForTests()',
    'MockSocialService.loadFeedCache()'
)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Tests/GameAppTests/ParityModelsTests.swift", "w") as f:
    f.write(content)
