import SwiftUI
import GameCore
import GameApp

@MainActor
struct ThemePaywallSheet: View {
    let title: String
    let tagline: String
    let assetName: String
    let productID: String
    let onUnlocked: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchaseService) private var purchaseService
    @State private var isPurchasing: Bool = false
    @State private var displayedPrice: String = ""
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ZStack(alignment: .topTrailing) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .shadow(radius: 8, y: 4)
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.tint, in: Circle())
                    .offset(x: 8, y: -8)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(tagline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 4)

            Button {
                Task { await unlock() }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "lock.open.fill")
                    }
                    Text(isPurchasing ? "Processing…" : "Unlock for \(displayedPrice.isEmpty ? "—" : displayedPrice)")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(isPurchasing || displayedPrice.isEmpty)
            .padding(.horizontal, 20)

            Button("Restore Purchases") {
                Task { await purchaseService.restorePurchases() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .task {
            await loadPrice()
        }
        .onChange(of: purchaseService.isOwned(productID)) { _, owned in
            if owned {
                onUnlocked()
                dismiss()
            }
        }
    }

    private func loadPrice() async {
        await purchaseService.ensureProductsLoaded(for: [productID])
        #if os(iOS)
        if let product = purchaseService.product(withID: productID) {
            displayedPrice = product.displayPrice
        } else if let staticProduct = IAPProduct.allProducts.first(where: { $0.id == productID }) {
            displayedPrice = staticProduct.formattedPrice
        }
        #else
        if let staticProduct = IAPProduct.allProducts.first(where: { $0.id == productID }) {
            displayedPrice = staticProduct.formattedPrice
        }
        #endif
    }

    private func unlock() async {
        isPurchasing = true
        errorText = nil
        let success = await purchaseService.purchase(productID: productID)
        isPurchasing = false
        if success {
            onUnlocked()
            dismiss()
        } else if let message = purchaseService.errorMessage {
            errorText = message
        }
    }
}
