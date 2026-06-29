import re

with open("Packages/GameApp/Sources/GameApp/ParityModels.swift", "r") as f:
    content = f.read()

# Fix comment count logic
old_comment_logic = """            let numBaseComments = Int.random(in: 4...10)
            var usedStats: Set<String> = []"""
new_comment_logic = """            let ageFactor = abs(timeOffset) / 43200.0
            let baseMin = 1 + Int(ageFactor * 6)
            let baseMax = 3 + Int(ageFactor * 18)
            let numBaseComments = Int.random(in: baseMin...baseMax)
            var usedStats: Set<String> = []"""
content = content.replace(old_comment_logic, new_comment_logic)

# Replace complex NPC turn logic
pattern = r'( +)if isNpc2Turn \{.*?isNpc2Turn\.toggle\(\)\n'
replacement = r"""\1if isNpc2Turn {
\1    if npc2Value == nil {
\1        if Double.random(in: 0...1) < 0.45, let n1Val = npc1Value {
\1            npc2Value = Self.lowerValue(for: n1Val, topic: topic)
\1        } else {
\1            npc2Value = Self.oneUpValue(for: npc1Value, topic: topic)
\1        }
\1    }
\1    
\1    let isBehind: Bool
\1    if let n1Val = npc1Value, let n2Val = npc2Value {
\1        isBehind = Self.isRecord(n2Val, worseThan: n1Val, topic: topic)
\1    } else {
\1        isBehind = false
\1    }
\1    
\1    let toneStr = isBehind ? "behind" : "one_up"
\1    let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: toneStr, speakerValue: npc2Value)
\1    let replyOffset = Double.random(in: 60...90)
\1    let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
\1    
\1    let replyComment = SocialFeedComment(
\1        authorName: npc2!.name,
\1        avatarID: npc2!.avatar,
\1        text: replyText,
\1        createdAt: replyCreatedAt,
\1        likes: Int.random(in: 0...5)
\1    )
\1    comments.append(replyComment)
\1    lastComment = replyComment
\1    currentDepth += 1
\1} else {
\1    let isBehind: Bool
\1    if let sVal = npc1Value, let oVal = npc2Value {
\1        isBehind = Self.isRecord(sVal, worseThan: oVal, topic: topic)
\1    } else {
\1        isBehind = false
\1    }
\1    
\1    let toneStr = isBehind ? "behind" : "one_up"
\1    let replyText = "@\(lastComment.authorName) " + generateContextualReply(to: lastComment.text, message: message, forceTone: toneStr, speakerValue: npc1Value)
\1    let replyOffset = Double.random(in: 60...90)
\1    let replyCreatedAt = lastComment.createdAt.addingTimeInterval(replyOffset)
\1    
\1    let replyComment = SocialFeedComment(
\1        authorName: npc1.name,
\1        avatarID: npc1.avatar,
\1        text: replyText,
\1        createdAt: replyCreatedAt,
\1        likes: Int.random(in: 0...5)
\1    )
\1    comments.append(replyComment)
\1    lastComment = replyComment
\1    currentDepth += 1
\1}
\1isNpc2Turn.toggle()
"""

# Test if regex works
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
if new_content == content:
    print("Failed to replace NPC turn logic.")
else:
    with open("Packages/GameApp/Sources/GameApp/ParityModels.swift", "w") as f:
        f.write(new_content)
    print("Successfully updated ParityModels.swift")

