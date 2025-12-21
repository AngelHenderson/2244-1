import SwiftUI

struct AvatarOption: Identifiable, Hashable {
    let id: String
    let imageName: String
    let accessibilityLabel: String

    var label: String { accessibilityLabel }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        AvatarOption(id: "avatar-shiba-dog", imageName: "avatar_shiba_dog", accessibilityLabel: "Shiba Inu dog avatar"),
        AvatarOption(id: "avatar-astronaut-cat", imageName: "avatar_astronaut_cat", accessibilityLabel: "Astronaut cat avatar"),
        AvatarOption(id: "avatar-robot-green", imageName: "avatar_robot_green", accessibilityLabel: "Green robot avatar"),
        AvatarOption(id: "avatar-phoenix-fire", imageName: "avatar_phoenix_fire", accessibilityLabel: "Fire phoenix avatar"),
        AvatarOption(id: "avatar-shark-teeth", imageName: "avatar_shark_teeth", accessibilityLabel: "Shark avatar"),
        AvatarOption(id: "avatar-paper-plane", imageName: "avatar_paper_plane", accessibilityLabel: "Paper plane avatar"),
        AvatarOption(id: "avatar-baseball-cap", imageName: "avatar_baseball_cap", accessibilityLabel: "Baseball cap avatar"),
        AvatarOption(id: "avatar-warrior-samurai", imageName: "avatar_warrior_samurai", accessibilityLabel: "Samurai warrior avatar"),
        AvatarOption(id: "avatar-burger-food", imageName: "avatar_burger_food", accessibilityLabel: "Burger avatar"),
        AvatarOption(id: "avatar-chicken-bird", imageName: "avatar_chicken_bird", accessibilityLabel: "Chicken avatar"),
        AvatarOption(id: "avatar-anchor-nautical", imageName: "avatar_anchor_nautical", accessibilityLabel: "Anchor avatar"),
        AvatarOption(id: "avatar-bear-grizzly", imageName: "avatar_bear_grizzly", accessibilityLabel: "Grizzly bear avatar")
    ]

    static var `default`: AvatarOption {
        all.first ?? AvatarOption(id: "avatar-default", imageName: "avatar_shiba_dog", accessibilityLabel: "Default avatar")
    }

    static func option(for id: String) -> AvatarOption {
        all.first { $0.id == id } ?? `default`
    }
}

struct AvatarBadge: View {
    let option: AvatarOption
    var size: CGFloat = 80

    var body: some View {
        avatarImage
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: size * 0.05)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            )
            .accessibilityLabel(option.accessibilityLabel)
    }

    private var avatarImage: Image {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: option.imageName) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(named: option.imageName) {
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(systemName: "person.circle.fill")
    }
}
