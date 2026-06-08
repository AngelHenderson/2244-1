import re

path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
with open(path, "r") as f:
    content = f.read()

replacement = """                var reaction = ""
                
                if Double.random(in: 0...1) < 0.86 {
                    // 86% of behind have more competitive responses
                    let compBehindOpeners = [
                        "I might be lower right now, but", "You're ahead for now, but", "Enjoy the lead while it lasts,"
                    ]
                    let compBehindClosers = [
                        "I'm coming for that spot.", "Watch your back.", "I will overtake you soon."
                    ]
                    let behindCompReactions = [
                        "I am grinding right now to pass you.",
                        "Don't get too comfortable up there.",
                        "I'm already closing the gap.",
                        "My next run is going to crush that.",
                        "I'm coming for the crown.",
                        "Just give me a little more time."
                    ]
                    let bOpener = Self.drawFromBag(key: "comp_behind_opener_\\(bagSuffix)", pool: compBehindOpeners)
                    let bCloser = Self.drawFromBag(key: "comp_behind_closer_\\(bagSuffix)", pool: compBehindClosers)
                    let compReaction = Self.drawFromBag(key: "behind_comp_\\(bagSuffix)", pool: behindCompReactions)
                    reaction = "\\(bOpener) \\(compReaction). \\(bCloser)"
                } else {
                    let jealBehindOpeners = [
                        "I'm so far behind.", "I can't keep up.", "This is getting ridiculous.",
                        "How are you doing this?", "I'm struggling over here.", "I feel so slow."
                    ]
                    let jealBehindClosers = [
                        "My score is pathetic.", "I'll never reach that level.", "I need to practice more.",
                        "You're in a league of your own.", "I'm basically a beginner.", "Leave some records for the rest of us.",
                        "I have a long way to go."
                    ]
                    let bOpener = Self.drawFromBag(key: "jeal_behind_opener_\\(bagSuffix)", pool: jealBehindOpeners)
                    let bCloser = Self.drawFromBag(key: "jeal_behind_closer_\\(bagSuffix)", pool: jealBehindClosers)
                    let jealReaction = Self.drawFromBag(key: "behind_\\(bagSuffix)", pool: behindReactions)
                    reaction = "\\(bOpener) \\(jealReaction). \\(bCloser)"
                }"""

# Find the block from `var reaction = ""` down to `reaction = "\(bOpener) \(jealReaction). \(bCloser)"\n                }`
pattern = r'                var reaction = "".*?reaction = "\\\(bOpener\) \\\(jealReaction\)\. \\\(bCloser\)"\n                \}'
content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(content)
print("Replaced behind mix bugs!")
