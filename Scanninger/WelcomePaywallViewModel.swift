//
//  WelcomePaywallViewModel.swift
//  Scanninger
//
//  Draft MVVM layer for WelcomePaywallView.
//  Wire `purchase`, `restore`, and Sign in with Apple to real services when ready.
//

import SwiftUI
import Combine

@MainActor
final class WelcomePaywallViewModel: ObservableObject {
    @Published var selectedPlan: SubscriptionPlan = .oneYear
    /// Mock: set when user taps either primary continue action (Apple or Unlock).
    @Published var isLoggedInMock = false
    /// Session flag: user reached the paywall screen (useful for future analytics).
    @Published var hasSeenPaywall = false

    func recordPaywallSeen() {
        hasSeenPaywall = true
    }

    func select(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }

    /// Called after `SignInWithAppleButton` succeeds and `AppleSignInSessionManager` has saved the credential.
    func continueWithApple() {
        isLoggedInMock = true
    }

    /// Call before dismissing for direct unlock / secondary CTA (stub for future IAP).
    func continueUnlockPremium() {
        isLoggedInMock = true
    }

    /// Stub — hook up StoreKit `Transaction.currentEntitlements` / RevenueCat later.
    func restorePurchases() {
        // No-op in draft; could show a toast when wired.
    }
}
