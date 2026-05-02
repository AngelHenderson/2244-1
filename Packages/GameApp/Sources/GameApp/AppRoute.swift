import Foundation

/// Typed destinations for deep links and external triggers.
///
/// Add a case here, map a URL host to it in `init?(url:)`, and let
/// `RootGameView` / `HomeView` consume the matching route via
/// `DeepLinkRouter`.
public enum AppRoute: Hashable, Sendable {
    case shop
    case daily
    case spin
    case challenge
    case settings
    case tutorial
    case gameplay
}

public extension AppRoute {
    /// URL scheme reserved for the app. Register in Info.plist
    /// (`CFBundleURLTypes`) so iOS routes external `game2244://` URLs to
    /// `.onOpenURL`.
    static let scheme = "game2244"

    /// Parses `game2244://<host>` style URLs. Returns nil for unknown hosts.
    init?(url: URL) {
        guard url.scheme?.lowercased() == AppRoute.scheme else { return nil }
        let host = (url.host ?? url.pathComponents.first(where: { $0 != "/" }) ?? "").lowercased()
        switch host {
        case "shop":
            self = .shop
        case "daily", "dailyclaims":
            self = .daily
        case "spin", "freespin", "spinwheel":
            self = .spin
        case "challenge", "challenges":
            self = .challenge
        case "settings":
            self = .settings
        case "tutorial", "howtoplay":
            self = .tutorial
        case "gameplay", "play":
            self = .gameplay
        default:
            return nil
        }
    }
}
