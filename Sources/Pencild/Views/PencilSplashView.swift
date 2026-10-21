import SwiftUI

enum SplashTiming {
    static let displaySeconds: Double = 5.0
}

enum SplashCopy {
    static let slogan = "Scanned. Reviewed. Pencil’d."
}

/// Launch splash: brand intro screen following Stitch design specification.
/// Includes luminous spectrum backdrop, brand hero composition, feature pill badges,
/// interactive "Swipe right to start" slider track, and fast on-device sync assurance.
struct PencilSplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppleAccount.splashChoiceKey) private var signInChoiceMade = false
    @State private var finished = false

    var body: some View {
        ZStack {
            Color.pdSurface.ignoresSafeArea()

            SplashBackdrop(reduceMotion: reduceMotion)

            VStack(spacing: 0) {
                Spacer()

                SplashHeroHeader(reduceMotion: reduceMotion)
                    .offset(y: -100)

                Spacer()

                SplashFooter(
                    reduceMotion: reduceMotion,
                    onStart: finish
                )
                .padding(.horizontal, PDSpacing.margin)
                .padding(.bottom, PDSpacing.lg)
            }
        }
        .contentShape(Rectangle())
        .task {
            try? await Task.sleep(for: .seconds(SplashTiming.displaySeconds))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        signInChoiceMade = true
        onFinish()
    }
}

// MARK: - Luminous Backdrop

private struct SplashBackdrop: View {
    let reduceMotion: Bool
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Sunset Core Gradient Orbs
            Circle()
                .fill(Color.pdPrimaryContainer.opacity(0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(y: -180)

            Circle()
                .fill(Color.pdTertiaryContainer.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -120, y: -40)

            Circle()
                .fill(Color.pdSecondary.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 120, y: 160)

            // Dynamic diagonal light stream
            SplashLightArcs()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.pdOrange.opacity(0.65),
                            Color.pdCoral.opacity(0.55),
                            Color.pdLavender.opacity(0.40),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .blur(radius: 1)
                .opacity(glowPulse ? 0.9 : 0.6)

            // Star sparkles
            Group {
                SparkleDot(x: 110, y: 180, size: 3, color: .pdPrimary)
                SparkleDot(x: 310, y: 220, size: 4, color: .pdSecondary)
                SparkleDot(x: 80, y: 300, size: 3, color: .pdCoral)
                SparkleDot(x: 330, y: 370, size: 3.5, color: .pdOrange)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

private struct SparkleDot: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.85))
            .frame(width: size, height: size)
            .position(x: x, y: y)
    }
}

private struct SplashLightArcs: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Swooping light arc 1
        path.move(to: CGPoint(x: -20, y: height * 0.18))
        path.addCurve(
            to: CGPoint(x: width + 20, y: height * 0.42),
            control1: CGPoint(x: width * 0.45, y: height * 0.12),
            control2: CGPoint(x: width * 0.75, y: height * 0.38)
        )

        // Swooping light arc 2 (crossing)
        path.move(to: CGPoint(x: width + 20, y: height * 0.20))
        path.addCurve(
            to: CGPoint(x: -20, y: height * 0.48),
            control1: CGPoint(x: width * 0.55, y: height * 0.16),
            control2: CGPoint(x: width * 0.25, y: height * 0.42)
        )
        return path
    }
}

// MARK: - Hero Header

private struct SplashHeroHeader: View {
    let reduceMotion: Bool
    @State private var logoGlow = false

    var body: some View {
        VStack(spacing: 34) {
            Image("PencildBrand")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 270, maxHeight: 180)
                .shadow(color: Color.black.opacity(0.65), radius: 24, y: 12)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.pdOrange.opacity(0.35),
                                    Color.pdTertiaryContainer.opacity(0.25),
                                    Color.pdSecondary.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 250, height: 250)
                        .blur(radius: 40)
                        .scaleEffect(logoGlow ? 1.08 : 0.95)
                        .allowsHitTesting(false)
                )
                .accessibilityLabel("Pencil’d")

            // Slogan with luminous gradient fill
            Text(SplashCopy.slogan.uppercased())
                .font(PDFont.jakarta(16, .heavy, relativeTo: .subheadline))
                .tracking(3.2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pdOrange, Color.pdCoral, Color.pdLavender],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .shadow(color: Color.pdOrange.opacity(0.35), radius: 16)
                .padding(.horizontal, 16)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                logoGlow = true
            }
        }
    }
}

// MARK: - Footer (Feature Badges, Slider, Assurance)

private struct SplashFooter: View {
    let reduceMotion: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: PDSpacing.md) {
            featureBadges

            SplashSliderTrack(
                reduceMotion: reduceMotion,
                onComplete: onStart
            )

            assuranceTag
        }
        .frame(maxWidth: 380)
    }

    private var featureBadges: some View {
        HStack(spacing: 5) {
            featureBadge(icon: "doc.text.viewfinder", label: "Instant OCR", tint: .pdPrimary)
            featureBadge(icon: "sparkles", label: "Apple Intelligence", tint: .pdSecondary)
            featureBadge(icon: "lock.fill", label: "100% Private", tint: .pdTertiary)
        }
    }

    private func featureBadge(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)

            Text(label)
                .font(PDFont.jakarta(9.5, .semibold, relativeTo: .caption2))
                .foregroundStyle(Color.pdOnSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color.pdSurfaceLow.opacity(0.85))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var assuranceTag: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.pdPrimary)

            Text("Fast, zero-latency on-device calendar sync")
                .font(PDFont.jakarta(11, .medium, relativeTo: .caption2))
                .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
        }
        .padding(.top, 2)
    }
}

// MARK: - Interactive Slider Track

private struct SplashSliderTrack: View {
    let reduceMotion: Bool
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false
    @State private var arrowNudge = false

    private let trackHeight: CGFloat = 72
    private let knobSize: CGFloat = 56
    private let horizontalPadding: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let maxTravel = max(0, availableWidth - knobSize - (horizontalPadding * 2))
            let currentX = isCompleted ? maxTravel : min(max(0, dragOffset), maxTravel)
            let progress = maxTravel > 0 ? (currentX / maxTravel) : 0

            ZStack(alignment: .leading) {
                // Background Track Capsule
                Capsule()
                    .fill(Color.pdSurfaceContainerHigh.opacity(0.70))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                // Fill gradient that expands with drag
                if currentX > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.pdOrange.opacity(0.45),
                                    Color.pdCoral.opacity(0.35),
                                    Color.pdLavender.opacity(0.25)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: min(availableWidth, currentX + knobSize + (horizontalPadding * 2)))
                        .clipShape(Capsule())
                }

                // Center Prompt Text & Arrow
                HStack(spacing: 8) {
                    Text("Swipe right to start")
                        .font(PDFont.jakarta(14, .semibold, relativeTo: .subheadline))
                        .tracking(0.6)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .offset(x: arrowNudge ? 4 : 0)
                }
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, knobSize / 2)
                .opacity(max(0, 1.0 - Double(progress) * 1.6))

                // Interactive Glowing Knob
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pdOrange, Color.pdTertiaryContainer, Color.pdLavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: Color.pdOrange.opacity(0.60), radius: 6)

                    Image(systemName: isCompleted ? "checkmark" : "chevron.right")
                        .font(.system(size: isCompleted ? 20 : 22, weight: .bold))
                        .foregroundStyle(Color.pdOnPrimaryFixed)
                }
                .offset(x: horizontalPadding + currentX)
            }
            .clipShape(Capsule())
            .background(
                Capsule()
                    .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isCompleted else { return }
                        dragOffset = max(0, value.translation.width)
                    }
                    .onEnded { value in
                        guard !isCompleted else { return }
                        if value.translation.width >= maxTravel * 0.70 || value.predictedEndTranslation.width >= maxTravel {
                            triggerCompletion(maxTravel: maxTravel)
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .frame(height: trackHeight)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                arrowNudge = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Swipe right to start")
        .accessibilityAction {
            onComplete()
        }
    }

    private func triggerCompletion(maxTravel: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = maxTravel
            isCompleted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onComplete()
        }
    }
}
