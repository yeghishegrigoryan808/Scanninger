//
//  MyProfileView.swift
//  Scanninger
//
//  Account: name and email from `AppleSignInSessionManager`; subscription from StoreKit 2 / `SubscriptionManager`.
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
                profileHeader(fullName: profile.fullName, email: profile.email)
            }

            Section {
                LabeledContent("Current Plan") {
                    Text(subscription.friendlyPlanName())
                        .foregroundStyle(.primary)
                }

                LabeledContent("Status") {
                    subscriptionStatusBadge(subscription.subscriptionStatusLabel())
                }

                LabeledContent("Renews on") {
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
            }

            Section {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
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

    private func profileHeader(fullName: String, email: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary, Color(uiColor: .tertiarySystemFill))

            VStack(alignment: .leading, spacing: 5) {
                Text(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : fullName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
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
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(tint.opacity(0.92))
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
