import SwiftUI
import UIKit
import StoreKit

// Manage Plan — active subscription, benefits, premium upsell and
// subscription controls. Pushed from the Settings Hub.
struct ManagePlanView: View {
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @StateObject private var purchases = PurchaseViewModel()
    @State private var showManageSubscriptions = false
    @State private var showOfferCode = false
    @State private var restoring = false
    @State private var entitlement: EntitlementSnapshot? = nil

    /// The active subscription as reported by StoreKit.
    struct EntitlementSnapshot {
        var productID: String
        var expirationDate: Date?
        var willAutoRenew: Bool?
        var isAnnual: Bool { productID.hasSuffix(".annual") }
    }

    private var tier: SubscriptionTier { appState.subscriptionTier }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Manage Plan", showBack: true)
                subscriptionCard
                benefits
                if tier != .premium { upsell }
                controls
                SettingsFooterNote(
                    lines: ["Subscriptions are handled securely through your Apple ID. Modify or cancel anytime in iPhone Settings at least 24 hours before renewal. DateSnap never receives, parses, or stores payment credentials."],
                    systemImage: "info.circle.fill"
                )
                footerLinks
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .offerCodeRedemption(isPresented: $showOfferCode) { _ in
            Task { await refreshEntitlement() }
        }
        .task {
            await purchases.attach(services.subscription)
            await refreshEntitlement()
        }
        .onChange(of: appState.subscriptionTier) { _, _ in
            Task { await refreshEntitlement() }
        }
        .alert("Subscription Issue", isPresented: Binding(
            get: { purchases.errorMessage != nil },
            set: { if !$0 { purchases.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.errorMessage ?? "")
        }
    }

    /// Reads the current subscription transaction and renewal state from StoreKit.
    private func refreshEntitlement() async {
        var latest: StoreKit.Transaction? = nil
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  transaction.productType == .autoRenewable else { continue }
            if latest == nil || (transaction.expirationDate ?? .distantPast) > (latest?.expirationDate ?? .distantPast) {
                latest = transaction
            }
        }
        guard let latest else {
            entitlement = nil
            return
        }
        var willAutoRenew: Bool? = nil
        if let statuses = try? await purchases.product(latest.productID.contains("premium") ? .premium : .plus,
                                                       annual: latest.productID.hasSuffix(".annual"))?.subscription?.status,
           let status = statuses.first(where: { status in
               if case .verified(let t) = status.transaction { return t.originalID == latest.originalID }
               return false
           }),
           case .verified(let renewal) = status.renewalInfo {
            willAutoRenew = renewal.willAutoRenew
        }
        entitlement = EntitlementSnapshot(productID: latest.productID, expirationDate: latest.expirationDate, willAutoRenew: willAutoRenew)
    }

    // MARK: - Subscription card

    private var planName: String {
        switch tier {
        case .starter: return "DateSnap Starter"
        case .plus, .premium:
            guard let entitlement else { return tier.displayName }
            return "\(tier.displayName) (\(entitlement.isAnnual ? "Annual" : "Monthly"))"
        }
    }

    private var planPrice: String {
        guard tier != .starter else { return "Free" }
        let plan: PurchaseViewModel.Plan = tier == .premium ? .premium : .plus
        let annual = entitlement?.isAnnual ?? true
        return purchases.displayPrice(plan, annual: annual)
            ?? (purchases.isLoadingProducts ? "Loading price…" : "Price unavailable")
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if tier == .starter {
                    ValueChip(text: "FREE PLAN", tint: .dsInfo, systemImage: "sparkle")
                } else {
                    ValueChip(text: "ACTIVE SUBSCRIPTION", tint: .dsSuccess, systemImage: "checkmark.seal.fill")
                    ValueChip(text: "Apple ID Linked", tint: .dsInfo, systemImage: "filemenu.and.selection")
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(planName)
                    .font(DSTypography.headlineCard())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(planPrice)
                        .font(DSTypography.displayTitle())
                        .foregroundStyle(Color.dsPrimary)
                    Text(tier == .starter ? "" : (entitlement?.isAnnual == false ? "/ month" : "/ year"))
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }

            if let entitlement, let expiration = entitlement.expirationDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsMutedForeground)
                    Text("\(entitlement.willAutoRenew == false ? "Expires" : "Renews") on \(expiration.formatted(date: .abbreviated, time: .omitted))")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                    if let willAutoRenew = entitlement.willAutoRenew {
                        Text("•")
                            .foregroundStyle(Color.dsMutedForeground)
                        HStack(spacing: 4) {
                            Image(systemName: willAutoRenew ? "arrow.triangle.2.circlepath" : "exclamationmark.circle")
                                .font(.system(size: 10, weight: .bold))
                            Text(willAutoRenew ? "Auto-renewal ON" : "Auto-renewal OFF")
                                .font(DSTypography.overlineConfidence())
                        }
                        .foregroundStyle(willAutoRenew ? Color.dsSuccess : Color.dsWarning)
                    }
                }
            } else if tier == .starter {
                Button {
                    appState.activeModal = .plusPaywall
                } label: {
                    HStack {
                        Text("See Plus & Premium Plans")
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(DSSecondaryButtonStyle(minHeight: 44))
            }

            HStack(spacing: 10) {
                planStat("doc.text.viewfinder", "Neural Scans", "Unlimited")
                planStat("bell.badge.fill", "Reminders", "3 per event")
                planStat("tray.full.fill", "Auto-Detect", tier == .starter ? "Plus" : "On")
            }
        }
        .padding(16)
        .dsGlassCard()
    }

    private func planStat(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.dsPrimary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.dsMutedForeground)
                Text(value)
                    .font(DSTypography.labelChip())
                    .foregroundStyle(Color.dsForeground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsMuted))
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "checkmark.seal.fill", title: "Your Current Benefits",
                                  tint: .dsSuccess, trailing: "Included")
            VStack(spacing: 12) {
                benefitRow("doc.text.viewfinder", "Unlimited Screenshot OCR",
                           "Instant localized on-device neural temporal extraction")
                benefitRow("bell.badge.fill", "3 Reminders Per Captured Event",
                           "Direct Apple Calendar, Reminders & ICS bidirectional sync")
                benefitRow("sparkles", "Smart Auto-Draft Generation",
                           "Intelligent temporal titles, venues, flight numbers & zoom URLs")
                benefitRow("lock.shield.fill", "Zero Cloud Telemetry",
                           "100% on-device sandboxed privacy; images never leave storage")
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private func benefitRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.dsPrimaryForeground)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.dsSuccess))
                .padding(.top, 2)
            SettingRow(icon: icon, iconTint: .dsSecondary, title: title, subtitle: subtitle) {
                EmptyView()
            }
        }
    }

    // MARK: - Upsell

    private var upsell: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsGoldGradient)
                Text("UPGRADE TO PREMIUM")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsWarning)
            }
            Text("Need multi-page PDF scanning & iOS Files import?")
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsForeground)
            Text("Multi-Page PDF schedule scanning · iOS Files & iCloud Drive integration · High-velocity batch flyer imports up to 10× at once.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)

            Button {
                appState.activeModal = .premiumPaywall
            } label: {
                HStack {
                    Text(tier == .starter ? "Explore Premium" : "Upgrade to Premium")
                    Image(systemName: "arrow.up.right")
                }
            }
            .buttonStyle(DSSecondaryButtonStyle(minHeight: 44))

            Button {
                appState.activeModal = .premiumPaywall
            } label: {
                HStack {
                    Text("Review Plan")
                        .font(DSTypography.labelChip())
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.dsPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .dsGlassCard(borderColor: Color.dsWarning.opacity(0.35))
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "slider.horizontal.3", title: "Subscription Controls", tint: .dsSecondary)
            VStack(spacing: 14) {
                Button {
                    showManageSubscriptions = true
                } label: {
                    SettingRow(icon: "person.crop.rectangle.stack", iconTint: .dsInfo,
                               title: "Manage Subscription",
                               subtitle: "Cancel, switch family sharing, or edit billing") {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.dsInfo)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    showManageSubscriptions = true
                } label: {
                    SettingRow(icon: "arrow.left.arrow.right", iconTint: .dsSecondary,
                               title: "Change Billing Frequency",
                               subtitle: "Switch between annual & monthly billing in the App Store") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    restoring = true
                    Task { @MainActor in
                        let restored = await purchases.restore()
                        restoring = false
                        if let restored {
                            appState.showToast(restored == .starter ? "No active subscription found to restore" : "✓ \(restored.displayName) restored")
                            await refreshEntitlement()
                        }
                    }
                } label: {
                    SettingRow(icon: "arrow.triangle.2.circlepath", iconTint: .dsPrimary,
                               title: "Restore Purchases",
                               subtitle: "Re-sync active licenses on this Apple device") {
                        if restoring {
                            ProgressView()
                                .tint(Color.dsPrimary)
                        } else {
                            SettingsChevron()
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(restoring)

                Divider().overlay(Color.dsBorder)

                Button {
                    showOfferCode = true
                } label: {
                    SettingRow(icon: "gift.fill", iconTint: .dsAccent,
                               title: "Redeem Offer Code",
                               subtitle: "Enter promotional or educational partner keys") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Terms of Use (EULA)") { openURL(DateSnapLinks.termsOfUse) }
                Text("•").foregroundStyle(Color.dsMutedForeground)
                Button("Privacy Policy") { openURL(DateSnapLinks.privacyPolicy) }
            }
            .font(DSTypography.caption())
            .foregroundStyle(Color.dsSecondary)
            Text("DateSnap \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")) • StoreKit 2")
                .font(.system(size: 10))
                .foregroundStyle(Color.dsMutedForeground.opacity(0.7))
        }
    }
}
