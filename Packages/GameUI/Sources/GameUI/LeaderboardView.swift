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
            // Filter Tabs (Global, Hall of Fame, US)
            HStack(spacing: 8) {
                ForEach(LeaderboardFilter.allCases) { filter in
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
                } else if filter == .country {
                    Text(flagEmoji("US"))
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
                if let avatarURL = entry.avatarURL, let url = URL(string: avatarURL) {
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
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.6, green: 0.5, blue: 0.2), Color(red: 0.5, green: 0.4, blue: 0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case 2:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.45, green: 0.45, blue: 0.5), Color(red: 0.35, green: 0.35, blue: 0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case 3:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.35, blue: 0.2), Color(red: 0.45, green: 0.28, blue: 0.15)],
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
        case 1: return Color(red: 0.7, green: 0.55, blue: 0.25)
        case 2: return Color(red: 0.5, green: 0.5, blue: 0.55)
        case 3: return Color(red: 0.6, green: 0.4, blue: 0.25)
        default: return Color(red: 0.4, green: 0.3, blue: 0.5)
        }
    }

    private func milestoneBorderColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.7, blue: 0.35)
        case 2: return Color(red: 0.65, green: 0.65, blue: 0.7)
        case 3: return Color(red: 0.75, green: 0.5, blue: 0.3)
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


