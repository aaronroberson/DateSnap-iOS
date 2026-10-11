import SwiftUI
import SwiftData

/// Timing for the launch carousel. The splash always hands off to the home
/// screen on its own; it never stays up longer than `maximumSeconds`.
enum SplashTiming {
    static let firstPageSeconds: Double = 3.0
    static let maximumSeconds: Double = 8.0
}

enum SplashCopy {
    static let slogan = "Scanned. Reviewed. Pencil'd."
    static let welcomeLead = "Scanned. Reviewed. "
    static let welcomeAccent = "Pencil'd."
    static let welcomeBody = "Select screenshots, physical flyers, invites, tickets, or PDFs. Your calendar handles the rest automatically."
    static let scanCTA = "Scan screenshot or flyer"
    static let importCTA = "Import PDF or file"
    static let privacyBody = "Pencil'd detects screenshots containing dates, venues, or meeting links directly on your phone."
    static let privacyLine = "None of your data, photos or calendar entries leave your iPhone."
}

/// Two-page launch carousel: (1) brand splash, (2) welcome with the two
/// primary capture actions. Auto-advances, can be swiped or skipped, and
/// always finishes by itself.
struct PencilSplashView: View {
    let onFinish: () -> Void
    let onScan: () -> Void
    let onImport: () -> Void
    let onReview: () -> Void

    @State private var page = 0
    @State private var finished = false

    var body: some View {
        ZStack {
            Color.pdSurface.ignoresSafeArea()

            TabView(selection: $page) {
                SplashBrandPage()
                    .tag(0)
                SplashWelcomePage(
                    onScan: { finish(then: onScan) },
                    onImport: { finish(then: onImport) },
                    onReview: { finish(then: onReview) }
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { finish(then: nil) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Skip intro")
                }
                Spacer()
                pageDots
                    .padding(.bottom, 14)
            }
        }
        .task { await runTimeline() }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.pdPrimary : Color.pdOnSurfaceVariant.opacity(0.3))
                    .frame(width: index == page ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: page)
        .accessibilityHidden(true)
    }

    /// Page 1 → page 2 after a short beat, then hand off to home.
    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(SplashTiming.firstPageSeconds))
        guard !Task.isCancelled, !finished else { return }
        if page == 0 {
            withAnimation(.easeInOut(duration: 0.5)) { page = 1 }
        }
        try? await Task.sleep(for: .seconds(SplashTiming.maximumSeconds - SplashTiming.firstPageSeconds))
        guard !Task.isCancelled else { return }
        finish(then: nil)
    }

    private func finish(then action: (() -> Void)?) {
        guard !finished else { return }
        finished = true
        onFinish()
        action?()
    }
}

// MARK: - Page 1: Brand splash

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
                    .accessibilityLabel("Pencil'd app icon")

                Text("Pencil'd")
                    .font(.system(size: 42, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(LinearGradient.pdSignature)

                Text(SplashCopy.slogan.uppercased())
                    .font(.system(size: 13, weight: .medium))
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

// MARK: - Page 2: Welcome

private struct SplashWelcomePage: View {
    let onScan: () -> Void
    let onImport: () -> Void
    let onReview: () -> Void

    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]

    private let inputs: [(icon: String, title: String, detail: String)] = [
        ("iphone", "Screenshots", "iOS Photos"),
        ("camera", "Photos", "Posters & Notes"),
        ("doc.richtext", "PDFs", "Itineraries"),
        ("ticket", "Passes", "Boarding & Gigs")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Image("PencildMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 56)
                    .accessibilityHidden(true)

                (Text(SplashCopy.welcomeLead).foregroundStyle(Color.pdOnSurface)
                    + Text(SplashCopy.welcomeAccent).foregroundStyle(LinearGradient.pdSignature))
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text(SplashCopy.welcomeBody)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    Button(action: onScan) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                            Text(SplashCopy.scanCTA).fontWeight(.bold)
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(Color.pdSurface))
                        .padding(2)
                        .background(Capsule().fill(LinearGradient.pdSignature))
                    }

                    Button(action: onImport) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(Color.pdPrimary)
                            Text(SplashCopy.importCTA)
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(Color.pdSurfaceContainer))
                    }
                }
                .frame(maxWidth: 380)
                .padding(.top, 28)

                VStack(spacing: 10) {
                    HStack {
                        Text("ACCEPTED INPUTS")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.2)
                        Spacer()
                        Text("Instant OCR")
                            .font(.system(size: 12))
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.pdOnSurfaceVariant)

                    HStack(spacing: 8) {
                        ForEach(inputs, id: \.title) { input in
                            VStack(spacing: 6) {
                                Image(systemName: input.icon)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.pdPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainer))
                                Text(input.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.pdOnSurface)
                                Text(input.detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 2)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.pdSurfaceLow))
                        }
                    }
                }
                .frame(maxWidth: 380)
                .padding(.top, 28)

                libraryCard
                    .frame(maxWidth: 380)
                    .padding(.top, 24)

                Label(SplashCopy.privacyLine, systemImage: "lock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .padding(.top, 24)
                    .padding(.bottom, 64)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: From your library

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("From your library", systemImage: "photo.on.rectangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.pdOnSurface)
                Spacer(minLength: 8)
                Label("Private on-device", systemImage: "checkmark.shield")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.pdSurfaceContainerHigh))
            }
            Text(SplashCopy.privacyBody)
                .font(.system(size: 12))
                .foregroundStyle(Color.pdOnSurfaceVariant)

            if let latest = candidates.first {
                Button(action: onReview) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.pdLavender)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainer))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\u{201C}\(latest.title)\u{201D}")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.pdOnSurface)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text("Found \(latest.createdAt.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.pdPrimary)
                                    .lineLimit(1)
                            }
                            Text(candidateDetail(latest))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceLow))
                }
                .accessibilityHint("Opens the review queue")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pdSurfaceContainer))
    }

    private func candidateDetail(_ candidate: EventCandidate) -> String {
        let when = candidate.startDate.formatted(date: .abbreviated, time: candidate.isAllDay ? .omitted : .shortened)
        guard let place = candidate.venueName ?? candidate.location, !place.isEmpty else { return when }
        return "\(when) \u{2022} \(place)"
    }
}
