import Foundation
UserDefaults.standard.set(["a": 123.45], forKey: "testKey2")
let dict1 = UserDefaults.standard.dictionary(forKey: "testKey2") as? [String: Double]
let dict2 = UserDefaults.standard.dictionary(forKey: "testKey2")
print("dict1:", dict1 != nil)
print("dict2:", dict2 != nil)
