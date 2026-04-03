import SwiftUI
import GameApp

public struct LeaderboardView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentTheme) private var currentTheme
    @Environment(HomeState.self) private var homeState
    @State private var model: LeaderboardModel
    @State private var showError = false
    @State private var showingTop150 = false

    // Report system state
    @State private var reportCounts: [String: Int] = [:]  // player id -> report count
    @State private var bannedPlayerIds: Set<String> = []   // banned player ids
    @State private var showReportConfirmation = false
    @State private var showPlayerBanned = false
    @State private var lastReportedName: String = ""
    @State private var lastReportedCount: Int = 0

    // Report abuse protection
    /// How many unique players the local user has reported
    @State private var totalUniqueReports: Int = 0
    /// Player IDs that were banned because of THIS user's reports
    @State private var playersBannedByMe: Set<String> = []
    /// Alert for when the user is caught abusing reports
    @State private var showReportAbuseAlert = false
    /// Threshold: if user reports more than this many unique players, they are abusing reports
    private let reportAbuseThreshold = 5

    // "Are you sure?" confirmation before reporting
    @State private var pendingReportEntry: LeaderboardEntry?
    @State private var showReportAreYouSure = false
    @State private var showReportTrueOrFalse = false
    @State private var showFalseReportWarning = false
    @State private var showPlayerHistory = false

    private let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.14)

    public init(client: LeaderboardClient) {
        _model = State(initialValue: LeaderboardModel(client: client))
    }

    public var body: some View {
        ZStack {
            darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button {
                        if showingTop150 {
                            showingTop150 = false
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.avenirNext(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    // Player History button
                    Button {
                        showPlayerHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.avenirNext(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.2, green: 0.2, blue: 0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    GemBalancePill()

                    // Top 150 button (only show in milestone view, not for Hall of Fame)
                    if !showingTop150 && model.selectedFilter != .hallOfFame {
                        Button {
                            showingTop150 = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "infinity")
                                    .font(.avenirNext(size: 12, weight: .semibold))
                                Text("Top 150")
                                    .font(.avenirNext(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.6, green: 0.5, blue: 0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        // Invisible spacer for centering
                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                }
                .overlay {
                    Text(showingTop150 ? "TOP 150" : "LEADERBOARD")
                        .font(.avenirNext(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if showingTop150 || model.selectedFilter == .hallOfFame {
                    top150Content(model)
                } else {
                    milestoneContent(model)
                }
            }
            .task {
                await model.authenticate()
                await model.refresh()
                // Ban gate: do not submit scores or register rank progression while banned
                if !homeState.isBanned {
                    if let myEntry = model.myEntry, gameStore.state.score > myEntry.score {
                        await model.submitScore(gameStore.state.score)
                    }
                    if model.selectedFilter == .global, let myEntry = model.myEntry {
                        gameStore.registerLeaderboardRank(myEntry.rank)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayerHistory) {
            PlayerHistoryView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(model.error ?? "An error occurred")
        }
        .alert("Report Received", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            let remaining = 3 - lastReportedCount
            Text("Your report for \(lastReportedName) has been received. \(remaining) more report\(remaining == 1 ? "" : "s") and this player will be banned.")
        }
        .alert("Player Banned", isPresented: $showPlayerBanned) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(lastReportedName) has been banned and removed from the leaderboard due to multiple reports.")
        }
        .alert("Report Abuse Detected", isPresented: $showReportAbuseAlert) {
            Button("OK", role: .cancel) {
                // Trigger the ban system — issues a warning (or ban if out of chances)
                homeState.issueWarning(reason: "Abusing the report system")
                dismiss()
            }
        } message: {
            Text("You have been flagged for abusing the report system. All players you reported have been unbanned. Continued abuse will result in your account being suspended.")
        }
        .alert("Are you sure?", isPresented: $showReportAreYouSure) {
            Button("Yes", role: .destructive) {
                // Move to True or False step
                showReportTrueOrFalse = true
            }
            Button("Cancel", role: .cancel) {
                pendingReportEntry = nil
            }
        } message: {
            Text("Are you sure \(pendingReportEntry?.name ?? "this player") did something that violates the rules? False reports will count against you.")
        }
        .alert("True or False?", isPresented: $showReportTrueOrFalse) {
            Button("True") {
                // Legitimate report — player gets a warning toward ban
                if let entry = pendingReportEntry {
                    reportPlayer(entry)
                    pendingReportEntry = nil
                }
            }
            Button("False", role: .destructive) {
                // False report — 2 abuse points if reporting someone ahead (overtake), 1 otherwise
                if let entry = pendingReportEntry {
                    let myRank = model.myEntry?.rank ?? Int.max
                    let abusePoints = entry.rank < myRank ? 2 : 1
                    totalUniqueReports += abusePoints
                }
                pendingReportEntry = nil
                showFalseReportWarning = true
            }
        } message: {
            Text("Did \(pendingReportEntry?.name ?? "this player") actually do something wrong?")
        }
        .alert("False Report!", isPresented: $showFalseReportWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your false report has been recorded. False reports count against you and may result in your account being suspended.")
        }
        .onChange(of: showingTop150) { _, isTop150 in
            // When switching to Top 150 view, force a refresh so the entries
            // match the currently selected filter (e.g., Malaysia instead of Global).
            // The milestone view uses static rank data, not m.entries, so the
            // entries may not have been updated when the user switched filters there.
            if isTop150, !model.isLoading {
                Task { await model.refresh() }
            }
        }
    }
    
    // MARK: - Milestone-Based View (Default)

    @ViewBuilder
    private func milestoneContent(_ m: LeaderboardModel) -> some View {
        let userMilestone = UserLeaderboardData.currentMilestone
        let userRank = rankForFilter(m.selectedFilter, milestone: userMilestone)
        let headerTitle = headerTitleForFilter(m.selectedFilter)

        VStack(spacing: 0) {
            // Filter Tabs (Global, Hall of Fame, Country)
            HStack(spacing: 8) {
                ForEach(LeaderboardFilter.availableFilters(for: UserLeaderboardData.currentCountry)) { filter in
                    filterTab(filter, isSelected: m.selectedFilter == filter) {
                        m.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // User's current position header
            VStack(spacing: 6) {
                Text(headerTitle)
                    .font(.avenirNext(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 8) {
                    Text("#\(userRank)")
                        .font(.avenirNext(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    Text("–")
                        .font(.avenirNext(size: 28, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    Text(userMilestone)
                        .font(.avenirNext(size: 24, weight: .bold))
                        .foregroundStyle(tileTextColor(for: userMilestone))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(milestoneColor(for: userMilestone))
                        )
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.1, green: 0.12, blue: 0.18))

            // Milestone tiers list (shows context around user's position)
            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 8) {
                        ForEach(milestoneTiersAroundUser(userMilestone: userMilestone, filter: m.selectedFilter, entries: m.entries), id: \.milestone) { tier in
                            milestoneRow(
                                milestone: tier.milestone,
                                rankLabel: tier.rankLabel,
                                isUserTier: tier.milestone == userMilestone
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)

                    // Rank preview section - shows individual ranks for nearby milestones
                    rankPreviewSection(userMilestone: userMilestone, filter: m.selectedFilter, entries: m.entries)
                }
            }
        }
    }

    /// Shows individual rank examples for milestones around the user's position
    @ViewBuilder
    private func rankPreviewSection(userMilestone: String, filter: LeaderboardFilter, entries: [LeaderboardEntry]) -> some View {
        let previews = generateRankPreviews(userMilestone: userMilestone, filter: filter, entries: entries)

        if !previews.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rank Preview")
                    .font(.avenirNext(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                    .padding(.bottom, 8)

                ForEach(previews, id: \.rank) { preview in
                    HStack {
                        Text("\(preview.rank)")
                            .font(.avenirNext(size: 14, weight: .medium))
                            .foregroundStyle(preview.isUserRank ? .cyan : .white.opacity(0.6))

                        Text(preview.isUserRank ? "-" : "=")
                            .font(.avenirNext(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(preview.milestone)
                            .font(.avenirNext(size: 14, weight: .semibold))
                            .foregroundStyle(preview.isUserRank ? .cyan : .white.opacity(0.6))

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(red: 0.08, green: 0.09, blue: 0.12))
        }
    }

    private struct RankPreview {
        let rank: Int
        let milestone: String
        let isUserRank: Bool
    }

    /// Generates rank previews around the user's current rank using monotonic tier boundaries
    private func generateRankPreviews(userMilestone: String, filter: LeaderboardFilter, entries: [LeaderboardEntry]) -> [RankPreview] {
        guard let userEntry = entries.first(where: { $0.isMe }) else {
            return []
        }
        let userRank = userEntry.rank

        let startRank = max(1, userRank - 3)
        let endRank = userRank + 3
        var previews: [RankPreview] = []

        // Check if user is within Top 150 entries
        let userInTop150 = userRank <= 150

        for rank in startRank...endRank {
            var milestoneForRank = userMilestone

            if rank == userRank {
                milestoneForRank = userMilestone
            } else if userInTop150, let actualEntry = entries.first(where: { $0.rank == rank }) {
                // If in Top 150, exact entry data determines milestone
                milestoneForRank = actualEntry.highestTile ?? userMilestone
            } else if !userInTop150, rank <= 150, let actualEntry = entries.first(where: { $0.rank == rank }) {
                // Viewing Top 150 while outside of it
                milestoneForRank = actualEntry.highestTile ?? userMilestone
            } else {
                // For synthesized ranks (>150), strictly enforce mathematical monotonic boundaries
                // This perfectly mirrors the visual list representation in the main UI
                milestoneForRank = tierMilestoneForRank(rank, userMilestone: userMilestone, filter: filter)
            }

            previews.append(RankPreview(
                rank: rank,
                milestone: milestoneForRank,
                isUserRank: rank == userRank
            ))
        }

        return previews
    }

    /// Generate rank previews for country leaderboards using consecutive ranking
    /// Shows consecutive rank numbers with tier-based milestone assignments
    /// (consistent with the milestone tier view above)
    private func generateCountryRankPreviews(userMilestone: String, userRank: Int, filter: LeaderboardFilter, entries: [LeaderboardEntry]) -> [RankPreview] {
        // Show ranks from 3 above to 3 below user's rank
        let startRank = max(1, userRank - 3)
        let endRank = userRank + 3

        // Check if user is within Top 150 entries (use entries data)
        let userInTop150 = entries.first(where: { $0.isMe && $0.rank <= 150 }) != nil

        var previews: [RankPreview] = []
        for rank in startRank...endRank {
            let milestone: String

            if rank == userRank {
                milestone = userMilestone
            } else if userInTop150, let entry = entries.first(where: { $0.rank == rank }) {
                // Use actual entry milestone from loaded data (matches Top 150)
                milestone = entry.highestTile ?? userMilestone
            } else if !userInTop150, rank <= 150, let entry = entries.first(where: { $0.rank == rank }) {
                // User outside Top 150 but looking at a Top 150 rank
                milestone = entry.highestTile ?? userMilestone
            } else {
                // Fall back to tier boundary lookup
                milestone = tierMilestoneForRank(rank, userMilestone: userMilestone, filter: filter)
            }

            previews.append(RankPreview(
                rank: rank,
                milestone: milestone,
                isUserRank: rank == userRank
            ))
        }

        return previews
    }

    /// Look up the milestone tier boundary for a given rank using rankForFilter
    private func tierMilestoneForRank(_ targetRank: Int, userMilestone: String, filter: LeaderboardFilter) -> String {
        let milestones = Self.allMilestones
        guard let userIndex = milestones.firstIndex(of: userMilestone) else {
            return userMilestone
        }

        let searchStart = max(0, userIndex - 10)
        let searchEnd = min(milestones.count, userIndex + 10)

        // Build tier boundaries
        var tierBoundaries: [(milestone: String, startRank: Int)] = []
        for i in searchStart..<searchEnd {
            let milestone = milestones[i]
            let rank = rankForFilter(filter, milestone: milestone)
            tierBoundaries.append((milestone, rank))
        }

        // Enforce monotonicity
        let userBoundaryIndex = userIndex - searchStart
        for i in stride(from: userBoundaryIndex - 1, through: 0, by: -1) {
            if tierBoundaries[i].startRank >= tierBoundaries[i + 1].startRank {
                tierBoundaries[i].startRank = tierBoundaries[i + 1].startRank - 1
            }
        }
        for i in (userBoundaryIndex + 1)..<tierBoundaries.count {
            if tierBoundaries[i].startRank <= tierBoundaries[i - 1].startRank {
                tierBoundaries[i].startRank = tierBoundaries[i - 1].startRank + 1
            }
        }

        // Find matching tier
        var foundMilestone = userMilestone
        for boundary in tierBoundaries {
            if boundary.startRank <= targetRank {
                foundMilestone = boundary.milestone
            } else {
                break
            }
        }
        return foundMilestone
    }

    /// Find milestone for a rank better than user (lower rank number = better)
    private func findMilestoneForBetterRank(_ targetRank: Int, userRank: Int, userMilestone: String, rankToMilestone: [(startRank: Int, milestone: String)]) -> String {
        // Find user's milestone tier start rank
        let userTierStart = rankToMilestone.first { $0.milestone == userMilestone }?.startRank ?? userRank

        // If targetRank is within user's tier (>= tier start), show user's milestone
        if targetRank >= userTierStart {
            return userMilestone
        }

        // Otherwise find the appropriate better milestone
        var bestMatch = userMilestone
        for entry in rankToMilestone {
            if entry.startRank <= targetRank {
                bestMatch = entry.milestone
            }
            if entry.startRank > targetRank {
                break
            }
        }

        return bestMatch
    }

    /// Find milestone for a rank worse than user (higher rank number = worse)
    private func findMilestoneForWorseRank(_ targetRank: Int, userRank: Int, userMilestone: String, rankToMilestone: [(startRank: Int, milestone: String)]) -> String {
        // Find the next tier's start rank (the tier after user's milestone)
        var nextTierStart: Int? = nil
        var foundUserMilestone = false

        for entry in rankToMilestone {
            if foundUserMilestone && entry.milestone != userMilestone {
                nextTierStart = entry.startRank
                break
            }
            if entry.milestone == userMilestone {
                foundUserMilestone = true
            }
        }

        // If there's no clear next tier, or the target rank is before it starts,
        // show user's milestone (players at adjacent ranks likely share milestone)
        guard let nextStart = nextTierStart else {
            return userMilestone
        }

        // Only show a different milestone if targetRank is clearly past the next tier's start
        // Add a small buffer since adjacent ranks often share milestones
        if targetRank < nextStart {
            return userMilestone
        }

        // Target rank is past the next tier boundary, find appropriate milestone
        var result = userMilestone
        for entry in rankToMilestone {
            if entry.startRank <= targetRank {
                result = entry.milestone
            }
            if entry.startRank > targetRank {
                break
            }
        }

        return result
    }

    /// Returns the header title based on the selected filter
    private func headerTitleForFilter(_ filter: LeaderboardFilter) -> String {
        switch filter {
        case .global:
            return "Your Global Rank"
        case .hallOfFame:
            return "Your Hall of Fame Rank"
        default:
            return "Your \(filter.rawValue) Rank"
        }
    }

    /// Calculate rank for a milestone based on the selected filter
    private func rankForFilter(_ filter: LeaderboardFilter, milestone: String) -> Int {
        switch filter {
        case .global:
            return UserLeaderboardData.globalRank(for: milestone)
        case .hallOfFame:
            return MockLeaderboardData.calculateHallOfFameRank(milestone: milestone)
        default:
            // Country-specific rank
            if let countryCode = filter.countryCode {
                return MockLeaderboardData.calculateCountryRank(milestone: milestone, countryCode: countryCode)
            }
            return UserLeaderboardData.globalRank(for: milestone)
        }
    }

    // All milestones in order from highest to lowest
    // Includes: letter tiers (a-z, aa-az, etc.), B (Billion), M (Million), K (Thousand), raw numbers
    private static let allMilestones: [String] = [
        // Ultra-high tiers (alphabetic - highest first)
        "1an", "693am", "346am", "173am", "86am", "43am", "21am", "10am", "5am", "2am",
        "1am", "676al", "338al", "169al", "84al", "42al", "21al", "10al", "5al", "2al",
        "1al", "661ak", "330ak", "165ak", "82ak", "41ak", "20ak", "10ak", "5ak", "2ak",
        "1ak", "645aj", "322aj", "161aj", "80aj", "40aj", "20aj", "10aj", "5aj", "2aj",
        "1aj", "630ai", "315ai", "157ai", "78ai", "39ai", "19ai", "9ai", "4ai", "2ai",
        "1ai", "615ah", "307ah", "153ah", "76ah", "38ah", "19ah", "9ah", "4ah", "2ah",
        "1ah", "601ag", "300ag", "150ag", "75ag", "37ag", "18ag", "9ag", "4ag", "2ag",
        "1ag", "587af", "293af", "146af", "73af", "36af", "18af", "9af", "4af", "2af",
        "1af", "573ae", "286ae", "143ae", "71ae", "35ae", "17ae", "8ae", "4ae", "2ae",
        "1ae", "559ad", "279ad", "139ad", "69ad", "34ad", "17ad", "8ad", "4ad", "2ad",
        "1ad", "546ac", "273ac", "136ac", "68ac", "34ac", "17ac", "8ac", "4ac", "2ac",
        "1ac", "533ab", "266ab", "133ab", "66ab", "33ab", "16ab", "8ab", "4ab", "2ab",
        "1ab", "521aa", "260aa", "130aa", "65aa", "32aa", "16aa", "8aa", "4aa", "2aa",
        "1aa", "509z", "254z", "127z", "63z", "31z", "15z", "7z", "3z",
        "1z", "994y", "497y", "248y", "124y", "62y", "31y", "15y", "7y", "3y",
        "1y", "971x", "485x", "242x", "121x", "60x", "30x", "15x", "7x", "3x",
        "1x", "948w", "474w", "237w", "118w", "59w", "29w", "14w", "7w", "3w",
        "1w", "926v", "463v", "231v", "115v", "57v", "28v", "14v", "7v", "3v",
        "1v", "904u", "452u", "226u", "113u", "56u", "28u", "14u", "7u", "3u",
        "1u", "883t", "441t", "220t", "110t", "55t", "27t", "13t", "6t", "3t",
        "1t", "862s", "431s", "215s", "107s", "53s", "26s", "13s", "6s", "3s",
        "1s", "842r", "421r", "210r", "105r", "52r", "26r", "13r", "6r", "3r",
        "1r", "822q", "411q", "205q", "102q", "51q", "25q", "12q", "6q", "3q",
        "1q", "803p", "401p", "200p", "100p", "50p", "25p", "12p", "6p", "3p",
        "1p", "784o", "392o", "196o", "98o", "49o", "24o", "12o", "6o", "3o",
        "1o", "766n", "383n", "191n", "95n", "47n", "23n", "11n", "5n", "2n",
        "1n", "748m", "374m", "187m", "93m", "46m", "23m", "11m", "5m", "2m",
        "1m", "730l", "365l", "182l", "91l", "45l", "22l", "11l", "5l", "2l",
        "1l", "713k", "356k", "178k", "89k", "44k", "22k", "11k", "5k", "2k",
        "1k", "696j", "348j", "174j", "87j", "43j", "21j", "10j", "5j", "2j",
        "1j", "680i", "340i", "170i", "85i", "42i", "21i", "10i", "5i", "2i",
        "1i", "664h", "332h", "166h", "83h", "41h", "20h", "10h", "5h", "2h",
        "1h", "649g", "324g", "162g", "81g", "40g", "20g", "10g", "5g", "2g",
        "1g", "633f", "316f", "158f", "79f", "39f", "19f", "9f", "4f", "2f",
        "1f", "618e", "309e", "154e", "77e", "38e", "19e", "9e", "4e", "2e",
        "1e", "604d", "302d", "151d", "75d", "37d", "18d", "9d", "4d", "2d",
        "1d", "590c", "295c", "147c", "73c", "36c", "18c", "9c", "4c", "2c",
        "1c", "576b", "288b", "144b", "72b", "36b", "18b", "9b", "4b", "2b",
        "1b", "562a", "281a", "140a", "70a", "35a", "17a", "8a", "4a", "2a",
        "1a",
        // Billions
        "549B", "274B", "137B", "68B", "34B", "17B", "8B", "4B", "2B", "1B",
        // Millions
        "536M", "268M", "134M", "67M", "33M", "16M", "8M", "4M", "2M", "1M",
        // Thousands
        "524K", "262K", "131K", "65K", "32K", "16K",
        // Raw numbers (lowest)
        "8192", "4096", "2048", "1024", "512", "256", "128", "64", "32", "16", "8", "4", "2"
    ]

    /// Returns milestones around the user's current milestone (3 above, user, 3 below)
    /// Each entry includes the rank number for that milestone tier based on selected filter
    private func milestoneTiersAroundUser(userMilestone: String, filter: LeaderboardFilter, entries: [LeaderboardEntry]) -> [(milestone: String, rankLabel: String)] {
        // For country leaderboards when user is in Top 150, use actual entries data to match Top 150
        if filter.countryCode != nil && !entries.isEmpty {
            let userInTop150 = entries.first(where: { $0.isMe && $0.rank <= 150 }) != nil
            if userInTop150 {
                return milestoneTiersFromEntries(userMilestone: userMilestone, entries: entries)
            }
        }

        let milestones = Self.allMilestones

        // Find user's position in the milestone list
        guard let userIndex = milestones.firstIndex(of: userMilestone) else {
            // User milestone not found - show starting milestones with calculated ranks
            let endIndex = min(7, milestones.count)
            return milestones[0..<endIndex].map { milestone in
                let rank = rankForFilter(filter, milestone: milestone)
                return (milestone, "\(rank) - \(milestone)")
            }
        }

        // Get 3 milestones above (better) and 3 below (worse)
        let startIndex = max(0, userIndex - 3)
        let endIndex = min(milestones.count, userIndex + 4)  // +4 because endIndex is exclusive

        // Calculate ranks for each milestone using actual leaderboard data
        var tiers: [(milestone: String, rank: Int)] = milestones[startIndex..<endIndex].map { milestone in
            let rank = rankForFilter(filter, milestone: milestone)
            return (milestone, rank)
        }

        // Enforce monotonicity: better milestones (lower index) must have lower ranks.
        // When calculateCountryRank returns the same rank for adjacent milestones
        // (no mock players between them), push the better one to rank - 1.
        let userTierIndex = userIndex - startIndex
        // Going upward (better milestones should have lower ranks)
        for i in stride(from: userTierIndex - 1, through: 0, by: -1) {
            if tiers[i].rank >= tiers[i + 1].rank {
                tiers[i].rank = tiers[i + 1].rank - 1
            }
        }
        // Going downward (worse milestones should have higher ranks)
        for i in (userTierIndex + 1)..<tiers.count {
            if tiers[i].rank <= tiers[i - 1].rank {
                tiers[i].rank = tiers[i - 1].rank + 1
            }
        }

        return tiers.map { tier in
            (tier.milestone, "\(tier.rank) - \(tier.milestone)")
        }
    }

    /// Build milestone tiers from actual entries data (for country leaderboards)
    /// Shows unique milestones around the user's position, matching the Top 150 exactly
    private func milestoneTiersFromEntries(userMilestone: String, entries: [LeaderboardEntry]) -> [(milestone: String, rankLabel: String)] {
        // Find user entry in entries
        guard let userEntry = entries.first(where: { $0.isMe }) else {
            // User not in entries, fall back to showing entries around the middle
            let nearby = Array(entries.prefix(7))
            return nearby.map { entry in
                (entry.highestTile ?? "", "\(entry.rank) - \(entry.highestTile ?? "")")
            }
        }

        let userRank = userEntry.rank

        // Get entries sorted by rank
        let sorted = entries.sorted { $0.rank < $1.rank }

        // Find entries around the user (3 above + user + 3 below)
        // First, collect unique milestones with their first appearing rank
        var result: [(milestone: String, rankLabel: String)] = []
        var seenMilestones = Set<String>()

        // Entries above user (3 unique milestones)
        let aboveEntries = sorted.filter { $0.rank < userRank && !$0.isMe }
            .suffix(6) // Take last 6 entries above user to find 3 unique milestones
        var aboveTiers: [(milestone: String, rank: Int)] = []
        for entry in aboveEntries.reversed() {
            if let tile = entry.highestTile, !seenMilestones.contains(tile) {
                seenMilestones.insert(tile)
                aboveTiers.insert((tile, entry.rank), at: 0)
                if aboveTiers.count >= 3 { break }
            }
        }
        result.append(contentsOf: aboveTiers.map { ("\($0.milestone)", "\($0.rank) - \($0.milestone)") })

        // User's entry
        result.append((userMilestone, "\(userRank) - \(userMilestone)"))
        seenMilestones.insert(userMilestone)

        // Entries below user (3 unique milestones)
        let belowEntries = sorted.filter { $0.rank > userRank && !$0.isMe }
            .prefix(6) // Take first 6 entries below user to find 3 unique milestones
        for entry in belowEntries {
            if let tile = entry.highestTile, !seenMilestones.contains(tile) {
                seenMilestones.insert(tile)
                result.append((tile, "\(entry.rank) - \(tile)"))
                if result.count >= 7 { break }
            }
        }

        return result
    }

    @ViewBuilder
    private func milestoneRow(milestone: String, rankLabel: String, isUserTier: Bool) -> some View {
        HStack(spacing: 0) {

            // Rank label (e.g., "73150 - 1B")
            Text(rankLabel)
                .font(.avenirNext(size: 18, weight: isUserTier ? .bold : .medium))
                .foregroundStyle(isUserTier ? .white : .white.opacity(0.7))

            Spacer()

            // Milestone badge
            let tileRadius: CGFloat = currentTheme?.tileShape == .square ? 3 : 6
            Text(milestone)
                .font(.avenirNext(size: 14, weight: .bold))
                .foregroundStyle(tileTextColor(for: milestone))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: tileRadius)
                        .fill(milestoneColor(for: milestone).opacity(isUserTier ? 1.0 : 0.85))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUserTier ? Color(red: 0.1, green: 0.2, blue: 0.3) : Color(red: 0.12, green: 0.14, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUserTier ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 2)
                )
        )
    }

    private func milestoneColor(for milestone: String) -> Color {
        tileColor(for: milestone)
    }

    /// Returns the game tile background color for a milestone string, using the current theme
    private func tileColor(for milestone: String) -> Color {
        // Infinity tiles use light cyan/turquoise (matches the infinity tile in-game)
        if milestone.contains("∞") {
            return Color(red: 0.6, green: 0.9, blue: 0.9)
        }
        let idx = MockLeaderboardData.milestoneIndex(for: milestone)
        guard idx > 0 else { return Color(red: 0.4, green: 0.3, blue: 0.5) }
        if let theme = currentTheme {
            return theme.colorForStep(idx - 1)
        }
        return Theme.colorForStep(idx - 1)
    }

    /// Returns the game tile text color for a milestone string, using the current theme
    private func tileTextColor(for milestone: String) -> Color {
        // Infinity tiles use dark gray/blue text on light cyan background
        if milestone.contains("∞") {
            return Color(red: 0.4, green: 0.5, blue: 0.5)
        }
        let idx = MockLeaderboardData.milestoneIndex(for: milestone)
        guard idx > 0 else { return .white }
        if let theme = currentTheme {
            return theme.textColorForStep(idx - 1)
        }
        return Theme.textColorForStep(idx - 1)
    }

    // MARK: - Top 150 View

    @ViewBuilder
    private func top150Content(_ m: LeaderboardModel) -> some View {
        VStack(spacing: 0) {
            // Filter Tabs (based on user's country)
            HStack(spacing: 8) {
                ForEach(LeaderboardFilter.availableFilters(for: UserLeaderboardData.currentCountry)) { filter in
                    filterTab(filter, isSelected: m.selectedFilter == filter) {
                        m.selectedFilter = filter
                        // Track global rank for achievements when switching to global filter
                        if filter == .global, let myEntry = m.myEntry {
                            gameStore.registerLeaderboardRank(myEntry.rank)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Leaderboard List - Top 150 only (no pagination)
            if m.isLoading && !m.hasData {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Spacer()
            } else if m.hasData {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Only show top 150 entries
                        let top150Entries = Array(buildDisplayEntries(m).prefix(150))
                        ForEach(Array(top150Entries.enumerated()), id: \.element.id) { index, entry in
                            leaderboardRow(entry, index: index)
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.avenirNext(size: 48, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No leaderboard data")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Be the first to set a score!")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
        }
        .onChange(of: m.error) { _, newError in
            if newError != nil {
                showError = true
            }
        }
        .onChange(of: m.myEntry?.rank) { _, newRank in
            // Track global leaderboard rank for achievements whenever it updates
            if m.selectedFilter == .global, let rank = newRank, rank > 0 {
                print("🏆 Tracking leaderboard rank: \(rank)")
                gameStore.registerLeaderboardRank(rank)
            }
        }
        .onAppear {
            // Track initial rank when content appears
            if m.selectedFilter == .global, let myEntry = m.myEntry, myEntry.rank > 0 {
                print("🏆 Initial leaderboard rank: \(myEntry.rank)")
                gameStore.registerLeaderboardRank(myEntry.rank)
            }
        }
    }

    private func filterTab(_ filter: LeaderboardFilter, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter == .global {
                    Image(systemName: "globe")
                        .font(.avenirNext(size: 14, weight: .regular))
                } else if filter == .hallOfFame {
                    Image(systemName: "infinity")
                        .font(.avenirNext(size: 14, weight: .regular))
                } else if let countryCode = filter.countryCode {
                    Text(flagEmoji(countryCode))
                        .font(.avenirNext(size: 14, weight: .regular))
                }

                Text(filter.rawValue)
                    .font(.avenirNext(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(filterTabBackground(for: filter, isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func filterTabBackground(for filter: LeaderboardFilter, isSelected: Bool) -> Color {
        guard isSelected else {
            return Color(red: 0.15, green: 0.16, blue: 0.22)
        }
        switch filter {
        case .global:
            return Color.blue
        case .hallOfFame:
            return Color(red: 0.6, green: 0.5, blue: 0.2)
        case .country:
            return Color.green
        case .countryUK:
            return Color.red
        case .countryCA:
            return Color.red  // Canada - red like the maple leaf
        case .countryAU:
            return Color.green  // Australia - green and gold
        case .countryDE:
            return Color.red  // Germany - black, red, gold flag
        case .countryFR:
            return Color.blue  // France - blue, white, red flag
        case .countryJP:
            return Color.red  // Japan - red circle on white
        case .countryIN:
            return Color.orange  // India - saffron from the flag
        case .countryBR:
            return Color.green  // Brazil - green from the flag
        case .countryMX:
            return Color.green  // Mexico - green from the flag
        case .countryAF:
            return Color.black  // Afghanistan - black from the flag
        case .countryAL:
            return Color.red  // Albania - red from the flag
        case .countryDZ:
            return Color.green  // Algeria - green from the flag
        case .countryCN:
            return Color.red  // China - red from the flag
        case .countryKR:
            return Color.blue  // South Korea - blue from the flag
        case .countryIT:
            return Color.green  // Italy - green from the flag
        case .countryES:
            return Color.red  // Spain - red from the flag
        case .countryNL:
            return Color.orange  // Netherlands - orange (national color)
        case .countryCH:
            return Color.red  // Switzerland - red from the flag
        case .countryNO:
            return Color.red  // Norway - red from the flag
        case .countryDK:
            return Color.red  // Denmark - red from the flag
        case .countryFI:
            return Color.blue  // Finland - blue from the flag
        case .countryPL:
            return Color.red   // Poland - red from the flag
        case .countryBE:
            return Color.yellow  // Belgium - yellow from the flag
        case .countrySE:
            return Color.blue  // Sweden - blue from the flag
        case .countryAT:
            return Color.red  // Austria - red from the flag
        case .countryIE:
            return Color.green  // Ireland - green from the flag
        case .countryPT:
            return Color.red  // Portugal - red from the flag
        case .countryGR:
            return Color.blue  // Greece - blue from the flag
        case .countryCZ:
            return Color.blue  // Czechia - blue from the flag
        case .countryRO:
            return Color.blue  // Romania - blue from the flag
        case .countryMY:
            return Color.blue  // Malaysia - blue from the flag
        case .countryNZ:
            return Color.blue  // New Zealand - blue from the flag
        case .countryHU:
            return Color.red  // Hungary - red from the flag
        case .countryTH:
            return Color.blue  // Thailand - blue from the flag
        case .countryAE:
            return Color.green  // UAE - green from the flag
        case .countryPH:
            return Color.blue  // Philippines - blue from the flag
        case .countryAD:
            return Color.blue  // Andorra - blue from the flag
        case .countryID:
            return Color.red  // Indonesia - red from the flag
        case .countryZA:
            return Color.green  // South Africa - green from the flag
        case .countryKE:
            return Color.black  // Kenya - black from the flag
        case .countryFJ:
            return Color(red: 0.41, green: 0.69, blue: 0.83)  // Fiji - light blue from the flag
        case .countryVN:
            return Color.red  // Vietnam - red from the flag
        case .countryCW:
            return Color.blue  // Curacao - blue from the flag
        case .countryVE:
            return Color.yellow  // Venezuela - yellow from the flag
        case .countryAZ:
            return Color.blue  // Azerbaijan - blue from the flag
        case .countryKZ:
            return Color.blue  // Kazakhstan - blue from the flag
        case .countryTJ:
            return Color.red  // Tajikistan - red from the flag
        case .countryNU:
            return Color.yellow  // Niue - gold from the flag
        case .countryKG:
            return Color.red  // Kyrgyzstan - red from the flag
        case .countryIS:
            return Color.blue  // Iceland - blue from the flag
        case .countrySK:
            return Color.blue  // Slovakia - blue from the flag
        case .countryUZ:
            return Color.blue  // Uzbekistan - blue from the flag
        case .countryPK:
            return Color.green // Pakistan - green from the flag
        case .countryUA:
            return Color.blue  // Ukraine - blue from the flag
        }
    }

    // Build display entries with user merged at correct position
    private func buildDisplayEntries(_ m: LeaderboardModel) -> [LeaderboardEntry] {
        guard let myEntry = m.myEntry else {
            return m.entries
        }

        // Filter out banned players
        var result = m.entries.filter { !$0.isMe && !bannedPlayerIds.contains($0.id) }

        // Check if user should be in the displayed range
        guard let lastEntry = result.last else {
            return [myEntry]
        }

        // If user's rank is within or just after the displayed range, insert them
        // Also include user if they're within Top 150 even if last displayed entry
        // has a lower rank number (can happen when some entries are filtered)
        if myEntry.rank <= lastEntry.rank || myEntry.rank <= 150 {
            // Find the correct position based on rank
            if let insertIndex = result.firstIndex(where: { $0.rank > myEntry.rank }) {
                result.insert(myEntry, at: insertIndex)
            } else {
                result.append(myEntry)
            }
        }

        return result
    }

    // Check if user is in the display range
    private func isUserInDisplayRange(_ m: LeaderboardModel) -> Bool {
        guard let myEntry = m.myEntry else { return false }
        let entries = m.entries.filter { !$0.isMe }
        guard let lastEntry = entries.last else { return true }
        return myEntry.rank <= lastEntry.rank
    }

    private func leaderboardRow(_ entry: LeaderboardEntry, index: Int?) -> some View {
        HStack(spacing: 12) {
            // Rank Number
            Text(verbatim: "\(entry.rank)")
                .font(.avenirNext(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44)

            // Avatar with platform badge
            ZStack(alignment: .bottomTrailing) {
                if let avatarID = entry.avatarURL, avatarID.hasPrefix("avatar-") {
                    // Local avatar from AvatarCatalog
                    AvatarBadge(option: AvatarCatalog.option(for: avatarID), size: 44)
                } else if let avatarURL = entry.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder(for: entry)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder(for: entry)
                }

                // Platform badge
                Image(systemName: platformIcon(for: entry.platform))
                    .font(.avenirNext(size: 10, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(platformColor(for: entry.platform))
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }

            // Player Name
            Text(entry.name)
                .font(.avenirNext(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Country Flag
            if let countryCode = entry.countryCode {
                Text(flagEmoji(countryCode))
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))
            }

            // Milestone Badge (highest tile - styled as game tile)
            if let highestTile = entry.highestTile {
                let tileRadius: CGFloat = currentTheme?.tileShape == .square ? 3 : 5
                Text(highestTile)
                    .font(.avenirNext(size: 10, weight: .bold))
                    .foregroundStyle(tileTextColor(for: highestTile))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: tileRadius)
                            .fill(tileColor(for: highestTile))
                    )
                    .overlay(
                        rankFrame(for: entry.rank)
                    )
                    .overlay(alignment: .top) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                            .offset(y: -6)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground(for: entry.rank, isMe: entry.isMe))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(entry.isMe ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contextMenu {
            if !entry.isMe {
                Button(role: .destructive) {
                    pendingReportEntry = entry
                    showReportAreYouSure = true
                } label: {
                    Label("Report Player", systemImage: "exclamationmark.triangle.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func avatarPlaceholder(for entry: LeaderboardEntry) -> some View {
        ZStack {
            Circle()
                .fill(avatarGradient(for: entry.id))
                .frame(width: 44, height: 44)

            Text(String(entry.name.prefix(1)).uppercased())
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func rowBackground(for rank: Int, isMe: Bool) -> some ShapeStyle {
        if isMe {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.3), Color(red: 0.15, green: 0.25, blue: 0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        switch rank {
        case 1:
            // Gold
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.85, green: 0.65, blue: 0.13), Color(red: 0.72, green: 0.53, blue: 0.04)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case 2:
            // Silver
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.75, green: 0.75, blue: 0.78), Color(red: 0.55, green: 0.55, blue: 0.58)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case 3:
            // Bronze
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.80, green: 0.50, blue: 0.20), Color(red: 0.65, green: 0.38, blue: 0.12)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        default:
            return AnyShapeStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
        }
    }

    private func milestoneBadgeColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.72, green: 0.53, blue: 0.04) // Gold
        case 2: return Color(red: 0.55, green: 0.55, blue: 0.58) // Silver
        case 3: return Color(red: 0.65, green: 0.38, blue: 0.12) // Bronze
        default: return Color(red: 0.4, green: 0.3, blue: 0.5)
        }
    }

    private func milestoneBorderColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Bright gold
        case 2: return Color(red: 0.85, green: 0.85, blue: 0.88) // Bright silver
        case 3: return Color(red: 0.90, green: 0.58, blue: 0.22) // Bright bronze
        default: return Color(red: 0.55, green: 0.45, blue: 0.65)
        }
    }

    @ViewBuilder
    private func rankFrame(for rank: Int) -> some View {
        if rank <= 3 {
            // Decorative corner accents for top 3
            GeometryReader { geo in
                let size = geo.size
                Path { path in
                    // Top-left corner
                    path.move(to: CGPoint(x: -4, y: -4))
                    path.addLine(to: CGPoint(x: 8, y: -4))
                    path.move(to: CGPoint(x: -4, y: -4))
                    path.addLine(to: CGPoint(x: -4, y: 8))
                    // Top-right corner
                    path.move(to: CGPoint(x: size.width + 4, y: -4))
                    path.addLine(to: CGPoint(x: size.width - 8, y: -4))
                    path.move(to: CGPoint(x: size.width + 4, y: -4))
                    path.addLine(to: CGPoint(x: size.width + 4, y: 8))
                    // Bottom-left corner
                    path.move(to: CGPoint(x: -4, y: size.height + 4))
                    path.addLine(to: CGPoint(x: 8, y: size.height + 4))
                    path.move(to: CGPoint(x: -4, y: size.height + 4))
                    path.addLine(to: CGPoint(x: -4, y: size.height - 8))
                    // Bottom-right corner
                    path.move(to: CGPoint(x: size.width + 4, y: size.height + 4))
                    path.addLine(to: CGPoint(x: size.width - 8, y: size.height + 4))
                    path.move(to: CGPoint(x: size.width + 4, y: size.height + 4))
                    path.addLine(to: CGPoint(x: size.width + 4, y: size.height - 8))
                }
                .stroke(milestoneBorderColor(for: rank), lineWidth: 2)
            }
        } else {
            EmptyView()
        }
    }

    private func platformColor(for platform: Platform) -> Color {
        switch platform {
        case .ios: return Color(red: 0.2, green: 0.6, blue: 0.2)
        case .android: return Color(red: 0.2, green: 0.6, blue: 0.2)
        case .unknown: return .gray
        }
    }
    
    private func rankIcon(for rank: Int) -> String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return "number.circle.fill"
        }
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return .orange
        default: return .secondary
        }
    }
    
    private func avatarGradient(for id: String) -> LinearGradient {
        let hash = id.hashValue
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .indigo]
        let color1 = colors[abs(hash) % colors.count]
        let color2 = colors[abs(hash >> 8) % colors.count]
        return LinearGradient(colors: [color1, color2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func platformIcon(for platform: Platform) -> String {
        switch platform {
        case .ios: return "applelogo"
        case .android: return "a.circle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private func flagEmoji(_ countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicodeScalar = UnicodeScalar(base + scalar.value) {
                emoji.unicodeScalars.append(unicodeScalar)
            }
        }
        return emoji
    }

    // MARK: - Report System

    /// Report a player. After 3 reports, the player is banned and removed from the leaderboard.
    /// If the local user reports too many unique players (abuse threshold), they get banned
    /// and all victims are unbanned.
    private func reportPlayer(_ entry: LeaderboardEntry) {
        let isFirstReport = reportCounts[entry.id] == nil
        let currentCount = (reportCounts[entry.id] ?? 0) + 1
        reportCounts[entry.id] = currentCount
        lastReportedName = entry.name
        lastReportedCount = currentCount

        // Track unique reports for abuse detection
        // True reports always cost 1 abuse point
        if isFirstReport {
            totalUniqueReports += 1
        }

        if currentCount >= 3 {
            // Ban threshold reached for this player
            bannedPlayerIds.insert(entry.id)
            playersBannedByMe.insert(entry.id)

            // Check for report abuse AFTER banning
            if totalUniqueReports > reportAbuseThreshold {
                // Abusing reports — unban all victims and ban the reporter
                for victimId in playersBannedByMe {
                    bannedPlayerIds.remove(victimId)
                }
                playersBannedByMe.removeAll()
                showReportAbuseAlert = true
            } else {
                showPlayerBanned = true
            }
        } else {
            // Check for abuse even before any single player hits 3
            if totalUniqueReports > reportAbuseThreshold {
                // Unban all victims and flag the reporter
                for victimId in playersBannedByMe {
                    bannedPlayerIds.remove(victimId)
                }
                playersBannedByMe.removeAll()
                showReportAbuseAlert = true
            } else {
                showReportConfirmation = true
            }
        }
    }
}

#Preview("Leaderboard") {
    LeaderboardView(client: .preview)
}

public extension LeaderboardClient {
    static let preview = LeaderboardClient(
        authenticate: { true },
        submitScore: { _ in },
        fetchPage: { _, _, _, _ in
            .init(entries: previewEntries, myEntry: previewEntries.last, nextCursor: nil, totalPlayers: 12847)
        },
        fetchMyRank: { _, _ in previewEntries.last }
    )

    private static let previewEntries: [LeaderboardEntry] = [
        LeaderboardEntry(id: "1", rank: 1, name: "OldCentipede46123", score: 208000, countryCode: "US", platform: .ios, highestTile: "208bx"),
        LeaderboardEntry(id: "2", rank: 2, name: "lalajalay", score: 94000, countryCode: "US", platform: .ios, highestTile: "94bt"),
        LeaderboardEntry(id: "3", rank: 3, name: "AscertainableDoug", score: 370000, countryCode: "US", platform: .android, highestTile: "370bs"),
        LeaderboardEntry(id: "4", rank: 4, name: "VelvetyRoyalty17", score: 2000, countryCode: "US", platform: .android, highestTile: "2br"),
        LeaderboardEntry(id: "5", rank: 5, name: "Player73918", score: 42000, countryCode: "US", platform: .ios, highestTile: "42bo"),
        LeaderboardEntry(id: "6", rank: 6, name: "Player47812", score: 149000, countryCode: "US", platform: .android, highestTile: "149bj"),
        LeaderboardEntry(id: "7", rank: 7, name: "ExtensiveFlag8", score: 18000, countryCode: "US", platform: .ios, highestTile: "18bj"),
        LeaderboardEntry(id: "8", rank: 8, name: "StompingStronghold96", score: 2000, countryCode: "US", platform: .ios, highestTile: "2bi"),
        LeaderboardEntry(id: "9", rank: 9, name: "Player11104", score: 1000, countryCode: "US", platform: .android, highestTile: "1bi"),
        LeaderboardEntry(id: "me", rank: 46, name: "Angel Junior711", score: 1000, countryCode: "US", platform: .ios, isMe: true, highestTile: "1an"),
    ]
}
