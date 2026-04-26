import SwiftUI
import GameKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class GameCenterManager {
    public static let shared = GameCenterManager()
    private init() {}

    public var isAuthenticated: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    public var displayName: String {
        GKLocalPlayer.local.displayName
    }
    
    public func configureAccessPoint(active: Bool = true,
                                     location: GKAccessPoint.Location = .topLeading) {
        GKAccessPoint.shared.isActive = active
        GKAccessPoint.shared.location = location
    }

    public func authenticate() async -> Bool {
        await authenticate(presentingRoot: nil)
    }
    
    #if canImport(UIKit)
    public func authenticate(presentingRoot rootProvider: (() -> UIViewController?)?) async -> Bool {
        let local = GKLocalPlayer.local
        guard !local.isAuthenticated else { return true }

        return await withCheckedContinuation { continuation in
            var didResume = false
            let resume: (Bool) -> Void = { value in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            local.authenticateHandler = { vc, error in
                if let vc, let root = rootProvider?() {
                    root.present(vc, animated: true)
                    return
                }

                if let error {
                    #if DEBUG
                    print("Game Center auth error:", error.localizedDescription)
                    #endif
                    resume(false)
                    return
                }

                resume(local.isAuthenticated)
            }
        }
    }

    public func authenticateIfNeeded(presentingRoot rootProvider: @escaping () -> UIViewController?) {
        let local = GKLocalPlayer.local
        guard !local.isAuthenticated else { return }
        local.authenticateHandler = { vc, error in
            if let vc = vc, let root = rootProvider() {
                root.present(vc, animated: true, completion: nil)
            } else if let error = error {
                #if DEBUG
                print("Game Center auth error:", error)
                #endif
            }
        }
    }
    #else
    public func authenticate(presentingRoot rootProvider: (() -> Any?)?) async -> Bool {
        let local = GKLocalPlayer.local
        guard !local.isAuthenticated else { return true }

        return await withCheckedContinuation { continuation in
            var didResume = false
            let resume: (Bool) -> Void = { value in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            local.authenticateHandler = { _, error in
                if let error {
                    #if DEBUG
                    print("Game Center auth error:", error.localizedDescription)
                    #endif
                    resume(false)
                    return
                }

                resume(local.isAuthenticated)
            }
        }
    }
    #endif
    
    public func loadExistingAchievements() async -> [GKAchievement] {
        await withCheckedContinuation { cont in
            GKAchievement.loadAchievements { result, _ in
                cont.resume(returning: result ?? [])
            }
        }
    }
    
    public func reportUnlock(gcIdentifier: String, showsBanner: Bool = true) async {
        let ach = GKAchievement(identifier: gcIdentifier)
        ach.percentComplete = 100.0
        ach.showsCompletionBanner = showsBanner
        await withCheckedContinuation { cont in
            GKAchievement.report([ach]) { _ in cont.resume(returning: ()) }
        }
    }
    
    public func presentDashboard() {
        #if canImport(UIKit)
        guard #available(iOS 26.0, *) else {
            return
        }
        presentAccessPointDashboard()
        #endif
    }
    
    #if canImport(UIKit)
    @available(iOS 26.0, *)
    private func presentAccessPointDashboard() {
        GKAccessPoint.shared.isActive = true
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.trigger { }
    }
    #endif
    
}
