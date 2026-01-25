import SwiftUI

public struct TilesInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentTheme) private var currentTheme
    @State private var isShowingAbbreviations: Bool = false

    public init() {}

    /// Get color for step from current theme, with fallback to default
    private func themedColor(forStep step: Int) -> Color {
        currentTheme?.colorForStep(step) ?? Theme.colorForStep(step)
    }

    /// Get text color for step from current theme, with fallback to default
    private func themedTextColor(forStep step: Int) -> Color {
        currentTheme?.textColorForStep(step) ?? Theme.textColorForStep(step)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Rule 1
                    BulletPoint(text: "Join One Or More Same Numbers To Merge Them.")

                    // Rule 2
                    BulletPoint(text: "The Same Block Can Be Merged In Horizontally, Vertically And Diagonally.")

                    // Rule 3 with visual
                    BulletPoint(text: "If You Join And Merge 2 Same Number Blocks, You Will Get A Higher Number, Eg Merging")

                    // 2 + 2 = 4 visual (using actual gameplay colors from current theme)
                    HStack(spacing: 12) {
                        Spacer()
                        TileBlock(value: "2", color: themedColor(forStep: 0))  // 2 = 2^1, step 0
                        Text("+")
                            .font(.title2.bold())
                        TileBlock(value: "2", color: themedColor(forStep: 0))
                        Text("=")
                            .font(.title2.bold())
                        TileBlock(value: "4", color: themedColor(forStep: 1))  // 4 = 2^2, step 1
                        Spacer()
                    }

                    // Rule 4 with visual
                    BulletPoint(text: "Join 2 Same Number Blocks And 1 Higher Number Block, It Will Become")

                    // 2 + 2 + 4 = 8 visual (using actual gameplay colors from current theme)
                    HStack(spacing: 8) {
                        Spacer()
                        TileBlock(value: "2", color: themedColor(forStep: 0))  // 2 = 2^1, step 0
                        Text("+")
                            .font(.title3.bold())
                        TileBlock(value: "2", color: themedColor(forStep: 0))
                        Text("+")
                            .font(.title3.bold())
                        TileBlock(value: "4", color: themedColor(forStep: 1))  // 4 = 2^2, step 1
                        Text("=")
                            .font(.title3.bold())
                        TileBlock(value: "8", color: themedColor(forStep: 2))  // 8 = 2^3, step 2
                        Spacer()
                    }

                    // Goal rule
                    BulletPoint(text: "The Goal Is To Create The Highest Number Block Possible Which Is")

                    // Infinity visual
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                            Image(systemName: "infinity")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }

                    // Abbreviations section
                    BulletPoint(text: "For Abbreviations")

                    // Click Here button
                    HStack {
                        Spacer()
                        Button {
                            isShowingAbbreviations = true
                        } label: {
                            Text("Click Here")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(hex: "4A4A4A"), in: RoundedRectangle(cornerRadius: 8))
                        }
                        Spacer()
                    }
                }
                .padding(24)
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
            .navigationDestination(isPresented: $isShowingAbbreviations) {
                AbbreviationsListView()
            }
        }
    }
}

// MARK: - Bullet Point

private struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.primary)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(text)
                .font(.body.weight(.medium))
        }
    }
}

// MARK: - Tile Block

private struct TileBlock: View {
    let value: String
    let color: Color

    var body: some View {
        Text(value)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Abbreviations List View

private struct AbbreviationsListView: View {
    @Environment(\.currentTheme) private var currentTheme

    /// Get color for step from current theme, with fallback to default
    private func themedColor(forStep step: Int) -> Color {
        currentTheme?.colorForStep(step) ?? Theme.colorForStep(step)
    }

    /// Get text color for step from current theme, with fallback to default
    private func themedTextColor(forStep step: Int) -> Color {
        currentTheme?.textColorForStep(step) ?? Theme.textColorForStep(step)
    }

    /// Convert a base-10 exponent to the approximate game tile step (0-based)
    /// Formula: step = (base10Exp / 3) * 10 - 1
    /// This maps M(10^6)→step 19, B(10^9)→step 29, a(10^12)→step 39, etc.
    private func stepForBase10Exponent(_ exp: Int) -> Int {
        return (exp / 3) * 10 - 1
    }

    // Generate all tile info including double letters
    // overrideColor allows specific entries to use a fixed color instead of theme color
    private var tileInfo: [(abbrev: String, exponent: Int, sample: String, step: Int, overrideColor: Color?)] {
        var info: [(abbrev: String, exponent: Int, sample: String, step: Int, overrideColor: Color?)] = []

        // Single letters: K, M, B
        // K is special: sample "16K" = 16,384 = 2^14 → step 13
        // M: 1M ≈ 2^20 → step 19
        info.append(("K", 3, "16K", 13, nil))
        info.append(("M", 6, "1M", 19, nil))
        info.append(("B", 9, "1B", stepForBase10Exponent(9), nil))

        // Single letters: a-z (exponents 12, 15, 18, ... 87)
        let letters = "abcdefghijklmnopqrstuvwxyz"
        for (index, letter) in letters.enumerated() {
            let exponent = 12 + (index * 3)
            let abbrev = String(letter)
            info.append((abbrev, exponent, "1\(abbrev)", stepForBase10Exponent(exponent), nil))
        }

        // Double letters: aa-az (exponents 90, 93, ... 165)
        for (index, secondLetter) in letters.enumerated() {
            let exponent = 90 + (index * 3)
            let abbrev = "a\(secondLetter)"
            info.append((abbrev, exponent, "1\(abbrev)", stepForBase10Exponent(exponent), nil))
        }

        // Double letters: ba-bz (exponents 168, 171, ... 243)
        for (index, secondLetter) in letters.enumerated() {
            let exponent = 168 + (index * 3)
            let abbrev = "b\(secondLetter)"
            info.append((abbrev, exponent, "1\(abbrev)", stepForBase10Exponent(exponent), nil))
        }

        return info
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(tileInfo, id: \.abbrev) { info in
                    TileInfoRow(
                        sample: info.sample,
                        abbrev: info.abbrev,
                        exponent: info.exponent,
                        color: info.overrideColor ?? themedColor(forStep: info.step),
                        textColor: themedTextColor(forStep: info.step)
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
    }
}

// MARK: - Tile Info Row

private struct TileInfoRow: View {
    let sample: String
    let abbrev: String
    let exponent: Int
    let color: Color
    var textColor: Color = .white

    var body: some View {
        HStack(spacing: 16) {
            // Sample tile
            Text(sample)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
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

// MARK: - Infinity Row

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

#Preview("Abbreviations") {
    NavigationStack {
        AbbreviationsListView()
    }
}
