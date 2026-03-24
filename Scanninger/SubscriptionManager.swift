//
//  SubscriptionManager.swift
//  Scanninger
//
//  StoreKit 2 subscription state, purchases, and restore.
//

import Combine
import Foundation
import StoreKit

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case productUnavailable
    case userCancelled
    case purchasePending

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This product isn’t available right now. Try again later."
        case .userCancelled:
            return nil
        case .purchasePending:
            return "Purchase is pending approval."
        }
    }
}

// MARK: - Manager

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// `true` when a verified premium subscription transaction exists in `Transaction.currentEntitlements`.
    @Published private(set) var isPremium: Bool = false

    /// Active premium product id from entitlements (if any).
    @Published private(set) var activeProductIdentifier: String?

    /// Latest known expiration for the active premium subscription.
    @Published private(set) var premiumExpirationDate: Date?

    @Published private(set) var productsById: [String: Product] = [:]
    @Published private(set) var isLoadingProducts: Bool = false

    @Published var lastErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.process(transactionResult: update)
            }
        }
    }

    /// Reconciles with the App Store then reads `Transaction.currentEntitlements`. **Call on cold launch** (and after reinstall) so subscriptions are restored without tapping Restore.
    /// Premium access is **only** derived from StoreKit — no UserDefaults.
    func synchronizeEntitlementsOnLaunch() async {
        do {
            try await AppStore.sync()
        } catch {
            // Still read whatever entitlements exist locally / from prior sync.
        }
        await refreshEntitlements()
    }

    // MARK: Products

    func loadProducts() async {
        isLoadingProducts = true
        lastErrorMessage = nil
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: Array(PremiumSubscriptionProductID.all).sorted())
            var map: [String: Product] = [:]
            for p in products {
                map[p.id] = p
            }
            productsById = map
            if products.isEmpty {
                lastErrorMessage = "Subscriptions are unavailable right now. Check your connection and try again."
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Display price for UI; falls back to `SubscriptionPlan.fallbackPriceLine` if the product is not loaded.
    func displayPrice(for plan: SubscriptionPlan) -> String {
        let id = plan.storeProductId
        if let product = productsById[id] {
            return product.displayPrice
        }
        return plan.fallbackPriceLine
    }

    // MARK: Purchase

    func purchase(plan: SubscriptionPlan) async throws {
        let id = plan.storeProductId
        guard let product = productsById[id] else {
            await loadProducts()
            guard let retry = productsById[id] else {
                throw SubscriptionError.productUnavailable
            }
            try await purchase(product: retry)
            return
        }
        try await purchase(product: product)
    }

    private func purchase(product: Product) async throws {
        lastErrorMessage = nil
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshEntitlements()
            case .unverified(_, let error):
                throw error
            }
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.purchasePending
        @unknown default:
            throw SubscriptionError.productUnavailable
        }
    }

    // MARK: Restore

    func restorePurchases() async {
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: Entitlements

    /// Re-evaluates premium access from StoreKit. Call after launch and when transactions change.
    func refreshEntitlements() async {
        var foundPremium = false
        var bestProductId: String?
        var bestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard PremiumSubscriptionProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }

            foundPremium = true

            if let exp = transaction.expirationDate {
                if let be = bestExpiration {
                    if exp > be {
                        bestExpiration = exp
                        bestProductId = transaction.productID
                    }
                } else {
                    bestExpiration = exp
                    bestProductId = transaction.productID
                }
            } else if bestProductId == nil {
                bestProductId = transaction.productID
            }
        }

        if isPremium != foundPremium {
            isPremium = foundPremium
        }
        activeProductIdentifier = bestProductId
        premiumExpirationDate = bestExpiration
    }

    private func process(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    // MARK: My Profile (display)

    func friendlyPlanName() -> String {
        guard let id = activeProductIdentifier else { return "—" }
        switch id {
        case PremiumSubscriptionProductID.weekly: return "Weekly"
        case PremiumSubscriptionProductID.monthly: return "Monthly"
        case PremiumSubscriptionProductID.yearly: return "Yearly"
        default: return id
        }
    }

    func subscriptionStatusLabel() -> String {
        isPremium ? "Active" : "Inactive"
    }

    func subscriptionExpirationFormatted() -> String {
        guard let date = premiumExpirationDate else {
            return isPremium ? "—" : "—"
        }
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: date)
    }
}
