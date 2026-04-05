//
//  SignInView.swift
//  Scanninger
//
//  Dedicated Sign in with Apple screen (after onboarding, before paywall).
//

import AuthenticationServices
import SwiftUI
import UIKit

private enum SignInChrome {
    static let backLabelGray = Color(red: 0.28, green: 0.30, blue: 0.34)
    static let horizontalPadding: CGFloat = 24
}

struct SignInView: View {
    /// Called after Apple credential is saved locally. Parent should set `AppFlowStorageKeys.isSignedIn`.
    let onSignedIn: () -> Void
    /// When set (onboarding flow step 2), shows a top **Back** control that returns to onboarding page 2.
    var onBack: (() -> Void)? = nil

    @State private var showSignInError = false
    @State private var signInErrorMessage = ""

    /// Drop a **non-screenshot** illustration (e.g. vector PDF) into Assets as `signin_illustration` to use it; until then a simple SF Symbol graphic is shown.
    private static let optionalIllustrationAssetName = "signin_illustration"

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                HStack(alignment: .center, spacing: 0) {
                    Button(action: onBack) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(SignInChrome.backLabelGray)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, SignInChrome.horizontalPadding - 2)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }

            GeometryReader { geometry in
                let horizontalPadding = SignInChrome.horizontalPadding
                let topBreathing: CGFloat = {
                    if onBack != nil {
                        return 24
                    }
                    return max(geometry.safeAreaInsets.top + geometry.size.height * 0.10, 52)
                }()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: topBreathing)

                    signInIllustration()
                        .frame(maxWidth: min(geometry.size.width - horizontalPadding * 2, 280))

                    Spacer()
                        .frame(minHeight: 32, maxHeight: 48)

                    VStack(spacing: 14) {
                        Text("Save your work and access it anytime")
                            .font(.title.bold())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Sign in with Apple to keep your invoices, clients, and business details secure.")
                            .font(.body)
                            .foregroundStyle(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, horizontalPadding + 4)

                    Spacer(minLength: 16)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemGray6).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                            signInErrorMessage = "Unexpected credential type."
                            showSignInError = true
                            return
                        }
                        AppleSignInSessionManager.shared.saveFromAppleCredential(credential)
                        await SubscriptionManager.shared.synchronizeEntitlementsOnLaunch()
                        onSignedIn()
                    case .failure(let error):
                        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                            return
                        }
                        signInErrorMessage = error.localizedDescription
                        showSignInError = true
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, SignInChrome.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color(uiColor: .systemGray6))
        }
        .alert("Sign In Failed", isPresented: $showSignInError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(signInErrorMessage)
        }
    }

    /// Simple graphic only: SF Symbols by default, or a **non-mockup** bitmap/PDF in Assets named `signin_illustration` if you add it later.
    @ViewBuilder
    private func signInIllustration() -> some View {
        if let uiImage = UIImage(named: Self.optionalIllustrationAssetName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .accessibilityLabel("Illustration")
        } else {
            minimalSymbolIllustration()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cloud and documents, representing saved work")
        }
    }

    private func minimalSymbolIllustration() -> some View {
        ZStack {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.blue.opacity(0.55))
                .offset(x: -58, y: 10)

            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.green.opacity(0.65))
                .offset(x: 54, y: 6)

            Image(systemName: "icloud.fill")
                .font(.system(size: 68, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SignInView(onSignedIn: {})
}
