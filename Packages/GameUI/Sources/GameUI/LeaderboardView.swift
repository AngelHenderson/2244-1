import SwiftUI
import GameApp

public struct LeaderboardView: View {
    @Environment(\.leaderboardClient) private var client
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @State private var model: LeaderboardModel? = nil
    @State private var showError = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView("Loading leaderboard...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task { await setup() }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
            // Period & Scope Selectors
            VStack(spacing: 12) {
                // Period Picker
                Picker("Period", selection: Binding(
                    get: { m.selectedPeriod },
                    set: { m.selectedPeriod = $0 }
                )) {
                    ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Filter Tabs
                HStack(spacing: 8) {
                    ForEach(LeaderboardFilter.allCases) { filter in
                        filterTab(filter, isSelected: m.selectedFilter == filter) {
                            m.selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            
            // Stats Bar
            if let total = m.totalPlayers {
                HStack {
                    Label("\(total) Players", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let myEntry = m.myEntry {
                        Text("Your Rank: \(LeaderboardModel.formatRank(myEntry.rank))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemBackground))
            }
            
            // Leaderboard List
            if m.isLoading && !m.hasData {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
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
                                .padding()
                        }
                        
                        // Show "My Entry" if not in the visible list
                        if let myEntry = m.myEntry,
                           !m.entries.contains(where: { $0.id == myEntry.id }) {
                            VStack(spacing: 0) {
                                Divider()
                                    .padding(.vertical, 16)
                                
                                Text("Your Position")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 8)
                                
                                leaderboardRow(myEntry, index: nil)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No leaderboard data")
                        .font(.headline)
                    Text("Be the first to set a score!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            Text(filter.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(UIColor.tertiarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func leaderboardRow(_ entry: LeaderboardEntry, index: Int?) -> some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                if entry.rank <= 3 {
                    Image(systemName: rankIcon(for: entry.rank))
                        .font(.title2)
                        .foregroundStyle(rankColor(for: entry.rank))
                } else {
                    Text("\(entry.rank)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44)
            
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarGradient(for: entry.id))
                    .frame(width: 40, height: 40)
                
                Text(String(entry.name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            // Name and Score
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    
                    if entry.isMe {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                    
                    if let countryCode = entry.countryCode {
                        Text(flagEmoji(countryCode))
                            .font(.caption)
                    }
                }
                
                Text(LeaderboardModel.formatScore(entry.score))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Platform Icon
            Image(systemName: platformIcon(for: entry.platform))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(index != nil && index! % 2 == 0 ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground).opacity(0.3))
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


