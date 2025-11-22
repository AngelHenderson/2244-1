import SwiftUI
import UIKit

// MARK: - Share Card View

@MainActor
struct ProfileShareCard: View {
    let playerName: String
    let avatarSystemName: String
    let bestScore: String
    let globalRank: Int
    let friendCode: String
    let season: SeasonInfo
    let topTiers: [TierStat] // Show top 4-6 tiers
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with app branding
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("2244")
                    .font(.title2.weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Player identity
            VStack(spacing: 12) {
                // Avatar with ring
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: avatarSystemName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.white)
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 84, height: 84)
                }
                
                Text(playerName)
                    .font(.title2.weight(.bold))
                
                HStack(spacing: 12) {
                    Label(friendCode, systemImage: "person.badge.key.fill")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.caption)
                        Text("\(season.name) \(season.division)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            // Stats row
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Best Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(bestScore)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("Global Rank")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "#\(globalRank)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            
            // Top tier mastery (compact grid)
            if !topTiers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tier Mastery")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 8
                    ) {
                        ForEach(topTiers.prefix(6)) { tier in
                            HStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(tier.color.opacity(0.8))
                                        .frame(width: 24, height: 24)
                                    Text(tier.key)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                                Text(verbatim: String(tier.value))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            // Footer
            HStack {
                Image(systemName: "qrcode")
                    .font(.caption2)
                Text("game2244.app/\(friendCode)")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 400, height: 500)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Transferable Profile

struct ShareableProfile: Transferable {
    let payload: ProfilePayload
    let deepLink: URL
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { profile in
            try await profile.renderImage()
        }
        ProxyRepresentation { profile in
            profile.deepLink
        }
    }
    
    @MainActor
    private func renderImage() async throws -> Data {
        let renderer = ImageRenderer(
            content: ProfileShareCard(
                playerName: payload.playerName,
                avatarSystemName: payload.avatarSystemName,
                bestScore: payload.bestScoreText,
                globalRank: payload.globalRank,
                friendCode: payload.friendCode,
                season: payload.season,
                topTiers: Array(payload.tiers.prefix(6))
            )
            .environment(\.colorScheme, .dark) // Force dark mode for consistent branding
        )
        
        renderer.scale = 2.0 // Retina quality
        
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else {
            throw ShareError.imageRenderingFailed
        }
        
        return data
    }
}

enum ShareError: LocalizedError {
    case imageRenderingFailed
    
    var errorDescription: String? {
        switch self {
        case .imageRenderingFailed:
            return "Failed to create share image"
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension ProfileShareCard {
    static var previewPayload: ProfilePayload {
        .init(
            playerName: "Angel Junior711",
            bestScoreText: "3513812",
            globalRank: 534,
            tiers: [
                TierStat(key: "K", value: 244, color: .purple, label: "K-Tier"),
                TierStat(key: "M", value: 395, color: .pink, label: "M-Tier"),
                TierStat(key: "B", value: 323, color: .red, label: "B-Tier"),
                TierStat(key: "a", value: 287, color: .teal, label: "a-Tier"),
                TierStat(key: "b", value: 323, color: .yellow, label: "b-Tier"),
                TierStat(key: "c", value: 275, color: .green, label: "c-Tier")
            ],
            friendCode: "AJ711-534",
            season: SeasonInfo(name: "Season 7", division: "Diamond"),
            avatarSystemName: "pawprint.circle.fill"
        )
    }
}

#Preview("Share Card - Light", traits: .sizeThatFitsLayout) {
    ProfileShareCard(
        playerName: "Angel Junior711",
        avatarSystemName: "pawprint.circle.fill",
        bestScore: "3513812",
        globalRank: 534,
        friendCode: "AJ711-534",
        season: SeasonInfo(name: "Season 7", division: "Diamond"),
        topTiers: ProfileShareCard.previewPayload.tiers
    )
    .preferredColorScheme(.light)
    .padding()
}

#Preview("Share Card - Dark", traits: .sizeThatFitsLayout) {
    ProfileShareCard(
        playerName: "Angel Junior711",
        avatarSystemName: "pawprint.circle.fill",
        bestScore: "3513812",
        globalRank: 534,
        friendCode: "AJ711-534",
        season: SeasonInfo(name: "Season 7", division: "Diamond"),
        topTiers: ProfileShareCard.previewPayload.tiers
    )
    .preferredColorScheme(.dark)
    .padding()
}
#endif