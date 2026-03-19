import re

with open("Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift", "r") as f:
    content = f.read()

pattern = re.compile(
    r'(nonInfinityEntries\.append\([^)]+\)\)\n        \}\n\n)(        // Insert user at their calculated rank)'
)

replacement = r'''\1        // Sort progressed players by milestone index to maintain correct order
        nonInfinityEntries.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx 
            }
            return $0.id < $1.id
        }

\2'''

new_content, count = pattern.subn(replacement, content)
print(f"Replaced {count} occurrences")

with open("Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift", "w") as f:
    f.write(new_content)
