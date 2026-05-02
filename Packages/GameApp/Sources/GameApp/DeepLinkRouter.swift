import SwiftUI

/// Single source of truth for incoming deep links and programmatic
/// navigation requests. Views observe `pendingRoute` and call `consume()`
/// once they have applied the destination.
@Observable
public final class DeepLinkRouter {
    public var pendingRoute: AppRoute?

    public init(initialRoute: AppRoute? = nil) {
        self.pendingRoute = initialRoute
    }

    /// Stores `route` as the next pending destination, replacing any
    /// previous unconsumed route.
    public func open(_ route: AppRoute) {
        pendingRoute = route
    }

    /// Parses `url` and stores the matched route. Returns `true` when the
    /// URL produced a known `AppRoute`.
    @discardableResult
    public func handle(_ url: URL) -> Bool {
        guard let route = AppRoute(url: url) else { return false }
        pendingRoute = route
        return true
    }

    /// Clears `pendingRoute`. Call once the destination has been applied
    /// so the same route is not re-applied on the next observation cycle.
    public func consume() {
        pendingRoute = nil
    }
}

@MainActor
private struct DeepLinkRouterKey: @preconcurrency EnvironmentKey {
    static let defaultValue = DeepLinkRouter()
}

public extension EnvironmentValues {
    var deepLinkRouter: DeepLinkRouter {
        get { self[DeepLinkRouterKey.self] }
        set { self[DeepLinkRouterKey.self] = newValue }
    }
}
