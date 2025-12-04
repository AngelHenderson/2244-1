import SwiftUI
import CoreGraphics
import Foundation

struct AvatarOption: Identifiable, Hashable {
    let id: String
    let spriteColumn: Int
    let spriteRow: Int
    let accessibilityLabel: String
    
    var label: String { accessibilityLabel }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        AvatarOption(id: "avatar-dog", spriteColumn: 0, spriteRow: 0, accessibilityLabel: "Dog avatar"),
        AvatarOption(id: "avatar-cat", spriteColumn: 1, spriteRow: 0, accessibilityLabel: "Astronaut cat avatar"),
        AvatarOption(id: "avatar-hat", spriteColumn: 2, spriteRow: 0, accessibilityLabel: "Baseball hat avatar"),
        AvatarOption(id: "avatar-warrior", spriteColumn: 3, spriteRow: 0, accessibilityLabel: "Warrior avatar"),
        AvatarOption(id: "avatar-burger", spriteColumn: 0, spriteRow: 1, accessibilityLabel: "Burger avatar"),
        AvatarOption(id: "avatar-robot", spriteColumn: 1, spriteRow: 1, accessibilityLabel: "Robot avatar"),
        AvatarOption(id: "avatar-phoenix", spriteColumn: 2, spriteRow: 1, accessibilityLabel: "Phoenix avatar"),
        AvatarOption(id: "avatar-chicken", spriteColumn: 3, spriteRow: 1, accessibilityLabel: "Chicken avatar"),
        AvatarOption(id: "avatar-anchor", spriteColumn: 0, spriteRow: 2, accessibilityLabel: "Anchor avatar"),
        AvatarOption(id: "avatar-bear", spriteColumn: 1, spriteRow: 2, accessibilityLabel: "Bear avatar"),
        AvatarOption(id: "avatar-shark", spriteColumn: 2, spriteRow: 2, accessibilityLabel: "Shark avatar"),
        AvatarOption(id: "avatar-plane", spriteColumn: 3, spriteRow: 2, accessibilityLabel: "Paper plane avatar")
    ]
    
    static var `default`: AvatarOption {
        all.first ?? AvatarOption(id: "avatar-default", spriteColumn: 0, spriteRow: 0, accessibilityLabel: "Default avatar")
    }
    
    static func option(for id: String) -> AvatarOption {
        all.first { $0.id == id } ?? `default`
    }
}

struct AvatarBadge: View {
    let option: AvatarOption
    var size: CGFloat = 80
    
    var body: some View {
        AvatarSpriteSheet.image(for: option)
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
}

@MainActor
enum AvatarSpriteSheet {
    private static let columns = 4
    private static let rows = 3
    private static var cache: [String: CGImage] = [:]
    
    private static let sheet: CGImage? = {
        guard let url = Bundle.module.url(forResource: "AvatarsSheet", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return nil
        }
        return image
    }()
    
    static func image(for option: AvatarOption) -> Image {
        if let cached = cache[option.id] {
            return Image(decorative: cached, scale: 1, orientation: .up)
        }
        guard let sheet else {
            return Image(systemName: "person.circle.fill")
        }
        
        let tileWidth = sheet.width / columns
        let tileHeight = sheet.height / rows
        let originX = option.spriteColumn * tileWidth
        let originY = option.spriteRow * tileHeight
        // Flip y-axis because CGImage origin is bottom-left
        let flippedY = sheet.height - originY - tileHeight
        let rect = CGRect(
            x: CGFloat(originX),
            y: CGFloat(flippedY),
            width: CGFloat(tileWidth),
            height: CGFloat(tileHeight)
        )
        
        guard let cropped = sheet.cropping(to: rect) else {
            return Image(systemName: "person.circle.fill")
        }
        cache[option.id] = cropped
        return Image(decorative: cropped, scale: 1, orientation: .up)
    }
}
