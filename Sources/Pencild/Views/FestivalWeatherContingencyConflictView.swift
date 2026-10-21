import SwiftUI

/// Multi-Day Festival & Weather Contingency Collision Resolution Modal.
/// Stitch Screen ID: 51bee88e4ad449dcaae98db66cbcf60f
/// Manages live outdoor festival contingency clauses (rain dates, lightning delays)
/// where headline sets push into midnight, clashing with transit and reservations.
struct FestivalWeatherContingencyConflictView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    enum ContingencyPlan: String, CaseIterable, Identifiable {
        case festivalFocus
        case transitPriority
        case manualSplit

        var id: String { rawValue }

        var title: String {
            switch self {
            case .festivalFocus: return "Festival Focus (Recommended)"
            case .transitPriority: return "Transit Priority: Keep Train"
            case .manualSplit: return "Custom Schedule Split"
            }
        }

        var badge: String {
            switch self {
            case .festivalFocus: return "Full Music"
            case .transitPriority: return "Catch Train"
            case .manualSplit: return "Custom"
            }
        }

        var subtitle: String {
            switch self {
            case .festivalFocus: return "Auto-Modify Transit & Release Dinner"
            case .transitPriority: return "Attend Early Acts Only • Depart 11:00 PM"
            case .manualSplit: return "Manually pick slots, rideshare, and late checkout"
            }
        }
    }

    @State private var selectedPlan: ContingencyPlan = .festivalFocus

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    topStatusPills

                    PDScreenIntro(
                        eyebrow: "Weather Contingency",
                        title: "Doppler Radar & Contingency Matrix",
                        subtitle: "Live event contingency clause pushes Gale Stage headline set by +4h to Midnight, colliding with return Amtrak rail transit and pre-booked dinner reservations."
                    )

                    radarSnippetCard
                    timelineDiffCard
                    activeCollisionsSection
                    contingencyPackagesSection
                    incidentClauseCard
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
            PDStatusBadge(text: "Live Doppler 10m ago", icon: "cloud.bolt.rain.fill", tone: .warning)
            PDStatusBadge(text: "2 Direct Conflicts", icon: "exclamationmark.triangle.fill", tone: .error)
            Spacer()
        }
    }

    private var radarSnippetCard: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(Color.pdSurfaceLowest)
                    .frame(height: 120)

                // Simulated Doppler Radar Cell
                ZStack {
                    Circle()
                        .fill(Color.pdError.opacity(0.18))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color.pdPrimaryContainer.opacity(0.3))
                        .frame(width: 48, height: 48)
                    Circle()
                        .fill(Color.pdPrimary)
                        .frame(width: 14, height: 14)
                }

                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.pdTertiary)
                            Text("Gale Stage: Lightning Cell active")
                                .font(PDFont.labelSM)
                                .bold()
                                .foregroundStyle(Color.pdOnSurface)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.pdSurface.opacity(0.85)))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                            Text("Schedule_Update_Live.png")
                                .font(PDFont.labelSM)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.pdSurface.opacity(0.85)))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
                .padding(8)
            }
        }
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var timelineDiffCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIMELINE DIFF: GALE MAIN STAGE")
                .font(PDFont.labelSM)
                .bold()
                .foregroundStyle(Color.pdOnSurfaceVariant)

            HStack(spacing: 8) {
                // Original Plan
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ORIGINAL")
                            .font(PDFont.labelSM)
                            .bold()
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                        Spacer()
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Text("Neon Lights Headline")
                        .font(PDFont.bodyMD)
                        .strikethrough()
                        .foregroundStyle(Color.pdOnSurface)
                    Text("08:30 PM – 10:30 PM")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Text("Stage Clear by 10:45 PM")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.7))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLow))

                // Rescheduled Contingency
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.pdPrimary).frame(width: 5, height: 5)
                            Text("RAIN SCHEDULE")
                                .font(PDFont.labelSM)
                                .bold()
                                .foregroundStyle(Color.pdPrimary)
                        }
                        Spacer()
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.pdPrimary)
                    }
                    Text("Neon Lights (Midnight)")
                        .font(PDFont.bodyMD)
                        .bold()
                        .foregroundStyle(Color.pdOnSurface)
                    Text("11:30 PM – 01:30 AM")
                        .font(PDFont.labelMD)
                        .bold()
                        .foregroundStyle(Color.pdPrimary)
                    Text("+4h Delay Contingency")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceContainerHigh))
            }
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var activeCollisionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Direct Horizon Conflicts (2 Detected)", systemImage: "bolt.trianglebadge.exclamationmark")
                .font(PDFont.labelMD)
                .bold()
                .foregroundStyle(Color.pdError)

            amtrakCollisionCard
            dinnerCollisionCard
        }
    }

    private var amtrakCollisionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tram.fill")
                        .foregroundStyle(Color.pdError)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Amtrak Empire Service #284")
                            .font(PDFont.bodyMD)
                            .bold()
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Rhinecliff Station → Moynihan Hall")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
                Spacer()
                Text("Critical Clash")
                    .font(PDFont.labelSM)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.pdError))
                    .foregroundStyle(Color.pdOnError)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("Departs Sat 11:45 PM")
                        .font(PDFont.labelSM)
                }
                Spacer()
                Text("Overlap: 1h 45m with Headline")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdError)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest))
        }
        .padding(12)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var dinnerCollisionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Color.pdPrimary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pre-Booked Dinner: Le Pavillon")
                            .font(PDFont.bodyMD)
                            .bold()
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Party of 2 • 45m drive from Festival")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
                Spacer()
                Text("Overlaps Shift")
                    .font(PDFont.labelSM)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.pdPrimaryContainer.opacity(0.2)))
                    .foregroundStyle(Color.pdPrimary)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("Reserved Sat 09:30 PM")
                        .font(PDFont.labelSM)
                }
                Spacer()
                Text("Collides with Rescheduled Openers")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest))
        }
        .padding(12)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var contingencyPackagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CONTINGENCY RESOLUTION OPTIONS")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdOnSurface)
                Spacer()
                Text("1-Tap Sync")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdPrimary)
            }

            ForEach(ContingencyPlan.allCases) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: ContingencyPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = plan }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(PDFont.labelLG)
                            .bold()
                            .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurface)
                        Text(plan.subtitle)
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Spacer()
                    Text(plan.badge)
                        .font(PDFont.labelSM)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? Color.pdPrimary.opacity(0.2) : Color.pdSurfaceHighest))
                        .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                }

                if plan == .festivalFocus {
                    VStack(alignment: .leading, spacing: 4) {
                        resolutionBenefitRow(icon: "arrow.triangle.swap", text: "Rebooks Amtrak to Sun 08:15 AM Express (+0 fee waiver)")
                        resolutionBenefitRow(icon: "xmark.circle", text: "Cancels Le Pavillon via OpenTable API (No charge)")
                        resolutionBenefitRow(icon: "checkmark.circle.fill", text: "Locks in 11:30 PM Midnight Headline Set with 35m buffer")
                    }
                    .padding(.top, 2)
                }
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

    private func resolutionBenefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.pdSecondary)
                .padding(.top, 2)
            Text(text)
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .multilineTextAlignment(.leading)
        }
    }

    private var incidentClauseCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Parsed Incident Clause", systemImage: "doc.text.magnifyingglass")
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdSecondary)

            Text("“Festival Contingency Addendum B: If lightning strikes within 8 miles of Gale Stage, all stage operations freeze. Saturday headline sets roll over to Midnight slot (11:30 PM - 01:30 AM). Local transit shuttles extend until 02:45 AM.”")
                .font(PDFont.bodySM)
                .italic()
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest))
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var primaryActionStack: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    appState.showToast("Applied Festival Focus: Train rebooked & Headline locked")
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("Apply Festival Focus & Rebook")
                }
                .font(PDFont.labelLG)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PDGradientButtonStyle())

            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.day.timeline.left")
                    Text("View Day 2 Full Timeline Matrix")
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
