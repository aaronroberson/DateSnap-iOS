import SwiftUI
import SwiftData

enum SplashTiming {
    static let firstPageSeconds: Double = 3.0
    static let maximumSeconds: Double = 8.0
}

enum SplashCopy {
    static let slogan = "Scanned. Reviewed. Pencil'd."
    static let welcomeLead = "Scanned. Reviewed. "
    static let welcomeAccent = "Pencil'd."
    static let welcomeBody = "Select screenshots, physical flyers, invites, tickets, or PDFs. Review the detected details before saving to your calendar."
    static let scanCTA = "Scan screenshot or flyer"
    static let importCTA = "Import PDF or file"
    static let privacyBody = "Pencil'd detects screenshots containing dates, venues, or meeting links directly on your phone."
    static let privacyLine = "Your scans are processed on this device."
}

/// Two-page launch carousel: (1) brand splash, (2) welcome with the two
/// primary capture actions. Auto-advances, can be swiped or skipped, and
/// always finishes by itself.
struct PencilSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                HStack(spacing: 8) {
                    Spacer()
                    if page == 0 {
                        Button("Continue") {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { page = 1 }
                        }
                        .font(PDFont.jakarta(15, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.pdPrimary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .accessibilityHint("Opens the capture and import options")
                        .accessibilityIdentifier("splash.continue")
                    }
                    Button("Skip") { finish(then: nil) }
                        .font(PDFont.jakarta(15, .semibold, relativeTo: .subheadline))
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
        .accessibilityHidden(true)
    }

    /// Page 1 → page 2 after a short beat, then hand off to home.
    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(SplashTiming.firstPageSeconds))
        guard !Task.isCancelled, !finished else { return }
        if page == 0 {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) { page = 1 }
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
                    + Text(SplashCopy.welcomeAccent).foregroundStyle(LinearGradient.pdHeadline))
                    .font(PDFont.jakarta(30, .bold, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text(SplashCopy.welcomeBody)
                    .font(PDFont.jakarta(16, .regular, relativeTo: .body))
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
                        .font(PDFont.jakarta(16, .regular, relativeTo: .body))
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
                        .font(PDFont.jakarta(15, .medium, relativeTo: .subheadline))
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
                            .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                            .tracking(1.2)
                        Spacer()
                        Text("On-device OCR")
                            .font(PDFont.jakarta(12, .regular, relativeTo: .footnote))
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.pdOnSurfaceVariant)

                    HStack(spacing: 8) {
                        ForEach(inputs, id: \.title) { input in
                            VStack(spacing: 6) {
                                Image(systemName: input.icon)
                                    .font(PDFont.jakarta(17, .regular, relativeTo: .body))
                                    .foregroundStyle(Color.pdPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainer))
                                Text(input.title)
                                    .font(PDFont.jakarta(11, .semibold, relativeTo: .caption2))
                                    .foregroundStyle(Color.pdOnSurface)
                                Text(input.detail)
                                    .font(PDFont.jakarta(10, .regular, relativeTo: .caption2))
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
                    .font(PDFont.jakarta(11, .semibold, relativeTo: .caption2))
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
                    .font(PDFont.jakarta(18, .semibold, relativeTo: .title3))
                    .foregroundStyle(Color.pdOnSurface)
                Spacer(minLength: 8)
                Label("Private on-device", systemImage: "checkmark.shield")
                    .font(PDFont.jakarta(10, .bold, relativeTo: .caption2))
                    .tracking(0.6)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.pdSurfaceContainerHigh))
            }
            Text(SplashCopy.privacyBody)
                .font(PDFont.jakarta(12, .regular, relativeTo: .footnote))
                .foregroundStyle(Color.pdOnSurfaceVariant)

            if let latest = candidates.first(where: { $0.savedEvent == nil || $0.savedEvent?.status == .draft }) {
                Button(action: onReview) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.open")
                            .font(PDFont.jakarta(18, .regular, relativeTo: .title3))
                            .foregroundStyle(Color.pdLavender)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainer))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("“\(latest.title)”")
                                    .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                                    .foregroundStyle(Color.pdOnSurface)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text("Found \(latest.createdAt.formatted(.relative(presentation: .named)))")
                                    .font(PDFont.jakarta(10, .bold, relativeTo: .caption2))
                                    .foregroundStyle(Color.pdPrimary)
                                    .lineLimit(1)
                            }
                            Text(candidateDetail(latest))
                                .font(PDFont.jakarta(12, .regular, relativeTo: .footnote))
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(PDFont.jakarta(13, .semibold, relativeTo: .footnote))
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
        return "\(when) • \(place)"
    }
}
