//
//  PaywallView.swift
//  Scanninger
//
//  Subscription plans with StoreKit 2 prices, purchase, and restore.
//

import StoreKit
import SwiftUI

// MARK: - Theme (paywall-only)

private enum PaywallTheme {
    static let screenBackground = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let titleNavy = Color(red: 0.07, green: 0.10, blue: 0.16)
    static let subtitleGray = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let accentBlue = Color(red: 0.22, green: 0.48, blue: 0.95)
    static let iconCircleFill = Color(red: 0.88, green: 0.93, blue: 0.99)
    static let ctaNavy = Color(red: 11 / 255, green: 28 / 255, blue: 52 / 255)
    static let cardSelectedFill = Color(red: 0.94, green: 0.97, blue: 1.0)
    static let cardUnselectedFill = Color.white
    static let borderUnselected = Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.08)
    static let saveGreen = Color(red: 0.18, green: 0.62, blue: 0.42)
}

// MARK: - Feature row

private struct PaywallFeatureRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(PaywallTheme.iconCircleFill)
                    .frame(width: 46, height: 46)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(PaywallTheme.accentBlue)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(PaywallTheme.titleNavy)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Plan radio

private struct PaywallPlanRadio: View {
    let selected: Bool

    var body: some View {
        Group {
            if selected {
                ZStack {
                    Circle()
                        .fill(PaywallTheme.accentBlue)
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            } else {
                Circle()
                    .strokeBorder(Color(red: 0.75, green: 0.77, blue: 0.80), lineWidth: 2)
                    .frame(width: 22, height: 22)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityLabel(selected ? "Selected" : "Not selected")
    }
}

// MARK: - Plan card

private struct PaywallPlanCard: View {
    let plan: SubscriptionPlan
    let selected: Bool
    let displayPrice: String
    let onSelect: () -> Void

    private var isYearly: Bool { plan == .oneYear }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: isYearly ? 10 : 0)

                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(plan.title)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(PaywallTheme.titleNavy)
                                if isYearly {
                                    Text("Save 50%")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(PaywallTheme.saveGreen))
                                }
                            }
                            Text(plan.paywallMarketingSubtitle)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundStyle(PaywallTheme.subtitleGray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(displayPrice)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(PaywallTheme.titleNavy)
                                    .minimumScaleFactor(0.85)
                                    .lineLimit(1)
                                Text(plan.periodSubtitle)
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundStyle(PaywallTheme.subtitleGray)
                            }
                            PaywallPlanRadio(selected: selected)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? PaywallTheme.cardSelectedFill : PaywallTheme.cardUnselectedFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            selected ? PaywallTheme.accentBlue : PaywallTheme.borderUnselected,
                            lineWidth: selected ? 2 : 1
                        )
                )

                if isYearly {
                    Text("Most Popular")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(PaywallTheme.accentBlue))
                        .offset(y: -11)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main view

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var purchaseInProgress = false
    @State private var purchaseError: String?

    private var trialPrimaryLine: String {
        switch viewModel.selectedPlan {
        case .oneYear:
            return "3-day free trial, then billed annually"
        case .oneMonth:
            return "3-day free trial, then billed monthly"
        case .oneWeek:
            return "3-day free trial, then billed weekly"
        }
    }

    var body: some View {
        ZStack {
            PaywallTheme.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 28)

                    featureSection
                        .padding(.top, 28)

                    planSection
                        .padding(.top, 28)

                    ctaSection
                        .padding(.top, 28)

                    footerSection
                        .padding(.top, 20)
                        .padding(.bottom, 32)
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

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Start creating invoices today")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PaywallTheme.titleNavy)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Professional tools to run your business effortlessly")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(PaywallTheme.subtitleGray)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var featureSection: some View {
        VStack(spacing: 4) {
            PaywallFeatureRow(systemImage: "doc.text.fill", title: "Unlimited invoices")
            PaywallFeatureRow(systemImage: "cube.fill", title: "Professional templates")
            PaywallFeatureRow(systemImage: "person.2.fill", title: "Manage clients & items")
            PaywallFeatureRow(systemImage: "square.and.arrow.down.fill", title: "Export and share PDFs")
        }
    }

    private var planSection: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionPlan.paywallDisplayOrder) { plan in
                PaywallPlanCard(
                    plan: plan,
                    selected: viewModel.selectedPlan == plan,
                    displayPrice: subscription.displayPrice(for: plan)
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        viewModel.select(plan)
                    }
                }
            }
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 14) {
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
                    Text("Start Free Trial")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .opacity(purchaseInProgress ? 0 : 1)
                    if purchaseInProgress {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PaywallTheme.ctaNavy)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PremiumPressButtonStyle())
            .disabled(purchaseInProgress)
            .accessibilityIdentifier("paywall.continue")

            Text(trialPrimaryLine)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(PaywallTheme.subtitleGray)
                .multilineTextAlignment(.center)

            Text("Cancel anytime. No commitments.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(PaywallTheme.subtitleGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
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
            .font(.system(size: 15, weight: .medium, design: .default))
            .foregroundStyle(PaywallTheme.accentBlue)

            HStack(spacing: 6) {
                Button("Privacy Policy") { showPrivacy = true }
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(PaywallTheme.subtitleGray.opacity(0.85))
                Text("·")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PaywallTheme.subtitleGray.opacity(0.55))
                Button("Terms of Use") { showTerms = true }
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(PaywallTheme.subtitleGray.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PremiumPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    PaywallView()
}
