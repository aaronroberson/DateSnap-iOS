import SwiftUI

struct PlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    
    @State private var selectedPeriod: BillingPeriod = .annual
    @State private var trialEligibleProductIDs: Set<String> = []
    @State private var showPremiumPaywall: Bool = false
    @State private var restoreMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    PDScreenIntro(
                        eyebrow: "Pencil'd Plus",
                        title: "Upgrade to Plus",
                        subtitle: "Find the dates worth keeping. Plus surfaces new screenshots on Home and highlights the ones that look like events."
                    )
                    .padding(.horizontal)
                    .padding(.top, PDSpacing.md)

                    PDSectionHeader(title: "Included with Plus")
                        .padding(.horizontal)
                    PDCard {
                        VStack(spacing: 16) {
                            featureRow(
                                icon: "camera.viewfinder", iconColor: .pdPrimary,
                                title: "Automatic screenshot detection",
                                subtitle: PremiumFeature.automaticScreenshotDetection.upgradeReason
                            )
                            featureRow(
                                icon: "sparkles", iconColor: .pdPrimary,
                                title: "Find likely event screenshots",
                                subtitle: PremiumFeature.likelyEventTriage.upgradeReason
                            )
                            featureRow(
                                icon: "infinity", iconColor: .pdPrimary,
                                title: "Unlimited scans",
                                subtitle: "The free plan includes \(PlanLimits.freeScansPerMonth) scans a month."
                            )
                            featureRow(
                                icon: "bell.badge", iconColor: .pdPrimary,
                                title: "Up to \(PlanLimits.paidAlertsPerEvent) alerts per event",
                                subtitle: "The free plan includes \(PlanLimits.freeAlertsPerEvent) alert per event."
                            )
                        }
                    }
                    .padding(.horizontal)

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
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        PDPlanOption(
                            title: "Annual",
                            badge: savingsText,
                            detail: planPriceDescription(.plus, .annual),
                            price: priceAmount(.plus, .annual),
                            showsPerMonth: purchases.monthlyEquivalent(.plus) != nil,
                            isSelected: selectedPeriod == .annual
                        ) { selectedPeriod = .annual }
                        PDPlanOption(
                            title: "Monthly",
                            detail: planPriceDescription(.plus, .monthly),
                            price: priceAmount(.plus, .monthly),
                            showsPerMonth: purchases.displayPrice(.plus, .monthly) != nil,
                            isSelected: selectedPeriod == .monthly
                        ) { selectedPeriod = .monthly }
                        if LifetimeIntroOffer.isAvailable() {
                            PDPlanOption(
                                title: "Lifetime",
                                badge: "Intro offer",
                                detail: planPriceDescription(.plus, .lifetime),
                                price: priceAmount(.plus, .lifetime),
                                isSelected: selectedPeriod == .lifetime
                            ) { selectedPeriod = .lifetime }
                        }
                    }
                    .padding(.horizontal)

                    // CTA Button
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
                    .disabled(!purchases.canPurchase(.plus, selectedPeriod) || appState.isPlusMember)
                    .padding(.horizontal)
                    
                    Text(selectedPeriod == .lifetime
                         ? "Lifetime is a one-time purchase and never renews."
                         : "Subscriptions renew until cancelled in App Store Subscriptions.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Cross-link to Premium
                    Button {
                        showPremiumPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 13))
                            Text("Need PDF & Files import? Explore Premium")
                                .font(PDFont.bodySM)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.pdWarning)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                    }
                    .sheet(isPresented: $showPremiumPaywall) {
                        PremiumPaywallView()
                    }
                    
                    // Legal and Privacy
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
                    .frame(minHeight: 44)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                PDInterstitialHeader(closeLabel: "Close paywall")
            }
            .pdScreenBackground()
            .task {
                await purchases.attach(services.subscription)
                for period in [BillingPeriod.annual, .monthly] {
                    if let product = purchases.product(.plus, period),
                       let subscription = product.subscription,
                       await subscription.isEligibleForIntroOffer {
                        trialEligibleProductIDs.insert(product.id)
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

    private var ctaTitle: String {
        if appState.isPlusMember { return "\(appState.subscriptionTier.displayName) Is Active" }
        guard let price = purchases.displayPrice(.plus, selectedPeriod) else {
            return priceUnavailableText
        }
        if selectedPeriod == .lifetime { return "Buy Lifetime for \(price)" }
        if let trial = eligibleTrialDescription(selectedPeriod) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return "Subscribe for \(price)"
    }

    private func eligibleTrialDescription(_ period: BillingPeriod) -> String? {
        guard let product = purchases.product(.plus, period),
              trialEligibleProductIDs.contains(product.id) else { return nil }
        return purchases.trialDescription(.plus, period)
    }

    private var priceUnavailableText: String {
        purchases.isLoadingProducts ? "Loading price…" : "Price unavailable"
    }

    private func priceAmount(_ plan: PurchaseViewModel.Plan, _ period: BillingPeriod) -> String {
        let price = period == .annual ? purchases.monthlyEquivalent(plan) : purchases.displayPrice(plan, period)
        return price ?? priceUnavailableText
    }

    private func planPriceDescription(_ plan: PurchaseViewModel.Plan, _ period: BillingPeriod) -> String {
        if period == .lifetime { return "Pay once · offer ends \(LifetimeIntroOffer.lastDayText())" }
        guard let price = purchases.displayPrice(plan, period) else { return priceUnavailableText }
        let billing = period == .annual ? "billed annually" : "billed monthly, cancel anytime"
        let trial = eligibleTrialDescription(period).map { " (includes \($0) free trial)" } ?? ""
        return "\(price) \(billing)\(trial)"
    }

    private var savingsText: String? {
        guard let monthly = purchases.product(.plus, .monthly), let annual = purchases.product(.plus, .annual),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        guard saving > 0 else { return nil }
        return "Save \(Int(NSDecimalNumber(decimal: saving).doubleValue.rounded()))%"
    }

    private func purchase() async {
        guard let tier = await purchases.purchase(.plus, selectedPeriod) else { return }
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
    
    @ViewBuilder
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PDIconTile(systemName: icon, tint: iconColor, size: .large)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text(subtitle)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
