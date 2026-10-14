import SwiftUI

enum SplashTiming {
    static let displaySeconds: Double = 5.0
}

enum SplashCopy {
    static let slogan = "Scanned. Reviewed. Pencil’d."
}

/// Launch splash: the brand page for a short beat, then Home. Tap Skip to leave early.
/// (The former second page is now the Add events sheet, `CaptureSourceSheet`.)
struct PencilSplashView: View {
    let onFinish: () -> Void

    @State private var finished = false

    var body: some View {
        ZStack {
            Color.pdSurface.ignoresSafeArea()
            SplashBrandPage()
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(PDFont.jakarta(15, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Skip intro")
                }
                Spacer()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(SplashTiming.displaySeconds))
            guard !Task.isCancelled else { return }
            finish()
        }
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
                Image("PencildMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.pdOrange.opacity(0.35), radius: 36, y: 10)
                    .accessibilityLabel("Pencil’d app icon")

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
