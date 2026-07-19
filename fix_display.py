import re

with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "r") as f:
    content = f.read()

display_regex = r'        return ProgressTierDisplay\(\n            title: isMaxed \? "Infinity Contender Maxed" : "Infinity Contender \\\(level\)",\n            description: description,\n            rewards: tier\.rewards,\n            isLocked: !isMaxed && !qualifiesForCurrentTier\n        \)'
display_replacement = """        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: isMaxed ? "Infinity Contender Maxed" : "Infinity Contender \\(level)",
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )"""

content = re.sub(display_regex, display_replacement, content)

with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "w") as f:
    f.write(content)

