import Foundation

let tileTiers: [(label: String, value: Double)] = [
    ("1M", 1_000_000), ("1B", 1_000_000_000), ("1a", 1e12), ("1b", 1e15), ("1c", 1e18),
    ("1d", 1e21), ("1e", 1e24), ("1f", 1e27), ("1g", 1e30), ("1h", 1e33),
    ("1i", 1e36), ("1j", 1e39), ("1k", 1e42), ("1l", 1e45), ("1m", 1e48),
    ("1n", 1e51), ("1o", 1e54), ("1p", 1e57), ("1q", 1e60), ("1r", 1e63),
    ("1s", 1e66), ("1t", 1e69), ("1u", 1e72), ("1v", 1e75), ("1w", 1e78),
    ("1x", 1e81), ("1y", 1e84), ("1z", 1e87), ("1aa", 1e90), ("1ab", 1e93),
    ("1ac", 1e96), ("1ad", 1e99), ("1ae", 1e102), ("1af", 1e105), ("1ag", 1e108),
    ("1ah", 1e111), ("1ai", 1e114), ("1aj", 1e117), ("1ak", 1e120), ("1al", 1e123),
    ("1am", 1e126), ("1an", 1e129), ("1ao", 1e132), ("1ap", 1e135), ("1aq", 1e138),
    ("1ar", 1e141), ("1as", 1e144), ("1at", 1e147), ("1au", 1e150), ("1av", 1e153),
    ("1aw", 1e156), ("1ax", 1e159), ("1ay", 1e162), ("1az", 1e165)
]

func labelForStep(_ step: Int) -> String {
    let rawValue = pow(2.0, Double(step + 1))
    if rawValue < 1_000_000 { return String(Int(rawValue)) }
    let suffixes = ["M", "B", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj", "ak", "al", "am", "an", "ao", "ap", "aq", "ar", "as", "at", "au", "av", "aw", "ax", "ay", "az"]
    var value = rawValue
    var suffixIndex = -1
    if value >= 1_000_000 { value /= 1_000_000; suffixIndex = 0 }
    if value >= 1000 && suffixIndex == 0 { value /= 1000; suffixIndex = 1 }
    while value >= 1000 && suffixIndex < suffixes.count - 1 { value /= 1000; suffixIndex += 1 }
    let roundedValue = Int(round(value))
    if roundedValue >= 1000 && suffixIndex < suffixes.count - 1 {
        return "1\(suffixes[suffixIndex + 1])"
    } else {
        return "\(roundedValue)\(suffixes[suffixIndex])"
    }
}

for tier in tileTiers {
    let ceilStep = Int(max(0, ceil(log2(tier.value)) - 1))
    let roundStep = Int(max(0, round(log2(tier.value)) - 1))
    
    let ceilLabel = labelForStep(ceilStep)
    let roundLabel = labelForStep(roundStep)
    
    if ceilLabel != tier.label {
        print("MISMATCH CEIL: expected \(tier.label), got \(ceilLabel) (step \(ceilStep))")
    }
    if roundLabel != tier.label {
        print("MISMATCH ROUND: expected \(tier.label), got \(roundLabel) (step \(roundStep))")
    }
}
print("Done.")
