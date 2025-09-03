import SwiftUI
import GameApp

public struct HomeView: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions

    public init() {}
    
    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color.indigo.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top HUD
                HUDTopBar()
                    .padding(.top, 8)

                // Main content with side rails and center progression
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 16) {
                        // Left rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "ads", // using available icon set
                                title: "DAILY",
                                badge: state.hasDailyBadge,
                                action: { actions.openDaily() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "ads",
                                title: "FREE SPIN",
                                badge: state.hasFreeSpinBadge,
                                action: { actions.openFreeSpin() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "mysterybox",
                                title: "SHOP",
                                badge: state.hasShopBadge,
                                action: { actions.openShop() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "restart",
                                title: "MUSIC",
                                action: { actions.openMusic() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "gift",
                                title: "SALE OFFER",
                                badge: true,
                                action: { actions.openSaleOffer() }
                            )
                            
                            Spacer(minLength: 0)
                            
                            // Theme selector (left)
                            ThemeButton(name: state.themesLeftName, action: { actions.openThemeLeft() })
                        }
                        .frame(width: 80)
                        .padding(.top, 20)

                        // Center progression ladder
                        VStack(spacing: 20) {
                            // Top locked milestones with connecting dots
                            if state.lockedMilestones.count > 1 {
                                TileBadge(value: state.lockedMilestones[1], style: .locked)
                                
                                // Dotted connector
                                VStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Circle()
                                            .fill(.white.opacity(0.3))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 20)
                            }
                            
                            if let first = state.lockedMilestones.first {
                                TileBadge(value: first, style: .locked)
                                
                                // Dotted connector
                                VStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Circle()
                                            .fill(.white.opacity(0.3))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 20)
                            }

                            // Highest tile (hero element)
                            VStack(spacing: 8) {
                                TileBadge(value: state.highestTile, style: .primary)
                                Text("Highest Tile")
                                    .foregroundStyle(.white.opacity(0.8))
                                    .font(.subheadline)
                            }
                            
                            // Dotted connector
                            VStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill(.white.opacity(0.3))
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 20)

                            // Below milestone
                            TileBadge(value: state.milestoneBelow, style: .secondary)
                            
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                        // Right rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "hammer",
                                title: "CREATE",
                                locked: state.isCreateLocked,
                                action: { actions.openCreate() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "ads",
                                title: "",
                                badge: true,
                                specialLabel: "+\(state.adReward)",
                                action: {
                                    Task {
                                        let reward = await actions.watchAd()
                                        await MainActor.run { state.addGems(reward) }
                                    }
                                }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "challenge",
                                title: "CHALLENGE",
                                locked: state.isChallengeLocked,
                                action: { actions.openChallenge() }
                            )

                            // Best Offer with countdown
                            if let deadline = state.bestOfferDeadline {
                                VStack(spacing: 6) {
                                    SideRailButton(
                                        systemImage: nil,
                                        customImage: "gift",
                                        title: "BEST OFFER",
                                        action: { actions.openShop() }
                                    )
                                    CountdownView(deadline: deadline)
                                }
                            } else {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "gift",
                                    title: "BEST OFFER",
                                    action: { actions.openShop() }
                                )
                            }
                            
                            Spacer(minLength: 0)
                            
                            // Theme selector (right)
                            ThemeButton(name: state.themesRightName, action: { actions.openThemeRight() })
                        }
                        .frame(width: 80)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 12)
                }

                // Play button
                PillButton(title: "Play", icon: "play.fill") { 
                    actions.play() 
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)

                // Bottom dock
                HStack(spacing: 22) {
                    dockItem(
                        system: "person.circle.fill",
                        title: "Profile",
                        badge: state.hasProfileBadge,
                        action: { actions.openProfile() }
                    )
                    dockItem(
                        system: "star.circle.fill",
                        title: "Achievements",
                        badge: state.hasAchievementsBadge,
                        action: { actions.openAchievements() }
                    )
                    dockItem(
                        system: "trophy.circle.fill",
                        title: "Leaderboard",
                        action: { actions.openLeaderboard() }
                    )
                    dockItem(
                        system: "gearshape.fill",
                        title: "Settings",
                        action: { actions.openSettings() }
                    )
                }
                .padding(.bottom, 16)
            }
        }
    }

    private func dockItem(system: String, title: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    // Prefer asset with same semantic name if available
                    let asset = assetName(for: title)
                    if !asset.isEmpty {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: system)
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                if badge {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .accessibilityLabel("\(title)\(badge ? ", new" : "")")
    }

    private func assetName(for title: String) -> String {
        switch title.lowercased() {
        case "profile": return "Icons/leaderboard"
        case "achievements": return "Icons/achievement"
        case "leaderboard": return "Icons/leaderboard"
        case "settings": return "Icons/settings"
        default: return ""
        }
    }
}

// Theme button component
private struct ThemeButton: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themeGradient)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: themeIcon)
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
    
    private var themeGradient: LinearGradient {
        switch name.lowercased() {
        case "beach":
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "aqua":
            return LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var themeIcon: String {
        switch name.lowercased() {
        case "beach": return "sun.max.fill"
        case "aqua": return "drop.fill"
        default: return "sparkle"
        }
    }
}
