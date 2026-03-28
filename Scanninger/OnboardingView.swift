//
//  OnboardingView.swift
//  Scanninger
//
//  Onboarding page 1 — single invoice hero, vertical flow, light mode only.
//

import SwiftUI

// MARK: - Light-only palette

private enum OnboardingLightPalette {
    static let backgroundTop = Color(red: 0.965, green: 0.968, blue: 0.974)
    static let backgroundBottom = Color(red: 1.0, green: 0.996, blue: 0.992)
    static let cardBackground = Color.white
    static let cardBorder = Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.06)
    static let inkPrimary = Color(red: 0.11, green: 0.13, blue: 0.18)
    static let inkSecondary = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let inkMuted = Color(red: 0.58, green: 0.60, blue: 0.64)
    static let ruleLine = Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.08)
    static let logoPlaceholder = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let paidGreen = Color(red: 0.18, green: 0.62, blue: 0.42)
    static let titleNavy = Color(red: 0.07, green: 0.10, blue: 0.16)
    static let subtitleGray = Color(red: 0.32, green: 0.34, blue: 0.38)
    static let skipGray = Color(red: 0.28, green: 0.30, blue: 0.34)
    static let buttonFill = Color(red: 11 / 255, green: 28 / 255, blue: 52 / 255)
}

// MARK: - Spacing

private enum OnboardingLayout {
    static let cardToTitle: CGFloat = 28
    static let titleToSubtitle: CGFloat = 10
    static let scrollBottomBreathing: CGFloat = 20
    static let horizontalPadding: CGFloat = 22
    /// Target width ≈ 84% of screen, capped so it stays inside padded bounds (~82–86% visually).
    static let cardWidthFraction: CGFloat = 0.84
    static let cardVerticalGutter: CGFloat = 16
    static let cardHorizontalGutter: CGFloat = 10
}

// MARK: - One invoice card (compact; natural height ≈ 300–320pt — nothing clipped)

private struct OnboardingInvoiceHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STUDIO NORTH")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(OnboardingLightPalette.inkPrimary)
                        .tracking(0.6)
                    Text("San Francisco, CA")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(OnboardingLightPalette.inkSecondary)
                }
                Spacer(minLength: 8)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(OnboardingLightPalette.logoPlaceholder)
                    .frame(width: 36, height: 36)
            }
            .padding(.bottom, 12)

            Text("Invoice")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingLightPalette.inkPrimary)
                .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 8) {
                metaCell(title: "NO.", value: "#2047")
                metaCell(title: "ISSUED", value: "Mar 15, 2026")
                metaCell(title: "DUE", value: "Apr 15, 2026")
            }
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(OnboardingLightPalette.paidGreen)
                    .frame(width: 6, height: 6)
                Text("Paid")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkPrimary)
            }
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 3) {
                Text("BILL TO")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkMuted)
                    .tracking(0.3)
                Text("Acme Studios LLC")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkPrimary)
                Text("Brooklyn, New York")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(OnboardingLightPalette.inkSecondary)
            }
            .padding(.bottom, 10)

            HStack {
                Text("DESCRIPTION")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkMuted)
                Spacer()
                Text("AMOUNT")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkMuted)
            }
            .padding(.bottom, 4)

            itemRow(text: "Brand identity & design", amount: "$650.00")
            itemRow(text: "Website design & development", amount: "$1,240.00")

            Rectangle()
                .fill(OnboardingLightPalette.ruleLine)
                .frame(height: 1)
                .padding(.vertical, 10)

            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkSecondary)
                Spacer()
                Text("$1,890.00")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingLightPalette.inkPrimary)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OnboardingLightPalette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(OnboardingLightPalette.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
    }

    private func metaCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingLightPalette.inkMuted)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingLightPalette.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemRow(text: String, amount: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(OnboardingLightPalette.inkPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Text(amount)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingLightPalette.inkPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Continue

private struct PremiumPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OnboardingLightPalette.buttonFill)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(OnboardingPremiumPressStyle())
    }
}

private struct OnboardingPremiumPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Page 1

private struct OnboardingPageOneView: View {
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let sideInset = OnboardingLayout.horizontalPadding
            let cardWidth = min(
                geo.size.width * OnboardingLayout.cardWidthFraction,
                geo.size.width - sideInset * 2
            )

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onComplete)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(OnboardingLightPalette.skipGray)
                }
                .padding(.horizontal, sideInset)
                .padding(.top, safeTop + 8)
                .padding(.bottom, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        OnboardingInvoiceHeroCard()
                            .frame(width: cardWidth, alignment: .center)
                            .rotationEffect(.degrees(-0.5))
                            .padding(.vertical, OnboardingLayout.cardVerticalGutter)
                            .padding(.horizontal, OnboardingLayout.cardHorizontalGutter)

                        Color.clear
                            .frame(height: OnboardingLayout.cardToTitle)

                        Text("Create professional invoices in seconds")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(OnboardingLightPalette.titleNavy)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.88)
                            .padding(.horizontal, 8)

                        Color.clear
                            .frame(height: OnboardingLayout.titleToSubtitle)

                        Text("Simple, fast, and designed to get you paid faster.")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(OnboardingLightPalette.subtitleGray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 300)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: OnboardingLayout.scrollBottomBreathing)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, sideInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    PremiumPrimaryButton(title: "Continue", action: onComplete)
                        .padding(.horizontal, sideInset)
                        .padding(.top, 16)
                        .padding(.bottom, max(20, safeBottom + 12))
                }
                .frame(maxWidth: .infinity)
                .background(OnboardingLightPalette.backgroundBottom)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background(
                LinearGradient(
                    colors: [
                        OnboardingLightPalette.backgroundTop,
                        OnboardingLightPalette.backgroundBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }
}

// MARK: - Public

struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        OnboardingPageOneView(onComplete: onComplete)
            .preferredColorScheme(.light)
    }
}

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
}
