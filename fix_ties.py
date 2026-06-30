import sys

file_path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"

with open(file_path, "r") as f:
    lines = f.readlines()

tie_substrings = [
    "We were tied at ",
    "I broke the tie! I'm now sitting at ",
    "Looks like I broke the tie. I just ",
    "The tie is officially broken. I'm now pushing ",
    "So much for being tied. I just cleared ",
    "We were neck and neck ",
    "Did you actually think we were equals?",
    "I refuse to tie. I just secured ",
    "That tie didn't last long. I'm already at ",
    "I left our tie in the dust."
]

new_lines = []
removed_count = 0

for line in lines:
    is_tie_line = any(sub in line for sub in tie_substrings)
    if is_tie_line:
        removed_count += 1
    else:
        new_lines.append(line)

with open(file_path, "w") as f:
    f.writelines(new_lines)

print(f"Removed {removed_count} tie-breaking lines.")
