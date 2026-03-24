//
//  AppleSignInSessionManager.swift
//  Scanninger
//
//  Persists Sign in with Apple identity locally (UserDefaults). Merge rules: never overwrite
//  stored name/email with empty values when Apple omits them on later sign-ins (relay email preserved).
//

import AuthenticationServices
import Combine
import Foundation

/// Locally stored Apple account fields (not Keychain — sufficient for local-only; migrate user id to Keychain if needed).
struct StoredAppleAccount: Codable, Equatable {
    var userIdentifier: String
    var email: String
    var fullName: String
}

@MainActor
final class AppleSignInSessionManager: ObservableObject {
    static let shared = AppleSignInSessionManager()

    private let defaultsKey = "auth.apple.storedAccount.v1"
    private let defaults = UserDefaults.standard

    @Published private(set) var account: StoredAppleAccount?

    private init() {
        loadFromStorage()
    }

    private func loadFromStorage() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(StoredAppleAccount.self, from: data) else {
            account = nil
            return
        }
        account = decoded
    }

    private func persist() {
        guard let account else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        if let data = try? JSONEncoder().encode(account) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    /// Merges credential into storage. Empty email/name from Apple on repeat sign-in do not wipe prior values.
    func saveFromAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        let userId = credential.user
        let incomingEmail = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let incomingName = Self.formattedFullName(from: credential.fullName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var next: StoredAppleAccount
        if let existing = account, existing.userIdentifier == userId {
            next = existing
        } else {
            next = StoredAppleAccount(userIdentifier: userId, email: "", fullName: "")
        }

        next.userIdentifier = userId

        if !incomingEmail.isEmpty {
            next.email = incomingEmail
        }
        if !incomingName.isEmpty {
            next.fullName = incomingName
        }

        account = next
        persist()
    }

    func userProfileSnapshot() -> UserProfileSnapshot {
        guard let a = account, !a.userIdentifier.isEmpty else {
            return UserProfileSnapshot(
                fullName: "—",
                email: "—",
                signInMethod: "Not signed in with Apple"
            )
        }
        return UserProfileSnapshot(
            fullName: a.fullName.isEmpty ? "—" : a.fullName,
            email: a.email.isEmpty ? "—" : a.email,
            signInMethod: "Apple ID"
        )
    }

    private static func formattedFullName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let s = formatter.string(from: components)
        return s.isEmpty ? nil : s
    }
}
