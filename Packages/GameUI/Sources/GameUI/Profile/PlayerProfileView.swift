import SwiftUI

@MainActor
public struct PlayerProfileView: View {
    @Environment(\.profileClient) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var model = ProfileModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    identityHero
                    coreStats
                    masteryGrid
                    actions
                    syncFooter
                }
                .padding(16)
            }
            .refreshable {
                await model.load(using: client)
            }
            .navigationTitle("Player Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Customize") { model.showCustomize = true }
                    Button("Compare") { model.showCompare = true }
                }
            }
            .task { 
                await model.load(using: client)
            }
            .sheet(isPresented: $model.showCustomize) {
                AvatarCustomizeView(
                    currentAvatar: model.avatarSystemName,
                    onSelect: { newAvatar in
                        model.avatarSystemName = newAvatar
                    }
                )
            }
            .sheet(isPresented: $model.showSeasonHistory) {
                SeasonHistoryView(season: model.season) 
            }
            .sheet(isPresented: $model.showCompare) {
                CompareView(friendCode: model.friendCode) 
            }
            .sheet(isPresented: $model.showRename) {
                RenameSheet(
                    current: model.playerName,
                    onSave: { newName in
                        await model.rename(to: newName, using: client)
                    }
                )
            }
        }
    }

    // MARK: Sections

    private var identityHero: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)
                Image(systemName: model.avatarSystemName)
                    .resizable().scaledToFit()
                    .frame(width: 56, height: 56)
                // Cosmetic ring
                Circle().stroke(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                    .frame(width: 80, height: 80)
            }
            .onTapGesture { model.showCustomize = true }
            .accessibilityLabel("Avatar. Double-tap to customize.")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.playerName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Button {
                        model.showRename = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit name")
                }

                HStack(spacing: 8) {
                    Label(model.friendCode, systemImage: "person.badge.key.fill")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .contextMenu {
                            Button("Copy Code") { 
                                #if os(iOS)
                                UIPasteboard.general.string = model.friendCode
                                #endif
                            }
                            ShareLink("Share Code", item: URL(string: "game2244://add-friend?code=\(model.friendCode)")!)
                        }

                    Spacer(minLength: 0)

                    Button {
                        model.showSeasonHistory = true
                    } label: {
                        HStack(spacing: 6) {
                            Label("\(model.season.name)", systemImage: "shield.checkerboard")
                            Text("• \(model.season.division)")
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Season history")
                }
            }
        }
    }

    private var coreStats: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Best Score",
                value: model.bestScoreText,
                info: "Your highest single‑run score. Ties are broken by earliest time achieved."
            )
            StatCard(
                title: "Global Rank",
                value: "#\(model.globalRank)",
                info: "Your position on the world ladder. Updates after each run."
            )
        }
    }

    private var masteryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tier Mastery")
                    .font(.headline)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(model.tiers) { tier in
                    TierCard(tier: tier)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            ShareLink(
                "Share",
                item: ShareableProfile(
                    payload: payload(),
                    deepLink: client.shareDeepLink(for: payload())
                ),
                preview: SharePreview(
                    "\(model.playerName)'s Profile",
                    image: Image(systemName: "person.crop.square.filled.and.at.rectangle")
                )
            )
            .buttonStyle(.borderedProminent)

            Button {
                model.showCompare = true
            } label: {
                Label("Compare", systemImage: "person.2.cross")
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }

    private var syncFooter: some View {
        HStack(spacing: 6) {
            switch model.sync {
            case .syncing:
                ProgressView().controlSize(.mini)
                Text("Syncing…").foregroundStyle(.secondary)
            case .synced(let date):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Synced • \(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now))")
                    .foregroundStyle(.secondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message).foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await model.load(using: client)
                    }
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
            Spacer()
        }
        .font(.footnote)
        .padding(.top, 8)
    }

    private func payload() -> ProfilePayload {
        .init(
            playerName: model.playerName,
            bestScoreText: model.bestScoreText,
            globalRank: model.globalRank,
            tiers: model.tiers,
            friendCode: model.friendCode,
            season: model.season,
            avatarSystemName: model.avatarSystemName
        )
    }
}

// MARK: - Components

private struct StatCard: View {
    var title: String
    var value: String
    var info: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Image(systemName: "info.circle").help(info)
            }
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TierCard: View {
    var tier: TierStat
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tier.color.opacity(0.9))
                    .frame(width: 36, height: 36)
                Text(tier.key)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Text("\(tier.value)")
                .font(.headline.monospacedDigit())
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .help(tier.label)
    }
}

// MARK: - Helper Extensions

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}