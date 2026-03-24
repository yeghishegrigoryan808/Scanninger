//
//  OnboardingView.swift
//  Scanninger
//
//  Three-page onboarding shown after splash, before sign-in.
//

import SwiftUI

private struct OnboardingPageModel {
    let title: String
    let subtitle: String
    let symbolName: String
}

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPageModel] = [
        OnboardingPageModel(
            title: "Create invoices in minutes",
            subtitle: "Professional invoices with a fast and simple workflow",
            symbolName: "doc.text.fill"
        ),
        OnboardingPageModel(
            title: "Manage your business easily",
            subtitle: "Keep clients, businesses, and invoice details organized",
            symbolName: "building.2.fill"
        ),
        OnboardingPageModel(
            title: "Export polished PDFs",
            subtitle: "Generate clean, professional invoice PDFs ready to share",
            symbolName: "doc.richtext.fill"
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 22)
                    .padding(.top, 12)
                }

                TabView(selection: $currentPage) {
                    ForEach(0 ..< pages.count, id: \.self) { index in
                        pageContent(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: 0.25), value: currentPage)

                VStack(spacing: 14) {
                    Button(action: advance) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                }
                .padding(.bottom, 28)
            }
        }
    }

    private func pageContent(_ page: OnboardingPageModel) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            Image(systemName: page.symbolName)
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            onComplete()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
