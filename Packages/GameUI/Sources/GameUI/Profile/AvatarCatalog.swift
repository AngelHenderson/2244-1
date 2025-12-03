import SwiftUI

struct AvatarOption: Identifiable, Hashable {
    let id: String
    let emoji: String
    let background: [Color]
    let accent: Color
    
    var label: String {
        "\(emoji) avatar"
    }
    
    var idDescription: String {
        id
    }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        AvatarOption(id: "avatar-dog", emoji: "🐶", background: [.orange, .pink], accent: .white),
        AvatarOption(id: "avatar-cat", emoji: "🐱", background: [.blue, .purple], accent: .white),
        AvatarOption(id: "avatar-hat", emoji: "🧢", background: [.yellow, .orange], accent: .white),
        AvatarOption(id: "avatar-warrior", emoji: "🧑‍🚀", background: [.red, .purple], accent: .white),
        AvatarOption(id: "avatar-burger", emoji: "🍔", background: [.green, .orange], accent: .white),
        AvatarOption(id: "avatar-robot", emoji: "🤖", background: [.gray, .blue], accent: .white),
        AvatarOption(id: "avatar-phoenix", emoji: "🐉", background: [.orange, .red], accent: .white),
        AvatarOption(id: "avatar-chicken", emoji: "🐔", background: [.pink, Color(red: 1.0, green: 0.75, blue: 0.65)], accent: .white),
        AvatarOption(id: "avatar-anchor", emoji: "⚓️", background: [.cyan, .blue], accent: .white),
        AvatarOption(id: "avatar-bear", emoji: "🐻", background: [.brown, .black], accent: .white),
        AvatarOption(id: "avatar-shark", emoji: "🦈", background: [.black, .blue], accent: .white),
        AvatarOption(id: "avatar-plane", emoji: "🛩", background: [.yellow, .orange], accent: .white)
    ]
    
    static var `default`: AvatarOption {
        all.first ?? AvatarOption(id: "avatar-default", emoji: "🙂", background: [.blue, .purple], accent: .white)
    }
    
    static func option(for id: String) -> AvatarOption {
        all.first { $0.id == id } ?? `default`
    }
}

struct AvatarBadge: View {
    let option: AvatarOption
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: option.background, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
            Text(option.emoji)
                .font(.system(size: size * 0.45))
                .accessibilityHidden(true)
        }
        .accessibilityLabel(option.label)
    }
}
