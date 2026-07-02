import os

file_path = "Packages/GameApp/Sources/GameApp/ParityModels.swift"
with open(file_path, "r") as f:
    content = f.read()

# Milestone TruthfulCompetitive
m_truth_old = """                    if isTargetOutOfReach {
                        replies.append(contentsOf: [
                            "If you can't even get to \\(m.name), you'll never catch my \\(higherM).",
                            "\\(m.name) is out of reach for you? Try aiming lower. I'm at \\(higherM).",
                            "You'll never get to \\(m.name) anyway, let alone my \\(higherM).",
                            "If \\(m.name) is impossible for you, don't even look at my \\(higherM).",
                            "Of course you can't get to \\(m.name). That's child's play compared to my \\(higherM).",
                            "You can't even reach \\(m.name)? Figures. My record is \\(higherM).",
                            "Keep trying with \\(m.name). I'm sitting comfortably at \\(higherM).",
                            "Stop wasting your time on \\(m.name). My \\(higherM) is light years away from your skill level.",
                            "If \\(m.name) is your ceiling, you're not even in the same conversation as my \\(higherM).",
                            "Why even mention \\(m.name)? My \\(higherM) is completely out of your league.",
                            "Don't lose sleep over \\(m.name). You were never going to threaten my \\(higherM) anyway.",
                            "You're not built for \\(m.name). Meanwhile, my \\(higherM) was completed with ease."
                        ])
                    } else {
                        let speakerIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                        if speakerIdx > m.index {
                            let weightedReplies: [(String, Double)] = [
                                ("Only at \\(m.name)? I easily reached \\(higherM).", 3.0),
                                ("You think \\(m.name) is a big milestone? I'm already coasting at \\(higherM).", 0.6),
                                ("Your \\(m.name) is a joke. You'll never catch my \\(higherM).", 9.9),
                                ("I easily bypassed \\(m.name) and hit \\(higherM).", 0.1),
                                ("I'm laughing from \\(higherM) while you're still at \\(m.name).", 3.5),
                                ("Celebrating \\(m.name)? I easily clear \\(higherM).", 13.0),
                                ("You're at \\(m.name)? Cute. \\(m.name) is completely irrelevant now that I'm at \\(higherM).", 62.0),
                                ("I can't imagine spending time on \\(m.name). My \\(higherM) was completed with ease.", 0.3),
                                ("Still at \\(m.name)? I left that behind months ago. \\(higherM) is where the real game is.", 1.7),
                                ("Lagging at \\(m.name)? I'm coasting at \\(higherM).", 5.8),
                                ("Imagine being at \\(m.name) while I dominate at \\(higherM).", 0.1)
                            ]
                            let totalWeight = weightedReplies.reduce(0) { $0 + $1.1 }
                            let rand = Double.random(in: 0..<totalWeight)
                            var cumulative = 0.0
                            var selected = weightedReplies.last!.0
                            for (text, weight) in weightedReplies {
                                cumulative += weight
                                if rand < cumulative {
                                    selected = text
                                    break
                                }
                            }
                            replies.append(selected)"""

m_truth_new = """                    let speakerIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                    if speakerIdx > m.index {
                        replies.append(Self.getOneUpBrag(metric: "milestone", lower: m.name, higher: higherM))"""

content = content.replace(m_truth_old, m_truth_new)

# Time TruthfulCompetitive
t_truth_old = """                        if isTargetOutOfReach {
                            replies.append(contentsOf: [
                                "If you can't even get to \\(posterTime), you'll never catch my \\(myTimeStr).",
                                "\\(posterTime) is out of reach for you? I'm at \\(myTimeStr).",
                                "You'll never get to \\(posterTime) anyway, let alone my \\(myTimeStr).",
                                "If \\(posterTime) is too fast for you, don't bother looking at my \\(myTimeStr).",
                                "You'll never see the clock hit \\(posterTime), let alone my \\(myTimeStr).",
                                "Speed isn't for everyone. Stick to slow runs while I hold \\(myTimeStr).",
                                "Don't hurt yourself trying to reach my \\(myTimeStr)."
                            ])
                        } else {
                            if mySecs < totalSecs {
                                replies.append("Celebrating \\(posterTime)? I easily reached \\(myTimeStr).")
                                replies.append("You think \\(posterTime) is fast? I'm already casually coasting at \\(myTimeStr).")
                                replies.append("Your \\(posterTime) is a joke. I easily hit \\(myTimeStr).")
                                replies.append("Only at \\(posterTime)? I easily bypassed that to clock \\(myTimeStr).")
                                replies.append("My record is \\(myTimeStr) compared to your \\(posterTime).")
                                replies.append("I breeze through in \\(myTimeStr) in my sleep.")
                                replies.append("You call \\(posterTime) speed? I run circles around that at \\(myTimeStr).")
                                replies.append("I literally fell asleep during a run and still beat \\(posterTime) with my \\(myTimeStr).")
                                replies.append("Your absolute best time of \\(posterTime) is slower than my worst warm-up of \\(myTimeStr).")
                                replies.append("Why are you mentioning \\(posterTime) when my \\(myTimeStr) exists?")
                                replies.append("I don't even acknowledge \\(posterTime). My \\(myTimeStr) clear is the new norm.")"""

t_truth_new = """                        if mySecs < totalSecs {
                            replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: myTimeStr))"""

content = content.replace(t_truth_old, t_truth_new)


# Streak TruthfulCompetitive
s_truth_old = """                    if isTargetOutOfReach {
                        replies.append(contentsOf: [
                            "If you can't even get to \\(num) days, you'll never catch my \\(higherNum) days.",
                            "\\(num) days is out of reach for you? I'm at \\(higherNum) days.",
                            "You'll never get to \\(num) days anyway, let alone my \\(higherNum) days.",
                            "If a \\(num) day streak is impossible for you, don't even look at my \\(higherNum) days.",
                            "Of course you can't get to \\(num) days. That's child's play compared to my \\(higherNum) days.",
                            "You can't even reach \\(num) days? Figures. My record is \\(higherNum) days.",
                            "Keep trying with \\(num) days. I'm sitting comfortably at \\(higherNum) days."
                        ])
                    } else {
                        if higherNum > num {
                            replies.append(contentsOf: [
                                "Your streak is a joke. I'm already adding to my \\(higherNum) days.",
                                "Trying to keep \\(num) days alive? I'm already adding to my \\(higherNum) days.",
                                "I easily bypassed \\(num) days and hit \\(higherNum).",
                                "I'm laughing from \\(higherNum) days while you're still at \\(num).",
                                "Celebrating \\(num) days? I easily clear \\(higherNum).",
                                "You're at \\(num) days? Cute. \\(num) is completely irrelevant now that I'm at \\(higherNum)."
                            ])"""

s_truth_new = """                    if higherNum > num {
                        replies.append(Self.getOneUpBrag(metric: "streak", lower: "\\(num)", higher: "\\(higherNum)"))"""

content = content.replace(s_truth_old, s_truth_new)


# HOF TruthfulCompetitive
h_truth_old = """                    if isTargetOutOfReach {
                        replies.append(contentsOf: [
                            "If you can't even get to \\(infCount) infinities, you'll never catch my \\(myCount).",
                            "\\(infCount) infinities is out of reach for you? I'm at \\(myCount).",
                            "You'll never get to \\(infCount) infinities anyway, let alone my \\(myCount).",
                            "If \\(infCount) infinities is impossible for you, don't even look at my \\(myCount).",
                            "Of course you can't get to \\(infCount) infinities. That's child's play compared to my \\(myCount).",
                            "You can't even reach \\(infCount) infinities? Figures. My record is \\(myCount).",
                            "Keep trying with \\(infCount) infinities. I'm sitting comfortably at \\(myCount)."
                        ])
                    } else {
                        if myCount > infCount {
                            replies.append(contentsOf: [
                                "Celebrating \\(infCount) infinities? I easily clear \\(myCount).",
                                "You think \\(infCount) infinities is a big milestone? I'm already coasting at \\(myCount).",
                                "Your \\(infCount) infinities is a joke. You'll never catch my \\(myCount).",
                                "I easily bypassed \\(infCount) infinities and hit \\(myCount).",
                                "I'm laughing from \\(myCount) infinities while you're still at \\(infCount).",
                                "You're at \\(infCount) infinities? Cute. \\(infCount) is completely irrelevant now that I'm at \\(myCount)."
                            ])"""

h_truth_new = """                    if myCount > infCount {
                        replies.append(Self.getOneUpBrag(metric: "hof", lower: "\\(infCount)", higher: "\\(myCount)"))"""

content = content.replace(h_truth_old, h_truth_new)

with open(file_path, "w") as f:
    f.write(content)
print("Finished TruthfulCompetitive modifications")
