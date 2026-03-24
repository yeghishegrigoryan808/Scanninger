//
//  PaywallViewModel.swift
//  Scanninger
//
//  Plan selection + restore; purchases go through `SubscriptionManager`.
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

    func restorePurchases() async {
        await SubscriptionManager.shared.restorePurchases()
    }
}
