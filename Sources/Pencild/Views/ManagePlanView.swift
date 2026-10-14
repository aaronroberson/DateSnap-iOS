import SwiftUI
import SwiftData
import UIKit
import StoreKit

// Active StoreKit subscription, local record counts and Apple billing controls.
struct ManagePlanView: View {
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    @Query private var savedEvents: [SavedEvent]
    @Query private var scannedAssets: [ScannedAsset]
    @State private var showManageSubscriptions = false
    @State private var showOfferCode = false
    @State private var restoring = false
    @State private var isRefreshingEntitlement = false
    @State private var entitlement: ActiveSubscription?

    private struct ActiveSubscription {
        var product: SubscriptionProductID
        var expirationDate: Date?
        var willAutoRenew: Bool?
    }

    private var tier: SubscriptionTier { appState.subscriptionTier }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                SettingsScreenHeader(title: "Manage Plan", showBack: true)
                PDScreenIntro(
                    eyebrow: "Your membership",
                    title: "Your Plan, Your Pace",
                    subtitle: "Review your current plan and manage billing with Apple."
                )
                subscriptionCard
                usageSummary
                benefits
                if tier != .premium { upsell }
                controls
                SettingsFooterNote(
                    lines: ["Apple manages subscription billing through your Apple ID. Pencil’d does not receive or store payment credentials."],
                    systemImage: "info.circle.fill"
                )
                footerLinks
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.lg)
        }
        .pdScreenBackground()
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
        .onChange(of: showManageSubscriptions) { _, presented in
            if !presented { Task { await refreshEntitlement() } }
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

    /// Only known, verified, active products matching the resolved tier supply billing details.
    private func refreshEntitlement() async {
        isRefreshingEntitlement = true
        defer { isRefreshingEntitlement = false }
        var latest: StoreKit.Transaction?
        var lifetime: SubscriptionProductID?
        let now = Date()
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let product = SubscriptionCatalog.product(id: transaction.productID),
                  product.tier == tier else { continue }
            // A lifetime purchase outranks any subscription for the same tier.
            if product.period == .lifetime {
                lifetime = product
                continue
            }
            guard transaction.productType == .autoRenewable,
                  let expiration = transaction.expirationDate, expiration > now else { continue }
            if latest == nil || expiration > (latest?.expirationDate ?? .distantPast) {
                latest = transaction
            }
        }
        if let lifetime {
            entitlement = ActiveSubscription(product: lifetime, expirationDate: nil, willAutoRenew: nil)
            return
        }
        guard let latest, let product = SubscriptionCatalog.product(id: latest.productID) else {
            entitlement = nil
            return
        }
        var willAutoRenew: Bool?
        if let statuses = try? await purchases.products[latest.productID]?.subscription?.status,
           let status = statuses.first(where: { status in
               if case .verified(let transaction) = status.transaction {
                   return transaction.originalID == latest.originalID
               }
               return false
           }),
           case .verified(let renewal) = status.renewalInfo {
            willAutoRenew = renewal.willAutoRenew
        }
        entitlement = ActiveSubscription(product: product, expirationDate: latest.expirationDate, willAutoRenew: willAutoRenew)
    }

    private var planName: String {
        guard let entitlement else { return tier.displayName }
        return "\(entitlement.product.tier.displayName) · \(entitlement.product.period.displayName)"
    }

    private var planPrice: String {
        guard tier != .starter else { return "Free" }
        guard let entitlement else {
            return isRefreshingEntitlement ? "Checking subscription…" : "Subscription details unavailable"
        }
        return purchases.products[entitlement.product.rawValue]?.displayPrice
            ?? (purchases.isLoadingProducts ? "Loading price…" : "Price unavailable")
    }

    private var subscriptionCard: some View {
        PDCard(highlighted: true) {
            VStack(alignment: .leading, spacing: 16) {
                if tier == .starter {
                    PDStatusBadge(text: "Free plan", icon: "sparkle", tone: .info)
                } else if entitlement?.product.period == .lifetime {
                    PDStatusBadge(text: "Lifetime access", icon: "infinity", tone: .success)
                } else if entitlement != nil {
                    PDStatusBadge(text: "Active subscription", icon: "checkmark.seal.fill", tone: .success)
                } else {
                    PDStatusBadge(text: "\(tier.badgeText) plan", icon: "checkmark.seal", tone: .neutral)
                }
                Text(planName).font(PDFont.headlineMD).foregroundStyle(Color.pdOnSurface)
                VStack(alignment: .leading, spacing: 4) {
                    Text(planPrice).font(PDFont.headlineSM).foregroundStyle(Color.pdPrimary)
                    if let entitlement, purchases.products[entitlement.product.rawValue] != nil {
                        Text(entitlement.product.period.billingDescription)
                            .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
                if let entitlement, let expiration = entitlement.expirationDate {
                    let status = entitlement.willAutoRenew.map { $0 ? "Renews" : "Expires" } ?? "Current period ends"
                    Label("\(status) on \(expiration.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.clock")
                        .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    if let willAutoRenew = entitlement.willAutoRenew {
                        PDStatusBadge(
                            text: willAutoRenew ? "Auto-renewal on" : "Auto-renewal off",
                            icon: willAutoRenew ? "arrow.triangle.2.circlepath" : "pause.circle",
                            tone: willAutoRenew ? .success : .warning
                        )
                    }
                }
                if tier == .starter {
                    Button { Task { await appState.present(.paywall(opening: .plus)) } } label: {
                        Label("See Plus & Premium Plans", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(PDSecondaryButtonStyle(minHeight: 44))
                }
            }
        }
    }

    private var usageSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            PDSectionHeader(title: "On this device")
            PDCard {
                VStack(spacing: 16) {
                    recordCount(icon: "calendar", title: "Saved events", count: savedEvents.filter { $0.status == .saved }.count)
                    Divider().overlay(Color.pdOutlineVariant)
                    recordCount(icon: "doc.text.viewfinder", title: "Stored scans", count: scannedAssets.count)
                }
            }
            Text("Counts reflect the records currently kept by Pencil’d on this device.")
                .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }

    private func recordCount(icon: String, title: String, count: Int) -> some View {
        HStack(spacing: 12) {
            PDIconTile(systemName: icon, tint: .pdPrimary)
            Text(title).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
            Spacer()
            Text(count.formatted()).font(PDFont.headlineMD).foregroundStyle(Color.pdPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var includedFeatures: [PremiumFeature] {
        PremiumFeature.allCases.filter {
            FeatureAccessPolicy.decision(for: $0, snapshot: services.subscription.entitlementSnapshot) == .allowed
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            PDSectionHeader(title: "Your current benefits")
            PDCard {
                VStack(alignment: .leading, spacing: 16) {
                    benefitRow(icon: "doc.text.viewfinder", title: "Scan, review and save", subtitle: "Read an image on your device, edit the details and approve events before saving.")
                    ForEach(includedFeatures, id: \.self) { feature in
                        benefitRow(icon: featureIcon(feature), title: featureTitle(feature), subtitle: feature.upgradeReason)
                    }
                }
            }
        }
    }

    private func featureTitle(_ feature: PremiumFeature) -> String {
        switch feature {
        case .automaticScreenshotDetection: return "Automatic screenshot detection"
        case .likelyEventTriage: return "Likely event triage"
        case .documentImport: return "PDF & Files import"
        case .duplicateClusters: return "Possible duplicate grouping"
        case .advancedReminderPlans: return "Tailored reminder plans"
        case .scheduleImport: return "Work schedules & multi-date flyers"
        }
    }

    private func featureIcon(_ feature: PremiumFeature) -> String {
        switch feature {
        case .automaticScreenshotDetection: return "camera.viewfinder"
        case .likelyEventTriage: return "sparkles"
        case .documentImport: return "doc.text"
        case .duplicateClusters: return "square.on.square"
        case .advancedReminderPlans: return "bell.badge"
        case .scheduleImport: return "calendar.day.timeline.left"
        }
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PDIconTile(systemName: icon, tint: .pdSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                Text(subtitle).font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var upsell: some View {
        PDCard(highlighted: true) {
            VStack(alignment: .leading, spacing: 12) {
                PDEyebrow(text: "Pencil’d Premium")
                Text("Bring your documents into the plan.")
                    .font(PDFont.headlineSM).foregroundStyle(Color.pdOnSurface)
                Text(PremiumFeature.documentImport.upgradeReason)
                    .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                Button { Task { await appState.present(.paywall(opening: .premium)) } } label: {
                    Label(tier == .starter ? "Explore Premium" : "Upgrade to Premium", systemImage: "arrow.up.right")
                }
                .buttonStyle(PDPrimaryButtonStyle(minHeight: 44))
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            PDSectionHeader(title: "Store management")
            PDGroupedList {
                Button { showManageSubscriptions = true } label: {
                    PDListRow(icon: "person.crop.rectangle.stack", tint: .pdInfo, title: "Manage Subscription", subtitle: "Change your plan or cancel through Apple")
                }
                .buttonStyle(PDRowButtonStyle())
                PDRowDivider()
                Button { showManageSubscriptions = true } label: {
                    PDListRow(icon: "arrow.left.arrow.right", tint: .pdSecondary, title: "Change Billing Frequency", subtitle: "Switch annual or monthly billing in the App Store")
                }
                .buttonStyle(PDRowButtonStyle())
                PDRowDivider()
                Button {
                    restoring = true
                    Task { @MainActor in
                        let restored = await purchases.restore()
                        restoring = false
                        if let restored {
                            appState.showToast(restored == .starter ? "No active subscription found to restore" : "\(restored.displayName) restored")
                            await refreshEntitlement()
                        }
                    }
                } label: {
                    PDListRow(icon: "arrow.triangle.2.circlepath", tint: .pdPrimary, title: "Restore Purchases", subtitle: "Check the subscriptions linked to your Apple ID") {
                        if restoring {
                            ProgressView().tint(Color.pdPrimary)
                        } else {
                            PDValueChevron()
                        }
                    }
                }
                .buttonStyle(PDRowButtonStyle())
                .disabled(restoring || purchases.isPurchasing)
                PDRowDivider()
                Button { showOfferCode = true } label: {
                    PDListRow(icon: "gift.fill", tint: .pdTertiary, title: "Redeem Offer Code", subtitle: "Redeem an App Store subscription offer code")
                }
                .buttonStyle(PDRowButtonStyle())
            }
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button { openURL(PencildLinks.termsOfUse) } label: {
                    Text("Terms of Use").frame(minHeight: 44)
                }
                Button { openURL(PencildLinks.privacyPolicy) } label: {
                    Text("Privacy Policy").frame(minHeight: 44)
                }
            }
            .font(PDFont.labelMD)
            .foregroundStyle(Color.pdSecondary)
            .frame(minHeight: 44)
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
               let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                Text("Pencil’d \(version) (\(build))")
                    .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
