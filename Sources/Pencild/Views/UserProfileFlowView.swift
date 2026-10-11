import SwiftUI
import SwiftData

// MARK: - Profile
/// Pencil'd has no account system: everything lives on this device and the plan comes from the
/// App Store. This screen therefore shows only real, locally derived values — the current plan,
/// activity counted from saved events, and on-device privacy facts. With no data it shows zeros.
struct UserProfileFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]

    private var tier: SubscriptionTier { appState.subscriptionTier }

    private var savedCount: Int { savedEvents.filter { $0.status == .saved }.count }
    private var archivedCount: Int { savedEvents.filter { $0.status == .archived }.count }
    private var thisWeekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return savedEvents.filter { $0.createdAt >= cutoff }.count
    }
    private var remindersCount: Int { savedEvents.reduce(0) { $0 + $1.externalReminderIds.count } }
    private var firstSavedDate: Date? { savedEvents.last?.createdAt }

    private var planTitle: String { tier == .starter ? "Pencil’d Free" : "Pencil’d \(tier.displayName)" }
    private var planSummary: String {
        switch tier {
        case .starter: return "Upgrade to Plus for auto-detect and unlimited screenshot scans."
        case .plus: return "Unlimited screenshot scans and multi-stage reminders."
        case .premium: return "PDF import, multi-page documents and batch scanning."
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header
                intro
                planCard
                activityGrid
                detailsCard
                privacyCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .dsScreenBackground()
    }

    // MARK: Sections
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.dsForeground)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.dsCard))
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Profile")
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsForeground)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(Color.dsPrimary).frame(width: 6, height: 6)
                Text("PROFILE")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsPrimary)
            }
            Text("Your Pencil’d")
                .font(DSTypography.displayTitle())
                .foregroundStyle(Color.dsForeground)
            Text("Your plan and capture activity, kept on this device.")
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: tier == .starter ? "sparkles" : "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dsPrimary)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsPrimary.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    Text(planSummary)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                Spacer()
            }
            Button {
                appState.activeModal = .premiumPaywall
            } label: {
                Text(tier == .starter ? "See plans" : "Manage subscription")
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsSurfaceElevated))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .dsGlassCard()
    }

    private var activityGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(title: "Saved events", value: savedCount, icon: "calendar.badge.plus", tint: .dsPrimary)
                metricTile(title: "Added this week", value: thisWeekCount, icon: "doc.viewfinder.fill", tint: .dsSecondary)
                metricTile(title: "Reminders set", value: remindersCount, icon: "bell.fill", tint: .dsAccent)
                metricTile(title: "Archived", value: archivedCount, icon: "archivebox.fill", tint: .dsMutedForeground)
            }
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "lock.shield", title: "Data storage", value: "On this device")
            Divider().overlay(Color.dsBorder)
            detailRow(
                icon: "calendar",
                title: "First event saved",
                value: firstSavedDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "None yet"
            )
        }
        .dsGlassCard()
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 22))
                .foregroundStyle(Color.dsSuccess)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.dsSuccess.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design")
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text("Pencil’d reads your screenshots and flyers on your device. There is no Pencil’d account to sign in to.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard()
    }

    // MARK: Helpers
    private func metricTile(title: String, value: Int, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(DSTypography.displayTitle())
                .foregroundStyle(Color.dsForeground)
            Text(title)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard()
        .accessibilityElement(children: .combine)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurfaceElevated)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.dsPrimary))
            Text(title)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
            Spacer()
            Text(value)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
    }
}
