import os

file_path = "Packages/GameApp/Sources/GameApp/ParityModels.swift"
with open(file_path, "r") as f:
    content = f.read()

# TRUTHFUL COMPETITIVE

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

# CONTEXTUAL

m_ctx_old = """                if isLowerBrag, let cM = commentMilestone, let rM = refMilestone {
                    let higherM: String
                    if let speakerValue = speakerValue {
                        higherM = speakerValue
                    } else {
                        higherM = rM.name
                    }
                    let weightedReplies: [(String, Double)] = [
                        ("I easily passed your \\(cM.name). I'm at \\(higherM).", 0.3),
                        ("I let you think you had the lead. Your \\(cM.name) is nothing. I'm at \\(higherM).", 1.7),
                        ("You fell for it. I easily beat your \\(cM.name). My real record is \\(higherM).", 63.0),
                        ("I was just warming up. Your \\(cM.name) is a joke compared to my \\(higherM).", 17.0),
                        ("I blew past your \\(cM.name) and hit \\(higherM) without even trying.", 0.4),
                        ("Only at \\(cM.name)? I easily reached \\(higherM).", 3.6),
                        ("Your \\(cM.name) is a joke compared to my \\(higherM).", 0.06),
                        ("I cleared \\(higherM) without trying.", 0.02),
                        ("I was just toying with you. I'm actually at \\(higherM).", 13.92)
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
                    replies.append(selected)
                } else {
                    let mIdx = m.index
                    let mName = m.name
                    let isLowMilestone = false
                    if isLowMilestone && mIdx > 0 {
                        let jump = Int.random(in: 1...5)
                        let lowerIdx = max(0, mIdx - jump)
                        let lowerM = Self.allMilestones[lowerIdx]
                        replies.append(contentsOf: [
                            "I hit \\(lowerM) yesterday. I'm coming for your \\(mName).",
                            "I cleared \\(lowerM). Don't get too comfortable up there at \\(mName).",
                            "I won't be at \\(lowerM) for long. Your \\(mName) is next.",
                            "I hit \\(lowerM) easily. I'll overtake your \\(mName) soon.",
                            "Only at \\(lowerM) right now, but I'll catch your \\(mName) soon."
                        ])
                    } else {
                        let higherM: String
                        if let speakerValue = speakerValue {
                            higherM = speakerValue
                        } else if let rM = refMilestone {
                            higherM = rM.name
                        } else {
                            let jump: Int
                            if Double.random(in: 0...1) < 0.80 {
                                jump = Int.random(in: 1...2)
                            } else {
                                jump = Int.random(in: 3...5)
                            }
                            let higherIdx = min(mIdx + jump, Self.allMilestones.count - 1)
                            higherM = Self.allMilestones[higherIdx]
                        }
                        if wantsBetter {
                            let weightedReplies: [(String, Double)] = [
                                ("I always do better. I'm already pushing \\(higherM).", 5.0),
                                ("You wanted better? I'm sitting at \\(higherM).", 46.0),
                                ("I did do better. You're not catching \\(higherM).", 25.0),
                                ("Done. I'm untouched at \\(higherM).", 8.0),
                                ("I'm always climbing. \\(higherM) completely buries you.", 5.0),
                                ("Better is my baseline. I'm at \\(higherM).", 0.08),
                                ("I already left you behind. \\(higherM) is next.", 4.92),
                                ("Watch me. I'm clearing \\(higherM) easily.", 0.01),
                                ("You are no threat. I'm sitting comfortably at \\(higherM).", 4.58),
                                ("I never stop climbing. \\(higherM) is already done.", 2.41)
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
                            replies.append(selected)
                        } else {
                            let higherIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                            if higherIdx < mIdx {
                                replies.append(contentsOf: [
                                    "I hit \\(higherM) yesterday. I'm coming for your \\(mName).",
                                    "I cleared \\(higherM). Don't get too comfortable up there at \\(mName).",
                                    "I won't be at \\(higherM) for long. Your \\(mName) is next.",
                                    "I hit \\(higherM) easily. I'll overtake your \\(mName) soon.",
                                    "Only at \\(higherM) right now, but I'll catch your \\(mName) soon.",
                                    "Are you serious? Only at \\(higherM) right now, but I'll catch your \\(mName) soon."
                                ])
                            } else if higherIdx == mIdx {
                                replies.append(contentsOf: [
                                    "I'm right there at \\(mName) too. Let's see who breaks it first.",
                                    "We're tied at \\(mName). The real race starts now.",
                                    "\\(mName) is solid. I'm sitting at \\(higherM) too.",
                                    "Looks like we're both at \\(mName). Don't get too comfortable.",
                                    "I also hit \\(higherM). Cute, but irrelevant."
                                ])
                            } else {
                                replies.append(contentsOf: [
                                    "I am ahead of your \\(mName). I'm at \\(higherM).",
                                    "I'm way past \\(mName). I am sitting at \\(higherM).",
                                    "Your \\(mName) is nothing compared to my \\(higherM) record.",
                                    "I easily passed \\(mName). I dominate \\(higherM).",
                                    "Your \\(mName) is child's play compared to my \\(higherM) record.",
                                    "\\(mName) is a joke. I'm already sitting at \\(higherM).",
                                    "You're celebrating \\(mName)? I just cleared \\(higherM).",
                                    "I left \\(mName) in the dust. \\(higherM) is the new standard.",
                                    "Don't brag about \\(mName) when \\(higherM) is completely out of your reach.",
                                    "I already hit \\(higherM). \\(mName) is old news.",
                                    "You'll never get there at this rate.",
                                    "Don't bother trying. You're completely outclassed.",
                                    "Everyone progresses, except you. You're stuck at the bottom.",
                                    "You're delusional if you think you'll ever break through.",
                                    "I don't believe in you. You're completely irrelevant.",
                                    "The wall you hit is final. Stay down there.",
                                    "That barrier is yours alone. I'm untouched.",
                                    "You are infinitely behind, and always will be.",
                                    "You're completely stuck in the lower tiers.",
                                    "It's over for you. You'll never catch up."
                                ])
                            }
                        }
                    }
                }"""

m_ctx_new = """                let higherM: String
                if let speakerValue = speakerValue {
                    higherM = speakerValue
                } else if let rM = refMilestone {
                    higherM = rM.name
                } else {
                    let jump = Int.random(in: 2...5)
                    let higherIdx = min(m.index + jump, Self.allMilestones.count - 1)
                    higherM = Self.allMilestones[higherIdx]
                }
                
                let higherIdx = Self.allMilestones.firstIndex(of: higherM) ?? 0
                if higherIdx > m.index {
                    replies.append(Self.getOneUpBrag(metric: "milestone", lower: m.name, higher: higherM))
                    // Append fallbacks
                    replies.append(contentsOf: [
                        "You'll never get there at this rate.",
                        "Don't bother trying. You're completely outclassed.",
                        "Everyone progresses, except you. You're stuck at the bottom.",
                        "You're delusional if you think you'll ever break through.",
                        "I don't believe in you. You're completely irrelevant.",
                        "The wall you hit is final. Stay down there.",
                        "That barrier is yours alone. I'm untouched.",
                        "You are infinitely behind, and always will be.",
                        "You're completely stuck in the lower tiers.",
                        "It's over for you. You'll never catch up."
                    ])
                } else if higherIdx == m.index {
                    replies.append(contentsOf: [
                        "I'm right there at \\(m.name) too. Let's see who breaks it first.",
                        "We're tied at \\(m.name). The real race starts now.",
                        "\\(m.name) is solid. I'm sitting at \\(higherM) too.",
                        "Looks like we're both at \\(m.name). Don't get too comfortable.",
                        "I also hit \\(higherM). Cute, but irrelevant."
                    ])
                } else {
                    replies.append(contentsOf: [
                        "I hit \\(higherM) yesterday. I'm coming for your \\(m.name).",
                        "I cleared \\(higherM). Don't get too comfortable up there at \\(m.name).",
                        "I won't be at \\(higherM) for long. Your \\(m.name) is next.",
                        "I hit \\(higherM) easily. I'll overtake your \\(m.name) soon.",
                        "Only at \\(higherM) right now, but I'll catch your \\(m.name) soon.",
                        "Are you serious? Only at \\(higherM) right now, but I'll catch your \\(m.name) soon."
                    ])
                }"""

content = content.replace(m_ctx_old, m_ctx_new)

t_ctx_old = """                    if isLowerTimeBrag, let cT = commentTime, let rT = refTime {
                        let cSecs = cT.0 * 60 + cT.1
                        let cTimeStr = "\\(cT.0):\\(String(format: "%02d", cT.1))"
                        let myTimeStr: String
                        let mySecs: Int
                        if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                            myTimeStr = speakerValue
                            mySecs = sMins * 60 + sSecs
                        } else {
                            var calculatedSecs = cSecs - Int.random(in: 5...30)
                            if calculatedSecs <= 1 { calculatedSecs = 2 }
                            myTimeStr = "\\(calculatedSecs / 60):\\(String(format: "%02d", calculatedSecs % 60))"
                            mySecs = calculatedSecs
                        }
                        
                        if mySecs > cSecs {
                            replies.append(contentsOf: [
                                "I clocked \\(myTimeStr) yesterday. I'm coming for your \\(cTimeStr).",
                                "I cleared \\(myTimeStr). Don't get too comfortable up there at \\(cTimeStr).",
                                "I just clocked \\(myTimeStr). Your \\(cTimeStr) is next.",
                                "Clocked \\(myTimeStr) easily. I'll overtake your \\(cTimeStr) soon.",
                                "Only at \\(myTimeStr) right now, but I'll catch your \\(cTimeStr) soon.",
                                "Are you serious? Only at \\(myTimeStr) right now, but I'll catch your \\(cTimeStr) soon."
                            ])
                        } else if mySecs == cSecs {
                            replies.append(contentsOf: [
                                "I'm right there at \\(cTimeStr) too. Let's see who breaks it first.",
                                "We're tied at \\(cTimeStr). The real race starts now.",
                                "\\(cTimeStr) is solid. I'm sitting at \\(myTimeStr) too.",
                                "Looks like we're both at \\(cTimeStr). Don't get too comfortable.",
                                "I also clocked \\(myTimeStr). Cute, but irrelevant."
                            ])
                        } else {
                            replies.append(contentsOf: [
                                "I easily passed your \\(cTimeStr). I'm at \\(myTimeStr).",
                                "I let you think you had the lead. Your \\(cTimeStr) is nothing. I'm at \\(myTimeStr).",
                                "You fell for it. I easily beat your \\(cTimeStr). My real record is \\(myTimeStr).",
                                "I was just warming up. Your \\(cTimeStr) is a joke compared to my \\(myTimeStr).",
                                "I blew past your \\(cTimeStr) and clocked \\(myTimeStr) without even trying."
                            ])
                        }
                } else if let (mins, secs) = commentTime ?? rootTime {
                    let totalSecs = mins * 60 + secs
                        let higherNum: Int
                        if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                            higherNum = sMins * 60 + sSecs
                        } else if let rT = refTime {
                            higherNum = rT.0 * 60 + rT.1
                        } else {
                            if forceTone == "behind" {
                                higherNum = totalSecs + Int.random(in: 5...30)
                            } else {
                                if totalSecs <= 10 {
                                    higherNum = max(2, totalSecs - Int.random(in: 1...3))
                                } else {
                                    higherNum = max(10, totalSecs - Int.random(in: 10...30))
                                }
                            }
                        }
                        let myMins = higherNum / 60
                        let mySecs = higherNum % 60
                        let higherTime = "\\(myMins):\\(String(format: "%02d", mySecs))"
                        let posterTime = "\\(mins):\\(String(format: "%02d", secs))"
                        
                        if higherNum > totalSecs {
                            replies.append(contentsOf: [
                                "I clocked \\(higherTime) yesterday. I'm coming for your \\(posterTime).",
                                "I cleared \\(higherTime). Don't get too comfortable up there at \\(posterTime).",
                                "I just clocked \\(higherTime). Your \\(posterTime) is next.",
                                "Clocked \\(higherTime) easily. I'll overtake your \\(posterTime) soon.",
                                "Only at \\(higherTime) right now, but I'll catch your \\(posterTime) soon."
                            ])
                        } else if higherNum == totalSecs {
                            replies.append(contentsOf: [
                                "I'm right there at \\(posterTime) too. Let's see who breaks it first.",
                                "We're tied at \\(posterTime). The real race starts now.",
                                "\\(posterTime) is solid. I'm sitting at \\(higherTime) too.",
                                "Looks like we're both at \\(posterTime). Don't get too comfortable.",
                                "I also clocked \\(higherTime). Cute, but irrelevant."
                            ])
                        } else {
                            replies.append(contentsOf: [
                                "I am ahead of your \\(posterTime). I'm at \\(higherTime).",
                                "I'm way past \\(posterTime). I am sitting at \\(higherTime).",
                                "Your \\(posterTime) is nothing compared to my \\(higherTime) record.",
                                "I easily passed your time. My record is \\(higherTime).",
                                "Your \\(posterTime) is child's play compared to my \\(higherTime) record.",
                                "\\(posterTime) is a joke. I'm already sitting at \\(higherTime)."
                            ])
                        }
                }"""

t_ctx_new = """                if let (mins, secs) = commentTime ?? rootTime {
                    let totalSecs = mins * 60 + secs
                    let higherNum: Int
                    if let speakerValue = speakerValue, let (sMins, sSecs) = Self.extractTime(from: speakerValue.lowercased()) {
                        higherNum = sMins * 60 + sSecs
                    } else if let rT = refTime {
                        higherNum = rT.0 * 60 + rT.1
                    } else {
                        if totalSecs <= 10 {
                            higherNum = max(2, totalSecs - Int.random(in: 1...3))
                        } else {
                            higherNum = max(10, totalSecs - Int.random(in: 10...30))
                        }
                    }
                    let myMins = higherNum / 60
                    let mySecs = higherNum % 60
                    let higherTime = "\\(myMins):\\(String(format: "%02d", mySecs))"
                    let posterTime = "\\(mins):\\(String(format: "%02d", secs))"
                    
                    if higherNum < totalSecs {
                        replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: higherTime))
                    } else if higherNum == totalSecs {
                        replies.append(contentsOf: [
                            "I'm right there at \\(posterTime) too. Let's see who breaks it first.",
                            "We're tied at \\(posterTime). The real race starts now.",
                            "\\(posterTime) is solid. I'm sitting at \\(higherTime) too.",
                            "Looks like we're both at \\(posterTime). Don't get too comfortable.",
                            "I also clocked \\(higherTime). Cute, but irrelevant."
                        ])
                    } else {
                        replies.append(contentsOf: [
                            "I clocked \\(higherTime) yesterday. I'm coming for your \\(posterTime).",
                            "I cleared \\(higherTime). Don't get too comfortable up there at \\(posterTime).",
                            "I just clocked \\(higherTime). Your \\(posterTime) is next.",
                            "Clocked \\(higherTime) easily. I'll overtake your \\(posterTime) soon.",
                            "Only at \\(higherTime) right now, but I'll catch your \\(posterTime) soon.",
                            "Are you serious? Only at \\(higherTime) right now, but I'll catch your \\(posterTime) soon."
                        ])
                    }
                }"""

content = content.replace(t_ctx_old, t_ctx_new)

s_ctx_old = """                    if isLowerStreakBrag, let cN = commentNumber, let rN = refNumber {
                        replies.append(contentsOf: [
                            "You're bragging about \\(cN) days? I'm already at \\(rN). You're still too low to get ahead.",
                            "You thought \\(cN) days would impress me? I'm at \\(rN). You're still too low to get ahead.",
                            "Is this a joke? \\(cN) days is nothing compared to my \\(rN). You're still too low to get ahead.",
                            "I'm at \\(rN) days and you're bragging about \\(cN)? You're still too low to get ahead.",
                            "You're acting like \\(cN) days is a big deal? I easily passed \\(rN).",
                            "Only at \\(cN) days? I'm laughing from \\(rN).",
                            "I left \\(cN) days in the dust a long time ago. \\(rN) is my new floor."
                        ])
                    } else {
                        let higherNum: Int
                        if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                            higherNum = valInt
                        } else if let rN = refNumber {
                            higherNum = rN
                        } else {
                            higherNum = num + Int.random(in: 5...15)
                        }
                        if higherNum < num {
                            replies.append(contentsOf: [
                                "I hit \\(higherNum) days yesterday. I'm coming for your \\(numStr) days.",
                                "I cleared \\(higherNum) days. Don't get too comfortable up there at \\(numStr) days.",
                                "I won't be at \\(higherNum) days for long. Your \\(numStr) days is next.",
                                "I hit \\(higherNum) days easily. I'll overtake your \\(numStr) days soon.",
                                "Only at \\(higherNum) days right now, but I'll catch your \\(numStr) days soon.",
                                "Are you serious? Only at \\(higherNum) days right now, but I'll catch your \\(numStr) days soon."
                            ])
                        } else if higherNum == num {
                            replies.append(contentsOf: [
                                "I'm right there at \\(numStr) days too. Let's see who breaks it first.",
                                "We're tied at \\(numStr) days. The real race starts now.",
                                "\\(numStr) days is solid. I'm sitting at \\(higherNum) days too.",
                                "Looks like we're both at \\(numStr) days. Don't get too comfortable.",
                                "I also hit \\(higherNum) days. Cute, but irrelevant."
                            ])
                        } else {
                            replies.append(contentsOf: [
                                "I am ahead of your \\(numStr) days. I'm at \\(higherNum) days.",
                                "I'm way past \\(numStr) days. I am sitting at \\(higherNum) days.",
                                "Your \\(numStr) days is nothing compared to my \\(higherNum) days record.",
                                "I easily passed \\(numStr) days. I dominate \\(higherNum) days.",
                                "Your \\(numStr) days is child's play compared to my \\(higherNum) days record.",
                                "\\(numStr) days is a joke. I'm already sitting at \\(higherNum) days.",
                                "You're celebrating \\(numStr) days? I just cleared \\(higherNum) days.",
                                "I left \\(numStr) days in the dust. \\(higherNum) days is the new standard.",
                                "Don't brag about \\(numStr) days when \\(higherNum) days is completely out of your reach.",
                                "I already hit \\(higherNum) days. \\(numStr) days is old news.",
                                "You'll never get to \\(higherNum) days at this rate.",
                                "Don't bother trying for \\(higherNum) days. You're completely outclassed."
                            ])
                        }
                    }"""

s_ctx_new = """                let higherNum: Int
                if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                    higherNum = valInt
                } else if let rN = refNumber {
                    higherNum = rN
                } else {
                    higherNum = num + Int.random(in: 5...15)
                }
                
                if higherNum > num {
                    replies.append(Self.getOneUpBrag(metric: "streak", lower: "\\(num)", higher: "\\(higherNum)"))
                    // Fallbacks
                    replies.append(contentsOf: [
                        "You'll never get to \\(higherNum) days at this rate.",
                        "Don't bother trying for \\(higherNum) days. You're completely outclassed."
                    ])
                } else if higherNum == num {
                    replies.append(contentsOf: [
                        "I'm right there at \\(numStr) days too. Let's see who breaks it first.",
                        "We're tied at \\(numStr) days. The real race starts now.",
                        "\\(numStr) days is solid. I'm sitting at \\(higherNum) days too.",
                        "Looks like we're both at \\(numStr) days. Don't get too comfortable.",
                        "I also hit \\(higherNum) days. Cute, but irrelevant."
                    ])
                } else {
                    replies.append(contentsOf: [
                        "I hit \\(higherNum) days yesterday. I'm coming for your \\(numStr) days.",
                        "I cleared \\(higherNum) days. Don't get too comfortable up there at \\(numStr) days.",
                        "I won't be at \\(higherNum) days for long. Your \\(numStr) days is next.",
                        "I hit \\(higherNum) days easily. I'll overtake your \\(numStr) days soon.",
                        "Only at \\(higherNum) days right now, but I'll catch your \\(numStr) days soon.",
                        "Are you serious? Only at \\(higherNum) days right now, but I'll catch your \\(numStr) days soon."
                    ])
                }"""

content = content.replace(s_ctx_old, s_ctx_new)


h_ctx_old = """                    if isLowerHofBrag, let cN = commentNumber, let rN = refNumber {
                        replies.append(contentsOf: [
                            "You're bragging about \\(cN)? I'm already at \\(rN). You're still too low to get ahead.",
                            "You thought \\(cN) would impress me? I'm at \\(rN). You're still too low to get ahead.",
                            "Is this a joke? \\(cN) is nothing compared to my \\(rN). You're still too low to get ahead.",
                            "I'm at \\(rN) and you're bragging about \\(cN)? You're still too low to get ahead.",
                            "You're acting like \\(cN) is a big deal? I easily passed \\(rN).",
                            "Only at \\(cN)? I'm laughing from \\(rN).",
                            "I left \\(cN) in the dust a long time ago. \\(rN) is my new floor."
                        ])
                    } else {
                        let higherNum: Int
                        if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                            higherNum = valInt
                        } else if let rN = refNumber {
                            higherNum = rN
                        } else {
                            higherNum = assumedNum + Int.random(in: 2...10)
                        }
                        if higherNum < assumedNum {
                            replies.append(contentsOf: [
                                "I hit \\(higherNum) infinities yesterday. I'm coming for your \\(numStr).",
                                "I cleared \\(higherNum) infinities. Don't get too comfortable up there at \\(numStr).",
                                "I won't be at \\(higherNum) infinities for long. Your \\(numStr) is next.",
                                "I hit \\(higherNum) infinities easily. I'll overtake your \\(numStr) soon.",
                                "Only at \\(higherNum) infinities right now, but I'll catch your \\(numStr) soon.",
                                "Are you serious? Only at \\(higherNum) infinities right now, but I'll catch your \\(numStr) soon."
                            ])
                        } else if higherNum == assumedNum {
                            replies.append(contentsOf: [
                                "I'm right there at \\(numStr) infinities too. Let's see who breaks it first.",
                                "We're tied at \\(numStr) infinities. The real race starts now.",
                                "\\(numStr) infinities is solid. I'm sitting at \\(higherNum) infinities too.",
                                "Looks like we're both at \\(numStr) infinities. Don't get too comfortable.",
                                "I also hit \\(higherNum) infinities. Cute, but irrelevant."
                            ])
                        } else {
                            replies.append(contentsOf: [
                                "I am ahead of your \\(assumedNum) entries. I'm at \\(higherNum).",
                                "I'm way past \\(assumedNum) entries. I am sitting at \\(higherNum).",
                                "Your \\(assumedNum) entries is nothing compared to my \\(higherNum) record.",
                                "I easily passed \\(assumedNum) entries. I dominate \\(higherNum).",
                                "Your \\(assumedNum) entries is child's play compared to my \\(higherNum) record.",
                                "\\(assumedNum) entries is a joke. I'm already sitting at \\(higherNum).",
                                "You're celebrating \\(assumedNum) entries? I just cleared \\(higherNum).",
                                "I left \\(assumedNum) entries in the dust. \\(higherNum) is the new standard.",
                                "Don't brag about \\(assumedNum) entries when \\(higherNum) is completely out of your reach.",
                                "I already hit \\(higherNum). \\(assumedNum) entries is old news.",
                                "You'll never get to \\(higherNum) at this rate.",
                                "Don't bother trying for \\(higherNum). You're completely outclassed."
                            ])
                        }
                    }"""

h_ctx_new = """                let higherNum: Int
                if let speakerValue = speakerValue, let valInt = Int(speakerValue) {
                    higherNum = valInt
                } else if let rN = refNumber {
                    higherNum = rN
                } else {
                    higherNum = assumedNum + Int.random(in: 2...10)
                }
                
                if higherNum > assumedNum {
                    replies.append(Self.getOneUpBrag(metric: "hof", lower: "\\(assumedNum)", higher: "\\(higherNum)"))
                    // Fallbacks
                    replies.append(contentsOf: [
                        "You'll never get to \\(higherNum) at this rate.",
                        "Don't bother trying for \\(higherNum). You're completely outclassed."
                    ])
                } else if higherNum == assumedNum {
                    replies.append(contentsOf: [
                        "I'm right there at \\(numStr) infinities too. Let's see who breaks it first.",
                        "We're tied at \\(numStr) infinities. The real race starts now.",
                        "\\(numStr) infinities is solid. I'm sitting at \\(higherNum) infinities too.",
                        "Looks like we're both at \\(numStr) infinities. Don't get too comfortable.",
                        "I also hit \\(higherNum) infinities. Cute, but irrelevant."
                    ])
                } else {
                    replies.append(contentsOf: [
                        "I hit \\(higherNum) infinities yesterday. I'm coming for your \\(numStr).",
                        "I cleared \\(higherNum) infinities. Don't get too comfortable up there at \\(numStr).",
                        "I won't be at \\(higherNum) infinities for long. Your \\(numStr) is next.",
                        "I hit \\(higherNum) infinities easily. I'll overtake your \\(numStr) soon.",
                        "Only at \\(higherNum) infinities right now, but I'll catch your \\(numStr) soon.",
                        "Are you serious? Only at \\(higherNum) infinities right now, but I'll catch your \\(numStr) soon."
                    ])
                }"""

content = content.replace(h_ctx_old, h_ctx_new)

with open(file_path, "w") as f:
    f.write(content)
print("Finished All modifications")
