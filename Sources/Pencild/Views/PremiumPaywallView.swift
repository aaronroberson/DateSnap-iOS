import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    
    @State private var selectedPlanIsAnnual: Bool = true
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
                                Text("Review every date before saving to Apple Calendar. Single-image scanning and manual review remain available on the Free plan.")
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
                            detail: planPriceDescription(.premium, annual: true),
                            price: priceAmount(.premium, annual: true),
                            showsPerMonth: purchases.monthlyEquivalent(.premium) != nil,
                            isSelected: selectedPlanIsAnnual
                        ) { selectedPlanIsAnnual = true }
                        PDPlanOption(
                            title: "Monthly",
                            detail: planPriceDescription(.premium, annual: false),
                            price: priceAmount(.premium, annual: false),
                            showsPerMonth: purchases.displayPrice(.premium, annual: false) != nil,
                            isSelected: !selectedPlanIsAnnual
                        ) { selectedPlanIsAnnual = false }
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
                    .disabled(!purchases.canPurchase(.premium, annual: selectedPlanIsAnnual) || appState.isPremiumMember)
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
                for annual in [true, false] {
                    if let product = purchases.product(.premium, annual: annual),
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
        guard let price = purchases.displayPrice(.premium, annual: selectedPlanIsAnnual) else {
            return priceUnavailableText
        }
        if let trial = eligibleTrialDescription(annual: selectedPlanIsAnnual) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return appState.isPlusMember ? "Upgrade to Premium" : "Subscribe for \(price)"
    }

    private func eligibleTrialDescription(annual: Bool) -> String? {
        guard let product = purchases.product(.premium, annual: annual),
              trialEligibleProductIDs.contains(product.id) else { return nil }
        return purchases.trialDescription(.premium, annual: annual)
    }

    private var priceUnavailableText: String {
        purchases.isLoadingProducts ? "Loading price…" : "Price unavailable"
    }

    private var renewalText: String {
        guard let price = purchases.displayPrice(.premium, annual: selectedPlanIsAnnual) else {
            return priceUnavailableText
        }
        return "Renews at \(price)/\(selectedPlanIsAnnual ? "yr" : "mo") until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions."
    }

    private func priceAmount(_ plan: PurchaseViewModel.Plan, annual: Bool) -> String {
        let price = annual ? purchases.monthlyEquivalent(plan) : purchases.displayPrice(plan, annual: false)
        return price ?? priceUnavailableText
    }

    private func planPriceDescription(_ plan: PurchaseViewModel.Plan, annual: Bool) -> String {
        guard let price = purchases.displayPrice(plan, annual: annual) else { return priceUnavailableText }
        let billing = annual ? "billed annually" : "billed monthly, cancel anytime"
        let trial = eligibleTrialDescription(annual: annual).map { " (includes \($0) free trial)" } ?? ""
        return "\(price) \(billing)\(trial)"
    }

    private var savingsText: String? {
        guard let monthly = purchases.product(.premium, annual: false), let annual = purchases.product(.premium, annual: true),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        guard saving > 0 else { return nil }
        return "Save \(Int(NSDecimalNumber(decimal: saving).doubleValue.rounded()))%"
    }

    private func purchase() async {
        guard let tier = await purchases.purchase(.premium, annual: selectedPlanIsAnnual) else { return }
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
