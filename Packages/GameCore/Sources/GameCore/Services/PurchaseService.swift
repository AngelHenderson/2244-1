import Foundation
@preconcurrency import StoreKit
import SwiftUI
import Observation

public struct VerifiedPurchase: Sendable, Equatable {
    public let productID: String
    public let transactionID: String
    public let isRestored: Bool

    public init(productID: String, transactionID: String, isRestored: Bool) {
        self.productID = productID
        self.transactionID = transactionID
        self.isRestored = isRestored
    }
}

@Observable
@MainActor
public final class PurchaseService {
    public static let adFreeProductID = IAPProduct.adFreeProduct.id

    #if os(iOS)
    public private(set) var products: [Product] = []
    private var productCache: [String: Product] = [:]
    #else
    public private(set) var products: [Any] = []
    #endif

    public private(set) var isAdFreePurchased = false
    public private(set) var ownedProductIDs: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    @ObservationIgnored
    public var onVerifiedPurchase: (@MainActor @Sendable (VerifiedPurchase) -> Void)?

    private static let ownedProductIDsKey = "ownedProductIDs"
    private static let deliveredTransactionIDsKey = "deliveredTransactionIDs"
    private var deliveredTransactionIDs: Set<String> = []

    public init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.ownedProductIDsKey) ?? []
        ownedProductIDs = Set(stored)

        let delivered = UserDefaults.standard.stringArray(forKey: Self.deliveredTransactionIDsKey) ?? []
        deliveredTransactionIDs = Set(delivered)

        if UserDefaults.standard.bool(forKey: "isAdFreePurchased") {
            ownedProductIDs.insert(Self.adFreeProductID)
        }
        updateAdFreeFlag()

        #if os(iOS)
        Task { [weak self] in
            await self?.loadProducts()
            await self?.checkPurchaseStatus(deliverNewTransactions: false, isRestored: false)
        }
        Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        #endif
    }

    public func isOwned(_ productID: String) -> Bool {
        ownedProductIDs.contains(productID)
    }

    public func loadProducts() async {
        isLoading = true
        errorMessage = nil

        #if os(iOS)
        await ensureProductsLoaded(for: IAPProduct.allProductIDs)
        #endif

        isLoading = false
    }

    public func ensureProductsLoaded(for ids: [String]) async {
        #if os(iOS)
        let uniqueIDs = Array(Set(ids)).filter { IAPProduct.product(for: $0) != nil }
        guard !uniqueIDs.isEmpty else { return }

        let missing = uniqueIDs.filter { productCache[$0] == nil }
        guard !missing.isEmpty else { return }

        do {
            let fetched = try await Product.products(for: missing)
            cacheProducts(fetched)
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        #endif
    }

    public func product(withID id: String) -> Product? {
        #if os(iOS)
        return productCache[id]
        #else
        return nil
        #endif
    }

    public func purchase(productID: String) async -> Bool {
        await purchaseVerified(productID: productID) != nil
    }

    public func purchaseVerified(productID: String) async -> VerifiedPurchase? {
        #if os(iOS)
        guard IAPProduct.product(for: productID) != nil else {
            errorMessage = "Unknown product"
            return nil
        }

        if let product = product(withID: productID) {
            return await purchaseVerified(product)
        }

        await ensureProductsLoaded(for: [productID])
        guard let product = product(withID: productID) else {
            errorMessage = "Product unavailable"
            return nil
        }

        return await purchaseVerified(product)
        #else
        errorMessage = "Purchases are only available on iOS"
        return nil
        #endif
    }

    #if os(iOS)
    public func purchase(_ product: Product) async -> Bool {
        await purchaseVerified(product) != nil
    }

    public func purchaseVerified(_ product: Product) async -> VerifiedPurchase? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    return await processVerifiedTransaction(
                        transaction,
                        deliverReward: true,
                        isRestored: false
                    )
                case .unverified:
                    errorMessage = "Transaction could not be verified"
                    return nil
                }
            case .userCancelled:
                return nil
            case .pending:
                errorMessage = "Purchase is pending"
                return nil
            @unknown default:
                errorMessage = "Unknown purchase result"
                return nil
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func cacheProducts(_ newProducts: [Product]) {
        for product in newProducts {
            productCache[product.id] = product
        }

        products = productCache.values.sorted { lhs, rhs in
            let lhsPriority = IAPProduct.product(for: lhs.id)?.displayPriority ?? Int.max
            let rhsPriority = IAPProduct.product(for: rhs.id)?.displayPriority ?? Int.max
            return lhsPriority < rhsPriority
        }
    }
    #endif

    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        #if os(iOS)
        do {
            try await AppStore.sync()
            await checkPurchaseStatus(deliverNewTransactions: true, isRestored: true)
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        #endif

        isLoading = false
    }

    public func deliverPendingTransactions() async {
        #if os(iOS)
        await checkPurchaseStatus(deliverNewTransactions: true, isRestored: false)
        #endif
    }

    private func markOwned(_ productID: String) {
        ownedProductIDs.insert(productID)
        persistOwnedProductIDs()
    }

    private func removeOwned(_ productID: String) {
        ownedProductIDs.remove(productID)
        persistOwnedProductIDs()
    }

    private func persistOwnedProductIDs() {
        UserDefaults.standard.set(Array(ownedProductIDs), forKey: Self.ownedProductIDsKey)
        updateAdFreeFlag()
    }

    private func updateAdFreeFlag() {
        isAdFreePurchased = ownedProductIDs.contains(Self.adFreeProductID)
        UserDefaults.standard.set(isAdFreePurchased, forKey: "isAdFreePurchased")
    }

    private func applyOwnership(for productID: String) {
        guard let product = IAPProduct.product(for: productID) else { return }
        for entitlementID in product.permanentEntitlementProductIDs {
            markOwned(entitlementID)
        }
    }

    private func removeOwnership(for productID: String) {
        guard let product = IAPProduct.product(for: productID) else { return }
        for entitlementID in product.permanentEntitlementProductIDs {
            removeOwned(entitlementID)
        }
    }

    private func markTransactionDelivered(_ transactionID: String) -> Bool {
        guard !deliveredTransactionIDs.contains(transactionID) else { return false }
        deliveredTransactionIDs.insert(transactionID)
        UserDefaults.standard.set(Array(deliveredTransactionIDs), forKey: Self.deliveredTransactionIDsKey)
        return true
    }

    #if os(iOS)
    private func checkPurchaseStatus(deliverNewTransactions: Bool, isRestored: Bool) async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                let purchase = await processVerifiedTransaction(
                    transaction,
                    deliverReward: deliverNewTransactions,
                    isRestored: isRestored
                )
                if let purchase {
                    onVerifiedPurchase?(purchase)
                }
            case .unverified:
                continue
            }
        }
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                let purchase = await processVerifiedTransaction(
                    transaction,
                    deliverReward: true,
                    isRestored: false
                )
                if let purchase {
                    onVerifiedPurchase?(purchase)
                }
            case .unverified:
                continue
            }
        }
    }

    private func processVerifiedTransaction(
        _ transaction: StoreKit.Transaction,
        deliverReward: Bool,
        isRestored: Bool
    ) async -> VerifiedPurchase? {
        if transaction.revocationDate != nil {
            removeOwnership(for: transaction.productID)
            await transaction.finish()
            return nil
        }

        applyOwnership(for: transaction.productID)

        let transactionID = String(transaction.id)
        let shouldDeliver = deliverReward && markTransactionDelivered(transactionID)

        await transaction.finish()

        guard shouldDeliver else { return nil }
        return VerifiedPurchase(
            productID: transaction.productID,
            transactionID: transactionID,
            isRestored: isRestored
        )
    }
    #endif
}
