import Foundation
import StoreKit
import SwiftUI
import Observation

@Observable
@MainActor
public final class PurchaseService {
    public static let adFreeProductID = "com.game2248.adfree"
    
    #if os(iOS)
    public private(set) var products: [Product] = []
    #else
    public private(set) var products: [Any] = []
    #endif
    public private(set) var isAdFreePurchased = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    
    public init() {
        // Defer task setup to avoid referencing actor-isolated 'self' before init completes
        #if os(iOS)
        Task { [weak self] in
            await self?.loadProducts()
            await self?.checkPurchaseStatus()
        }
        Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        #endif
    }
    
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        #if os(iOS)
        do {
            products = try await Product.products(for: [Self.adFreeProductID])
            isLoading = false
        } catch {
            errorMessage = "Failed to load products"
            isLoading = false
        }
        #else
        isLoading = false
        #endif
    }
    
    #if os(iOS)
    public func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    isAdFreePurchased = true
                    // Persist state so AdService can honor on next launch
                    UserDefaults.standard.set(true, forKey: "isAdFreePurchased")
                    isLoading = false
                    return true
                case .unverified:
                    errorMessage = "Transaction could not be verified"
                    isLoading = false
                    return false
                }
            case .userCancelled:
                isLoading = false
                return false
            case .pending:
                errorMessage = "Purchase is pending"
                isLoading = false
                return false
            @unknown default:
                errorMessage = "Unknown purchase result"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    #else
    public func purchaseDummy() async -> Bool { false }
    #endif
    
    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        #if os(iOS)
        do {
            try await AppStore.sync()
            await checkPurchaseStatus()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases"
            isLoading = false
        }
        #else
        isLoading = false
        #endif
    }
    
    private func checkPurchaseStatus() async {
        #if os(iOS)
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.adFreeProductID {
                    isAdFreePurchased = true
                    UserDefaults.standard.set(true, forKey: "isAdFreePurchased")
                    await transaction.finish()
                }
            case .unverified:
                continue
            }
        }
        #endif
    }
    
    private func observeTransactionUpdates() async {
        #if os(iOS)
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.adFreeProductID {
                    isAdFreePurchased = true
                    await transaction.finish()
                }
            case .unverified:
                continue
            }
        }
        #endif
    }
}