//
//  PaywallSubscriptionPlan.swift
//  Scanninger
//
//  Subscription plan model + UserDefaults keys for the draft paywall.
//  Replace mock pricing with StoreKit / RevenueCat when integrating purchases.
//

import Foundation

// MARK: - UserDefaults (draft)

enum PaywallAppStorageKeys {
    /// Legacy single gate from older builds; still cleared on logout. New flow uses `AppFlowStorageKeys`.
    static let hasPassedPaywall = "paywall.hasPassedPaywall"
}

/// Resets sign-in, mock unlock, legacy paywall flag, and local Apple session (logout).
@MainActor
enum PaywallReset {
    /// Returns user to **Sign-in** (onboarding stays complete). Clears Apple profile on device.
    static func resetDraftSession() {
        let d = UserDefaults.standard
        d.set(false, forKey: AppFlowStorageKeys.isSignedIn)
        d.set(false, forKey: AppFlowStorageKeys.hasUnlockedAppMock)
        d.set(false, forKey: PaywallAppStorageKeys.hasPassedPaywall)
        AppleSignInSessionManager.shared.clearSession()
    }

    /// Same as `resetDraftSession()` — kept for call sites that only cleared the pass flag.
    static func clearPassedPaywallFlag() {
        resetDraftSession()
    }
}

// MARK: - Plans (mock)

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case oneWeek
    case oneMonth
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .oneMonth: return "1 Month"
        case .oneYear: return "1 Year"
        }
    }

    /// Placeholder prices — swap for localized StoreKit prices later.
    var priceLine: String {
        switch self {
        case .oneWeek: return "$4.99"
        case .oneMonth: return "$12.99"
        case .oneYear: return "$49.99"
        }
    }

    var periodSubtitle: String {
        switch self {
        case .oneWeek: return "per week"
        case .oneMonth: return "per month"
        case .oneYear: return "per year"
        }
    }

    var badge: String? {
        switch self {
        case .oneYear: return "Best value"
        default: return nil
        }
    }
}
