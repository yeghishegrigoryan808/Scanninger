//
//  SignInView.swift
//  Scanninger
//
//  Dedicated Sign in with Apple screen (after onboarding, before paywall).
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    /// Called after Apple credential is saved locally. Parent should set `AppFlowStorageKeys.isSignedIn`.
    let onSignedIn: () -> Void

    @State private var showSignInError = false
    @State private var signInErrorMessage = ""

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

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 64, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                VStack(spacing: 10) {
                    Text(appTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Sign in to continue")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Use your Apple ID to save your profile on this device. Subscription choices come next.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer(minLength: 20)

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
                            await SubscriptionManager.shared.refreshEntitlements()
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
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 22)
                .accessibilityIdentifier("signIn.apple")

                Text("Next you’ll choose a subscription. Use Xcode StoreKit testing for local purchases.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer(minLength: 48)
            }
        }
        .alert("Sign In Failed", isPresented: $showSignInError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(signInErrorMessage)
        }
    }
}

#Preview {
    SignInView(onSignedIn: {})
}
