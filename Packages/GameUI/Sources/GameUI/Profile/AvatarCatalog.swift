import SwiftUI

struct AvatarOption: Identifiable, Hashable {
    let id: String
    let imageName: String
    let accessibilityLabel: String

    var label: String { accessibilityLabel }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        AvatarOption(id: "avatar-dog", imageName: "avatar_dog", accessibilityLabel: "Dog avatar"),
        AvatarOption(id: "avatar-cat", imageName: "avatar_cat", accessibilityLabel: "Astronaut cat avatar"),
        AvatarOption(id: "avatar-hat", imageName: "avatar_hat", accessibilityLabel: "Baseball hat avatar"),
        AvatarOption(id: "avatar-warrior", imageName: "avatar_warrior", accessibilityLabel: "Warrior avatar"),
        AvatarOption(id: "avatar-burger", imageName: "avatar_burger", accessibilityLabel: "Burger avatar"),
        AvatarOption(id: "avatar-robot", imageName: "avatar_robot", accessibilityLabel: "Robot avatar"),
        AvatarOption(id: "avatar-phoenix", imageName: "avatar_phoenix", accessibilityLabel: "Phoenix avatar"),
        AvatarOption(id: "avatar-chicken", imageName: "avatar_chicken", accessibilityLabel: "Chicken avatar"),
        AvatarOption(id: "avatar-anchor", imageName: "avatar_anchor", accessibilityLabel: "Anchor avatar"),
        AvatarOption(id: "avatar-bear", imageName: "avatar_bear", accessibilityLabel: "Bear avatar"),
        AvatarOption(id: "avatar-shark", imageName: "avatar_shark", accessibilityLabel: "Shark avatar"),
        AvatarOption(id: "avatar-plane", imageName: "avatar_plane", accessibilityLabel: "Paper plane avatar")
    ]

    static var `default`: AvatarOption {
        all.first ?? AvatarOption(id: "avatar-default", imageName: "avatar_dog", accessibilityLabel: "Default avatar")
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
