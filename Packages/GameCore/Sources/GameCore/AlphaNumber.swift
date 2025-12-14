import Foundation

/// Arbitrary-precision non-negative integer that uses base-1000 chunks.
/// Designed specifically for score tracking so we can preserve extremely large values
/// without overflowing `Int`.
public struct AlphaNumber: Equatable, Sendable, Codable, Comparable {
    private static let base: UInt16 = 1_000
    private var chunks: [UInt16] // Little-endian, chunks[0] is lowest 3 digits

    public static let zero = AlphaNumber()

    public init() {
        self.chunks = [0]
    }

    public init(_ value: Int) {
        self.init()
        if value <= 0 {
            return
        }
        var remaining = value
        var digits: [UInt16] = []
        while remaining > 0 {
            let chunk = remaining % Int(Self.base)
            digits.append(UInt16(chunk))
            remaining /= Int(Self.base)
        }
        self.chunks = digits
        normalize()
    }

    public init?(decimalString: String) {
        self.init()
        let trimmed = decimalString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let filtered = trimmed.filter { $0.isNumber }
        guard !filtered.isEmpty else { return nil }

        var start = filtered.endIndex
        var digits: [UInt16] = []
        while start > filtered.startIndex {
            let lower = filtered.index(start, offsetBy: -3, limitedBy: filtered.startIndex) ?? filtered.startIndex
            let chunkString = String(filtered[lower..<start])
            guard let value = UInt16(chunkString) else { return nil }
            digits.append(value)
            start = lower
        }
        self.chunks = digits
        normalize()
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.singleValueContainer()
        if let chunkArray = try? container.decode([UInt16].self) {
            self.chunks = chunkArray
            normalize()
        } else if let stringValue = try? container.decode(String.self),
                  let parsed = AlphaNumber(decimalString: stringValue) {
            self = parsed
        } else if let intValue = try? container.decode(Int.self) {
            self.init(intValue)
        } else {
            self.init()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(chunks)
    }

    // MARK: - Basic properties

    public var isZero: Bool {
        chunks.count == 1 && chunks[0] == 0
    }

    public func toInt(clamping: Bool = true) -> Int {
        var result = 0
        for index in chunks.indices.reversed() {
            let chunk = Int(chunks[index])
            if result > (Int.max / Int(Self.base)) {
                return clamping ? Int.max : result
            }
            result *= Int(Self.base)
            if result > Int.max - chunk {
                return clamping ? Int.max : result
            }
            result += chunk
        }
        return result
    }

    public var decimalString: String {
        guard let highest = highestNonZeroIndex else { return "0" }
        var output = "\(chunks[highest])"
        if highest > 0 {
            for index in stride(from: highest - 1, through: 0, by: -1) {
                output += String(format: "%03d", chunks[index])
            }
        }
        return output
    }

    // MARK: - Arithmetic

    public mutating func add(_ other: AlphaNumber) {
        let maxCount = max(chunks.count, other.chunks.count)
        if chunks.count < maxCount {
            chunks.append(contentsOf: repeatElement(0, count: maxCount - chunks.count))
        }

        var carry = 0
        for index in 0..<maxCount {
            let lhs = Int(chunks[safe: index] ?? 0)
            let rhs = Int(other.chunks[safe: index] ?? 0)
            let sum = lhs + rhs + carry
            chunks[index] = UInt16(sum % Int(Self.base))
            carry = sum / Int(Self.base)
        }

        if carry > 0 {
            chunks.append(UInt16(carry))
        }
    }

    public mutating func add(_ value: Int) {
        guard value > 0 else { return }
        var carry = value
        var index = 0
        while carry > 0 {
            if index >= chunks.count {
                chunks.append(0)
            }
            let sum = Int(chunks[index]) + carry
            chunks[index] = UInt16(sum % Int(Self.base))
            carry = sum / Int(Self.base)
            index += 1
        }
    }

    public mutating func addPowerStep(_ step: Int) {
        guard step >= 0 else { return }
        add(AlphaNumber.powerOfTwo(step: step))
    }

    public mutating func multiply(by multiplier: Int) {
        guard multiplier > 0 else {
            self = .zero
            return
        }
        if multiplier == 1 { return }

        var carry = 0
        for index in 0..<chunks.count {
            let product = Int(chunks[index]) * multiplier + carry
            chunks[index] = UInt16(product % Int(Self.base))
            carry = product / Int(Self.base)
        }
        while carry > 0 {
            chunks.append(UInt16(carry % Int(Self.base)))
            carry /= Int(Self.base)
        }
    }

    public mutating func halve() {
        var remainder = 0
        for index in chunks.indices.reversed() {
            let current = Int(chunks[index]) + remainder * Int(Self.base)
            chunks[index] = UInt16(current / 2)
            remainder = current % 2
        }
        normalize()
    }

    public func formattedLabel() -> String {
        let ints = chunks.map { Int($0) }
        return TileStepLabelFormatter.label(fromChunks: ints)
    }

    /// Returns the score formatted with commas and a tier suffix (e.g., "16,497K", "1,000M")
    /// Shows full number up to 999,999, then abbreviates with K, M, B, a, b, c...
    public func formattedWithCommas() -> String {
        let chunkCount = chunks.count

        // For numbers < 1,000,000 (1 or 2 chunks), show full number with commas
        if chunkCount <= 2 {
            return formatChunksWithCommas(chunks)
        }

        // For numbers >= 1,000,000, keep at most 2 chunks displayed (max 999,999)
        // Drop extra chunks and use tier suffix
        let chunksToDrop = chunkCount - 2
        let displayChunks = Array(chunks.dropFirst(chunksToDrop))
        let formatted = formatChunksWithCommas(displayChunks)
        let suffix = tierSuffix(for: chunksToDrop)

        return "\(formatted)\(suffix)"
    }

    private func tierSuffix(for droppedChunks: Int) -> String {
        switch droppedChunks {
        case 1: return "K"
        case 2: return "M"
        case 3: return "B"
        default:
            let letterIndex = droppedChunks - 3
            return alphabeticSuffix(for: letterIndex)
        }
    }

    private func alphabeticSuffix(for index: Int) -> String {
        var i = index
        var result = ""
        while i > 0 {
            let rem = (i - 1) % 26
            let char = Character(UnicodeScalar(97 + rem)!)
            result = String(char) + result
            i = (i - 1) / 26
        }
        return result
    }

    private func formatChunksWithCommas(_ chunks: [UInt16]) -> String {
        guard !chunks.isEmpty else { return "0" }
        var result = ""
        for (index, chunk) in chunks.reversed().enumerated() {
            if index == 0 {
                result = "\(chunk)"
            } else {
                result += ",\(String(format: "%03d", chunk))"
            }
        }
        return result
    }

    // MARK: - Comparable

    public static func < (lhs: AlphaNumber, rhs: AlphaNumber) -> Bool {
        let lhsIndex = lhs.highestNonZeroIndex ?? 0
        let rhsIndex = rhs.highestNonZeroIndex ?? 0
        if lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        for index in stride(from: lhsIndex, through: 0, by: -1) {
            let left = lhs.chunks[safe: index] ?? 0
            let right = rhs.chunks[safe: index] ?? 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    // MARK: - Helpers

    private mutating func normalize() {
        while chunks.count > 1, chunks.last == 0 {
            chunks.removeLast()
        }
        if chunks.isEmpty {
            chunks = [0]
        }
    }

    private var highestNonZeroIndex: Int? {
        for index in chunks.indices.reversed() where chunks[index] != 0 {
            return index
        }
        return chunks.first == 0 ? nil : chunks.count - 1
    }

    public static func powerOfTwo(step: Int) -> AlphaNumber {
        precondition(step >= 0, "step must be non-negative")
        if step == 0 {
            return AlphaNumber(2)
        }
        var value = AlphaNumber(2)
        for _ in 0..<step {
            value.multiply(by: 2)
        }
        return value
    }
}

private extension Array where Element == UInt16 {
    subscript(safe index: Int) -> UInt16? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
