//
//  PaywallView.swift
//  Scanninger
//
//  Subscription plans with StoreKit 2 prices, purchase, and restore.
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var purchaseInProgress = false
    @State private var purchaseError: String?
    @State private var contentVisible = false
    @State private var animateHero = false
    @State private var ctaVisible = false

    private var appTitle: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Scanninger"
    }

    private var yearlyMonthlyEquivalentText: String {
        guard
            let product = subscription.productsById[PremiumSubscriptionProductID.yearly]
        else {
            return "$4.17/mo"
        }

        let monthly = (product.price as NSDecimalNumber).doubleValue / 12.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: monthly)) ?? "$4.17") + "/mo"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground).opacity(0.82),
                    Color.blue.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 24)

                    benefitsSection
                        .padding(.top, 24)

                    planSection
                        .padding(.top, 24)

                    footnotes
                        .padding(.top, 16)

                    continueButton
                        .padding(.top, 28)

                    legalRow
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 18)
                .animation(.easeOut(duration: 0.5), value: contentVisible)
            }
        }
        .task {
            await subscription.loadProducts()
            await subscription.refreshEntitlements()
        }
        .onAppear {
            contentVisible = true
            animateHero = true
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.18)) {
                ctaVisible = true
            }
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
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 36, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .scaleEffect(animateHero ? 1.03 : 0.97)
                .offset(y: animateHero ? -4 : 4)
                .animation(
                    .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                    value: animateHero
                )

            Text(appTitle.uppercased())
                .font(.caption.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(.secondary)

            Text("Run your business like a pro")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("Create invoices, manage clients, and export professional PDFs — all in one place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefitsSection: some View {
        VStack(spacing: 10) {
            benefitRow(icon: "bolt.fill", text: "Create invoices in seconds")
            benefitRow(icon: "person.2.fill", text: "Keep clients organized")
            benefitRow(icon: "doc.richtext.fill", text: "Export beautiful PDFs")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.8))
        )
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
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
        let isYearly = plan == .oneYear
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
                        if isYearly {
                            Text("Best Value")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
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
                    if isYearly {
                        Text("Only \(yearlyMonthlyEquivalentText)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? Color.blue : Color.secondary.opacity(0.45))
            }
            .padding(isYearly ? 22 : 18)
            .frame(maxWidth: .infinity, minHeight: isYearly ? 112 : 88, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isYearly
                        ? LinearGradient(
                            colors: [
                                Color.blue.opacity(selected ? 0.17 : 0.1),
                                Color.blue.opacity(selected ? 0.07 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                selected ? Color.blue.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                                selected ? Color.blue.opacity(0.09) : Color(.secondarySystemGroupedBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        selected || isYearly ? Color.blue.opacity(0.85) : Color.primary.opacity(0.06),
                        lineWidth: selected || isYearly ? 2 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isYearly ? 0.12 : (selected ? 0.1 : 0.06)),
                radius: isYearly ? 18 : (selected ? 14 : 6),
                x: 0,
                y: isYearly ? 10 : (selected ? 8 : 3)
            )
            .scaleEffect(selected ? 1.03 : 1.0)
            .animation(.spring(response: 0.34, dampingFraction: 0.8), value: selected)
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
                Text("Get Premium")
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
            .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 8)
            .scaleEffect(ctaVisible ? 1 : 0.96)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: ctaVisible)
        }
        .buttonStyle(PremiumPressButtonStyle())
        .disabled(purchaseInProgress)
        .accessibilityIdentifier("paywall.continue")
    }

    private var legalRow: some View {
        VStack(spacing: 14) {
            Text("Cancel anytime • Secure with Apple")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

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
