import Foundation

extension MockSocialService {
    
    static func getOneUpBrag(metric: String, lower: String, higher: String) -> String {
        let randBucket = Int.random(in: 1...4)
        
        switch metric {
        case "milestone":
            switch randBucket {
            case 1:
                let weightedReplies: [(String, Double)] = [
                    ("Only at \(lower)? I easily reached \(higher).", 3.0),
                    ("You think \(lower) is a big milestone? I'm already coasting at \(higher).", 0.6),
                    ("Your \(lower) is a joke. You'll never catch my \(higher).", 9.9),
                    ("I easily bypassed \(lower) and hit \(higher).", 0.1),
                    ("I'm laughing from \(higher) while you're still at \(lower).", 3.5),
                    ("Celebrating \(lower)? I easily clear \(higher).", 13.0),
                    ("You're at \(lower)? Cute. \(lower) is completely irrelevant now that I'm at \(higher).", 62.0),
                    ("I can't imagine spending time on \(lower). My \(higher) was completed with ease.", 0.3),
                    ("Still at \(lower)? I left that behind months ago. \(higher) is where the real game is.", 1.7),
                    ("Lagging at \(lower)? I'm coasting at \(higher).", 5.8),
                    ("Imagine being at \(lower) while I dominate at \(higher).", 0.1)
                ]
                return pickWeighted(weightedReplies)
            case 2:
                let list = [
                    "If you can't even get past \(lower), you'll never catch my \(higher).",
                    "\(lower) is your ceiling? Try aiming lower. I'm at \(higher).",
                    "You'll never get past \(lower) anyway, let alone my \(higher).",
                    "If getting past \(lower) is impossible for you, don't even look at my \(higher).",
                    "Of course you're lagging at \(lower). That's child's play compared to my \(higher).",
                    "You're lagging at \(lower)? Figures. My record is \(higher).",
                    "Keep trying with \(lower). I'm sitting comfortably at \(higher).",
                    "Stop wasting your time on \(lower). My \(higher) is light years away from your skill level.",
                    "If \(lower) is your ceiling, you're not even in the same conversation as my \(higher).",
                    "Why even mention \(lower)? My \(higher) is completely out of your league.",
                    "Don't lose sleep over \(lower). You were never going to threaten my \(higher) anyway.",
                    "You're not built for \(lower). Meanwhile, my \(higher) was completed with ease."
                ]
                return list.randomElement()!
            case 3:
                let weightedReplies: [(String, Double)] = [
                    ("I easily passed your \(lower). I'm at \(higher).", 0.3),
                    ("I let you think you had the lead. Your \(lower) is nothing. I'm at \(higher).", 1.7),
                    ("You fell for it. I easily beat your \(lower). My real record is \(higher).", 63.0),
                    ("I was just warming up. Your \(lower) is a joke compared to my \(higher).", 17.0),
                    ("I blew past your \(lower) and hit \(higher) without even trying.", 0.4),
                    ("Only at \(lower)? I easily reached \(higher).", 3.6),
                    ("Your \(lower) is a joke compared to my \(higher).", 0.06),
                    ("I cleared \(higher) without trying.", 0.02),
                    ("I was just toying with you. I'm actually at \(higher).", 13.92)
                ]
                return pickWeighted(weightedReplies)
            case 4:
                let list = [
                    "I am ahead of your \(lower). I'm at \(higher).",
                    "I'm way past \(lower). I am sitting at \(higher).",
                    "Your \(lower) is nothing compared to my \(higher) record.",
                    "I easily passed \(lower). I dominate \(higher).",
                    "Your \(lower) is child's play compared to my \(higher) record.",
                    "\(lower) is a joke. I'm already sitting at \(higher).",
                    "You're celebrating \(lower)? I just cleared \(higher).",
                    "I left \(lower) in the dust. \(higher) is the new standard.",
                    "Don't brag about \(lower) when \(higher) is completely out of your reach.",
                    "I already hit \(higher). \(lower) is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        case "time":
            switch randBucket {
            case 1:
                let list = [
                    "Celebrating \(lower)? I easily reached \(higher).",
                    "You think \(lower) is fast? I'm already casually coasting at \(higher).",
                    "Your \(lower) is a joke. I easily hit \(higher).",
                    "Only at \(lower)? I easily bypassed that to clock \(higher).",
                    "My record is \(higher) compared to your \(lower).",
                    "I breeze through in \(higher) in my sleep.",
                    "You call \(lower) speed? I run circles around that at \(higher).",
                    "I literally fell asleep during a run and still beat \(lower) with my \(higher).",
                    "Your absolute best time of \(lower) is slower than my worst warm-up of \(higher).",
                    "Why are you mentioning \(lower) when my \(higher) exists?",
                    "I don't even acknowledge \(lower). My \(higher) clear is the new norm."
                ]
                return list.randomElement()!
            case 2:
                let list = [
                    "If you can't even beat \(lower), you'll never catch my \(higher).",
                    "\(lower) is your fastest? I'm at \(higher).",
                    "You'll never get past \(lower) anyway, let alone my \(higher).",
                    "If \(lower) is too fast for you, don't bother looking at my \(higher).",
                    "You'll never see the clock hit \(lower), let alone my \(higher).",
                    "Speed isn't for everyone. Stick to slow runs while I hold \(higher).",
                    "Don't hurt yourself trying to reach my \(higher)."
                ]
                return list.randomElement()!
            case 3:
                let list = [
                    "I easily passed your \(lower). I'm at \(higher).",
                    "I let you think you had the lead. Your \(lower) is nothing. I'm at \(higher).",
                    "You fell for it. I easily beat your \(lower). My real record is \(higher).",
                    "I was just warming up. Your \(lower) is a joke compared to my \(higher).",
                    "I blew past your \(lower) and clocked \(higher) without even trying."
                ]
                return list.randomElement()!
            case 4:
                let list = [
                    "I am ahead of your \(lower). I'm at \(higher).",
                    "I'm way past \(lower). I am sitting at \(higher).",
                    "Your \(lower) is nothing compared to my \(higher) record.",
                    "I easily passed your time. My record is \(higher).",
                    "Your \(lower) is child's play compared to my \(higher) record.",
                    "\(lower) is a joke. I'm already sitting at \(higher).",
                    "You're celebrating \(lower)? I just cleared \(higher).",
                    "I left \(lower) in the dust. \(higher) is the new standard.",
                    "Don't brag about \(lower) when \(higher) is completely out of your reach.",
                    "I already hit \(higher). \(lower) is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        case "streak":
            switch randBucket {
            case 1:
                let list = [
                    "Your streak is a joke. I'm already adding to my \(higher) days.",
                    "Trying to keep \(lower) days alive? I'm already adding to my \(higher) days.",
                    "I easily bypassed \(lower) days and hit \(higher).",
                    "I'm laughing from \(higher) days while you're still at \(lower).",
                    "Celebrating \(lower) days? I easily clear \(higher).",
                    "You're at \(lower) days? Cute. \(lower) is completely irrelevant now that I'm at \(higher)."
                ]
                return list.randomElement()!
            case 2:
                let list = [
                    "If you can't even reach \(lower) days, you'll never catch my \(higher) days.",
                    "\(lower) days is your best? I'm at \(higher) days.",
                    "You'll never get past \(lower) days anyway, let alone my \(higher) days.",
                    "If a \(lower) day streak is impossible for you, don't even look at my \(higher) days.",
                    "Of course you can't get past \(lower) days. That's child's play compared to my \(higher) days.",
                    "You can't even reach \(lower) days? Figures. My record is \(higher) days.",
                    "Keep trying with \(lower) days. I'm sitting comfortably at \(higher) days."
                ]
                return list.randomElement()!
            case 3:
                let list = [
                    "You're bragging about \(lower) days? I'm already at \(higher). You're still too low to get ahead.",
                    "You thought \(lower) days would impress me? I'm at \(higher). You're still too low to get ahead.",
                    "Is this a joke? \(lower) days is nothing compared to my \(higher). You're still too low to get ahead.",
                    "I'm at \(higher) days and you're bragging about \(lower)? You're still too low to get ahead.",
                    "You're acting like \(lower) days is a big deal? I easily passed \(higher).",
                    "Only at \(lower) days? I'm laughing from \(higher).",
                    "I left \(lower) days in the dust a long time ago. \(higher) is my new floor."
                ]
                return list.randomElement()!
            case 4:
                let list = [
                    "I am ahead of your \(lower) days. I'm at \(higher) days.",
                    "I'm way past \(lower) days. I am sitting at \(higher) days.",
                    "Your \(lower) days is nothing compared to my \(higher) days record.",
                    "I easily passed \(lower) days. I dominate \(higher) days.",
                    "Your \(lower) days is child's play compared to my \(higher) days record.",
                    "\(lower) days is a joke. I'm already sitting at \(higher) days.",
                    "You're celebrating \(lower) days? I just cleared \(higher) days.",
                    "I left \(lower) days in the dust. \(higher) days is the new standard.",
                    "Don't brag about \(lower) days when \(higher) days is completely out of your reach.",
                    "I already hit \(higher) days. \(lower) days is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        case "hof":
            switch randBucket {
            case 1:
                let list = [
                    "Celebrating \(lower) infinities? I easily clear \(higher).",
                    "You think \(lower) infinities is a big milestone? I'm already coasting at \(higher).",
                    "Your \(lower) infinities is a joke. You'll never catch my \(higher).",
                    "I easily bypassed \(lower) infinities and hit \(higher).",
                    "I'm laughing from \(higher) infinities while you're still at \(lower).",
                    "You're at \(lower) infinities? Cute. \(lower) is completely irrelevant now that I'm at \(higher)."
                ]
                return list.randomElement()!
            case 2:
                let list = [
                    "If you can't even get past \(lower) infinities, you'll never catch my \(higher).",
                    "\(lower) infinities is your ceiling? Try aiming lower. I'm at \(higher).",
                    "You'll never get past \(lower) infinities anyway, let alone my \(higher).",
                    "If \(lower) infinities is impossible for you, don't even look at my \(higher).",
                    "Of course you can't get past \(lower) infinities. That's child's play compared to my \(higher).",
                    "You can't even reach \(lower) infinities? Figures. My record is \(higher).",
                    "Keep trying with \(lower) infinities. I'm sitting comfortably at \(higher)."
                ]
                return list.randomElement()!
            case 3:
                let list = [
                    "You're bragging about \(lower)? I'm already at \(higher). You're still too low to get ahead.",
                    "You thought \(lower) would impress me? I'm at \(higher). You're still too low to get ahead.",
                    "Is this a joke? \(lower) is nothing compared to my \(higher). You're still too low to get ahead.",
                    "I'm at \(higher) and you're bragging about \(lower)? You're still too low to get ahead.",
                    "You're acting like \(lower) is a big deal? I easily passed \(higher).",
                    "Only at \(lower)? I'm laughing from \(higher).",
                    "I left \(lower) in the dust a long time ago. \(higher) is my new floor."
                ]
                return list.randomElement()!
            case 4:
                let list = [
                    "I am ahead of your \(lower) entries. I'm at \(higher).",
                    "I'm way past \(lower) entries. I am sitting at \(higher).",
                    "Your \(lower) entries is nothing compared to my \(higher) record.",
                    "I easily passed \(lower) entries. I dominate \(higher).",
                    "Your \(lower) entries is child's play compared to my \(higher) record.",
                    "\(lower) entries is a joke. I'm already sitting at \(higher).",
                    "You're celebrating \(lower) entries? I just cleared \(higher).",
                    "I left \(lower) entries in the dust. \(higher) is the new standard.",
                    "Don't brag about \(lower) entries when \(higher) is completely out of your reach.",
                    "I already hit \(higher). \(lower) entries is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        default:
            return ""
        }
    }
    
    private static func pickWeighted(_ list: [(String, Double)]) -> String {
        let totalWeight = list.reduce(0) { $0 + $1.1 }
        let rand = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        var selected = list.last!.0
        for (text, weight) in list {
            cumulative += weight
            if rand < cumulative {
                selected = text
                break
            }
        }
        return selected
    }
}
