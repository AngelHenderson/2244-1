import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

let replacements = [
    "You're a beginner at \\(m.name)?": "You can't get past \\(m.name)?",
    "Calling yourself terrible at \\(m.name) is an understatement.": "You being stuck at \\(m.name) is hilarious.",
    "Only a complete amateur would get stuck at \\(m.name)?": "Only someone completely clueless would get stuck at \\(m.name)?",
    "Pain? \\(m.name) is a joke.": "Complaining? \\(m.name) is a joke.",
    
    "You're a beginner at \\(num)?": "You're complaining about \\(num)?",
    "Calling yourself an amateur at \\(num)?": "You being stuck at \\(num) is hilarious.",
    "Only a complete amateur would get stuck at \\(num)?": "Only someone completely clueless would get stuck at \\(num)?",
    
    "You're a beginner at \\(posterTime)?": "You're complaining about \\(posterTime)?",
    "Calling yourself terrible at \\(posterTime) is an understatement.": "You taking \\(posterTime) is hilarious.",
    "Only a complete amateur would get stuck at \\(posterTime)?": "Only someone completely clueless would be that slow at \\(posterTime)?",
    "Pain? I breeze through in \\(myTime).": "Complaining? I breeze through in \\(myTime).",
    
    "You're a beginner at \\(num) days?": "You're complaining about \\(num) days?",
    "Calling yourself terrible at \\(num) is an understatement.": "You losing at \\(num) days is hilarious.",
    "Only a complete amateur would get stuck at \\(num) days?": "Only someone completely clueless would fail at \\(num) days?",
    
    "You're a beginner at quests?": "You're complaining about quests?",
    
    "You're a beginner at \\(infCount)?": "You're complaining about \\(infCount)?",
    "Calling yourself terrible at \\(infCount)?": "You being stuck at \\(infCount) is hilarious.",
    "Only a complete amateur would get stuck at \\(infCount)?": "Only someone completely clueless would get stuck at \\(infCount)?",
    
    "You're a beginner? I am effortlessly untouchable.": "You're complaining? I am effortlessly untouchable.",
    "Your struggles mean nothing.": "Your complaints mean nothing.",
    
    "You're a beginner at \\(cM.name)?": "You can't get past \\(cM.name)?",
    "Stuck at \\(cM.name) like a novice?": "Stuck at \\(cM.name)?",
    "You're still an amateur at \\(cM.name).": "You can't even beat \\(cM.name).",
    
    "You're a beginner at \\(cN)?": "You can't get past \\(cN)?",
    "Stuck at \\(cN) like a novice?": "Stuck at \\(cN)?",
    "You're still an amateur at \\(cN).": "You can't even beat \\(cN).",
    
    "You're a beginner at \\(cN) days?": "You can't get past \\(cN) days?",
    "Stuck at \\(cN) days like a novice?": "Stuck at \\(cN) days?",
    "You're still an amateur at \\(cN) days.": "You can't even beat \\(cN) days.",
    
    "I already passed that struggle.": "I already passed that phase.",
    
    // Also "You think \(m.name) is a struggle?" -> "is a challenge?"
    "is a struggle? Pathetic.": "is a challenge? Pathetic."
]

for (target, replacement) in replacements {
    content = content.replacingOccurrences(of: target, with: replacement)
}

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Banned words removed from competitive replies!")
