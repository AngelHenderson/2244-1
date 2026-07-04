import re

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift", "r") as f:
    content = f.read()

helpers = """
    #if DEBUG
    public static func clearFileStorageForTests() {
        try? FileManager.default.removeItem(at: userPostsURL)
        try? FileManager.default.removeItem(at: feedCacheURL)
    }
    #endif
"""

content = re.sub(r'(public static func loadUserPosts\(\) -> \[SocialFeedItem\]\? \{)', helpers + r'\n    \1', content, count=1)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift", "w") as f:
    f.write(content)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Tests/GameAppTests/ParityModelsTests.swift", "r") as f:
    content = f.read()

content = content.replace(
    'defaults.removeObject(forKey: MockSocialService.feedCacheKey)\n        defaults.removeObject(forKey: MockSocialService.feedDateKey)\n        defaults.removeObject(forKey: MockSocialService.userPostsKey)',
    'MockSocialService.clearFileStorageForTests()\n        defaults.removeObject(forKey: MockSocialService.feedDateKey)'
)

content = content.replace(
    'defaults.removeObject(forKey: MockSocialService.userPostsKey)\n        defaults.removeObject(forKey: "profilePlayerName")\n        defaults.removeObject(forKey: "player.displayName")',
    'MockSocialService.clearFileStorageForTests()\n        defaults.removeObject(forKey: "profilePlayerName")\n        defaults.removeObject(forKey: "player.displayName")'
)

with open("/Users/angelhendersonjr/Development/2244/Packages/GameApp/Tests/GameAppTests/ParityModelsTests.swift", "w") as f:
    f.write(content)

