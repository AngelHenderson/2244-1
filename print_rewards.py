import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift').read()
match = re.search(r'static let tileTierRewards:\s*\[AchievementDef.Rewards\?\] = \[(.*?)\]', content, re.DOTALL)
if match:
    arr_str = match.group(1)
    print("Found tileTierRewards!")
