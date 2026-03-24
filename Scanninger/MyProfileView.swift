//
//  MyProfileView.swift
//  Scanninger
//
//  Profile: Apple sign-in data from `AppleSignInSessionManager`; subscription from StoreKit 2 / `SubscriptionManager`.
//

import StoreKit
import SwiftUI
import UIKit

struct MyProfileView: View {
    @ObservedObject private var appleSession = AppleSignInSessionManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showLogoutAlert = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        let profile = appleSession.userProfileSnapshot()
        return List {
            Section {
                profileRow(icon: "person.fill", title: "Full Name", value: profile.fullName)
                profileRow(icon: "envelope.fill", title: "Email", value: profile.email)
                profileRow(icon: "apple.logo", title: "Sign in method", value: profile.signInMethod)
            } header: {
                Text("Profile")
            }

            Section {
                LabeledContent("Current Plan") {
                    Text(subscription.friendlyPlanName())
                        .foregroundStyle(.primary)
                }

                LabeledContent("Status") {
                    subscriptionStatusBadge(subscription.subscriptionStatusLabel())
                }

                LabeledContent("Subscription End Date") {
                    Text(subscription.subscriptionExpirationFormatted())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Subscription")
            }

            Section {
                Button {
                    Task {
                        await openManageSubscriptions()
                    }
                } label: {
                    Label("Manage Subscription", systemImage: "creditcard")
                }

                Button {
                    Task {
                        await subscription.restorePurchases()
                        if subscription.isPremium {
                            restoreMessage = "Subscription restored."
                        } else if let err = subscription.lastErrorMessage {
                            restoreMessage = err
                        } else {
                            restoreMessage = "No active subscription found for this Apple ID."
                        }
                        showRestoreAlert = true
                    }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
                }

                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } header: {
                Text("Actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Log out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) {
                PaywallReset.logout()
            }
        } message: {
            Text("You’ll return to sign in. Your name and email stay on this device for next time. Subscriptions remain tied to your Apple ID.")
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreMessage)
        }
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    @ViewBuilder
    private func subscriptionStatusBadge(_ status: String) -> some View {
        let normalized = status.lowercased()
        let tint: Color = {
            if normalized == "active" { return .green }
            if normalized.contains("trial") { return .blue }
            if normalized == "inactive" || normalized.contains("expired") { return .orange }
            return .secondary
        }()

        Text(status)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }

    @MainActor
    private func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyProfileView()
    }
}
