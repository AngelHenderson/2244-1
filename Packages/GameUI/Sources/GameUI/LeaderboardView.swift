import SwiftUI
import GameApp

public struct LeaderboardView: View {
    @Environment(\.leaderboardClient) private var client
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentTheme) private var currentTheme
    @State private var model: LeaderboardModel? = nil
    @State private var showError = false
    @State private var showingTop150 = false

    private let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.14)

    public init() {}

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

                    Text(showingTop150 ? "TOP 150" : "LEADERBOARD")
                        .font(.avenirNext(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    GemBalancePill()

                    // Top 150 button (only show in milestone view, not for Hall of Fame)
                    if !showingTop150 && model?.selectedFilter != .hallOfFame {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let model {
                    if showingTop150 || model.selectedFilter == .hallOfFame {
                        // Show Top 150 view for Hall of Fame (requires infinity to rank)
                        // or when user explicitly requests Top 150
                        top150Content(model)
                    } else {
                        // Show milestone-based view for Global and Country leaderboards
                        milestoneContent(model)
                    }
                } else {
                    Spacer()
                    ProgressView("Loading leaderboard...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .task { await setup() }
                    Spacer()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(model?.error ?? "An error occurred")
        }
    }
    
    private func setup() async {
        let m = LeaderboardModel(client: client)
        self.model = m
        await m.authenticate()
        await m.refresh()

        // Auto-submit current score if it's better than what's on the leaderboard
        if let myEntry = m.myEntry, gameStore.state.score > myEntry.score {
            await m.submitScore(gameStore.state.score)
        }

        // Track global leaderboard rank for achievements
        if m.selectedFilter == .global, let myEntry = m.myEntry {
            gameStore.registerLeaderboardRank(myEntry.rank)
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
                        .foregroundStyle(.white)
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
                        ForEach(milestoneTiersAroundUser(userMilestone: userMilestone, filter: m.selectedFilter), id: \.milestone) { tier in
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
                    rankPreviewSection(userMilestone: userMilestone, filter: m.selectedFilter)
                }
            }
        }
    }

    /// Shows individual rank examples for milestones around the user's position
    @ViewBuilder
    private func rankPreviewSection(userMilestone: String, filter: LeaderboardFilter) -> some View {
        let previews = generateRankPreviews(userMilestone: userMilestone, filter: filter)

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

    /// Generates rank preview entries around the user's current rank
    /// Shows consecutive individual ranks (-3 to +3) with their corresponding milestones
    private func generateRankPreviews(userMilestone: String, filter: LeaderboardFilter) -> [RankPreview] {
        let userRank = rankForFilter(filter, milestone: userMilestone)
        var previews: [RankPreview] = []

        // For country leaderboards with top 150 players, use direct lookup
        if let countryCode = filter.countryCode {
            return generateCountryRankPreviews(
                userMilestone: userMilestone,
                userRank: userRank,
                countryCode: countryCode,
                filter: filter
            )
        }

        // For non-country leaderboards, we need the user's position in the milestone list
        let milestones = Self.allMilestones
        guard let userIndex = milestones.firstIndex(of: userMilestone) else {
            return []
        }

        // Calculate the user's tier boundaries directly
        // The tier start is where players with this milestone begin (rank returned by rankForFilter)
        let userTierStart = rankForFilter(filter, milestone: userMilestone)

        // Find the next worse milestone to get the tier end
        let nextWorseMilestoneIndex = userIndex + 1
        let userTierEnd: Int
        if nextWorseMilestoneIndex < milestones.count {
            // The next tier starts where the worse milestone begins
            let nextTierRank = rankForFilter(filter, milestone: milestones[nextWorseMilestoneIndex])
            // Ensure userTierEnd is at least userTierStart + 1 to include user's rank
            userTierEnd = max(nextTierRank, userTierStart + 1)
        } else {
            // User has the worst milestone, tier extends to infinity
            userTierEnd = Int.max
        }

        // Build a map of rank ranges to milestones for ranks outside user's tier
        let rangeStart = max(0, userIndex - 5)
        let rangeEnd = min(milestones.count - 1, userIndex + 5)

        var rankToMilestone: [(startRank: Int, milestone: String)] = []
        for i in rangeStart...rangeEnd {
            let milestone = milestones[i]
            let rank = rankForFilter(filter, milestone: milestone)
            rankToMilestone.append((rank, milestone))
        }
        rankToMilestone.sort { $0.startRank < $1.startRank }

        // Show ranks from 3 above to 3 below user's rank
        let startRank = max(1, userRank - 3)
        let endRank = userRank + 3

        for rank in startRank...endRank {
            let milestone: String

            // Always show user's actual milestone for their exact rank
            if rank == userRank {
                milestone = userMilestone
            } else if rank >= userTierStart && rank < userTierEnd {
                // This rank is in the same tier as the user - show user's milestone
                milestone = userMilestone
            } else if rank < userTierStart {
                // Rank is better than user's tier - find the appropriate better milestone
                milestone = findMilestoneForBetterRank(rank, userRank: userRank, userMilestone: userMilestone, rankToMilestone: rankToMilestone)
            } else {
                // Rank is worse than user's tier - find the appropriate worse milestone
                milestone = findMilestoneForWorseRank(rank, userRank: userRank, userMilestone: userMilestone, rankToMilestone: rankToMilestone)
            }

            previews.append(RankPreview(
                rank: rank,
                milestone: milestone,
                isUserRank: rank == userRank
            ))
        }

        return previews
    }

    /// Generate rank previews for country leaderboards using consecutive ranking
    /// Shows consecutive rank numbers with tier-based milestone assignments
    /// (consistent with the milestone tier view above)
    private func generateCountryRankPreviews(userMilestone: String, userRank: Int, countryCode: String, filter: LeaderboardFilter) -> [RankPreview] {
        let milestones = Self.allMilestones

        // Build tier boundaries from allMilestones using rankForFilter
        guard let userMilestoneIndex = milestones.firstIndex(of: userMilestone) else {
            return []
        }

        let searchStart = max(0, userMilestoneIndex - 10)
        let searchEnd = min(milestones.count, userMilestoneIndex + 10)

        var tierBoundaries: [(milestone: String, startRank: Int)] = []
        for i in searchStart..<searchEnd {
            let milestone = milestones[i]
            let rank = rankForFilter(filter, milestone: milestone)
            tierBoundaries.append((milestone, rank))
        }

        // Ensure tier boundaries are monotonically ordered outward from user
        let userBoundaryIndex = userMilestoneIndex - searchStart
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

        // Show ranks from 3 above to 3 below user's rank
        let startRank = max(1, userRank - 3)
        let endRank = userRank + 3

        var previews: [RankPreview] = []
        for rank in startRank...endRank {
            let milestone: String

            if rank == userRank {
                milestone = userMilestone
            } else if rank <= 150 {
                // For ranks within top 150, use actual player data
                if let actualMilestone = MockLeaderboardData.milestoneAtCountryRank(rank: rank, countryCode: countryCode) {
                    milestone = actualMilestone
                } else {
                    // Fallback to tier boundary lookup
                    var foundMilestone = userMilestone
                    for boundary in tierBoundaries {
                        if boundary.startRank <= rank {
                            foundMilestone = boundary.milestone
                        } else {
                            break
                        }
                    }
                    milestone = foundMilestone
                }
            } else {
                // For ranks beyond 150, use tier boundary lookup
                var foundMilestone = userMilestone
                for boundary in tierBoundaries {
                    if boundary.startRank <= rank {
                        foundMilestone = boundary.milestone
                    } else {
                        break
                    }
                }
                milestone = foundMilestone
            }

            previews.append(RankPreview(
                rank: rank,
                milestone: milestone,
                isUserRank: rank == userRank
            ))
        }

        return previews
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
    private func milestoneTiersAroundUser(userMilestone: String, filter: LeaderboardFilter) -> [(milestone: String, rankLabel: String)] {
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
        let tiers: [(milestone: String, rank: Int)] = milestones[startIndex..<endIndex].map { milestone in
            let rank = rankForFilter(filter, milestone: milestone)
            return (milestone, rank)
        }

        return tiers.map { tier in
            (tier.milestone, "\(tier.rank) - \(tier.milestone)")
        }
    }

    @ViewBuilder
    private func milestoneRow(milestone: String, rankLabel: String, isUserTier: Bool) -> some View {
        HStack(spacing: 0) {
            // User indicator on left
            if isUserTier {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.avenirNext(size: 12, weight: .regular))
                    .foregroundStyle(.cyan)
                    .padding(.trailing, 8)
            } else {
                Color.clear.frame(width: 20)
            }

            // Rank label (e.g., "73150 - 1B")
            Text(rankLabel)
                .font(.avenirNext(size: 18, weight: isUserTier ? .bold : .medium))
                .foregroundStyle(isUserTier ? .white : .white.opacity(0.7))

            Spacer()

            // Milestone badge
            let tileRadius: CGFloat = currentTheme?.tileShape == .square ? 3 : 6
            Text(milestone)
                .font(.avenirNext(size: 14, weight: .bold))
                .foregroundStyle(.white)
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
        }
    }

    // Build display entries with user merged at correct position
    private func buildDisplayEntries(_ m: LeaderboardModel) -> [LeaderboardEntry] {
        guard let myEntry = m.myEntry else {
            return m.entries
        }

        // Filter out any existing user entry to avoid duplicates
        var result = m.entries.filter { !$0.isMe }

        // Check if user should be in the displayed range
        guard let lastEntry = result.last else {
            return [myEntry]
        }

        // If user's rank is within or just after the displayed range, insert them
        if myEntry.rank <= lastEntry.rank {
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
}

#Preview("Leaderboard") {
    LeaderboardView()
        .environment(\.leaderboardClient, .preview)
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
