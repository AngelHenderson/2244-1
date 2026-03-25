import SwiftUI
import GameApp

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
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
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
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
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

    private var mockPlayers: [MockPlayer] { MockPlayer.generateAll() }
    private static let selectedPlayersKey = "CompareView.selectedPlayerIDs"

    private func loadSelectedPlayers() {
        let savedIDs = UserDefaults.standard.stringArray(forKey: Self.selectedPlayersKey) ?? []
        selectedPlayers = savedIDs.compactMap { id in
            mockPlayers.first { $0.id == id }
        }
    }

    private func saveSelectedPlayers() {
        let ids = selectedPlayers.map { $0.id }
        UserDefaults.standard.set(ids, forKey: Self.selectedPlayersKey)
    }

    private var filteredPlayers: [MockPlayer] {
        let query = searchText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        // Filter by name or code (contains match), exclude already selected, limit to 50
        let selectedIDs = Set(selectedPlayers.map { $0.id })
        return mockPlayers
            .filter {
                !selectedIDs.contains($0.id) &&
                ($0.code.uppercased().contains(query) || $0.name.uppercased().contains(query))
            }
            .prefix(50)
            .map { $0 }
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

        // Add selected players (milestone comes from leaderboard data)
        for player in selectedPlayers {
            entries.append(ComparisonEntry(
                id: player.id,
                name: player.name,
                code: player.code,
                countryFlag: player.countryFlag,
                milestone: player.milestone,
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
                        Text(friendCode).font(.avenirNext(size: GameFonts.bodySize, weight: .medium)).monospaced()
                        Spacer()
                        Button("Copy") {
                            #if os(iOS)
                            UIPasteboard.general.string = friendCode
                            #endif
                        }
                    }
                }

                Section("Add Players to Compare") {
                    TextField("Search by name or code", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if !filteredPlayers.isEmpty {
                    Section("Search Results (\(filteredPlayers.count))") {
                        ForEach(filteredPlayers) { player in
                            HStack {
                                Text(player.countryFlag)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .medium))
                                    Text(player.code)
                                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular)).monospaced()
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        // Prevent duplicates
                                        if !selectedPlayers.contains(where: { $0.id == player.id }) {
                                            selectedPlayers.append(player)
                                            saveSelectedPlayers()
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
                                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                                    .foregroundColor(entry.isMe ? .accentColor : .secondary)
                                    .frame(width: 28, alignment: .leading)

                                // Country flag
                                Text(entry.countryFlag)
                                    .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))

                                // Name and code
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: entry.isMe ? .bold : .medium))
                                        .foregroundColor(entry.isMe ? .accentColor : .primary)
                                    Text(entry.code)
                                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular)).monospaced()
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Milestone
                                Text(entry.milestone)
                                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .bold))
                                    .foregroundColor(entry.isMe ? .accentColor : .primary)

                                // Remove button (only for non-me entries)
                                if !entry.isMe {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPlayers.removeAll { $0.id == entry.id }
                                            saveSelectedPlayers()
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
                                        saveSelectedPlayers()
                                    }
                                }
                                .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
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
            .onAppear {
                loadSelectedPlayers()
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
        let s = str.uppercased()
        var multiplier: Double = 1

        // Find where the numeric part ends and suffix begins
        var numericEnd = s.startIndex
        for (index, char) in s.enumerated() {
            if char.isNumber || char == "." {
                numericEnd = s.index(s.startIndex, offsetBy: index + 1)
            } else {
                break
            }
        }

        let numericPart = String(s[..<numericEnd])
        let suffix = String(s[numericEnd...])

        if !suffix.isEmpty {
            switch suffix {
            case "K": multiplier = 1_000
            case "M": multiplier = 1_000_000
            case "B": multiplier = 1_000_000_000
            default:
                // Extended suffixes: single letters (a-z) or double letters (aa-zz)
                let lowSuffix = suffix.lowercased()
                if lowSuffix.count == 1, let asciiVal = lowSuffix.first?.asciiValue {
                    // Single letter: a = 10^12, b = 10^15, etc.
                    let letterIndex = Int(asciiVal) - Int(Character("a").asciiValue!)
                    multiplier = pow(10, Double(12 + letterIndex * 3))
                } else if lowSuffix.count == 2 {
                    // Double letter: aa-az, ba-bz (52 total)
                    let chars = Array(lowSuffix)
                    if let first = chars[0].asciiValue, let second = chars[1].asciiValue {
                        let firstIndex = Int(first) - Int(Character("a").asciiValue!) // 0 for 'a', 1 for 'b'
                        let secondIndex = Int(second) - Int(Character("a").asciiValue!)
                        // 26 single letters (a-z) come first, then aa starts at index 26
                        let combinedIndex = 26 + firstIndex * 26 + secondIndex
                        multiplier = pow(10, Double(12 + combinedIndex * 3))
                    }
                }
            }
        }
        return (Double(numericPart) ?? 0) * multiplier
    }
}

// MARK: - Mock Player Data

struct MockPlayer: Identifiable {
    let id: String
    let name: String
    let code: String
    let countryCode: String
    let milestone: String

    var countryFlag: String {
        let base: UInt32 = 0x1F1E6
        return countryCode.uppercased().unicodeScalars.compactMap { scalar -> String? in
            guard let flag = UnicodeScalar(base + scalar.value - 65) else { return nil }
            return String(flag)
        }.joined()
    }

    /// Generate all players from the actual leaderboard data
    static func generateAll() -> [MockPlayer] {
        MockLeaderboardData.allSearchablePlayers().map { player in
            MockPlayer(
                id: player.id,
                name: player.name,
                code: player.code,
                countryCode: player.countryCode,
                milestone: player.milestone
            )
        }
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
        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
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
