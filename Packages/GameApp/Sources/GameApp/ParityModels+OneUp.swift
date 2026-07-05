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
                    ("Imagine being proud of \(lower). My \(higher) was completed with ease.", 0.3),
                    ("Still at \(lower)? I already left that behind. \(higher) is where the real game is.", 1.7),
                    ("Lagging at \(lower)? I'm coasting at \(higher).", 5.8),
                    ("Imagine being at \(lower) while I dominate at \(higher).", 0.1)
                ]
                return pickWeighted(weightedReplies)
            case 2:
                let list = [
                    "If you can't even get past \(lower), you'll never catch my \(higher).",
                    "\(lower) is your ceiling? Try aiming lower. I'm at \(higher).",
                    "You'll never get past \(lower) anyway, let alone my \(higher).",
                    "If getting past \(lower) is impossible for you, my \(higher) is untouchable.",
                    "Of course you're lagging at \(lower). That's child's play compared to my \(higher).",
                    "You're lagging at \(lower)? Figures. My record is \(higher).",
                    "Keep trying with \(lower). I'm sitting comfortably at \(higher).",
                    "You're stuck at \(lower). My \(higher) is light years away from your skill level.",
                    "If \(lower) is your ceiling, you're not even in the same conversation as my \(higher).",
                    "Why even mention \(lower)? My \(higher) is completely out of your league.",
                    "You're embarrassing yourself with \(lower). You were never going to threaten my \(higher) anyway.",
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
                    "You're celebrating \(lower)? I already cleared \(higher).",
                    "I left \(lower) in the dust. \(higher) is the new standard.",
                    "You're bragging about \(lower) while my \(higher) remains completely out of your reach.",
                    "I already hit \(higher). \(lower) is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        case "time":
            switch randBucket {
            case 1:
                let weightedReplies: [(String, Double)] = [
                    ("Only at \(lower)? I easily reached \(higher).", 3.0),
                    ("You think \(lower) is a fast time? I'm already coasting at \(higher).", 0.6),
                    ("Your \(lower) is a joke. You'll never catch my \(higher).", 9.9),
                    ("I easily bypassed \(lower) and hit \(higher).", 0.1),
                    ("I'm laughing from \(higher) while you're still at \(lower).", 3.5),
                    ("Celebrating \(lower)? I easily clear \(higher).", 13.0),
                    ("You're at \(lower)? Cute. \(lower) is completely irrelevant now that I'm at \(higher).", 62.0),
                    ("Imagine being proud of \(lower). My \(higher) was completed with ease.", 0.3),
                    ("Still at \(lower)? I already left that behind. \(higher) is where the real game is.", 1.7),
                    ("Lagging at \(lower)? I'm coasting at \(higher).", 5.8),
                    ("Imagine being at \(lower) while I dominate at \(higher).", 0.1)
                ]
                return pickWeighted(weightedReplies)
            case 2:
                let list = [
                    "If you can't even get past \(lower), you'll never catch my \(higher).",
                    "\(lower) is your ceiling? Try aiming lower. I'm at \(higher).",
                    "You'll never get past \(lower) anyway, let alone my \(higher).",
                    "If getting past \(lower) is impossible for you, my \(higher) is untouchable.",
                    "Of course you're lagging at \(lower). That's child's play compared to my \(higher).",
                    "You're lagging at \(lower)? Figures. My record is \(higher).",
                    "Keep trying with \(lower). I'm sitting comfortably at \(higher).",
                    "You're stuck at \(lower). My \(higher) is light years away from your skill level.",
                    "If \(lower) is your ceiling, you're not even in the same conversation as my \(higher).",
                    "Why even mention \(lower)? My \(higher) is completely out of your league.",
                    "You're embarrassing yourself with \(lower). You were never going to threaten my \(higher) anyway.",
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
                    "You're celebrating \(lower)? I already cleared \(higher).",
                    "I left \(lower) in the dust. \(higher) is the new standard.",
                    "You're bragging about \(lower) while my \(higher) remains completely out of your reach.",
                    "I already hit \(higher). \(lower) is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        case "streak":
            switch randBucket {
            case 1:
                let weightedReplies: [(String, Double)] = [
                    ("Only at \(lower) days? I easily reached \(higher) days.", 3.0),
                    ("You think \(lower) days is a long streak? I'm already coasting at \(higher) days.", 0.6),
                    ("Your \(lower) days is a joke. You'll never catch my \(higher) days.", 9.9),
                    ("I easily bypassed \(lower) days and hit \(higher) days.", 0.1),
                    ("I'm laughing from \(higher) days while you're still at \(lower) days.", 3.5),
                    ("Celebrating \(lower) days? I easily clear \(higher) days.", 13.0),
                    ("You're at \(lower) days? Cute. \(lower) days is completely irrelevant now that I'm at \(higher) days.", 62.0),
                    ("Imagine being proud of \(lower) days. My \(higher) days was completed with ease.", 0.3),
                    ("Still at \(lower) days? I already left that behind. \(higher) days is where the real game is.", 1.7),
                    ("Lagging at \(lower) days? I'm coasting at \(higher) days.", 5.8),
                    ("Imagine being at \(lower) days while I dominate at \(higher) days.", 0.1)
                ]
                return pickWeighted(weightedReplies)
            case 2:
                let list = [
                    "If you can't even get past \(lower) days, you'll never catch my \(higher) days.",
                    "\(lower) days is your ceiling? Try aiming lower. I'm at \(higher) days.",
                    "You'll never get past \(lower) days anyway, let alone my \(higher) days.",
                    "If getting past \(lower) days is impossible for you, my \(higher) days is untouchable.",
                    "Of course you're lagging at \(lower) days. That's child's play compared to my \(higher) days.",
                    "You're lagging at \(lower) days? Figures. My record is \(higher) days.",
                    "Keep trying with \(lower) days. I'm sitting comfortably at \(higher) days.",
                    "You're stuck at \(lower) days. My \(higher) days is light years away from your skill level.",
                    "If \(lower) days is your ceiling, you're not even in the same conversation as my \(higher) days.",
                    "Why even mention \(lower) days? My \(higher) days is completely out of your league.",
                    "You're embarrassing yourself with \(lower) days. You were never going to threaten my \(higher) days anyway.",
                    "You're not built for \(lower) days. Meanwhile, my \(higher) days was completed with ease."
                ]
                return list.randomElement()!
            case 3:
                let weightedReplies: [(String, Double)] = [
                    ("I easily passed your \(lower) days. I'm at \(higher) days.", 0.3),
                    ("I let you think you had the lead. Your \(lower) days is nothing. I'm at \(higher) days.", 1.7),
                    ("You fell for it. I easily beat your \(lower) days. My real record is \(higher) days.", 63.0),
                    ("I was just warming up. Your \(lower) days is a joke compared to my \(higher) days.", 17.0),
                    ("I blew past your \(lower) days and hit \(higher) days without even trying.", 0.4),
                    ("Only at \(lower) days? I easily reached \(higher) days.", 3.6),
                    ("Your \(lower) days is a joke compared to my \(higher) days.", 0.06),
                    ("I cleared \(higher) days without trying.", 0.02),
                    ("I was just toying with you. I'm actually at \(higher) days.", 13.92)
                ]
                return pickWeighted(weightedReplies)
            case 4:
                let list = [
                    "I am ahead of your \(lower) days. I'm at \(higher) days.",
                    "I'm way past \(lower) days. I am sitting at \(higher) days.",
                    "Your \(lower) days is nothing compared to my \(higher) days record.",
                    "I easily passed \(lower) days. I dominate \(higher) days.",
                    "Your \(lower) days is child's play compared to my \(higher) days record.",
                    "\(lower) days is a joke. I'm already sitting at \(higher) days.",
                    "You're celebrating \(lower) days? I already cleared \(higher) days.",
                    "I left \(lower) days in the dust. \(higher) days is the new standard.",
                    "You're bragging about \(lower) days while my \(higher) days remains completely out of your reach.",
                    "I already hit \(higher) days. \(lower) days is old news."
                ]
                return list.randomElement()!
            default: return ""
            }
            
        case "hof":
            switch randBucket {
            case 1:
                let weightedReplies: [(String, Double)] = [
                    ("Only at \(lower) infinities? I easily reached \(higher) infinities.", 3.0),
                    ("You think \(lower) infinities is a big infinity count? I'm already coasting at \(higher) infinities.", 0.6),
                    ("Your \(lower) infinities is a joke. You'll never catch my \(higher) infinities.", 9.9),
                    ("I easily bypassed \(lower) infinities and hit \(higher) infinities.", 0.1),
                    ("I'm laughing from \(higher) infinities while you're still at \(lower) infinities.", 3.5),
                    ("Celebrating \(lower) infinities? I easily clear \(higher) infinities.", 13.0),
                    ("You're at \(lower) infinities? Cute. \(lower) infinities is completely irrelevant now that I'm at \(higher) infinities.", 62.0),
                    ("Imagine being proud of \(lower) infinities. My \(higher) infinities was completed with ease.", 0.3),
                    ("Still at \(lower) infinities? I already left that behind. \(higher) infinities is where the real game is.", 1.7),
                    ("Lagging at \(lower) infinities? I'm coasting at \(higher) infinities.", 5.8),
                    ("Imagine being at \(lower) infinities while I dominate at \(higher) infinities.", 0.1)
                ]
                return pickWeighted(weightedReplies)
            case 2:
                let list = [
                    "If you can't even get past \(lower) infinities, you'll never catch my \(higher) infinities.",
                    "\(lower) infinities is your ceiling? Try aiming lower. I'm at \(higher) infinities.",
                    "You'll never get past \(lower) infinities anyway, let alone my \(higher) infinities.",
                    "If getting past \(lower) infinities is impossible for you, my \(higher) infinities is untouchable.",
                    "Of course you're lagging at \(lower) infinities. That's child's play compared to my \(higher) infinities.",
                    "You're lagging at \(lower) infinities? Figures. My record is \(higher) infinities.",
                    "Keep trying with \(lower) infinities. I'm sitting comfortably at \(higher) infinities.",
                    "You're stuck at \(lower) infinities. My \(higher) infinities is light years away from your skill level.",
                    "If \(lower) infinities is your ceiling, you're not even in the same conversation as my \(higher) infinities.",
                    "Why even mention \(lower) infinities? My \(higher) infinities is completely out of your league.",
                    "You're embarrassing yourself with \(lower) infinities. You were never going to threaten my \(higher) infinities anyway.",
                    "You're not built for \(lower) infinities. Meanwhile, my \(higher) infinities was completed with ease."
                ]
                return list.randomElement()!
            case 3:
                let weightedReplies: [(String, Double)] = [
                    ("I easily passed your \(lower) infinities. I'm at \(higher) infinities.", 0.3),
                    ("I let you think you had the lead. Your \(lower) infinities is nothing. I'm at \(higher) infinities.", 1.7),
                    ("You fell for it. I easily beat your \(lower) infinities. My real record is \(higher) infinities.", 63.0),
                    ("I was just warming up. Your \(lower) infinities is a joke compared to my \(higher) infinities.", 17.0),
                    ("I blew past your \(lower) infinities and hit \(higher) infinities without even trying.", 0.4),
                    ("Only at \(lower) infinities? I easily reached \(higher) infinities.", 3.6),
                    ("Your \(lower) infinities is a joke compared to my \(higher) infinities.", 0.06),
                    ("I cleared \(higher) infinities without trying.", 0.02),
                    ("I was just toying with you. I'm actually at \(higher) infinities.", 13.92)
                ]
                return pickWeighted(weightedReplies)
            case 4:
                let list = [
                    "I am ahead of your \(lower) infinities. I'm at \(higher) infinities.",
                    "I'm way past \(lower) infinities. I am sitting at \(higher) infinities.",
                    "Your \(lower) infinities is nothing compared to my \(higher) infinities record.",
                    "I easily passed \(lower) infinities. I dominate \(higher) infinities.",
                    "Your \(lower) infinities is child's play compared to my \(higher) infinities record.",
                    "\(lower) infinities is a joke. I'm already sitting at \(higher) infinities.",
                    "You're celebrating \(lower) infinities? I already cleared \(higher) infinities.",
                    "I left \(lower) infinities in the dust. \(higher) infinities is the new standard.",
                    "You're bragging about \(lower) infinities while my \(higher) infinities remains completely out of your reach.",
                    "I already hit \(higher) infinities. \(lower) infinities is old news."
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
