//
//  OnboardingView.swift
//  Scanninger
//
//  Onboarding pages 1–2: shared chrome (Skip, Continue, background), light mode only.
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
    static let connectorLine = Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.12)
    static let stepNeutralFill = Color(red: 0.94, green: 0.95, blue: 0.96)
    static let stepPurpleFill = Color(red: 0.94, green: 0.91, blue: 0.98)
    static let stepPurpleIcon = Color(red: 0.45, green: 0.35, blue: 0.85)
    static let stepGreenFill = Color(red: 0.91, green: 0.96, blue: 0.93)
    static let stepGreenIcon = Color(red: 0.18, green: 0.62, blue: 0.42)
}

// MARK: - Spacing

private enum OnboardingLayout {
    static let cardToTitle: CGFloat = 28
    static let titleToSubtitle: CGFloat = 10
    static let scrollBottomBreathing: CGFloat = 20
    static let horizontalPadding: CGFloat = 22
    static let cardWidthFraction: CGFloat = 0.84
    static let cardVerticalGutter: CGFloat = 16
    static let cardHorizontalGutter: CGFloat = 10
    static let stepsToMainTitle: CGFloat = 32
    static let stepIconTitleGap: CGFloat = 10
    static let stepTitleSubtitleGap: CGFloat = 4
    static let connectorHeight: CGFloat = 22
    static let connectorWidth: CGFloat = 2
    static let stepBlockTopPadding: CGFloat = 8
}

// MARK: - Reusable chrome (page 1 & 2 — identical styling)

/// Top bar: optional **Back** (page 2) on the leading side, **Skip** trailing. Sits just below the safe area (no extra `safeAreaInsets.top` padding — that was doubling the inset and pushed the bar down).
private struct OnboardingTopBar: View {
    let sideInset: CGFloat
    let onSkip: () -> Void
    var onBack: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if let onBack {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(OnboardingLightPalette.skipGray)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button("Skip", action: onSkip)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingLightPalette.skipGray)
        }
        .padding(.horizontal, sideInset)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

/// Primary CTA; matches page 1 fill, radius, shadow, press scale, and footer padding.
private struct OnboardingPrimaryButton: View {
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
        .buttonStyle(OnboardingPrimaryPressStyle())
    }
}

private struct OnboardingPrimaryPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

/// Primary CTA bar for `safeAreaInset(edge: .bottom)` so layout does not depend on a full-screen `GeometryReader` for bottom inset.
private struct OnboardingBottomCTA: View {
    let title: String
    let sideInset: CGFloat
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingPrimaryButton(title: title, action: action)
                .padding(.horizontal, sideInset)
                .padding(.top, 16)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(OnboardingLightPalette.backgroundBottom)
    }
}

private enum OnboardingScreenBackground {
    static func gradient() -> some View {
        LinearGradient(
            colors: [
                OnboardingLightPalette.backgroundTop,
                OnboardingLightPalette.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Connector (between steps)

private struct OnboardingConnectorView: View {
    var body: some View {
        Rectangle()
            .fill(OnboardingLightPalette.connectorLine)
            .frame(width: OnboardingLayout.connectorWidth, height: OnboardingLayout.connectorHeight)
    }
}

// MARK: - Step row

private struct OnboardingStepView: View {
    let systemImage: String
    let iconForeground: Color
    let iconBackground: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 56, height: 56)
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(iconForeground)
            }
            .padding(.bottom, OnboardingLayout.stepIconTitleGap)

            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingLightPalette.titleNavy)
                .multilineTextAlignment(.center)

            Color.clear
                .frame(height: OnboardingLayout.stepTitleSubtitleGap)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(OnboardingLightPalette.subtitleGray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Page 1 — invoice hero

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

private struct OnboardingPageOneView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        let sideInset = OnboardingLayout.horizontalPadding
        VStack(spacing: 0) {
            OnboardingTopBar(sideInset: sideInset, onSkip: onSkip, onBack: nil)

            GeometryReader { geo in
                let cardWidth = min(
                    geo.size.width * OnboardingLayout.cardWidthFraction,
                    geo.size.width - sideInset * 2
                )
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

                        Color.clear
                            .frame(height: OnboardingLayout.scrollBottomBreathing)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, sideInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingScreenBackground.gradient())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomCTA(title: "Continue", sideInset: sideInset, action: onContinue)
        }
    }
}

// MARK: - Page 2 — three steps + headline

private struct OnboardingPageTwoView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        let sideInset = OnboardingLayout.horizontalPadding
        VStack(spacing: 0) {
            OnboardingTopBar(sideInset: sideInset, onSkip: onSkip, onBack: onBack)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: 0) {
                    Color.clear
                        .frame(height: OnboardingLayout.stepBlockTopPadding)

                    OnboardingStepView(
                        systemImage: "person.crop.circle",
                        iconForeground: OnboardingLightPalette.titleNavy,
                        iconBackground: OnboardingLightPalette.stepNeutralFill,
                        title: "Add client",
                        subtitle: "Enter basic details"
                    )

                    OnboardingConnectorView()
                        .padding(.vertical, 6)

                    OnboardingStepView(
                        systemImage: "list.clipboard.fill",
                        iconForeground: OnboardingLightPalette.stepPurpleIcon,
                        iconBackground: OnboardingLightPalette.stepPurpleFill,
                        title: "Add items",
                        subtitle: "List your services"
                    )

                    OnboardingConnectorView()
                        .padding(.vertical, 6)

                    OnboardingStepView(
                        systemImage: "paperplane.fill",
                        iconForeground: OnboardingLightPalette.stepGreenIcon,
                        iconBackground: OnboardingLightPalette.stepGreenFill,
                        title: "Send invoice",
                        subtitle: "Done in seconds"
                    )

                    Color.clear
                        .frame(height: OnboardingLayout.stepsToMainTitle)

                    Text("Create invoices in seconds")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(OnboardingLightPalette.titleNavy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.88)
                        .padding(.horizontal, 8)

                    Color.clear
                        .frame(height: OnboardingLayout.titleToSubtitle)

                    Text("Add your client, enter items, and send — it's that simple.")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(OnboardingLightPalette.subtitleGray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)

                    Color.clear
                        .frame(height: OnboardingLayout.scrollBottomBreathing)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, sideInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingScreenBackground.gradient())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomCTA(title: "Continue", sideInset: sideInset, action: onComplete)
        }
    }
}

// MARK: - Page transitions (forward / back)

private enum OnboardingNavigationAnimation {
    static let duration: Double = 0.32
    static var animation: Animation {
        .easeInOut(duration: duration)
    }

    /// Forward (0→1, 1→2): outgoing slides off **leading**, incoming from **trailing** — one consistent “push” for every step.
    static let pushForward = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    /// Backward (2→1, 1→0): mirror of `pushForward`.
    static let pushBackward = AnyTransition.asymmetric(
        insertion: .move(edge: .leading).combined(with: .opacity),
        removal: .move(edge: .trailing).combined(with: .opacity)
    )
}

// MARK: - Public container (onboarding pages 1–2 + sign in as one state machine)

/// Single parent for steps **0 → 1 → 2** (page 1, page 2, sign in). `ScanningerRootView` presents this whenever the user is not signed in after splash.
struct OnboardingFlowView: View {
    @Binding var hasSeenOnboarding: Bool
    let onSignedIn: () -> Void

    @AppStorage(AppFlowStorageKeys.hasCompletedSignInBefore) private var hasCompletedSignInBefore = false

    @State private var currentStep: Int
    /// Drives which asymmetric transition applies so forward steps all match and Back is the mirror.
    @State private var stepPushesForward = true

    init(hasSeenOnboarding: Binding<Bool>, onSignedIn: @escaping () -> Void) {
        self._hasSeenOnboarding = hasSeenOnboarding
        self.onSignedIn = onSignedIn
        _currentStep = State(initialValue: Self.restoredStep())
    }

    /// Restore step from storage; keep logout / returning users on sign-in without onboarding Back (`hasCompletedSignInBefore`).
    private static func restoredStep() -> Int {
        let d = UserDefaults.standard
        if d.bool(forKey: AppFlowStorageKeys.hasCompletedSignInBefore) {
            return 2
        }
        if let n = d.object(forKey: AppFlowStorageKeys.onboardingFlowStep) as? Int, (0...2).contains(n) {
            return n
        }
        return d.bool(forKey: AppFlowStorageKeys.hasSeenOnboarding) ? 2 : 0
    }

    private static func persistOnboardingStep(_ step: Int) {
        UserDefaults.standard.set(step, forKey: AppFlowStorageKeys.onboardingFlowStep)
    }

    private var stepTransition: AnyTransition {
        stepPushesForward ? OnboardingNavigationAnimation.pushForward : OnboardingNavigationAnimation.pushBackward
    }

    var body: some View {
        ZStack {
            if currentStep == 0 {
                OnboardingPageOneView(
                    onContinue: {
                        stepPushesForward = true
                        withAnimation(OnboardingNavigationAnimation.animation) {
                            currentStep = 1
                        }
                    },
                    onSkip: { goToSignIn() }
                )
                .transition(stepTransition)
            }

            if currentStep == 1 {
                OnboardingPageTwoView(
                    onComplete: { goToSignIn() },
                    onSkip: { goToSignIn() },
                    onBack: {
                        stepPushesForward = false
                        withAnimation(OnboardingNavigationAnimation.animation) {
                            currentStep = 0
                        }
                    }
                )
                .transition(stepTransition)
            }

            if currentStep == 2 {
                SignInView(
                    onSignedIn: onSignedIn,
                    onBack: hasCompletedSignInBefore
                        ? nil
                        : {
                            stepPushesForward = false
                            withAnimation(OnboardingNavigationAnimation.animation) {
                                currentStep = 1
                            }
                        }
                )
                .transition(stepTransition)
            }
        }
        .preferredColorScheme(currentStep == 2 ? nil : .light)
        .onAppear {
            Self.persistOnboardingStep(currentStep)
        }
        .onChange(of: currentStep) { _, newStep in
            Self.persistOnboardingStep(newStep)
        }
    }

    private func goToSignIn() {
        stepPushesForward = true
        hasSeenOnboarding = true
        withAnimation(OnboardingNavigationAnimation.animation) {
            currentStep = 2
        }
    }
}

#Preview("Onboarding flow") {
    struct Holder: View {
        @State private var seen = false
        var body: some View {
            OnboardingFlowView(hasSeenOnboarding: $seen, onSignedIn: {})
        }
    }
    return Holder()
}
