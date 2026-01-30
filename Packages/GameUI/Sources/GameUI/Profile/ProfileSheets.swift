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
    @State private var selectedPlayers: [MockPlayer] = []

    private let mockPlayers: [MockPlayer] = MockPlayer.generateAll()
    private let maxCompareCount = 5

    private var filteredPlayers: [MockPlayer] {
        let query = searchText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        // Filter by any letters typed (contains match), exclude already selected, limit to 50
        let selectedIDs = Set(selectedPlayers.map { $0.id })
        return mockPlayers
            .filter { $0.code.uppercased().contains(query) && !selectedIDs.contains($0.id) }
            .prefix(50)
            .map { $0 }
    }

    /// All valid milestones in progression order (doubling pattern)
    private static let allMilestones: [String] = [
        // Score 0 and lowest milestones (2-512)
        "0", "2", "4", "8", "16", "32", "64", "128", "256", "512",
        // Raw numbers and K-tier (thousands)
        "1024", "2048", "4096", "8192", "16K", "32K", "65K", "131K", "262K", "524K",
        // M-tier (millions)
        "1M", "2M", "4M", "8M", "16M", "33M", "67M", "134M", "268M", "536M",
        "1B", "2B", "4B", "8B", "17B", "34B", "68B", "137B", "274B", "549B",
        "1a", "2a", "4a", "8a", "17a", "35a", "70a", "140a", "281a", "562a",
        "1b", "2b", "4b", "9b", "18b", "36b", "72b", "144b", "288b", "576b",
        "1c", "2c", "4c", "9c", "18c", "36c", "73c", "147c", "295c", "590c",
        "1d", "2d", "4d", "9d", "18d", "37d", "75d", "151d", "302d", "604d",
        "1e", "2e", "4e", "9e", "19e", "38e", "77e", "154e", "309e", "618e",
        "1f", "2f", "4f", "9f", "19f", "39f", "79f", "158f", "316f", "633f",
        "1g", "2g", "5g", "10g", "20g", "40g", "81g", "162g", "324g", "649g",
        "1h", "2h", "5h", "10h", "20h", "41h", "83h", "166h", "332h", "664h",
        "1i", "2i", "5i", "10i", "21i", "42i", "85i", "170i", "340i", "680i",
        "1j", "2j", "5j", "10j", "21j", "43j", "87j", "174j", "348j", "696j",
        "1k", "2k", "5k", "11k", "22k", "44k", "89k", "178k", "356k", "713k",
        "1l", "2l", "5l", "11l", "22l", "45l", "91l", "182l", "365l", "730l",
        "1m", "2m", "5m", "11m", "23m", "46m", "93m", "187m", "374m", "748m",
        "1n", "2n", "5n", "11n", "23n", "47n", "95n", "191n", "383n", "766n",
        "1o", "3o", "6o", "12o", "24o", "49o", "98o", "196o", "392o", "784o",
        "1p", "3p", "6p", "12p", "25p", "50p", "100p", "200p", "401p", "803p",
        "1q", "3q", "6q", "12q", "25q", "51q", "102q", "205q", "411q", "822q",
        "1r", "3r", "6r", "13r", "26r", "52r", "105r", "210r", "421r", "842r",
        "1s", "3s", "6s", "13s", "26s", "53s", "107s", "215s", "431s", "862s",
        "1t", "3t", "6t", "13t", "27t", "55t", "110t", "220t", "441t", "883t",
        "1u", "3u", "7u", "14u", "28u", "56u", "113u", "226u", "452u", "904u",
        "1v", "3v", "7v", "14v", "28v", "57v", "115v", "231v", "463v", "926v",
        "1w", "3w", "7w", "14w", "29w", "59w", "118w", "237w", "474w", "948w",
        "1x", "3x", "7x", "15x", "30x", "60x", "121x", "242x", "485x", "971x",
        "1y", "3y", "7y", "15y", "31y", "62y", "124y", "248y", "497y", "994y",
        "1z", "3z", "7z", "15z", "31z", "63z", "127z", "254z", "509z", "1aa",
        "2aa", "4aa", "8aa", "16aa", "32aa", "65aa", "130aa", "260aa", "521aa", "1ab",
        "2ab", "4ab", "8ab", "16ab", "33ab", "66ab", "133ab", "266ab", "533ab", "1ac",
        "2ac", "4ac", "8ac", "17ac", "34ac", "68ac", "136ac", "273ac", "546ac", "1ad",
        "2ad", "4ad", "8ad", "17ad", "34ad", "69ad", "139ad", "279ad", "559ad", "1ae",
        "2ae", "4ae", "8ae", "17ae", "35ae", "71ae", "143ae", "286ae", "573ae", "1af",
        "2af", "4af", "9af", "18af", "36af", "73af", "146af", "293af", "587af", "1ag",
        "2ag", "4ag", "9ag", "18ag", "37ag", "75ag", "150ag", "300ag", "601ag", "1ah",
        "2ah", "4ah", "9ah", "19ah", "38ah", "76ah", "153ah", "307ah", "615ah", "1ai",
        "2ai", "4ai", "9ai", "19ai", "39ai", "78ai", "157ai", "315ai", "630ai", "1aj",
        "2aj", "5aj", "10aj", "20aj", "40aj", "80aj", "161aj", "322aj", "645aj", "1ak",
        "2ak", "5ak", "10ak", "20ak", "41ak", "82ak", "165ak", "330ak", "661ak", "1al",
        "2al", "5al", "10al", "21al", "42al", "84al", "169al", "338al", "676al", "1am",
        "2am", "5am", "10am", "21am", "43am", "86am", "173am", "346am", "693am", "1an",
        "2an", "5an", "11an", "22an", "44an", "88an", "177an", "354an", "709an", "1ao",
        "2ao", "5ao", "11ao", "22ao", "45ao", "90ao", "181ao", "363ao", "726ao", "1ap",
        "2ap", "5ap", "11ap", "23ap", "46ap", "93ap", "186ap", "372ap", "744ap", "1aq",
        "2aq", "5aq", "11aq", "23aq", "47aq", "95aq", "190aq", "381aq", "762aq", "1ar",
        "3ar", "6ar", "12ar", "24ar", "48ar", "97ar", "195ar", "390ar", "780ar", "1as",
        "3as", "6as", "12as", "24as", "49as", "99as", "199as", "399as", "799as", "1at",
        "3at", "6at", "12at", "25at", "51at", "102at", "204at", "409at", "818at", "1au",
        "3au", "6au", "13au", "26au", "52au", "105au", "209au", "419au", "837au", "1av",
        "3av", "6av", "13av", "27av", "54av", "107av", "214av", "429av", "858av", "1aw",
        "3aw", "6aw", "13aw", "27aw", "55aw", "110aw", "220aw", "439aw", "878aw", "1ax",
        "3ax", "7ax", "14ax", "28ax", "56ax", "112ax", "224ax", "449ax", "899ax", "1ay",
        "3ay", "7ay", "14ay", "28ay", "57ay", "115ay", "230ay", "460ay", "921ay", "1az",
        "3az", "7az", "14az", "29az", "58az", "117az", "235az", "471az", "943az", "1ba",
        "3ba", "7ba", "15ba", "30ba", "60ba", "120ba", "241ba", "483ba", "966ba", "1bb",
        "3bb", "7bb", "15bb", "30bb", "61bb", "123bb", "247bb", "494bb", "989bb", "1bc",
        "3bc", "7bc", "15bc", "31bc", "63bc", "126bc", "253bc", "506bc", "1bd",
        "2bd", "4bd", "8bd", "16bd", "32bd", "64bd", "129bd", "259bd", "518bd", "1be",
        "2be", "4be", "8be", "16be", "33be", "66be", "132be", "265be", "531be", "1bf",
        "2bf", "4bf", "8bf", "16bf", "33bf", "67bf", "135bf", "271bf", "543bf", "1bg",
        "2bg", "4bg", "8bg", "17bg", "34bg", "69bg", "139bg", "278bg", "556bg", "1bh",
        "2bh", "4bh", "8bh", "17bh", "35bh", "71bh", "142bh", "285bh", "570bh", "1bi",
        "2bi", "4bi", "9bi", "18bi", "36bi", "72bi", "145bi", "291bi", "583bi", "1bj",
        "2bj", "4bj", "9bj", "18bj", "37bj", "74bj", "149bj", "298bj", "598bj", "1bk",
        "2bk", "4bk", "9bk", "19bk", "38bk", "76bk", "152bk", "306bk", "612bk", "1bl",
        "2bl", "4bl", "9bl", "19bl", "39bl", "78bl", "156bl", "313bl", "627bl", "1bm",
        "2bm", "5bm", "10bm", "20bm", "40bm", "80bm", "160bm", "321bm", "642bm", "1bn",
        "2bn", "5bn", "10bn", "20bn", "41bn", "82bn", "164bn", "328bn", "657bn", "1bo",
        "2bo", "5bo", "10bo", "21bo", "42bo", "84bo", "168bo", "336bo", "673bo", "1bp",
        "2bp", "5bp", "10bp", "21bp", "43bp", "86bp", "172bp", "345bp", "689bp", "1bq",
        "2bq", "5bq", "11bq", "22bq", "44bq", "88bq", "177bq", "354bq", "706bq", "1br",
        "2br", "5br", "11br", "22br", "45br", "90br", "180br", "361br", "722br", "1bs",
        "2bs", "5bs", "11bs", "23bs", "46bs", "92bs", "185bs", "370bs", "740bs", "1bt",
        "2bt", "5bt", "11bt", "23bt", "47bt", "94bt", "189bt", "379bt", "758bt", "1bu",
        "3bu", "6bu", "12bu", "24bu", "48bu", "97bu", "194bu", "388bu", "776bu", "1bv",
        "3bv", "6bv", "12bv", "24bv", "49bv", "99bv", "198bv", "397bv", "794bv", "1bw",
        "3bw", "6bw", "12bw", "25bw", "50bw", "101bw", "203bw", "407bw", "814bw", "1bx",
        "3bx", "6bx", "13bx", "26bx", "52bx", "104bx", "208bx", "416bx", "833bx", "1by",
        "3by", "6by", "13by", "26by", "53by", "106by", "213by", "426by", "853by", "1bz",
        "3bz", "6bz", "13bz", "27bz", "54bz", "109bz", "218bz", "436bz", "873bz"
    ]

    /// Generates mock milestone data for a player based on their code (deterministic)
    private func mockMilestone(for player: MockPlayer) -> String {
        let seed = abs(player.code.hashValue)
        return Self.allMilestones[seed % Self.allMilestones.count]
    }

    /// Sorted leaderboard entries for the mini comparison
    private var comparisonLeaderboard: [ComparisonEntry] {
        var entries: [ComparisonEntry] = []

        // Add "You" entry
        entries.append(ComparisonEntry(
            id: "me",
            name: "You",
            code: friendCode,
            countryFlag: myProfile.countryFlag,
            milestone: myProfile.milestone,
            isMe: true
        ))

        // Add selected players
        for player in selectedPlayers {
            entries.append(ComparisonEntry(
                id: player.id,
                name: player.name,
                code: player.code,
                countryFlag: player.countryFlag,
                milestone: mockMilestone(for: player),
                isMe: false
            ))
        }

        // Sort by milestone (highest first)
        return entries.sorted { parseMilestone($0.milestone) > parseMilestone($1.milestone) }
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

                Section("Add Players to Compare") {
                    TextField("Search codes (e.g., A1 or XY)", text: $searchText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if selectedPlayers.count >= maxCompareCount {
                        Text("Maximum \(maxCompareCount) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !filteredPlayers.isEmpty && selectedPlayers.count < maxCompareCount {
                    Section("Search Results (\(filteredPlayers.count))") {
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
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        // Prevent duplicates
                                        if !selectedPlayers.contains(where: { $0.id == player.id }) {
                                            selectedPlayers.append(player)
                                        }
                                        searchText = ""
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Mini Comparison Leaderboard
                if !selectedPlayers.isEmpty {
                    Section {
                        ForEach(Array(comparisonLeaderboard.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 12) {
                                // Rank
                                Text("#\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(entry.isMe ? .accentColor : .secondary)
                                    .frame(width: 28, alignment: .leading)

                                // Country flag
                                Text(entry.countryFlag)
                                    .font(.title3)

                                // Name and code
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.subheadline.weight(entry.isMe ? .bold : .medium))
                                        .foregroundColor(entry.isMe ? .accentColor : .primary)
                                    Text(entry.code)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Milestone
                                Text(entry.milestone)
                                    .font(.subheadline.bold())
                                    .foregroundColor(entry.isMe ? .accentColor : .primary)

                                // Remove button (only for non-me entries)
                                if !entry.isMe {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPlayers.removeAll { $0.id == entry.id }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .background(entry.isMe ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                    } header: {
                        HStack {
                            Text("Comparison Leaderboard")
                            Spacer()
                            if selectedPlayers.count > 1 {
                                Button("Clear All") {
                                    withAnimation {
                                        selectedPlayers.removeAll()
                                    }
                                }
                                .font(.caption)
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

// MARK: - Comparison Entry (for mini leaderboard)

struct ComparisonEntry: Identifiable {
    let id: String
    let name: String
    let code: String
    let countryFlag: String
    let milestone: String
    let isMe: Bool
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
