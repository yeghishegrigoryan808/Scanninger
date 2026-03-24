//
//  MyProfileView.swift
//  Scanninger
//
//  Profile: local Apple sign-in data when available; subscription section remains mock until StoreKit.
//

import SwiftUI

struct MyProfileView: View {
    @ObservedObject private var appleSession = AppleSignInSessionManager.shared
    @State private var showLogoutAlert = false
    @State private var showManagePlaceholder = false
    @State private var showRestorePlaceholder = false

    /// Mock subscription — unchanged until StoreKit / RevenueCat.
    private let subscriptionMock = SubscriptionSnapshot(
        currentPlan: "1 Year Plan",
        status: "Inactive",
        subscriptionEndDate: "April 30, 2026"
    )

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
                    Text(subscriptionMock.currentPlan)
                        .foregroundStyle(.primary)
                }

                LabeledContent("Status") {
                    subscriptionStatusBadge(subscriptionMock.status)
                }

                LabeledContent("Subscription End Date") {
                    Text(subscriptionMock.subscriptionEndDate)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Subscription")
            }

            Section {
                Button {
                    showManagePlaceholder = true
                } label: {
                    Label("Manage Subscription", systemImage: "creditcard")
                }

                Button {
                    showRestorePlaceholder = true
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
                PaywallReset.resetDraftSession()
            }
        } message: {
            Text("You’ll return to the welcome screen. Local Apple sign-in data will be cleared.")
        }
        .alert("Manage Subscription", isPresented: $showManagePlaceholder) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Subscription management will open App Store / your billing provider here.")
        }
        .alert("Restore Purchases", isPresented: $showRestorePlaceholder) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Restore will verify past purchases with the App Store when implemented.")
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
            if normalized.contains("active") { return .green }
            if normalized.contains("trial") { return .blue }
            if normalized.contains("inactive") || normalized.contains("expired") { return .orange }
            return .secondary
        }()

        Text(status)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }
}

#Preview {
    NavigationStack {
        MyProfileView()
    }
}
