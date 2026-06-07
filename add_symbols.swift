import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
var content = try String(contentsOfFile: path, encoding: .utf8)

// Replace positive/general arrays
let oldPos = "[\"!!\", \" :)\", \" :D\", \" xD\", \" ~\", \" :P\", \" <3\", \" =)\", \" ^_^\", \" ;-)\", \" :-)\"]"
let newPos = "[\"!!\", \" :)\", \" :D\", \" XD\", \" xD\", \" ~\", \" :P\", \" <3\", \" =)\", \" ^_^\", \" rn\", \" RN\", \" fr\", \" tbh\"]"
content = content.replacingOccurrences(of: oldPos, with: newPos)

// Replace sad/jealous arrays
let oldSad = "[\" :(\", \" :((\", \" >:(\", \" :/\", \" ;-((?=\")\", \" -_-\", \" >_<\", \"...\"]" // wait, let's just do it directly
let oldSadActual = "[\" :(\", \" :((\", \" >:(\", \" :/\", \" ;-<\", \" -_-\", \" >_<\", \"...\"]" // wait, no it was ;-(
let oldSadReal = "[\" :(\", \" :((\", \" >:(\", \" :/\", \" ;-o\", \" -_-\", \" >_<\", \"...\"]" // no, look at the file.
// It is " ;-("
content = content.replacingOccurrences(
    of: "[\" :(\", \" :((\", \" >:(\", \" :/\", \" ;-C\", \" -_-\", \" >_<\", \"...\"]".replacingOccurrences(of: "C", with: "("),
    with: "[\" :(\", \" :((\", \" >:(\", \" :/\", \" ;-C\", \" -_-\", \" >_<\", \"...\", \" rn\", \" fr\", \" tbh\", \" ngl\", \" smh\"]".replacingOccurrences(of: "C", with: "(")
)

// Replace competitive arrays
let oldComp = "[\" >:)\", \" !!\", \" !!!\", \" >\"]"
let newComp = "[\" >:)\", \" !!\", \" !!!\", \" >\", \" XD\", \" RN\", \" rn\", \" fr\", \" tbh\", \" ngl\"]"
content = content.replacingOccurrences(of: oldComp, with: newComp)

try content.write(toFile: path, atomically: true, encoding: .utf8)
print("Symbols added successfully via script!")
