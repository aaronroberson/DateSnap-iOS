import SwiftUI

/// Ambient Audio Stream Deconfliction Modal.
/// Stitch Screen ID: 28789503b0f7464594251a79a5de5b11
/// Ingests ambient audio memos and voice notes with in-flight conversational self-corrections.
/// Provides scrubber waveform audio proof, transcript diff, and radar comparison between slots.
struct AmbientAudioConflictView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    enum ResolutionChoice: String, CaseIterable, Identifiable {
        case slot3PM
        case slot4PM
        case keepBoth

        var id: String { rawValue }

        var title: String {
            switch self {
            case .slot3PM: return "Pencil In Thu, Oct 29 @ 3:00 PM"
            case .slot4PM: return "Pencil In Thu, Oct 29 @ 4:00 PM"
            case .keepBoth: return "Keep Both as Soft Holds"
            }
        }

        var description: String {
            switch self {
            case .slot3PM:
                return "Matches verbal correction cleanly. Zero schedule friction."
            case .slot4PM:
                return "Notifies Dr. Miller clinic to push appointment to 5:15 PM."
            case .keepBoth:
                return "Prompt sender for written confirmation before booking."
            }
        }

        var isOptimal: Bool { self == .slot3PM }
    }

    @State private var selectedChoice: ResolutionChoice = .slot3PM
    @State private var isPlaying = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    topStatusPills

                    PDScreenIntro(
                        eyebrow: "Ambient Audio Stream",
                        title: "Acoustic NLP Deconfliction",
                        subtitle: "Spoken intent contained in-flight self-correction. Neural NLP parsed a switch from Tuesday morning to Thursday afternoon across two candidate slots."
                    )

                    audioScrubberCard
                    transcriptProofCard
                    calendarRadarSection
                    resolutionPickerSection
                    primaryActionStack
                }
                .padding(.horizontal, PDSpacing.md)
                .padding(.top, PDSpacing.sm)
                .padding(.bottom, PDSpacing.xl)
            }
            .pdScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdPrimary)
                }
            }
        }
    }

    // MARK: - Subviews

    private var topStatusPills: some View {
        HStack(spacing: 8) {
            PDStatusBadge(text: "voice_memo_clinic_update.m4a", icon: "waveform", tone: .info)
            PDStatusBadge(text: "94.8% Speech Conf.", icon: "sparkles", tone: .success)
            Spacer()
        }
    }

    private var audioScrubberCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    isPlaying.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.pdAction)
                            .frame(width: 44, height: 44)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.pdOnPrimaryFixed)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ambient Audio Memo (Siri Sync)")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Self-correction parsed at timestamp 0:22")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer()
            }

            // Waveform with correction markers
            ZStack(alignment: .center) {
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<28) { index in
                        waveformBar(index: index)
                    }
                }
                .frame(height: 52)

                // Playhead marker at 0:22
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.pdPrimaryContainer)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.pdPrimaryContainer, radius: 4)
                        Rectangle()
                            .fill(Color.pdPrimaryContainer)
                            .frame(width: 2, height: 44)
                    }
                    .position(x: geo.size.width * 0.54, y: geo.size.height / 2)
                }
                .frame(height: 52)
            }
            .padding(.vertical, 4)

            HStack {
                Text("0:00").font(PDFont.labelSM).foregroundStyle(Color.pdOnSurfaceVariant)
                Spacer()
                Text("0:22 (Correction)").font(PDFont.labelSM).bold().foregroundStyle(Color.pdPrimary)
                Spacer()
                Text("0:42").font(PDFont.labelSM).foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private func waveformBar(index: Int) -> some View {
        let height: CGFloat = {
            let pattern: [CGFloat] = [10, 16, 24, 18, 12, 14, 28, 36, 44, 48, 32, 22, 16, 12, 18, 38, 48, 46, 50, 36, 26, 16, 12, 14, 18, 22, 14, 8]
            return pattern[index % pattern.count]
        }()

        let isCorrectionSegment = (index >= 14 && index <= 20)
        let isSupersededSegment = (index >= 6 && index <= 10)

        let color: Color = {
            if isCorrectionSegment { return Color.pdPrimaryContainer }
            if isSupersededSegment { return Color.pdSecondary }
            return Color.pdOutlineVariant.opacity(0.6)
        }()

        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 4, height: height)
    }

    private var transcriptProofCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Acoustic NLP Transcript Proof", systemImage: "quote.opening")
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)

            // Segment 1: Superseded
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("[0:08 – 0:15]").font(PDFont.labelSM).foregroundStyle(Color.pdOutline)
                    Spacer()
                    Text("Superseded")
                        .font(PDFont.labelSM)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.pdError.opacity(0.18)))
                        .foregroundStyle(Color.pdError)
                }
                Text("“Let's meet at Blue Bottle Coffee on Tuesday the 27th at 10 AM…”")
                    .font(PDFont.bodyMD)
                    .strikethrough()
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest.opacity(0.6)))

            // Segment 2: Final Correction
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("[0:22 – 0:34]").font(PDFont.labelSM).foregroundStyle(Color.pdSecondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text("Final Correction • 94.8% Conf.")
                    }
                    .font(PDFont.labelSM)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.pdSecondaryContainer.opacity(0.4)))
                    .foregroundStyle(Color.pdSecondary)
                }
                Text("“…actually scratch that, I'm stuck in clinic. Let's do Thursday the 29th, maybe 3:00 PM or 4:00 PM instead.”")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurface)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSecondaryContainer.opacity(0.15)))
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var calendarRadarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CALENDAR RADAR")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdOnSurface)
                Spacer()
                Text("Thu, Oct 29")
                    .font(PDFont.labelMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            // Slot 1: Clear & Optimal
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("03:00 PM – 04:00 PM")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Thursday, Oct 29")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Spacer()
                    Label("Clear Slot", systemImage: "checkmark.circle.fill")
                        .font(PDFont.labelSM)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.pdPrimaryContainer.opacity(0.2)))
                        .foregroundStyle(Color.pdPrimary)
                }

                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(Color.pdSecondary)
                    Text("45m buffer preserved from “Team Sprint” at HQ")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest))
            }
            .padding(14)
            .pdGlassCard(cornerRadius: PDRadius.card)

            // Slot 2: Overlapping Dentist
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("04:00 PM – 05:00 PM")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Thursday, Oct 29")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Spacer()
                    Label("Conflict", systemImage: "exclamationmark.triangle.fill")
                        .font(PDFont.labelSM)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.pdError.opacity(0.2)))
                        .foregroundStyle(Color.pdError)
                }

                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(Color.pdError)
                    Text("Overlaps 30m with “Dentist at Dr. Miller” (4:30 PM)")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdError)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdError.opacity(0.12)))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceLow))
        }
    }

    private var resolutionPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RESOLUTION ACTION")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdOnSurface)
                Spacer()
                Text("Pencil’d Recommendation")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdPrimary)
            }

            ForEach(ResolutionChoice.allCases) { choice in
                choiceCard(choice)
            }
        }
    }

    private func choiceCard(_ choice: ResolutionChoice) -> some View {
        let isSelected = selectedChoice == choice
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedChoice = choice }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(choice.title)
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdOnSurface)
                        if choice.isOptimal {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.pdPrimary)
                        }
                    }

                    Text(choice.description)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurfaceVariant.opacity(0.6))
                    .padding(.top, 2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(isSelected ? Color.pdSurfaceContainerHigh : Color.pdSurfaceLow)
                    .overlay(
                        RoundedRectangle(cornerRadius: PDRadius.card)
                            .stroke(isSelected ? Color.pdPrimary.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryActionStack: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    appState.showToast("Confirmed: \(selectedChoice.title)")
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                    Text("Confirm 3:00 PM Catchup & Pencil In")
                }
                .font(PDFont.labelLG)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PDGradientButtonStyle())

            Button {
                isPlaying.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                    Text("Play Audio Snippet [0:20 – 0:35]")
                }
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurface)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceContainerHigh))
            }
        }
        .padding(.top, 6)
    }
}
