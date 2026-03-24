//
//  AppFlowState.swift
//  Scanninger
//
//  Persisted launch-flow flags: onboarding → sign-in → paywall → main app.
//

import Foundation

// MARK: - UserDefaults keys

enum AppFlowStorageKeys {
    static let hasSeenOnboarding = "flow.hasSeenOnboarding"
    /// Set after successful Sign in with Apple (local session).
    static let isSignedIn = "flow.isSignedIn"
    /// Mock “unlocked” after paywall Continue — replace with real entitlement when using IAP.
    static let hasUnlockedAppMock = "flow.hasUnlockedAppMock"
}

// MARK: - One-time migration from older single-flag paywall gate

enum AppFlowBootstrap {
    private static let didMigrateKey = "flow.didMigrateLegacyPaywall"

    /// If the user previously completed the old combined paywall (`paywall.hasPassedPaywall`), map them to the full new flow as completed.
    /// Call once at launch (e.g. `ScanningerApp.init`) before the first frame.
    static func migrateFromLegacyIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: didMigrateKey) else { return }
        d.set(true, forKey: didMigrateKey)

        guard d.bool(forKey: PaywallAppStorageKeys.hasPassedPaywall) else { return }

        d.set(true, forKey: AppFlowStorageKeys.hasSeenOnboarding)
        d.set(true, forKey: AppFlowStorageKeys.isSignedIn)
        d.set(true, forKey: AppFlowStorageKeys.hasUnlockedAppMock)
    }
}
