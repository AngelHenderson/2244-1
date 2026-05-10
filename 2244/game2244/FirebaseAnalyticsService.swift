import Foundation
import FirebaseAnalytics
import GameCore

struct FirebaseAnalyticsService: AnalyticsServiceProtocol, Sendable {
    func fire(event name: String, params: [String: any Sendable]) async {
        if let enabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool,
           !enabled {
            return
        }

        var firebaseParams: [String: Any] = [:]
        for (key, value) in params {
            switch value {
            case let string as String:
                firebaseParams[key] = string
            case let int as Int:
                firebaseParams[key] = int
            case let int64 as Int64:
                firebaseParams[key] = int64
            case let double as Double:
                firebaseParams[key] = double
            case let float as Float:
                firebaseParams[key] = float
            case let bool as Bool:
                firebaseParams[key] = bool
            default:
                firebaseParams[key] = String(describing: value)
            }
        }

        await MainActor.run {
            Analytics.logEvent(name, parameters: firebaseParams)
        }
    }
}
