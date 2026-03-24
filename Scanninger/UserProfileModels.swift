//
//  UserProfileModels.swift
//  Scanninger
//
//  Profile snapshot for the My Profile screen (Sign in with Apple data via `AppleSignInSessionManager`).
//

import Foundation

struct UserProfileSnapshot: Sendable {
    var fullName: String
    var email: String
    var signInMethod: String
}
