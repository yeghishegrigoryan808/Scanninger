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
    /// Set after successful Sign in with Apple (session flag; profile data lives in `AppleSignInSessionManager`).
    static let isSignedIn = "flow.isSignedIn"
    /// Persisted step inside `OnboardingFlowView`: 0 = page 1, 1 = page 2, 2 = sign in. Cleared only when no longer needed (optional); read on launch while `!isSignedIn`.
    static let onboardingFlowStep = "flow.onboardingFlowStep"
    /// Set after at least one successful Sign in with Apple and **not** cleared on logout — used to show sign-in without “Back to onboarding” for returning users.
    static let hasCompletedSignInBefore = "flow.hasCompletedSignInBefore"
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

        d.removeObject(forKey: "flow.hasUnlockedAppMock")

        guard d.bool(forKey: PaywallAppStorageKeys.hasPassedPaywall) else { return }

        d.set(true, forKey: AppFlowStorageKeys.hasSeenOnboarding)
        d.set(true, forKey: AppFlowStorageKeys.isSignedIn)
        d.set(true, forKey: AppFlowStorageKeys.hasCompletedSignInBefore)
    }
}

// MARK: - Session hints for onboarding / sign-in UI

extension AppFlowBootstrap {
    /// If the user is already signed in (e.g. upgraded from an older build), treat them as having completed sign-in before so logout shows sign-in only without onboarding Back.
    static func syncSignInCompletedFlagWithSession() {
        let d = UserDefaults.standard
        if d.bool(forKey: AppFlowStorageKeys.isSignedIn) {
            d.set(true, forKey: AppFlowStorageKeys.hasCompletedSignInBefore)
        }
    }
} 
