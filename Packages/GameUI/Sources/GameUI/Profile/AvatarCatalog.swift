import SwiftUI

struct AvatarOption: Identifiable, Hashable {
    let id: String
    let imageName: String
    let accessibilityLabel: String

    var label: String { accessibilityLabel }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        // Original avatars
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
        AvatarOption(id: "avatar-bear-grizzly", imageName: "avatar_bear_grizzly", accessibilityLabel: "Grizzly bear avatar"),
        // New avatars
        AvatarOption(id: "avatar-ancient-scroll", imageName: "avatar_ancient_scroll", accessibilityLabel: "Ancient scroll avatar"),
        AvatarOption(id: "avatar-bubble-narwhal", imageName: "avatar_bubble_narwhal", accessibilityLabel: "Bubble narwhal avatar"),
        AvatarOption(id: "avatar-buddy-bot", imageName: "avatar_buddy_bot", accessibilityLabel: "Buddy bot avatar"),
        AvatarOption(id: "avatar-cosmic-sloth", imageName: "avatar_cosmic_sloth", accessibilityLabel: "Cosmic sloth avatar"),
        AvatarOption(id: "avatar-crimson-wyrm", imageName: "avatar_crimson_wyrm", accessibilityLabel: "Crimson wyrm avatar"),
        AvatarOption(id: "avatar-dapper-ape", imageName: "avatar_dapper_ape", accessibilityLabel: "Dapper ape avatar"),
        AvatarOption(id: "avatar-ember-drake", imageName: "avatar_ember_drake", accessibilityLabel: "Ember drake avatar"),
        AvatarOption(id: "avatar-emerald-android", imageName: "avatar_emerald_android", accessibilityLabel: "Emerald android avatar"),
        AvatarOption(id: "avatar-frosty-cupcake", imageName: "avatar_frosty_cupcake", accessibilityLabel: "Frosty cupcake avatar"),
        AvatarOption(id: "avatar-moonlight-wizard", imageName: "avatar_moonlight_wizard", accessibilityLabel: "Moonlight wizard avatar"),
        AvatarOption(id: "avatar-nordic-warrior", imageName: "avatar_nordic_warrior", accessibilityLabel: "Nordic warrior avatar"),
        AvatarOption(id: "avatar-professor-bee", imageName: "avatar_professor_bee", accessibilityLabel: "Professor bee avatar"),
        AvatarOption(id: "avatar-sea-captain", imageName: "avatar_sea_captain", accessibilityLabel: "Sea captain avatar"),
        AvatarOption(id: "avatar-skull-crossbones", imageName: "avatar_skull_crossbones", accessibilityLabel: "Skull and crossbones avatar"),
        AvatarOption(id: "avatar-sly-fox", imageName: "avatar_sly_fox", accessibilityLabel: "Sly fox avatar"),
        AvatarOption(id: "avatar-soccer-star", imageName: "avatar_soccer_star", accessibilityLabel: "Soccer star avatar"),
        AvatarOption(id: "avatar-specimen-jar", imageName: "avatar_specimen_jar", accessibilityLabel: "Specimen jar avatar"),
        AvatarOption(id: "avatar-spooky-ghost", imageName: "avatar_spooky_ghost", accessibilityLabel: "Spooky ghost avatar"),
        AvatarOption(id: "avatar-starfighter", imageName: "avatar_starfighter", accessibilityLabel: "Starfighter avatar"),
        AvatarOption(id: "avatar-storm-sword", imageName: "avatar_storm_sword", accessibilityLabel: "Storm sword avatar"),
        AvatarOption(id: "avatar-sunny-sunflower", imageName: "avatar_sunny_sunflower", accessibilityLabel: "Sunny sunflower avatar"),
        AvatarOption(id: "avatar-toxic-tonic", imageName: "avatar_toxic_tonic", accessibilityLabel: "Toxic tonic avatar"),
        AvatarOption(id: "avatar-treasure-chest", imageName: "avatar_treasure_chest", accessibilityLabel: "Treasure chest avatar"),
        AvatarOption(id: "avatar-winter-doll", imageName: "avatar_winter_doll", accessibilityLabel: "Winter doll avatar")
    ]

    static var `default`: AvatarOption {
        all.first ?? AvatarOption(id: "avatar-default", imageName: "avatar_shiba_dog", accessibilityLabel: "Default avatar")
    }

    static func option(for id: String) -> AvatarOption {
        let normalizedId = id.replacingOccurrences(of: "_", with: "-")
        let normalizedImageName = id.replacingOccurrences(of: "-", with: "_")
        return all.first { $0.id == id || $0.id == normalizedId || $0.imageName == id || $0.imageName == normalizedImageName } ?? `default`
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
            .accessibilityLabel(option.accessibilityLabel)
    }

    private var avatarImage: Image {
        Image.avatar(option.imageName)
    }
}
