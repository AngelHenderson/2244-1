import Foundation

// Copying logic
func splitBase1000(_ n: UInt64) -> [Int] {
    var x = n
    var out: [Int] = []
    while x > 0 {
        out.append(Int(x % 1_000))
        x /= 1_000
    }
    return out
}

func doubleTimes(_ chunks: inout [Int], _ times: Int) {
    for _ in 0..<times {
        var carry = 0
        for i in 0..<chunks.count {
            let v = chunks[i] * 2 + carry
            chunks[i] = v % 1_000
            carry = v / 1_000
        }
        if carry > 0 { chunks.append(carry) }
    }
}

func excelLetters(for index: Int) -> String {
    var i = index
    var result = ""
    while i > 0 {
        let rem = (i - 1) % 26
        let scalar = UnicodeScalar(65 + rem)! // 'A'..'Z'
        result = String(scalar) + result
        i = (i - 1) / 26
    }
    return result
}

func label(fromChunks chunks: [Int]) -> String {
    let hi = chunks.count - 1
    if hi == 0 { return String(chunks[0]) }
    if hi == 1 {
        let total = chunks[1] * 1_000 + chunks[0]
        if total < 10_000 { return String(total) }
        return "\(chunks[1])K"
    }
    if hi == 2 { return "\(chunks[2])M" }
    if hi == 3 { return "\(chunks[3])B" }
    let tierIndex = hi - 3
    let suffix = excelLetters(for: tierIndex).lowercased()
    let mantissa = chunks[hi]
    return "\(mantissa)\(suffix)"
}

func labelForStep(_ step: Int) -> String {
    var chunks = splitBase1000(2)
    if step > 0 {
        doubleTimes(&chunks, step)
    }
    return label(fromChunks: chunks)
}

for step in 0...818 {
    let l = labelForStep(step)
    if l == "1al" {
        print("1al is step \(step)")
    }
    if l == "873bz" {
        print("873bz is step \(step)")
    }
}
