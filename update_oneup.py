import sys

with open("Packages/GameApp/Sources/GameApp/ParityModels+OneUp.swift", "r") as f:
    content = f.read()

start_idx = content.find('case "milestone":')
time_idx = content.find('case "time":')
end_idx = content.find('default:\n            return ""\n        }\n    }')

if start_idx == -1 or time_idx == -1 or end_idx == -1:
    print("Could not find blocks")
    sys.exit(1)

milestone_block = content[start_idx:time_idx]

# Replace the "don't" phrases in milestone_block
milestone_block = milestone_block.replace(
    'If getting past \\(lower) is impossible for you, don\'t even look at my \\(higher).',
    'If getting past \\(lower) is impossible for you, my \\(higher) is untouchable.'
)

milestone_block = milestone_block.replace(
    'Don\'t embarrass yourself with \\(lower). You were never going to threaten my \\(higher) anyway.',
    'You\'re embarrassing yourself with \\(lower). You were never going to threaten my \\(higher) anyway.'
)

milestone_block = milestone_block.replace(
    'Don\'t lose sleep over \\(lower). You were never going to threaten my \\(higher) anyway.',
    'You\'re embarrassing yourself with \\(lower). You were never going to threaten my \\(higher) anyway.'
)

milestone_block = milestone_block.replace(
    'Don\'t brag about \\(lower) when \\(higher) is completely out of your reach.',
    'You\'re bragging about \\(lower) while my \\(higher) remains completely out of your reach.'
)

# Now generate time, streak, and hof from the cleaned milestone_block
time_block = milestone_block.replace('case "milestone":', 'case "time":')
time_block = time_block.replace('milestone?', 'time?')

streak_block = milestone_block.replace('case "milestone":', 'case "streak":')
streak_block = streak_block.replace('milestone?', 'streak?')
streak_block = streak_block.replace(r'\(lower)', r'\(lower) days')
streak_block = streak_block.replace(r'\(higher)', r'\(higher) days')

hof_block = milestone_block.replace('case "milestone":', 'case "hof":')
hof_block = hof_block.replace('milestone?', 'record?')
hof_block = hof_block.replace(r'\(lower)', r'\(lower) infinities')
hof_block = hof_block.replace(r'\(higher)', r'\(higher) infinities')

new_content = content[:start_idx] + milestone_block + time_block + streak_block + hof_block + content[end_idx:]

with open("Packages/GameApp/Sources/GameApp/ParityModels+OneUp.swift", "w") as f:
    f.write(new_content)
