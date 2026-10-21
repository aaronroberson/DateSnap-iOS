import SwiftUI

/// Syllabus Addendum: Cascade Milestone Collision Resolution Modal.
/// Stitch Screen ID: 04f8163ba5644ff1849cdb97ca3f76b2
/// Manages cascading multi-milestone domino collapses triggered by academic syllabus shifts
/// (hard locks, transit deficits, and work-study shift conflicts).
struct SyllabusCascadeConflictView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    enum DeconflictionStrategy: String, CaseIterable, Identifiable {
        case smartAcademic
        case isolateOnly
        case revertSnapshot

        var id: String { rawValue }

        var title: String {
            switch self {
            case .smartAcademic: return "Smart Academic Deconfliction"
            case .isolateOnly: return "Isolate CS 4820 Only & Flag 5 Hazards"
            case .revertSnapshot: return "Revert Addendum to Prior Snapshot"
            }
        }

        var badge: String? {
            switch self {
            case .smartAcademic: return "Optimal"
            case .isolateOnly, .revertSnapshot: return nil
            }
        }

        var description: String {
            switch self {
            case .smartAcademic:
                return "Auto-dispatches Cornell Academic Conflict petition to Prof. Martinez (moves ECE 3140 lab to Thu 10:00 AM makeup block) and initiates auto-swap request on Workday Student for Friday store shift."
            case .isolateOnly:
                return "Accept new exam date without automated outreach. Downstream deadlines will remain marked with critical warning badges on calendar."
            case .revertSnapshot:
                return "Ignore PDF syllabus changes until departmental registrar confirms official final schedule."
            }
        }
    }

    @State private var selectedStrategy: DeconflictionStrategy = .smartAcademic
    @State private var showHiddenHazards = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    topStatusPills

                    PDScreenIntro(
                        eyebrow: "Milestone Collision Chain",
                        title: "Syllabus Addendum v3.2",
                        subtitle: "Prof. Vance posted an emergency syllabus addendum shifting the CS 4820 Final Exam +4 days. This generates 1 direct exam clash and 5 cascading domino buffer failures."
                    )

                    sourceIngestionCard
                    timelineDiffCard
                    dominoChainSection
                    strategyPickerSection
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
            PDStatusBadge(text: "Syllabus Addendum v3.2", icon: "doc.text.fill", tone: .info)
            PDStatusBadge(text: "6 Collisions", icon: "exclamationmark.triangle.fill", tone: .error)
            Spacer()
        }
    }

    private var sourceIngestionCard: some View {
        HStack {
            Image(systemName: "doc.viewfinder")
                .foregroundStyle(Color.pdPrimary)
            Text("CS4820_Addendum_Week14.pdf (p.2)")
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurface)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color.pdSecondary).frame(width: 5, height: 5)
                Text("99.2% OCR")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdSecondary)
                    .bold()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.pdSurfaceHighest))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceLow))
    }

    private var timelineDiffCard: some View {
        VStack(spacing: 10) {
            // Original Slot (Strikethrough)
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pdOutline)
                    Text("ORIGINAL SCHEDULE")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOutline)
                }
                Spacer()
                Text("Mon, Dec 8 • 09:00 AM – 11:30 AM")
                    .font(PDFont.bodySM)
                    .strikethrough()
                    .foregroundStyle(Color.pdOutline)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest))

            // Shift Indicator
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                Text("+4 Days Shifted")
                    .font(PDFont.labelSM)
                    .bold()
            }
            .foregroundStyle(Color.pdPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.pdPrimaryContainer.opacity(0.2)))

            // Rescheduled Slot
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rescheduled Exam Slot")
                        .font(PDFont.labelSM)
                        .bold()
                        .foregroundStyle(Color.pdPrimary)
                    Text("Fri, Dec 12")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("01:30 PM – 04:00 PM")
                        .font(PDFont.labelLG)
                        .bold()
                        .foregroundStyle(Color.pdPrimary)
                    Text("Barton Hall East")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceContainerHigh))

            HStack {
                Label("Finals Week Forward Compression", systemImage: "arrow.down.right.and.arrow.up.left")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdTertiary)
                Spacer()
                Text("Dec 12 = 4 Milestones")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdSecondary)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var dominoChainSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DOMINO COLLISION CHAIN (DEC 12)")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdOnSurface)
                Spacer()
                Text("1 Severe • 5 Moderate")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdError)
            }

            domino1Card
            domino2Card
            domino3Card
            hiddenHazardsSection
        }
    }

    private var domino1Card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.pdError)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ECE 3140 Practical")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text("HARD LOCK")
                            .font(PDFont.labelSM)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.pdError))
                            .foregroundStyle(Color.pdOnError)
                    }
                    Text("Embedded Systems Lab Exam • Phillips 318")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer()
                Text("02:00 – 04:30 PM")
                    .font(PDFont.labelMD)
                    .bold()
                    .foregroundStyle(Color.pdError)
            }

            HStack {
                Label("2h 00m Direct Overlap with CS 4820", systemImage: "arrow.left.arrow.right")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdError)
                Spacer()
                Text("Prof. Martinez Slot")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest.opacity(0.8)))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdError.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: PDRadius.card).stroke(Color.pdError.opacity(0.3), lineWidth: 1))
        )
    }

    private var domino2Card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(Color.pdPrimary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cornell Store Shift (Work-Study)")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Central Register • Student Emp ID #8812")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer()
                Text("05:00 – 08:30 PM")
                    .font(PDFont.labelMD)
                    .foregroundStyle(Color.pdOnSurface)
            }

            HStack {
                Label("Zero Recovery Buffer (Transit Deficit)", systemImage: "timer.square")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdPrimary)
                Spacer()
                Text("Shift Swap Eligible")
                    .font(PDFont.labelSM)
                    .bold()
                    .foregroundStyle(Color.pdSecondary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLow))
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var domino3Card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: "video.badge.waveform")
                    .foregroundStyle(Color.pdSecondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Systems Sprint Final Video")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Team of 4 • Git Submission & Loom")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer()
                Text("11:59 PM")
                    .font(PDFont.labelMD)
                    .foregroundStyle(Color.pdOnSurface)
            }

            HStack {
                Label("Study Time Deficit: -4.5 hrs estimated", systemImage: "hourglass.bottomhalf.filled")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdSecondary)
                Spacer()
                Text("Canvas LMS")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLow))
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var hiddenHazardsSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showHiddenHazards.toggle() }
            } label: {
                HStack {
                    Image(systemName: showHiddenHazards ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pdOutline)
                    Text("3 Additional Low-Buffer Conflicts (Dec 13 Review)")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceLow))
            }
            .buttonStyle(.plain)

            if showHiddenHazards {
                VStack(spacing: 6) {
                    hiddenHazardRow(title: "CS 4820 Office Hours", time: "Dec 13 • 10:00 AM", note: "Overlaps review session")
                    hiddenHazardRow(title: "ECE Group Dry-Run", time: "Dec 13 • 01:00 PM", note: "Tight 15m transfer")
                    hiddenHazardRow(title: "Dorm Packing Slot", time: "Dec 13 • 04:30 PM", note: "Displaced by exam study")
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func hiddenHazardRow(title: String, time: String, note: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurface)
                Text(note).font(PDFont.bodySM).foregroundStyle(Color.pdWarning)
            }
            Spacer()
            Text(time).font(PDFont.labelSM).foregroundStyle(Color.pdOnSurfaceVariant)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest))
    }

    private var strategyPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PDSectionHeader(title: "Auto-Deconfliction Strategies", trailing: "1 Recommended")

            ForEach(DeconflictionStrategy.allCases) { strategy in
                strategyCard(strategy)
            }
        }
    }

    private func strategyCard(_ strategy: DeconflictionStrategy) -> some View {
        let isSelected = selectedStrategy == strategy
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedStrategy = strategy }
        } label: {
            strategyCardContent(strategy, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func strategyCardContent(_ strategy: DeconflictionStrategy, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                strategyHeader(strategy, isSelected: isSelected)

                Text(strategy.description)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.leading)

                if strategy == .smartAcademic {
                    HStack(spacing: 6) {
                        perkBadge(icon: "envelope.fill", text: "Drafts ECE Petition")
                        perkBadge(icon: "arrow.triangle.2.circlepath", text: "Shift Swap Link")
                        perkBadge(icon: "clock.badge.checkmark", text: "+6.5h Study Buffer")
                    }
                    .padding(.top, 4)
                }
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

    private func strategyHeader(_ strategy: DeconflictionStrategy, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(strategy.title)
                .font(PDFont.labelLG)
                .bold()
                .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurface)
            if let badge = strategy.badge {
                Text(badge.uppercased())
                    .font(PDFont.labelSM)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.pdPrimaryContainer))
                    .foregroundStyle(Color.pdOnPrimary)
            }
        }
    }

    private func perkBadge(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(PDFont.labelSM)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.pdSurfaceLowest))
        .foregroundStyle(Color.pdSecondary)
    }

    private var primaryActionStack: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    appState.showToast("Applied deconfliction for 6 events")
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("Apply Deconfliction (6 Events)")
                }
                .font(PDFont.labelLG)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PDGradientButtonStyle())

            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    Text("Inspect Finals Week Matrix")
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
