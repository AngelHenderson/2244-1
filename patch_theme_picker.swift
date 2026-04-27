import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/ThemePickerView.swift"
var content = try! String(contentsOfFile: path)

content = content.replacingOccurrences(of: "Color(.secondarySystemGroupedBackground)", with: "Color.gray.opacity(0.1)")
content = content.replacingOccurrences(of: "Button(action: onSelect)", with: "Button(action: { onSelect() })")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Fixed ThemePickerView")
