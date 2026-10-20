import SwiftUI
import AuthenticationServices

enum SplashTiming {
    static let displaySeconds: Double = 5.0
}

enum SplashCopy {
    static let slogan = "Scanned. Reviewed. Pencil’d."
}

/// Launch splash: the brand page for a short beat, then Home. Until the person signs in with Apple
/// or chooses to continue without an account, it also offers optional sign-in and waits for that
/// choice instead of closing itself. Sign-in is never required (`AppleAccount`).
/// (The former second page is now the Add events sheet, `CaptureSourceSheet`.)
struct PencilSplashView: View {
    let onFinish: () -> Void

    @AppStorage(AppleAccount.userIDKey) private var appleUserID = ""
    @AppStorage(AppleAccount.splashChoiceKey) private var signInChoiceMade = false
    @State private var finished = false
    @State private var signInError: String?

    private var offersSignIn: Bool {
        AppleAccount.isSignInAvailable && appleUserID.isEmpty && !signInChoiceMade
    }

    var body: some View {
        ZStack {
            Color.pdSurface.ignoresSafeArea()
            SplashBrandPage()
            VStack {
                if !offersSignIn {
                    HStack {
                        Spacer()
                        Button("Skip") { finish() }
                            .font(PDFont.jakarta(15, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Skip intro")
                    }
                }
                Spacer()
                if offersSignIn { signInOptions }
            }
        }
        .task {
            // With sign-in on offer, wait for the person's choice instead of closing on a timer.
            guard !offersSignIn else { return }
            try? await Task.sleep(for: .seconds(SplashTiming.displaySeconds))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private var signInOptions: some View {
        VStack(spacing: PDSpacing.sm) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                signInError = AppleAccount.handle(result)
                if AppleAccount.isSignedIn() { choose() }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)

            Button("Continue without an account") { choose() }
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdOnSurface)
                .frame(maxWidth: .infinity, minHeight: 44)

            Text(signInError ?? "Optional. Pencil’d works without an account; signing in shows your Apple ID name and email in Profile.")
                .font(PDFont.bodySM)
                .foregroundStyle(signInError == nil ? Color.pdOnSurfaceVariant : Color.pdError)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 380)
        .padding(.horizontal, PDSpacing.margin)
        .padding(.bottom, PDSpacing.xl)
    }

    private func choose() {
        signInChoiceMade = true
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

// MARK: - Brand page

private struct SplashBrandPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.pdOrange.opacity(0.28), Color.pdCoral.opacity(0.10), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 360
            )
            .scaleEffect(glow ? 1.08 : 0.94)
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("PencildBrand")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 184)
                    .shadow(color: Color.pdOrange.opacity(0.35), radius: 36, y: 10)
                    .accessibilityLabel("Pencil’d")

                Text("Pencil’d")
                    .font(PDFont.jakarta(42, .heavy, relativeTo: .largeTitle))
                    .tracking(-1)
                    .foregroundStyle(LinearGradient.pdHeadline)

                Text(SplashCopy.slogan.uppercased())
                    .font(PDFont.jakarta(13, .medium, relativeTo: .footnote))
                    .tracking(2)
                    .foregroundStyle(Color.pdOnSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
