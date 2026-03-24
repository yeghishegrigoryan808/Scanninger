//
//  PaywallView.swift
//  Scanninger
//
//  Subscription plans with StoreKit 2 prices, purchase, and restore.
//

import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var purchaseInProgress = false
    @State private var purchaseError: String?

    private var appTitle: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Scanninger"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 12)

                    planSection
                        .padding(.top, 28)

                    footnotes
                        .padding(.top, 16)

                    continueButton
                        .padding(.top, 28)

                    legalRow
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
            }
        }
        .task {
            await subscription.loadProducts()
            await subscription.refreshEntitlements()
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPrivacy = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack {
                TermsOfUseView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showTerms = false }
                        }
                    }
            }
        }
        .alert("Purchase", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(appTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Choose your plan")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subscription.isLoadingProducts ? "Loading prices…" : "Prices from the App Store.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var planSection: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionPlan.allCases) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        let selected = viewModel.selectedPlan == plan
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.select(plan)
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.blue.gradient))
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(subscription.displayPrice(for: plan))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(plan.periodSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? Color.blue : Color.secondary.opacity(0.45))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Color.blue.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Color.blue.opacity(0.85) : Color.primary.opacity(0.06), lineWidth: selected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: selected ? 12 : 6, x: 0, y: selected ? 6 : 3)
        }
        .buttonStyle(.plain)
    }

    private var footnotes: some View {
        VStack(spacing: 6) {
            Text("Cancel anytime")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Premium unlocks PDF export and advanced invoice design")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var continueButton: some View {
        Button {
            Task {
                purchaseError = nil
                purchaseInProgress = true
                defer { purchaseInProgress = false }
                do {
                    try await subscription.purchase(plan: viewModel.selectedPlan)
                } catch {
                    if let sub = error as? SubscriptionError, case .userCancelled = sub { return }
                    purchaseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        } label: {
            ZStack {
                Text("Continue")
                    .font(.headline)
                    .opacity(purchaseInProgress ? 0 : 1)
                if purchaseInProgress {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchaseInProgress)
        .accessibilityIdentifier("paywall.continue")
    }

    private var legalRow: some View {
        VStack(spacing: 14) {
            Button("Restore Purchases") {
                Task {
                    await viewModel.restorePurchases()
                    if let msg = subscription.lastErrorMessage {
                        purchaseError = msg
                    } else if !subscription.isPremium {
                        purchaseError = "No active subscription found for this Apple ID."
                    }
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button("Privacy Policy") { showPrivacy = true }
                Text("·")
                    .foregroundStyle(.quaternary)
                Button("Terms of Use") { showTerms = true }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PaywallView()
}
