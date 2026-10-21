import SwiftUI

/// Transmeridian Flight & Timezone Shear Conflict Resolution Modal.
/// Stitch Screen ID: 20cddd471317418eb67d5e72ffafce87
/// Resolves calendar day-break and UTC discrepancy paradoxes (e.g., SFO -> HND)
/// that eclipse critical business events during in-flight zero-connectivity corridors.
struct TransmeridianConflictView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    enum ResolutionPlan: String, CaseIterable, Identifiable {
        case planA
        case planB
        case planC

        var id: String { rawValue }

        var title: String {
            switch self {
            case .planA: return "Pre-Departure Breakfast Sync"
            case .planB: return "Elena Rostova Proxy Chair"
            case .planC: return "Tentative Starlink Audio Slot"
            }
        }

        var tag: String {
            switch self {
            case .planA: return "Recommended • Frees Full Transit Window"
            case .planB: return "Asynchronous Delegation"
            case .planC: return "Mid-Flight Window"
            }
        }

        var description: String {
            switch self {
            case .planA:
                return "Shift Review to Thu, 08:00 AM – 09:30 AM PST at SFO Polaris Lounge prior to boarding."
            case .planB:
                return "Delegate live hosting rights to VP Elena. Full cloud transcript & action matrix synthesized to Apple Notes upon HND arrival."
            case .planC:
                return "Maintain board review placeholder. Drop video feed to VOIP audio-only with low-bandwidth satellite packet fallback."
            }
        }

        var perk: (icon: String, text: String, isWarning: Bool) {
            switch self {
            case .planA:
                return ("person.3.fill", "Notifies 6 board directors with automated UTC shift rationale", false)
            case .planB:
                return ("waveform.and.mic", "Pre-authorizes proxy voting packet", false)
            case .planC:
                return ("network.badge.shield.half.filled", "42% risk of satellite handover drop", true)
            }
        }

        var ctaLabel: String {
            switch self {
            case .planA: return "Approve & Reschedule to Morning"
            case .planB: return "Delegate Chair & Ingest Flight"
            case .planC: return "Lock Starlink Audio Tentative"
            }
        }
    }

    @State private var selectedPlan: ResolutionPlan = .planA
    @State private var isApplying = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    topPillHeader

                    PDScreenIntro(
                        eyebrow: "Timezone Shear Conflict",
                        title: "Arrival Paradox Detected",
                        subtitle: "Incoming flight SFO → HND crosses the International Date Line (+1 Day). Mid-flight window completely eclipses your Global Executive Board Review."
                    )

                    sourceIngestionPill
                    flightRibbonCard
                    collidingEventCard
                    resolutionPlansSection
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

    private var topPillHeader: some View {
        HStack(spacing: 8) {
            PDStatusBadge(text: "+17h UTC Discrepancy", icon: "clock.badge.exclamationmark", tone: .warning)
            PDStatusBadge(text: "Date Line Crossover", icon: "globe.americas.fill", tone: .info)
            Spacer()
        }
    }

    private var sourceIngestionPill: some View {
        HStack {
            Image(systemName: "paperclip")
                .foregroundStyle(Color.pdPrimary)
            Text("united_flight_UA875_confirmation.pdf")
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurface)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pdPrimary)
                Text("99.6% OCR")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdOnSurface)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.pdSurfaceHighest))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceLow))
    }

    private var flightRibbonCard: some View {
        VStack(spacing: PDSpacing.sm) {
            // Dual Departure & Arrival Anchor
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEPARTURE • SFO")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Text("10:45 AM")
                        .font(PDFont.headlineMD)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Thu, Nov 12")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdPrimary)
                    HStack {
                        Text("Pacific (PST)")
                        Spacer()
                        Text("UTC-8").bold().foregroundStyle(Color.pdSecondary)
                    }
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLow))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ARRIVAL • HND")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                        Spacer()
                        Text("+1 Day")
                            .font(PDFont.labelSM)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.pdTertiaryContainer.opacity(0.35)))
                            .foregroundStyle(Color.pdTertiary)
                    }
                    Text("02:15 PM")
                        .font(PDFont.headlineMD)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Fri, Nov 13")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdPrimary)
                    HStack {
                        Text("Tokyo (JST)")
                        Spacer()
                        Text("UTC+9").bold().foregroundStyle(Color.pdSecondary)
                    }
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLow))
            }

            // Visual Arc Schematic
            VStack(spacing: 8) {
                HStack {
                    Label("San Francisco", systemImage: "airplane.departure")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdPrimary)
                    Spacer()
                    Text("11h 30m in-flight horizon")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOnSurface)
                        .bold()
                    Spacer()
                    Label("Tokyo", systemImage: "airplane.arrival")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdTertiary)
                }

                ZStack {
                    FlightArcShape()
                        .stroke(Color.pdOutlineVariant, lineWidth: 2)
                        .frame(height: 38)
                    // Zero connectivity dead-zone arc segment
                    FlightBlackoutArcShape()
                        .stroke(Color.pdError, style: StrokeStyle(lineWidth: 3, dash: [4, 4]))
                        .frame(height: 38)

                    // Plane symbol
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.pdPrimary)
                        .offset(y: -14)
                }

                HStack {
                    Text("Thu 10:45 AM PST").font(PDFont.labelSM).foregroundStyle(Color.pdPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.pdError).frame(width: 5, height: 5)
                        Text("Zero Connectivity Corridor").font(PDFont.labelSM).foregroundStyle(Color.pdError).bold()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.pdError.opacity(0.15)))
                    Spacer()
                    Text("Fri 02:15 PM JST").font(PDFont.labelSM).foregroundStyle(Color.pdTertiary)
                }

                Divider().overlay(Color.pdOutlineVariant.opacity(0.4))

                HStack {
                    VStack(spacing: 2) {
                        Text("Depart (Origin)").font(PDFont.labelSM).foregroundStyle(Color.pdOnSurfaceVariant)
                        Text("10:45 AM PST").font(PDFont.bodySM).bold().foregroundStyle(Color.pdOnSurface)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("Date Line Entry").font(PDFont.labelSM).foregroundStyle(Color.pdSecondary)
                        Text("Midnight UTC").font(PDFont.bodySM).bold().foregroundStyle(Color.pdSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("Landing (Remote)").font(PDFont.labelSM).foregroundStyle(Color.pdOnSurfaceVariant)
                        Text("Fri 2:15 PM").font(PDFont.bodySM).bold().foregroundStyle(Color.pdOnSurface)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceLowest))
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var collidingEventCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Severely Colliding Event", systemImage: "exclamationmark.triangle.fill")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdError)
                Spacer()
                Text("Home Calendar")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.pdSurfaceHighest))
            }

            Text("Global Executive Board Review (Q4 Strategy)")
                .font(PDFont.headlineSM)
                .foregroundStyle(Color.pdOnSurface)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(Color.pdPrimary)
                Text("Thu, Nov 12 • 06:00 PM – 08:00 PM PST")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(Color.pdPrimary)
                    .padding(.top, 2)
                Text("At 06:00 PM PST, Flight UA875 will be over the Central Pacific at FL380, traversing nautical dead-zones with 100% video loss risk.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest.opacity(0.8)))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdError.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: PDRadius.card).stroke(Color.pdError.opacity(0.3), lineWidth: 1))
        )
    }

    private var resolutionPlansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PDSectionHeader(title: "Conflict Resolution Plans", trailing: "Tap to swap")

            ForEach(ResolutionPlan.allCases) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: ResolutionPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = plan }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(plan.tag)
                            .font(PDFont.labelSM)
                            .bold()
                            .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                    }

                    Text(plan.title)
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)

                    Text(plan.description)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Image(systemName: plan.perk.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(plan.perk.isWarning ? Color.pdError : Color.pdSecondary)
                        Text(plan.perk.text)
                            .font(PDFont.labelSM)
                            .foregroundStyle(plan.perk.isWarning ? Color.pdError : Color.pdOnSurfaceVariant)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurfaceVariant.opacity(0.6))
                    .padding(.top, 4)
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
                isApplying = true
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    appState.showToast("Applied: \(selectedPlan.title)")
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                    Text(selectedPlan.ctaLabel)
                }
                .font(PDFont.labelLG)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PDGradientButtonStyle())

            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("Preview in Dual-Timezone Master Timeline")
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

// MARK: - Schematic Shapes

private struct FlightArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 4))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 4),
            control: CGPoint(x: rect.midX, y: rect.minY + 2)
        )
        return path
    }
}

private struct FlightBlackoutArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.maxY - 14))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.maxY - 14),
            control: CGPoint(x: rect.midX, y: rect.minY + 2)
        )
        return path
    }
}
