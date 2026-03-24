//
//  PaywallViewModel.swift
//  Scanninger
//
//  Mock plan selection for PaywallView. Wire StoreKit / RevenueCat later.
//

import Combine
import SwiftUI

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var selectedPlan: SubscriptionPlan = .oneYear
    @Published var hasSeenPaywall = false

    func recordPaywallSeen() {
        hasSeenPaywall = true
    }

    func select(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }

    /// Stub — hook up StoreKit restore later.
    func restorePurchases() {}
}
