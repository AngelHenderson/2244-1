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
        // Filter by any letters typed (contains match), sort by milestone descending, limit to top 50
        return mockPlayers
            .filter { $0.code.uppercased().contains(query) }
            .sorted { parseMilestone($0.milestone) > parseMilestone($1.milestone) }
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
                    Section("Top \(filteredPlayers.count) by Milestone") {
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
                                Text(player.milestone)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                    Section("Milestone Comparison") {
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
                                        .foregroundColor(milestoneComparison > 0 ? .green : (milestoneComparison < 0 ? .primary : .primary))
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
                                    Text(player.milestone)
                                        .font(.title2.bold())
                                        .foregroundColor(milestoneComparison < 0 ? .green : (milestoneComparison > 0 ? .primary : .primary))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)

                            // Result message
                            Text(comparisonResultMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Section {
                        Button("Compare with someone else") {
                            selectedPlayer = nil
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

    private var milestoneComparison: Int {
        guard let player = selectedPlayer else { return 0 }
        return compareMilestones(myProfile.milestone, player.milestone)
    }

    private var comparisonResultMessage: String {
        guard let player = selectedPlayer else { return "" }
        if milestoneComparison > 0 {
            return "Your milestone is higher than \(player.name)'s!"
        } else if milestoneComparison < 0 {
            return "\(player.name)'s milestone is higher than yours."
        } else {
            return "You and \(player.name) have the same milestone!"
        }
    }

    private func compareMilestones(_ a: String, _ b: String) -> Int {
        let aVal = parseMilestone(a)
        let bVal = parseMilestone(b)
        if aVal > bVal { return 1 }
        if aVal < bVal { return -1 }
        return 0
    }

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
    let milestone: String
    let countryCode: String

    var countryFlag: String {
        let base: UInt32 = 0x1F1E6
        return countryCode.uppercased().unicodeScalars.compactMap { scalar -> String? in
            guard let flag = UnicodeScalar(base + scalar.value - 65) else { return nil }
            return String(flag)
        }.joined()
    }

    static func generateAll() -> [MockPlayer] {
        let names = ["Alex", "Jordan", "Riley", "Casey", "Morgan", "Taylor", "Quinn", "Avery",
                     "Blake", "Cameron", "Dakota", "Emerson", "Finley", "Gray", "Hayden", "Jamie",
                     "Kai", "Logan", "Mason", "Noah", "Oliver", "Parker", "Reese", "Sage",
                     "Tyler", "Uma", "Victor", "Wesley", "Xander", "Yuki", "Zara"]
        let milestones = ["16K", "32K", "64K", "128K", "256K", "512K", "1M", "2M", "4M", "8M",
                         "16M", "32M", "64M", "128M", "256M", "512M", "1B", "2B", "4B", "8B",
                         "16B", "32B", "1a", "2a", "4a", "8a", "16a", "1b", "2b", "1c"]
        let countries = ["US", "GB", "CA", "AU", "DE", "FR", "JP", "KR", "BR", "MX",
                        "IN", "IT", "ES", "NL", "SE", "NO", "DK", "FI", "PL", "RU"]

        var players: [MockPlayer] = []
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        // Generate ~200 mock players with varied codes
        for i in 0..<200 {
            let seed = i * 7 + 13
            let c1 = letters[letters.index(letters.startIndex, offsetBy: (seed) % 26)]
            let c2 = letters[letters.index(letters.startIndex, offsetBy: (seed * 3) % 26)]
            let c3 = letters[letters.index(letters.startIndex, offsetBy: (seed * 7) % 26)]
            let num = String(format: "%03d", (seed * 11) % 1000)
            let code = "\(c1)\(c2)\(c3)-\(num)"

            let player = MockPlayer(
                id: code,
                name: names[seed % names.count],
                code: code,
                milestone: milestones[seed % milestones.count],
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