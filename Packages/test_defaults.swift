import Foundation
UserDefaults.standard.set(["a": 123.45], forKey: "testKey")
let dict = UserDefaults.standard.dictionary(forKey: "testKey") as? [String: Double] ?? [:]
print(dict)
