import SwiftUI

public struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    /// Called when tutorial is completed (for first-launch flow)
    public var onComplete: (() -> Void)?

    private let pages: [TutorialPage] = [
        TutorialPage(
            title: "Welcome to 2244!",
            subtitle: "Learn the basics",
            description: "Connect tiles to create chains and merge them into higher values. Let's learn how!",
            systemImage: "hand.wave.fill",
            imageColor: .blue
        ),
        TutorialPage(
            title: "Connect Tiles",
            subtitle: "Draw chains",
            description: "Drag your finger across adjacent tiles to create a chain. Tiles can connect in all 8 directions - horizontal, vertical, and diagonal.",
            systemImage: "hand.draw.fill",
            imageColor: .green
        ),
        TutorialPage(
            title: "Chain Rules",
            subtitle: "Same or double",
            description: "Start with two tiles of the same value. Then you can add tiles that are the same value OR double the previous tile in your chain.",
            systemImage: "link",
            imageColor: .orange
        ),
        TutorialPage(
            title: "Merge & Score",
            subtitle: "Watch them combine",
            description: "When you release your chain, all tiles merge into one! The final value depends on how many tiles you chained together. Longer chains = higher values!",
            systemImage: "arrow.triangle.merge",
            imageColor: .purple
        ),
        TutorialPage(
            title: "Power-Ups",
            subtitle: "Special abilities",
            description: "Use power-ups to help you:\n\n🔨 Hammer - Remove any tile\n🔄 Swap - Switch two tiles\n🧲 Magnet - Attract matching tiles\n↩️ Undo - Reverse your last move",
            systemImage: "bolt.fill",
            imageColor: .yellow
        ),
        TutorialPage(
            title: "You're Ready!",
            subtitle: "Start playing",
            description: "Reach higher tile values to unlock new milestones and climb the leaderboard. Good luck!",
            systemImage: "trophy.fill",
            imageColor: .mint
        )
    ]

    public init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        TutorialPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicator and buttons
                VStack(spacing: 20) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }

                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        if currentPage < pages.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Let's Play!") {
                                if let onComplete {
                                    onComplete()
                                } else {
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Tutorial Page Model

private struct TutorialPage {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let imageColor: Color
}

// MARK: - Tutorial Page View

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.systemImage)
                .font(.system(size: 80))
                .foregroundStyle(page.imageColor)
                .padding(.bottom, 16)

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    HowToPlayView()
}

#Preview("First Launch") {
    HowToPlayView(onComplete: {
        print("Tutorial completed!")
    })
}
