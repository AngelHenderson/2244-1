import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
public final class GemWallet {
    public enum Source: String {
        case achievement
        case daily
        case manual
    }
    
    private struct Keys {
        static let balance = "coins"
        static let playerId = "player_id"
    }
    
    private let defaults: UserDefaults
    private var playerId: String
    private weak var gameStore: GameStore?
    private weak var homeState: HomeState?
    private(set) var balance: Int
    #if canImport(FirebaseFirestore)
    private var document: DocumentReference?
    #endif
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.balance = defaults.integer(forKey: Keys.balance)
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
        guard amount > 0 else {
            print("💎 GemWallet.deposit: amount \(amount) <= 0, skipping")
            return
        }
        let oldBalance = balance
        balance += amount
        print("💎 GemWallet.deposit: \(oldBalance) + \(amount) = \(balance) (source: \(source.rawValue))")
        persistLocal()
        applyToGameState()
        syncToCloud(reason: source.rawValue)
    }
    
    public func reconcile(with remoteValue: Int) {
        let merged = max(remoteValue, balance)
        guard merged != balance else { return }
        balance = merged
        persistLocal()
        applyToGameState()
    }
    
    public func startCloudSync() async {
        #if canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else { return }
        let firestore = Firestore.firestore()
        let doc = firestore.collection("players").document(playerId)
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
    
    private func persistLocal() {
        defaults.set(balance, forKey: Keys.balance)
    }
    
    private func applyToGameState() {
        if let gs = gameStore {
            gs.coins = balance
            print("💎 Applied to gameStore.coins = \(balance)")
        } else {
            print("⚠️ gameStore is nil, cannot apply gem balance")
        }
        if let hs = homeState {
            hs.gems = balance
            print("💎 Applied to homeState.gems = \(balance)")
        } else {
            print("⚠️ homeState is nil, cannot apply gem balance")
        }
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
