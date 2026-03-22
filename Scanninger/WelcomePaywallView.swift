//
//  WelcomePaywallView.swift
//  Scanninger
//
//  Draft full-screen paywall after splash. Mock only — no StoreKit or Sign in with Apple.
//

import SwiftUI

struct WelcomePaywallView: View {
    @StateObject private var viewModel = WelcomePaywallViewModel()
    let onComplete: () -> Void

    @State private var showPrivacy = false
    @State private var showTerms = false

    private var appTitle: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Scanninger"
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 12)

                    planSection
                        .padding(.top, 28)

                    footnotes
                        .padding(.top, 16)

                    primaryButtons
                        .padding(.top, 28)

                    legalRow
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
            }
        }
        .onAppear {
            viewModel.recordPaywallSeen()
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
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(appTitle)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Create professional invoices in minutes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
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
                        Text(plan.priceLine)
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

    private var primaryButtons: some View {
        VStack(spacing: 14) {
            continueWithAppleButton
            unlockButton
        }
    }

    private var continueWithAppleButton: some View {
        Button {
            viewModel.continueWithApple()
            onComplete()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "applelogo")
                    .font(.title3.weight(.semibold))
                Text("Continue with Apple")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.continueWithApple")
    }

    private var unlockButton: some View {
        Button {
            viewModel.continueUnlockPremium()
            onComplete()
        } label: {
            Text("Unlock Premium")
                .font(.headline)
                .foregroundStyle(Color.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.unlockPremium")
    }

    private var legalRow: some View {
        VStack(spacing: 14) {
            Button("Restore Purchases") {
                viewModel.restorePurchases()
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
    WelcomePaywallView(onComplete: {})
}
