import SwiftUI

struct HomeDockItem: Identifiable {
    let id: String
    let system: String
    let title: String
    var badge: Bool = false
    var badgeCount: Int = 0
    var banned: Bool = false
    let action: () -> Void
}

struct HomeCustomTabBar: View {
    let items: [HomeDockItem]
    let metrics: HomeLayoutMetrics.DockMetrics

    var body: some View {
        HStack(spacing: metrics.itemSpacing) {
            ForEach(items) { item in
                HomeTabBarButton(item: item, metrics: metrics)
                    .frame(width: metrics.slotWidth, height: metrics.buttonSize)
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.bottom, metrics.bottomPadding)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }
}

private struct HomeTabBarButton: View {
    let item: HomeDockItem
    let metrics: HomeLayoutMetrics.DockMetrics

    var body: some View {
        Button(action: item.action) {
            ZStack(alignment: .topTrailing) {
                Group {
                    let asset = assetName(for: item.title)
                    if !asset.isEmpty {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: metrics.iconSize, height: metrics.iconSize)
                    } else {
                        Image(systemName: item.system)
                            .font(.system(size: metrics.iconSize * 0.58, weight: .semibold))
                    }
                }
                .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                badgeView
            }
            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }

    @ViewBuilder
    private var badgeView: some View {
        if item.banned {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: max(14, metrics.buttonSize * 0.28)))
                .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                .offset(x: 4, y: -4)
        } else if item.badgeCount > 0 {
            Text("\(item.badgeCount)")
                .font(.avenirNext(size: metrics.badgeFontSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.red, in: Capsule())
                .offset(x: 4, y: -4)
        } else if item.badge {
            Circle()
                .fill(.red)
                .frame(width: max(8, metrics.buttonSize * 0.16), height: max(8, metrics.buttonSize * 0.16))
                .offset(x: 4, y: -4)
        }
    }

    private func assetName(for title: String) -> String {
        switch title.lowercased() {
        case "profile":
            "profile"
        case "achievements":
            "achievement"
        case "leaderboard":
            "leaderboard"
        case "settings":
            "settings"
        case "theme":
            "themedefault"
        default:
            ""
        }
    }
}
