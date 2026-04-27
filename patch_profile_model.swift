import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Profile/ProfileModel.swift"
var content = try! String(contentsOfFile: path)

let targetFunc = """
        if lowercased.count == 2 {
            let chars = Array(lowercased)
            guard chars[0] >= "a" && chars[0] <= "b",
                  chars[1] >= "a" && chars[1] <= "z" else { return nil }

            // aa, ab, ..., az = indices 26-51
            // ba, bb, ..., bz = indices 52-77
            let firstIndex = Int(chars[0].asciiValue! - Character("a").asciiValue!) // 0 for 'a', 1 for 'b'
            let secondIndex = Int(chars[1].asciiValue! - Character("a").asciiValue!) // 0-25
            let letterIndex = 26 + firstIndex * 26 + secondIndex
            return 29 + (letterIndex + 1) * 10
        }
"""

let newFunc = """
        if lowercased.count == 2 {
            let chars = Array(lowercased)
            guard chars[0] >= "a" && chars[0] <= "b",
                  chars[1] >= "a" && chars[1] <= "z" else { return nil }

            // aa, ab, ..., az = indices 26-51
            // ba, bb, ..., bz = indices 52-77
            let firstIndex = Int(chars[0].asciiValue! - Character("a").asciiValue!) // 0 for 'a', 1 for 'b'
            let secondIndex = Int(chars[1].asciiValue! - Character("a").asciiValue!) // 0-25
            let letterIndex = 26 + firstIndex * 26 + secondIndex
            
            var step = 29 + (letterIndex + 1) * 10
            
            // Adjust for missing tier steps (z and bc only have 9 steps instead of 10)
            if lowercased >= "aa" && lowercased <= "bb" {
                step -= 1
            } else if lowercased >= "bd" && lowercased <= "bz" {
                step -= 2
            }
            
            return step
        }
"""

if content.contains("return 29 + (letterIndex + 1) * 10") {
    content = content.replacingOccurrences(of: targetFunc, with: newFunc)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Updated ProfileModel.swift")
} else {
    print("Could not find the function block in ProfileModel.swift")
}
