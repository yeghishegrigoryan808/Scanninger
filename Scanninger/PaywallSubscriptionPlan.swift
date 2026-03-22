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
    /// When `true`, the user completed the paywall flow and should not see it again (until reset).
    static let hasPassedPaywall = "paywall.hasPassedPaywall"
}

/// Clears persisted paywall state for testing (e.g. from a future debug menu or one-off call).
enum PaywallReset {
    static func clearPassedPaywallFlag() {
        UserDefaults.standard.removeObject(forKey: PaywallAppStorageKeys.hasPassedPaywall)
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
