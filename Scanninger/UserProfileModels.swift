//
//  UserProfileModels.swift
//  Scanninger
//
//  Snapshot types for the My Profile screen. Replace mock values with
//  Sign in with Apple / Firebase / subscription services when integrated.
//

import Foundation

/// User-visible identity. Populated from `AppleSignInSessionManager` (local); map to Firebase later if needed.
struct UserProfileSnapshot: Sendable {
    var fullName: String
    var email: String
    var signInMethod: String
}

/// Subscription summary (mock). Map from StoreKit 2 / RevenueCat later.
struct SubscriptionSnapshot: Sendable {
    var currentPlan: String
    var status: String
    var subscriptionEndDate: String
}
