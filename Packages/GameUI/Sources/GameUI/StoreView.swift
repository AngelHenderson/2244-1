import SwiftUI
import GameApp

struct StoreView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.purchaseService) private var purchase
    @Environment(\.dismiss) private var dismiss
    
    struct CoinPack: Identifiable { let id = UUID(); let amount: Int; let priceLabel: String }
    private let packs: [CoinPack] = [
        .init(amount: 250, priceLabel: "$0.99"),
        .init(amount: 750, priceLabel: "$2.99"),
        .init(amount: 2200, priceLabel: "$6.99")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Gem Packs") {
                    ForEach(packs) { pack in
                        HStack {
                            Image("gems")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("\(pack.amount)")
                            Spacer()
                            Button(pack.priceLabel) { buy(pack) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                Section("Ad-Free") {
                    HStack {
                        Text("Remove Ads")
                        Spacer()
                        if purchase.isAdFreePurchased {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        } else {
                            Button("Restore") { Task { await purchase.restorePurchases() } }
                        }
                    }
                }
            }
            .navigationTitle("Store")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
    private func buy(_ pack: CoinPack) {
        // Placeholder: add coins directly. Hook to real IAP later
        gameStore.addCoins(pack.amount)
    }
}


