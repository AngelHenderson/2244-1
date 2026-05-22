import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
public final class GemWallet {
    public enum Source: String {
        case achievement
        case daily
        case manual
        case purchase
    }
    
    private struct Keys {
        static let balance = "coins"
        static let playerId = "player_id"
    }
    
    private let defaults: UserDefaults
    private var playerId: String
    private weak var gameStore: GameStore?
    private weak var homeState: HomeState?
    public var balance: Int {
        get { defaults.integer(forKey: Keys.balance) }
        set {
            defaults.set(newValue, forKey: Keys.balance)
            applyToGameState()
        }
    }
    #if canImport(FirebaseFirestore)
    private var document: DocumentReference?
    #endif
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let existing = defaults.string(forKey: Keys.playerId) {
            playerId = existing
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: Keys.playerId)
            playerId = generated
        }
    }
    
    public func attach(gameStore: GameStore, homeState: HomeState) {
        self.gameStore = gameStore
        self.homeState = homeState
        applyToGameState()
    }
    
    public func bootstrapFromLocal() {
        applyToGameState()
    }
    
    public func deposit(_ amount: Int, source: Source) {
        guard amount > 0 else { return }
        balance += amount
        syncToCloud(reason: source.rawValue)
    }
    
    public func reconcile(with remoteValue: Int) {
        let merged = max(remoteValue, balance)
        guard merged != balance else { return }
        balance = merged
    }
    
    public func startCloudSync() async {
        #if canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else { return }
        // The deployed Firestore rules gate /players/{uid} on `isOwner(uid)` —
        // i.e. the document key MUST equal the Firebase Auth UID. Without an
        // auth UID we'd fail every write, so refuse to sync until sign-in lands.
        guard let uid = currentAuthUID(), !uid.isEmpty else {
            #if DEBUG
            print("⚠️ GemWallet.startCloudSync skipped — no Firebase Auth UID available yet")
            #endif
            return
        }
        let firestore = Firestore.firestore()
        let doc = firestore.collection("players").document(uid)
        document = doc
        do {
            let snapshot = try await doc.getDocument()
            if let remote = snapshot.data()?["gems"] as? Int {
                reconcile(with: remote)
            } else {
                try await doc.setData([
                    "gems": balance,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        } catch {
            #if DEBUG
            print("❌ Failed to sync gem balance: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    private func currentAuthUID() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
    
    private func applyToGameState() {
        gameStore?.coins = balance
        homeState?.gems = balance
    }
    
    private func syncToCloud(reason: String) {
        #if canImport(FirebaseFirestore)
        guard let document else { return }
        Task {
            do {
                try await document.setData([
                    "gems": balance,
                    "reason": reason,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            } catch {
                #if DEBUG
                print("❌ Failed to update Firestore gem balance: \(error.localizedDescription)")
                #endif
            }
        }
        #endif
    }
}
