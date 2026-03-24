//
//  SplashScreen.swift
//  Scanninger
//
//  TEMPORARY: Lottie splash after launch. To remove later:
//  1. Delete this file and Scanninger/Resources/splash_animation.json
//  2. In ScanningerApp.swift, use MainTabView() directly again
//  3. Remove the Lottie package (Project → Package Dependencies)
//
//  Flow: Splash → Onboarding → SignInView → PaywallView → MainTabView when `hasActiveSubscription` (StoreKit entitlements).
//  Logout: `PaywallReset.logout()` clears `isSignedIn` only; saved Apple profile preserved; subscription state from StoreKit.
//

import SwiftUI
import UIKit
import Lottie

// MARK: - Lottie bridge (UIKit)

/// Fixed logical size for the splash Lottie (SwiftUI `.frame` should match for predictable layout).
private enum SplashLottieLayout {
    static let sideLength: CGFloat = 200
}

/// Loads a Lottie JSON from the app bundle by **filename without extension** (e.g. `"splash_animation"`).
/// Uses a plain `UIView` container so SwiftUI’s proposed size applies to a bounded rect; `LottieAnimationView`
/// is pinned inside with Auto Layout and `scaleAspectFit` (Lottie’s intrinsic size no longer expands the host view).
struct BundledLottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var onPlaybackFinished: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaybackFinished: onPlaybackFinished)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.animation = LottieAnimation.named(name, bundle: .main)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }
        guard !context.coordinator.didStartPlayback else { return }
        context.coordinator.didStartPlayback = true
        if animationView.animation == nil {
            DispatchQueue.main.async {
                context.coordinator.onPlaybackFinished?(false)
            }
            return
        }
        animationView.play { finished in
            DispatchQueue.main.async {
                context.coordinator.onPlaybackFinished?(finished)
            }
        }
    }

    final class Coordinator {
        var didStartPlayback = false
        weak var animationView: LottieAnimationView?
        let onPlaybackFinished: ((Bool) -> Void)?

        init(onPlaybackFinished: ((Bool) -> Void)?) {
            self.onPlaybackFinished = onPlaybackFinished
        }
    }
}

// MARK: - Splash

/// Full-screen splash with bundled Lottie; then calls `onFinished` once.
struct SplashView: View {
    /// Bundle resource name **without** `.json` (file: `splash_animation.json`).
    static let animationName = "splash_animation"

    /// At least this long on screen (avoids an instant flash if the animation is short).
    static let minimumVisibleDuration: TimeInterval = 1.5

    /// Hard cap — transition to the app even if playback never completes.
    static let maximumVisibleDuration: TimeInterval = 2.2

    let onFinished: () -> Void

    @State private var animationEnded = false
    @State private var minimumMet = false
    @State private var didFinish = false

    private var hasAnimationFile: Bool {
        LottieAnimation.named(Self.animationName, bundle: .main) != nil
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if hasAnimationFile {
                BundledLottieView(
                    name: Self.animationName,
                    loopMode: .playOnce,
                    onPlaybackFinished: { _ in
                        animationEnded = true
                        tryComplete()
                    }
                )
                .frame(width: SplashLottieLayout.sideLength, height: SplashLottieLayout.sideLength)
            } else {
                ProgressView()
                    .scaleEffect(1.4)
                    .onAppear {
                        // Missing JSON — don’t block startup.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            animationEnded = true
                            tryComplete()
                        }
                    }
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.minimumVisibleDuration * 1_000_000_000))
                minimumMet = true
                tryComplete()
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.maximumVisibleDuration * 1_000_000_000))
                forceComplete()
            }
        }
    }

    private func tryComplete() {
        guard !didFinish else { return }
        guard animationEnded && minimumMet else { return }
        didFinish = true
        onFinished()
    }

    private func forceComplete() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

// MARK: - App shell (swap root here when removing splash)

struct ScanningerRootView: View {
    @AppStorage(AppFlowStorageKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(AppFlowStorageKeys.isSignedIn) private var isSignedIn = false

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showSplash = true

    /// Premium access per StoreKit 2 `Transaction.currentEntitlements` (see `SubscriptionManager.synchronizeEntitlementsOnLaunch()` in `ScanningerApp`).
    private var hasActiveSubscription: Bool { subscriptionManager.isPremium }

    private var showMainApp: Bool {
        !showSplash && hasSeenOnboarding && isSignedIn && hasActiveSubscription
    }

    var body: some View {
        ZStack {
            MainTabView()
                .opacity(showMainApp ? 1 : 0)
                .allowsHitTesting(showMainApp)

            if !showSplash && !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }

            if !showSplash && hasSeenOnboarding && !isSignedIn {
                SignInView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        isSignedIn = true
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }

            if !showSplash && hasSeenOnboarding && isSignedIn && !hasActiveSubscription {
                PaywallView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(3)
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(4)
            }
        }
        .animation(.easeOut(duration: 0.28), value: showSplash)
        .animation(.easeOut(duration: 0.28), value: hasSeenOnboarding)
        .animation(.easeOut(duration: 0.28), value: isSignedIn)
        .animation(.easeOut(duration: 0.28), value: hasActiveSubscription)
    }
}
