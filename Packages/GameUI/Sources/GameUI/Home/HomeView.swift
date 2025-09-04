import SwiftUI
import GameApp

public struct HomeView: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions
    @Environment(\.tileJourney) private var journey
    @State private var isShowingJourney: Bool = false

    public init() {}
    
    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.init(hex: "EBEBEB")],
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
                                customImage: "dailypic", // using available icon set
                                title: "DAILY",
                                badge: state.hasDailyBadge,
                                action: { actions.openDaily() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "spinthewheel",
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
                                customImage: "soundeffect",
                                title: "MUSIC",
                                action: { actions.openMusic() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "salesoffer",
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

                        // Center progression ladder - USING JOURNEYKIT
                        VStack(spacing: 20) {
                            // Get visual journey path (optimized for vertical display)
                            let journeyPath = journey.visualJourneyPath()
                            let current = journey.highestTile
                            
                            // Show milestones from the journey path (reversed for top-to-bottom display)
                            ForEach(Array(journeyPath.reversed().enumerated()), id: \.offset) { index, milestone in
                                VStack(spacing: 0) {
                                    if milestone > current {
                                        // Locked future milestone
                                        TileBadge(value: milestone, style: .locked)
                                    } else if milestone == current {
                                        // Current highest tile (hero element) — tap to open Journey
                                        Button(action: { isShowingJourney = true }) {
                                            VStack(spacing: 8) {
                                                TileBadge(
                                                    value: milestone, 
                                                    style: .primary,
                                                    showClaimBadge: !journey.claimed.contains(milestone)
                                                )
                                                Text("Highest Tile")
                                                    .foregroundStyle(.white.opacity(0.8))
                                                    .font(.subheadline)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        // Previously achieved milestone
                                        TileBadge(
                                            value: milestone, 
                                            style: .secondary,
                                            showClaimBadge: !journey.claimed.contains(milestone) && milestone <= current,
                                            isClaimed: journey.claimed.contains(milestone)
                                        )
                                    }
                                    
                                    // Dotted connector (except for last item)
                                    if index < journeyPath.count - 1 {
                                        VStack(spacing: 4) {
                                            ForEach(0..<6, id: \.self) { _ in
                                                Circle()
                                                    .fill(.white.opacity(0.3))
                                                    .frame(width: 4, height: 4)
                                            }
                                        }
//                                        .frame(height: 20)
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                        // Right rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "createagame",
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
        // Journey sheet
        .sheet(isPresented: $isShowingJourney) {
            VStack(spacing: 16) {
                JourneyHeader()
                JourneyPanel(showAll: true)
                    .padding(.horizontal)
            }
            .padding(.top, 12)
            .presentationDetents([.medium, .large])
        }
    }

    private func dockItem(system: String, title: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack{
                VStack(spacing: 4) {
                    // Prefer asset with same semantic name if available
                    let asset = assetName(for: title)
                    if !asset.isEmpty {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: system)
                            .font(.system(size: 24))
                            //.foregroundStyle(.white)
                    }
//                    Text(title)
//                        .font(.caption2)
//                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
        case "profile": return "profile"
        case "achievements": return "achievement"
        case "leaderboard": return "leaderboard"
        case "settings": return "settings"
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
                            //.foregroundStyle(.white)
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
                colors: [Color.init(hex: "EBEBEB")],
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
