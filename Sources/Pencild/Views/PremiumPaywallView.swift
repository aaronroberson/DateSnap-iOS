import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    
    @State private var selectedPeriod: BillingPeriod = .annual
    @State private var trialEligibleProductIDs: Set<String> = []
    @State private var restoreMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    PDScreenIntro(
                        eyebrow: "Pencil'd Premium",
                        title: "Upgrade to Premium",
                        subtitle: "Turn flyers and files into plans. Import PDFs and images from Files, review the extracted dates, and choose what to save."
                    )
                    .padding(.horizontal)
                    .padding(.top, PDSpacing.md)

                    PDSectionHeader(title: "Included with Premium")
                        .padding(.horizontal)
                    PDCard {
                        VStack(spacing: 16) {
                            featureRow(
                                icon: "camera.viewfinder", iconColor: .pdPrimary,
                                title: "Everything in Plus",
                                subtitle: PremiumFeature.automaticScreenshotDetection.upgradeReason
                            )
                            featureRow(
                                icon: "doc.text.viewfinder", iconColor: .pdPrimary,
                                title: "PDF & Files import",
                                subtitle: PremiumFeature.documentImport.upgradeReason,
                                isHighlighted: true
                            )
                            featureRow(
                                icon: "sparkles", iconColor: .pdPrimary,
                                title: "Likely event triage",
                                subtitle: PremiumFeature.likelyEventTriage.upgradeReason
                            )
                            featureRow(
                                icon: "square.on.square", iconColor: .pdPrimary,
                                title: "Find possible duplicates",
                                subtitle: PremiumFeature.duplicateClusters.upgradeReason
                            )
                            featureRow(
                                icon: "bell.badge", iconColor: .pdPrimary,
                                title: "Tailored reminder plans",
                                subtitle: PremiumFeature.advancedReminderPlans.upgradeReason
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
                            detail: planPriceDescription(.premium, .annual),
                            price: priceAmount(.premium, .annual),
                            showsPerMonth: purchases.monthlyEquivalent(.premium) != nil,
                            isSelected: selectedPeriod == .annual
                        ) { selectedPeriod = .annual }
                        PDPlanOption(
                            title: "Monthly",
                            detail: planPriceDescription(.premium, .monthly),
                            price: priceAmount(.premium, .monthly),
                            showsPerMonth: purchases.displayPrice(.premium, .monthly) != nil,
                            isSelected: selectedPeriod == .monthly
                        ) { selectedPeriod = .monthly }
                        if LifetimeIntroOffer.isAvailable() {
                            PDPlanOption(
                                title: "Lifetime",
                                badge: "Intro offer",
                                detail: planPriceDescription(.premium, .lifetime),
                                price: priceAmount(.premium, .lifetime),
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
                    .disabled(!purchases.canPurchase(.premium, selectedPeriod) || appState.isPremiumMember)
                    .padding(.horizontal)
                    
                    // Reassurance & Terms
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
                await purchases.attach(services.subscription)
                for period in [BillingPeriod.annual, .monthly] {
                    if let product = purchases.product(.premium, period),
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
        if appState.isPremiumMember { return "Premium Is Active" }
        guard let price = purchases.displayPrice(.premium, selectedPeriod) else {
            return priceUnavailableText
        }
        if selectedPeriod == .lifetime { return "Buy Lifetime for \(price)" }
        if let trial = eligibleTrialDescription(selectedPeriod) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return appState.isPlusMember ? "Upgrade to Premium" : "Subscribe for \(price)"
    }

    private func eligibleTrialDescription(_ period: BillingPeriod) -> String? {
        guard let product = purchases.product(.premium, period),
              trialEligibleProductIDs.contains(product.id) else { return nil }
        return purchases.trialDescription(.premium, period)
    }

    private var priceUnavailableText: String {
        purchases.isLoadingProducts ? "Loading price…" : "Price unavailable"
    }

    private var renewalText: String {
        guard let price = purchases.displayPrice(.premium, selectedPeriod) else {
            return priceUnavailableText
        }
        if selectedPeriod == .lifetime { return "\(price) once. Lifetime is a one-time purchase and never renews." }
        return "Renews at \(price)/\(selectedPeriod == .annual ? "yr" : "mo") until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions."
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
        guard let monthly = purchases.product(.premium, .monthly), let annual = purchases.product(.premium, .annual),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        guard saving > 0 else { return nil }
        return "Save \(Int(NSDecimalNumber(decimal: saving).doubleValue.rounded()))%"
    }

    private func purchase() async {
        guard let tier = await purchases.purchase(.premium, selectedPeriod) else { return }
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
    /// `isHighlighted` marks Premium's headline feature: a bold title on the highlight-card
    /// gradient, so it stands out from the rows around it.
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String, isHighlighted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PDIconTile(systemName: icon, tint: iconColor, size: .large)

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
