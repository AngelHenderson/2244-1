import SwiftUI

// MARK: - Rename Sheet

struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    var current: String
    var onSave: @MainActor (String) async -> Bool

    @State private var name: String = ""
    @State private var saving = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Player Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                if failed {
                    Text("Could not save name. Try again.").foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            saving = true
                            failed = !(await onSave(name))
                            saving = false
                            if !failed { dismiss() }
                        }
                    }.disabled(name.trimmed().isEmpty || saving)
                }
            }
        }
        .onAppear { name = current }
    }
}

// MARK: - Avatar Customize View

struct AvatarCustomizeView: View {
    let currentAvatar: String
    let onSelect: @MainActor (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAvatar: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose Avatar")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 20)], spacing: 20) {
                        ForEach(AvatarCatalog.all) { option in
                            Button {
                                selectedAvatar = option.id
                                onSelect(option.id)
                            } label: {
                                AvatarBadge(option: option, size: 90)
                                    .overlay(alignment: .topTrailing) {
                                        if selectedAvatar == option.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                                .shadow(radius: 2)
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                    .scaleEffect(selectedAvatar == option.id ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedAvatar)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Cosmetics are purely for fun and do not affect gameplay.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Customize Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .confirmationAction) { 
                    Button("Done") { dismiss() } 
                } 
            }
        }
        .onAppear { selectedAvatar = currentAvatar }
    }
}

// MARK: - Season History View

struct SeasonHistoryView: View {
    var season: SeasonInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Current") {
                    HStack {
                        Label("\(season.name)", systemImage: "calendar")
                        Spacer()
                        Text(season.division).foregroundStyle(.secondary)
                    }
                }
                Section("Past Seasons") {
                    ForEach(1..<7) { i in
                        HStack {
                            Label("Season \(i)", systemImage: "calendar")
                            Spacer()
                            Text(["Bronze","Silver","Gold","Platinum","Diamond","Mythic"].randomElement()!)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Season History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .cancellationAction) { 
                    Button("Close") { dismiss() } 
                } 
            }
        }
    }
}

// MARK: - Compare View

struct CompareView: View {
    var friendCode: String
    var myProfile: CompareProfile
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedPlayer: MockPlayer?

    private let mockPlayers: [MockPlayer] = MockPlayer.generateAll()

    private var filteredPlayers: [MockPlayer] {
        let query = searchText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        // Filter by any letters typed (contains match), sort alphabetically by code, limit to 50
        return mockPlayers
            .filter { $0.code.uppercased().contains(query) }
            .prefix(50)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Code") {
                    HStack {
                        Text(friendCode).font(.body.monospaced())
                        Spacer()
                        Button("Copy") {
                            #if os(iOS)
                            UIPasteboard.general.string = friendCode
                            #endif
                        }
                    }
                }

                Section("Compare With") {
                    TextField("Search codes (e.g., A or XY)", text: $searchText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, _ in
                            selectedPlayer = nil
                        }
                }

                if !filteredPlayers.isEmpty && selectedPlayer == nil {
                    Section("Players (\(filteredPlayers.count))") {
                        ForEach(filteredPlayers) { player in
                            HStack {
                                Text(player.countryFlag)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(player.code)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Compare") {
                                    selectedPlayer = player
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                if let player = selectedPlayer {
                    Section {
                        VStack(spacing: 16) {
                            HStack(alignment: .top, spacing: 20) {
                                // Your profile
                                VStack(spacing: 8) {
                                    Text(myProfile.countryFlag)
                                        .font(.largeTitle)
                                    Text("You")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(myProfile.milestone)
                                        .font(.title2.bold())
                                }
                                .frame(maxWidth: .infinity)

                                Text("vs")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 20)

                                // Their profile
                                VStack(spacing: 8) {
                                    Text(player.countryFlag)
                                        .font(.largeTitle)
                                    Text(player.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("—")
                                        .font(.title2.bold())
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)

                            Text("Milestone data requires server connection")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } header: {
                        HStack {
                            Text("Comparing with \(player.name)")
                            Spacer()
                            Button {
                                selectedPlayer = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Compare Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Milestone Comparison Helpers

    /// Compares two milestone strings and returns comparison result
    /// Returns: 1 if a > b, -1 if a < b, 0 if equal
    private func compareMilestones(_ a: String, _ b: String) -> Int {
        let aVal = parseMilestone(a)
        let bVal = parseMilestone(b)
        if aVal > bVal { return 1 }
        if aVal < bVal { return -1 }
        return 0
    }

    /// Parses a milestone string (e.g., "256K", "1M", "32a") into a numeric value for comparison
    private func parseMilestone(_ str: String) -> Double {
        var s = str.uppercased()
        var multiplier: Double = 1

        // Handle letter suffixes (a, b, c, ... after B)
        if let last = s.last, last.isLetter {
            let suffix = String(last)
            s = String(s.dropLast())

            switch suffix {
            case "K": multiplier = 1_000
            case "M": multiplier = 1_000_000
            case "B": multiplier = 1_000_000_000
            default:
                // Extended suffixes: a = 10^12, b = 10^15, etc.
                if let asciiVal = suffix.lowercased().first?.asciiValue {
                    let letterIndex = Int(asciiVal) - Int(Character("a").asciiValue!)
                    multiplier = pow(10, Double(12 + letterIndex * 3))
                }
            }
        }
        return (Double(s) ?? 0) * multiplier
    }
}

// MARK: - Mock Player Data

struct MockPlayer: Identifiable {
    let id: String
    let name: String
    let code: String
    let countryCode: String

    var countryFlag: String {
        let base: UInt32 = 0x1F1E6
        return countryCode.uppercased().unicodeScalars.compactMap { scalar -> String? in
            guard let flag = UnicodeScalar(base + scalar.value - 65) else { return nil }
            return String(flag)
        }.joined()
    }

    static func generateAll() -> [MockPlayer] {
        // Use the same name lists as MockLeaderboardData for consistency
        let gamertags = MockLeaderboardData.globalNames
        let realisticNames = MockLeaderboardData.realNames
        // Only countries that have leaderboard data
        // Update this list when new country leaderboards are added
        let countries = [
            "US", "GB", "CA", "AU",  // US, UK, Canada, Australia
            "DE", "FR", "JP", "IN",  // Germany, France, Japan, India
            "BR", "MX", "CN", "KR",  // Brazil, Mexico, China, South Korea
            "IT", "ES", "NL", "CH",  // Italy, Spain, Netherlands, Switzerland
            "NO", "DK", "FI", "PL",  // Norway, Denmark, Finland, Poland
            "AF", "AL", "DZ"         // Afghanistan, Albania, Algeria
        ]

        var players: [MockPlayer] = []
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let digits = Array("0123456789")

        // Generate ~200 mock players with varied codes
        // Codes have mixed letters/numbers in any position (e.g., A1B-2C3, 1A2-B3C)
        for i in 0..<200 {
            let seed = i * 7 + 13

            // Generate 6 alphanumeric characters with varied letter/number positions
            func char(at pos: Int) -> Character {
                let charSeed = seed * (pos + 1) * 11
                let useDigit = (charSeed % 3) == 0  // ~33% digits, ~67% letters
                if useDigit {
                    return digits[(charSeed / 3) % 10]
                } else {
                    return letters[(charSeed / 2) % 26]
                }
            }

            let c1 = char(at: 0)
            let c2 = char(at: 1)
            let c3 = char(at: 2)
            let c4 = char(at: 3)
            let c5 = char(at: 4)
            let c6 = char(at: 5)
            let code = "\(c1)\(c2)\(c3)-\(c4)\(c5)\(c6)"

            // Name distribution based on ranking bracket
            // Top 150: 85% gamertag, 15% realistic
            // Extended (150+): 30% gamertag, 70% realistic
            let useGamertag: Bool
            let roll = (seed * 17) % 100
            if i < 150 {
                useGamertag = roll < 85
            } else {
                useGamertag = roll < 30
            }

            let name: String
            if useGamertag {
                name = gamertags[(seed * 3) % gamertags.count]
            } else {
                name = realisticNames[(seed * 5) % realisticNames.count]
            }

            let player = MockPlayer(
                id: code,
                name: name,
                code: code,
                countryCode: countries[seed % countries.count]
            )
            players.append(player)
        }
        return players.sorted { $0.code < $1.code }
    }
}

// MARK: - Compare Profile Data

struct CompareProfile {
    let name: String
    let score: String
    let milestone: String
    let countryFlag: String
    let avatar: String
}

// MARK: - Comparison Row (kept for potential future use)

private struct ComparisonRow: View {
    let label: String
    let myValue: String
    let theirValue: String
    var highlightWinner: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text(myValue)
                .fontWeight(highlightWinner && isMyValueBetter ? .bold : .regular)
                .foregroundColor(highlightWinner && isMyValueBetter ? .green : .primary)
            Text("vs")
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            Text(theirValue)
                .fontWeight(highlightWinner && !isMyValueBetter && myValue != theirValue ? .bold : .regular)
                .foregroundColor(highlightWinner && !isMyValueBetter && myValue != theirValue ? .green : .primary)
        }
        .font(.subheadline)
    }

    private var isMyValueBetter: Bool {
        // Simple comparison - works for scores/milestones formatted as numbers with K/M/B suffix
        compareValues(myValue, theirValue) > 0
    }

    private func compareValues(_ a: String, _ b: String) -> Int {
        let aNum = parseValue(a)
        let bNum = parseValue(b)
        if aNum > bNum { return 1 }
        if aNum < bNum { return -1 }
        return 0
    }

    private func parseValue(_ str: String) -> Double {
        var s = str.uppercased()
        var multiplier: Double = 1
        if s.hasSuffix("B") {
            multiplier = 1_000_000_000
            s = String(s.dropLast())
        } else if s.hasSuffix("M") {
            multiplier = 1_000_000
            s = String(s.dropLast())
        } else if s.hasSuffix("K") {
            multiplier = 1_000
            s = String(s.dropLast())
        }
        return (Double(s) ?? 0) * multiplier
    }
}

// MARK: - Helpers

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}