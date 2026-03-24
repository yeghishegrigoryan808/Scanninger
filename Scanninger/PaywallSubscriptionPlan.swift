//
//  PaywallSubscriptionPlan.swift
//  Scanninger
//
//  Subscription plan model + legacy UserDefaults keys for migration.
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

// MARK: - UserDefaults (legacy migration)

enum PaywallAppStorageKeys {
    /// Legacy single gate from older builds; still cleared on logout. New flow uses `AppFlowStorageKeys`.
    static let hasPassedPaywall = "paywall.hasPassedPaywall"
}

/// Clears the signed-in session flag so the user returns to sign-in. **Preserves** saved Apple profile (name, email, user id). StoreKit entitlements stay on the Apple ID.
@MainActor
enum PaywallReset {
    static func logout() {
        let d = UserDefaults.standard
        d.set(false, forKey: AppFlowStorageKeys.isSignedIn)
        d.set(false, forKey: PaywallAppStorageKeys.hasPassedPaywall)
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

    /// Shown only when `Product` hasn’t loaded yet (offline).
    var fallbackPriceLine: String {
        switch self {
        case .oneWeek: return "$4.99"
        case .oneMonth: return "$12.99"
        case .oneYear: return "$49.99"
        }
    }

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
