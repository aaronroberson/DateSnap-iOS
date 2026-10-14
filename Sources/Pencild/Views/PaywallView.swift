import SwiftUI

/// The one paywall, for both plans. Free and Plus users see Plus and Premium tabs; callers choose
/// only which tab opens first (`AppModalScreen.paywall(for:)` picks the tab a feature needs). On a Plus member's plan the
/// billing option they already have is marked "Current plan" and can't be bought again; the other
/// intervals stay available so they can switch. Premium members never see a paywall.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()

    let initialPlan: PurchaseViewModel.Plan

    @State private var plan: PurchaseViewModel.Plan
    @State private var selectedPeriod: BillingPeriod = .annual
    @State private var trialEligibleProductIDs: Set<String> = []
    @State private var restoreMessage: String?
    /// What the member already owns for the shown plan's tier; `nil` for free users or while loading.
    @State private var currentProduct: SubscriptionProductID?
    @State private var isLoadingCurrent = false

    init(initialPlan: PurchaseViewModel.Plan) {
        self.initialPlan = initialPlan
        _plan = State(initialValue: initialPlan)
    }

    private var showsTabs: Bool { appState.subscriptionTier != .premium }
    private var tierName: String { plan == .plus ? "Plus" : "Premium" }

    /// The user already holds this tab's tier (Premium includes Plus, but billing switches apply
    /// only to the tier actually owned).
    private var ownsPlanTier: Bool { appState.subscriptionTier == plan.tier }
    /// Premium members don't buy Plus.
    private var isIncludedInHigherPlan: Bool { plan == .plus && appState.isPremiumMember }

    private func isCurrent(_ period: BillingPeriod) -> Bool {
        ownsPlanTier && currentProduct?.period == period
    }

    /// A lifetime owner has nothing to switch to on that plan.
    private var ownsLifetime: Bool { ownsPlanTier && currentProduct?.period == .lifetime }

    private var purchaseBlocked: Bool {
        isIncludedInHigherPlan || ownsLifetime || isCurrent(selectedPeriod)
            || (ownsPlanTier && currentProduct == nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if showsTabs {
                        planTabs
                            .padding(.horizontal)
                            .padding(.top, PDSpacing.xs)
                    }

                    PDScreenIntro(
                        eyebrow: tierName,
                        title: "Upgrade to \(tierName)",
                        subtitle: plan == .plus
                            ? "Find the dates worth keeping. Plus surfaces new screenshots on Home and highlights the ones that look like events."
                            : "Turn flyers and files into plans. Import PDFs and images from Files, review the extracted dates, and choose what to save."
                    )
                    .padding(.horizontal)
                    .padding(.top, showsTabs ? 0 : PDSpacing.md)

                    PDSectionHeader(title: "Included with \(tierName)")
                        .padding(.horizontal)
                    PDCard {
                        VStack(spacing: 16) {
                            if plan == .plus { plusFeatures } else { premiumFeatures }
                        }
                    }
                    .padding(.horizontal)

                    planOptions
                        .padding(.horizontal)

                    controlCard
                        .padding(.horizontal)

                    Button {
                        Task { await purchase() }
                    } label: {
                        HStack(spacing: 8) {
                            if purchases.isPurchasing {
                                ProgressView()
                                    .tint(Color.pdOnPrimaryFixed)
                            } else {
                                Text(ctaTitle)
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                    .buttonStyle(PDPrimaryButtonStyle())
                    .disabled(!purchases.canPurchase(plan, selectedPeriod) || purchaseBlocked)
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.pdSuccess)
                            Text(renewalText)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            Button {
                                Task { await restore() }
                            } label: {
                                Text("Restore Purchases").frame(minHeight: 44)
                            }
                            .disabled(purchases.isPurchasing)
                            Text("•").foregroundStyle(Color.pdOnSurfaceVariant)
                            Button {
                                openURL(PencildLinks.termsOfUse)
                            } label: {
                                Text("Terms of Use").frame(minHeight: 44)
                            }
                            Text("•").foregroundStyle(Color.pdOnSurfaceVariant)
                            Button {
                                openURL(PencildLinks.privacyPolicy)
                            } label: {
                                Text("Privacy Policy").frame(minHeight: 44)
                            }
                        }
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .padding(.bottom, 24)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                PDInterstitialHeader(closeLabel: "Close paywall")
            }
            .pdScreenBackground()
            .task {
                // Same check as `AppState.present`, for screens that open the paywall in their own
                // sheet: retry an unresolved entitlement, and never sell to a Premium member.
                if await !appState.shouldShowPaywall() { dismiss() }
            }
            .task(id: plan) { await loadCurrentProduct() }
            .task {
                await purchases.attach(services.subscription)
                for candidate in [PurchaseViewModel.Plan.plus, .premium] {
                    for period in [BillingPeriod.annual, .monthly] {
                        if let product = purchases.product(candidate, period),
                           let subscription = product.subscription,
                           await subscription.isEligibleForIntroOffer {
                            trialEligibleProductIDs.insert(product.id)
                        }
                    }
                }
            }
            .alert("Purchase Issue", isPresented: Binding(
                get: { purchases.errorMessage != nil },
                set: { if !$0 { purchases.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchases.errorMessage ?? "")
            }
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    // MARK: - Tabs

    private var planTabs: some View {
        HStack(spacing: 4) {
            tab(.plus, title: "Plus")
            tab(.premium, title: "Premium")
        }
        .padding(4)
        .background(Capsule().fill(Color.pdSurfaceContainer))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plan")
    }

    private func tab(_ option: PurchaseViewModel.Plan, title: String) -> some View {
        let selected = plan == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { plan = option }
        } label: {
            Text(title)
                .font(PDFont.labelLG)
                .foregroundStyle(selected ? Color.pdOnPrimaryFixed : Color.pdOnSurfaceVariant)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(selected ? AnyShapeStyle(LinearGradient.pdAction) : AnyShapeStyle(Color.clear)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("paywall.tab.\(title.lowercased())")
    }

    // MARK: - Features

    @ViewBuilder
    private var plusFeatures: some View {
        featureRow(icon: "camera.viewfinder", title: "Automatic screenshot detection",
                   subtitle: PremiumFeature.automaticScreenshotDetection.upgradeReason)
        featureRow(icon: "sparkles", title: "Find likely event screenshots",
                   subtitle: PremiumFeature.likelyEventTriage.upgradeReason)
        featureRow(icon: "infinity", title: "Unlimited scans",
                   subtitle: "The free plan includes \(PlanLimits.freeScansPerMonth) scans a month.")
        featureRow(icon: "bell.badge", title: "Up to \(PlanLimits.paidAlertsPerEvent) alerts per event",
                   subtitle: "The free plan includes \(PlanLimits.freeAlertsPerEvent) alert per event.")
    }

    @ViewBuilder
    private var premiumFeatures: some View {
        featureRow(icon: "camera.viewfinder", title: "Everything in Plus",
                   subtitle: "Screenshot detection, likely-event triage, unlimited scans, and \(PlanLimits.paidAlertsPerEvent) alerts per event.")
        featureRow(icon: "doc.text.viewfinder", title: "PDF & Files import",
                   subtitle: PremiumFeature.documentImport.upgradeReason, isHighlighted: true)
        featureRow(icon: "calendar.day.timeline.left", title: "Work schedules & multi-date flyers",
                   subtitle: PremiumFeature.scheduleImport.upgradeReason)
        featureRow(icon: "square.on.square", title: "Find possible duplicates",
                   subtitle: PremiumFeature.duplicateClusters.upgradeReason)
        featureRow(icon: "bell.badge", title: "Tailored reminder plans",
                   subtitle: PremiumFeature.advancedReminderPlans.upgradeReason)
    }

    // MARK: - Plan options

    private var planOptions: some View {
        VStack(spacing: 12) {
            if LifetimeIntroOffer.isAvailable() {
                PDPlanOption(
                    title: "Lifetime",
                    ribbon: "Intro offer",
                    detail: planPriceDescription(.lifetime),
                    price: priceAmount(.lifetime),
                    isSelected: selectedPeriod == .lifetime,
                    isCurrent: isCurrent(.lifetime)
                ) { selectedPeriod = .lifetime }
                .disabled(ownsLifetime)
            }
            PDPlanOption(
                title: "Annual",
                badge: savingsText,
                detail: planPriceDescription(.annual),
                price: priceAmount(.annual),
                showsPerMonth: purchases.monthlyEquivalent(plan) != nil,
                isSelected: selectedPeriod == .annual,
                isCurrent: isCurrent(.annual)
            ) { selectedPeriod = .annual }
            .disabled(ownsLifetime)
            PDPlanOption(
                title: "Monthly",
                detail: planPriceDescription(.monthly),
                price: priceAmount(.monthly),
                showsPerMonth: purchases.displayPrice(plan, .monthly) != nil,
                isSelected: selectedPeriod == .monthly,
                isCurrent: isCurrent(.monthly)
            ) { selectedPeriod = .monthly }
            .disabled(ownsLifetime)
        }
        // Room for the Lifetime ribbon, which rises above its option.
        .padding(.top, LifetimeIntroOffer.isAvailable() ? 14 : 0)
    }

    private var controlCard: some View {
        PDCard(highlighted: true) {
            HStack(alignment: .top, spacing: 12) {
                PDIconTile(systemName: "checkmark.shield", tint: .pdSecondary, size: .large)
                VStack(alignment: .leading, spacing: 4) {
                    Text("You stay in control")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Review every date before saving to Apple Calendar. The free plan includes \(PlanLimits.freeScansPerMonth) scans a month and \(PlanLimits.freeAlertsPerEvent) alert per event.")
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
        }
    }

    // MARK: - Copy

    private var ctaTitle: String {
        if isIncludedInHigherPlan { return "Included in Premium" }
        if ownsLifetime { return "\(tierName) Lifetime Is Active" }
        if ownsPlanTier && currentProduct == nil {
            return isLoadingCurrent ? "Checking your plan…" : "\(tierName) Is Active"
        }
        if isCurrent(selectedPeriod) { return "This Is Your Current Plan" }
        guard let price = purchases.displayPrice(plan, selectedPeriod) else {
            return priceUnavailableText
        }
        if selectedPeriod == .lifetime { return "Buy Lifetime for \(price)" }
        if ownsPlanTier { return "Switch to \(selectedPeriod.displayName) for \(price)" }
        if plan == .premium && appState.isPlusMember { return "Upgrade to Premium" }
        if let trial = eligibleTrialDescription(selectedPeriod) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return "Subscribe for \(price)"
    }

    private var renewalText: String {
        guard let price = purchases.displayPrice(plan, selectedPeriod) else {
            return priceUnavailableText
        }
        if selectedPeriod == .lifetime {
            let cancelNote = appState.subscriptionTier != .starter && !ownsLifetime
                ? " Cancel your current subscription in Settings › Apple ID › Subscriptions afterward."
                : ""
            return "\(price) once. Lifetime is a one-time purchase and never renews.\(cancelNote)"
        }
        return "Renews at \(price)/\(selectedPeriod == .annual ? "yr" : "mo") until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions."
    }

    private func eligibleTrialDescription(_ period: BillingPeriod) -> String? {
        guard let product = purchases.product(plan, period),
              trialEligibleProductIDs.contains(product.id) else { return nil }
        return purchases.trialDescription(plan, period)
    }

    private var priceUnavailableText: String {
        purchases.isLoadingProducts ? "Loading price…" : "Price unavailable"
    }

    private func priceAmount(_ period: BillingPeriod) -> String {
        let price = period == .annual ? purchases.monthlyEquivalent(plan) : purchases.displayPrice(plan, period)
        return price ?? priceUnavailableText
    }

    private func planPriceDescription(_ period: BillingPeriod) -> String {
        if period == .lifetime { return "Pay once · offer ends \(LifetimeIntroOffer.lastDayText())" }
        guard let price = purchases.displayPrice(plan, period) else { return priceUnavailableText }
        let billing = period == .annual ? "billed annually" : "billed monthly, cancel anytime"
        let trial = eligibleTrialDescription(period).map { " (includes \($0) free trial)" } ?? ""
        return "\(price) \(billing)\(trial)"
    }

    private var savingsText: String? {
        guard let monthly = purchases.product(plan, .monthly), let annual = purchases.product(plan, .annual),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        guard saving > 0 else { return nil }
        return "Save \(Int(NSDecimalNumber(decimal: saving).doubleValue.rounded()))%"
    }

    // MARK: - Actions

    /// Loads what the member owns for this tab, then moves the selection off an option they
    /// can't buy (their current interval).
    private func loadCurrentProduct() async {
        guard ownsPlanTier else { currentProduct = nil; return }
        isLoadingCurrent = true
        currentProduct = await purchases.currentProduct(for: plan.tier)
        isLoadingCurrent = false
        if isCurrent(selectedPeriod) {
            let options: [BillingPeriod] = [.annual, .monthly] + (LifetimeIntroOffer.isAvailable() ? [.lifetime] : [])
            if let next = options.first(where: { !isCurrent($0) }) { selectedPeriod = next }
        }
    }

    private func purchase() async {
        guard let tier = await purchases.purchase(plan, selectedPeriod) else { return }
        appState.showToast("Current plan: \(tier.displayName)")
        dismiss()
    }

    private func restore() async {
        guard let tier = await purchases.restore() else { return }
        if tier == .starter {
            restoreMessage = "No active subscription found to restore."
        } else {
            appState.showToast("✓ \(tier.displayName) restored")
            dismiss()
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String, isHighlighted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PDIconTile(systemName: icon, tint: .pdPrimary, size: .large)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(isHighlighted ? PDFont.headlineSM : PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text(subtitle)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(isHighlighted ? 12 : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(LinearGradient.pdHighlightCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: PDRadius.card)
                            .stroke(Color.pdPrimary.opacity(0.35), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, isHighlighted ? -12 : 0)
    }
}
