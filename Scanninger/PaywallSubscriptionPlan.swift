//
//  PaywallSubscriptionPlan.swift
//  Scanninger
//
//  Subscription plan model + UserDefaults keys for the draft paywall.
//  Replace mock pricing with StoreKit / RevenueCat when integrating purchases.
//

import Foundation

// MARK: - StoreKit product identifiers

/// Must match App Store Connect and the local StoreKit Configuration file.
enum PremiumSubscriptionProductID {
    static let weekly = "com.yeghishe.scanninger.premium.weekly"
    static let monthly = "com.yeghishe.scanninger.premium.monthly"
    static let yearly = "com.yeghishe.scanninger.premium.yearly"

    static let all: Set<String> = [weekly, monthly, yearly]
}

// MARK: - UserDefaults (draft)

enum PaywallAppStorageKeys {
    /// Legacy single gate from older builds; still cleared on logout. New flow uses `AppFlowStorageKeys`.
    static let hasPassedPaywall = "paywall.hasPassedPaywall"
}

/// Resets sign-in, legacy flags, and local Apple profile (logout). Does **not** remove StoreKit subscriptions.
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

// MARK: - Plans (UI + StoreKit product ids)

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case oneWeek
    case oneMonth
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneWeek: return "Weekly"
        case .oneMonth: return "Monthly"
        case .oneYear: return "Yearly"
        }
    }

    /// StoreKit 2 product identifier (matches App Store Connect & local `.storekit` file).
    var storeProductId: String {
        switch self {
        case .oneWeek: return PremiumSubscriptionProductID.weekly
        case .oneMonth: return PremiumSubscriptionProductID.monthly
        case .oneYear: return PremiumSubscriptionProductID.yearly
        }
    }

    /// Shown only when `Product` hasn’t loaded yet (offline / misconfigured StoreKit file).
    var fallbackPriceLine: String {
        switch self {
        case .oneWeek: return "$4.99"
        case .oneMonth: return "$12.99"
        case .oneYear: return "$49.99"
        }
    }

    /// Backward compatibility for previews.
    var priceLine: String { fallbackPriceLine }

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
