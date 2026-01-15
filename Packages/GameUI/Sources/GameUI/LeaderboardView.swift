import SwiftUI
import GameApp

public struct LeaderboardView: View {
    @Environment(\.leaderboardClient) private var client
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @State private var model: LeaderboardModel? = nil
    @State private var showError = false

    private let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.14)

    public init() {}

    public var body: some View {
        ZStack {
            darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    Text("LEADERBOARD")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Invisible spacer for centering
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let model {
                    content(model)
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
    }
    
    @ViewBuilder
    private func content(_ m: LeaderboardModel) -> some View {
        VStack(spacing: 0) {
            // Filter Tabs (based on user's country)
            HStack(spacing: 8) {
                ForEach(LeaderboardFilter.availableFilters(for: UserLeaderboardData.currentCountry)) { filter in
                    filterTab(filter, isSelected: m.selectedFilter == filter) {
                        m.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Leaderboard List
            if m.isLoading && !m.hasData {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Spacer()
            } else if m.hasData {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(m.entries.enumerated()), id: \.element.id) { index, entry in
                            leaderboardRow(entry, index: index)
                                .task {
                                    // Load more when reaching the end
                                    if entry.id == m.entries.last?.id, m.canLoadMore {
                                        await m.loadMore()
                                    }
                                }
                        }

                        // Show loading indicator for pagination
                        if m.isLoadingMore {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        }

                        // Show "My Entry" if not in the visible list
                        if let myEntry = m.myEntry,
                           !m.entries.contains(where: { $0.id == myEntry.id }) {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.vertical, 16)

                                Text("Your Position")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.bottom, 8)

                                leaderboardRow(myEntry, index: nil)
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No leaderboard data")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Be the first to set a score!")
                        .font(.caption)
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
    }
    
    private func filterTab(_ filter: LeaderboardFilter, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter == .global {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 14))
                } else if filter == .hallOfFame {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                } else if let countryCode = filter.countryCode {
                    Text(flagEmoji(countryCode))
                        .font(.system(size: 14))
                }

                Text(filter.rawValue)
                    .font(.system(size: 14, weight: .semibold))
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
        }
    }
    
    private func leaderboardRow(_ entry: LeaderboardEntry, index: Int?) -> some View {
        HStack(spacing: 12) {
            // Rank Number
            Text(verbatim: entry.isMe && entry.rank > 9 ? "▶\(entry.rank)" : "\(entry.rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
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
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(platformColor(for: entry.platform))
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }

            // Player Name
            Text(entry.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Country Flag
            if let countryCode = entry.countryCode {
                Text(flagEmoji(countryCode))
                    .font(.title3)
            }

            // Milestone Badge (highest tile)
            if let highestTile = entry.highestTile {
                Text(highestTile)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(milestoneBadgeColor(for: entry.rank))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(milestoneBorderColor(for: entry.rank), lineWidth: 2)
                            )
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
                .font(.headline)
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
