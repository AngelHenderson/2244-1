import SwiftUI

public struct TilesInfoView: View {
    @Environment(\.dismiss) private var dismiss

    // Color palette for tiles
    private let colors: [Color] = [
        Color(hex: "5DADE2"), Color(hex: "E74C9C"), Color(hex: "F4D03F"),
        Color(hex: "58D68D"), Color(hex: "48C9B0"), Color(hex: "F5B041"),
        Color(hex: "52BE80"), Color(hex: "F1948A"), Color(hex: "BB8FCE"),
        Color(hex: "85C1E9"), Color(hex: "F7DC6F"), Color(hex: "82E0AA"),
        Color(hex: "F8C471"), Color(hex: "D7BDE2"), Color(hex: "A9DFBF"),
        Color(hex: "FAD7A0"), Color(hex: "AED6F1"), Color(hex: "F9E79F"),
        Color(hex: "D5F5E3"), Color(hex: "FADBD8"), Color(hex: "E8DAEF"),
        Color(hex: "D4E6F1"), Color(hex: "FCF3CF"), Color(hex: "D5D8DC"),
        Color(hex: "ABEBC6"), Color(hex: "F5B7B1"), Color(hex: "D2B4DE"),
        Color(hex: "A9CCE3"), Color(hex: "F9E79F"), Color(hex: "85C1E9")
    ]

    // Generate all tile info including double letters
    private var tileInfo: [(abbrev: String, exponent: Int, sample: String, color: Color)] {
        var info: [(abbrev: String, exponent: Int, sample: String, color: Color)] = []

        // Single letters: K, M, B
        info.append(("K", 3, "16K", colors[0]))
        info.append(("M", 6, "1M", colors[1]))
        info.append(("B", 9, "1B", colors[2]))

        // Single letters: a-z (exponents 12, 15, 18, ... 87)
        let letters = "abcdefghijklmnopqrstuvwxyz"
        for (index, letter) in letters.enumerated() {
            let exponent = 12 + (index * 3)
            let abbrev = String(letter)
            info.append((abbrev, exponent, "1\(abbrev)", colors[(index + 3) % colors.count]))
        }

        // Double letters: aa-az (exponents 90, 93, ... 165)
        for (index, secondLetter) in letters.enumerated() {
            let exponent = 90 + (index * 3)
            let abbrev = "a\(secondLetter)"
            info.append((abbrev, exponent, "1\(abbrev)", colors[(index) % colors.count]))
        }

        // Double letters: ba-bz (exponents 168, 171, ... 243)
        for (index, secondLetter) in letters.enumerated() {
            let exponent = 168 + (index * 3)
            let abbrev = "b\(secondLetter)"
            info.append((abbrev, exponent, "1\(abbrev)", colors[(index + 10) % colors.count]))
        }

        return info
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(tileInfo, id: \.abbrev) { info in
                        TileInfoRow(
                            sample: info.sample,
                            abbrev: info.abbrev,
                            exponent: info.exponent,
                            color: info.color
                        )
                    }

                    // Infinity row at the end
                    InfinityRow()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tiles Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                    }
                }
            }
        }
    }
}

private struct TileInfoRow: View {
    let sample: String
    let abbrev: String
    let exponent: Int
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Sample tile
            Text(sample)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color, in: RoundedRectangle(cornerRadius: 10))

            // Abbreviation = exponent
            HStack(spacing: 4) {
                Text(abbrev)
                    .font(.title2.bold())

                Text(":")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                // 10^exponent with superscript
                HStack(alignment: .top, spacing: 0) {
                    Text("10")
                        .font(.title2)
                    Text("\(exponent)")
                        .font(.caption.bold())
                        .baselineOffset(10)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfinityRow: View {
    var body: some View {
        HStack(spacing: 16) {
            // Infinity tile
            Image(systemName: "infinity")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            // Infinity description
            HStack(spacing: 4) {
                Image(systemName: "infinity")
                    .font(.title2.bold())

                Text(":")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("The Goal!")
                    .font(.title3.bold())
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TilesInfoView()
}
