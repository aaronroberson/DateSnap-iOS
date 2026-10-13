import SwiftUI

struct PlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    
    @State private var selectedPlanIsAnnual: Bool = true
    @State private var trialEligibleProductIDs: Set<String> = []
    @State private var showPremiumPaywall: Bool = false
    @State private var restoreMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.pdSurfaceHighest))
                        }
                        
                        .accessibilityLabel("Close paywall")

                        Spacer()

                        Button("Restore") {
                            Task { await restore() }
                        }
                        .disabled(purchases.isPurchasing)
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    PDScreenIntro(
                        eyebrow: "Pencil'd Plus",
                        title: "Find the dates worth keeping.",
                        subtitle: "Surface new screenshots on Home and highlight the ones that look like events."
                    )
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
                        }
                    }
                    .padding(.horizontal)

                    // Pricing Selector Cards
                    VStack(spacing: 12) {
                        // Annual Plan
                        Button {
                            selectedPlanIsAnnual = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text("Annual")
                                            .font(PDFont.labelLG)
                                            .foregroundStyle(Color.pdOnSurface)
                                        
                                        if let savingsText {
                                            Text(savingsText)
                                                .font(PDFont.labelSM)
                                                .foregroundStyle(Color.pdOnPrimaryFixed)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.pdPrimary))
                                        }
                                    }
                                    
                                    Text(planPriceDescription(.plus, annual: true))
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(priceAmount(.plus, annual: true))
                                        .font(PDFont.headlineSM)
                                        .foregroundStyle(Color.pdOnSurface)
                                    if purchases.monthlyEquivalent(.plus) != nil {
                                        Text("/ month")
                                            .font(PDFont.bodySM)
                                            .foregroundStyle(Color.pdOnSurfaceVariant)
                                    }
                                }
                                
                                Image(systemName: selectedPlanIsAnnual ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(selectedPlanIsAnnual ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                                    .padding(.leading, 8)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedPlanIsAnnual ? Color.pdSurfaceContainer : Color.pdSurfaceLow,
                                in: RoundedRectangle(cornerRadius: PDRadius.plan)
                            )
                            .overlay(alignment: .leading) {
                                if selectedPlanIsAnnual {
                                    Capsule().fill(Color.pdPrimary)
                                        .frame(width: 4)
                                        .padding(.vertical, 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedPlanIsAnnual ? .isSelected : [])

                        // Monthly Plan
                        Button {
                            selectedPlanIsAnnual = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly")
                                        .font(PDFont.labelLG)
                                        .foregroundStyle(Color.pdOnSurface)
                                    
                                    Text(planPriceDescription(.plus, annual: false))
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(priceAmount(.plus, annual: false))
                                        .font(PDFont.headlineSM)
                                        .foregroundStyle(Color.pdOnSurface)
                                    if purchases.displayPrice(.plus, annual: false) != nil {
                                        Text("/ month")
                                            .font(PDFont.bodySM)
                                            .foregroundStyle(Color.pdOnSurfaceVariant)
                                    }
                                }
                                
                                Image(systemName: !selectedPlanIsAnnual ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(!selectedPlanIsAnnual ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                                    .padding(.leading, 8)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                !selectedPlanIsAnnual ? Color.pdSurfaceContainer : Color.pdSurfaceLow,
                                in: RoundedRectangle(cornerRadius: PDRadius.plan)
                            )
                            .overlay(alignment: .leading) {
                                if !selectedPlanIsAnnual {
                                    Capsule().fill(Color.pdPrimary)
                                        .frame(width: 4)
                                        .padding(.vertical, 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(!selectedPlanIsAnnual ? .isSelected : [])
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
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(!purchases.canPurchase(.plus, annual: selectedPlanIsAnnual) || appState.isPlusMember)
                    .padding(.horizontal)
                    
                    Text("Subscriptions renew until cancelled in App Store Subscriptions.")
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
            .dsScreenBackground()
            .task {
                await purchases.attach(services.subscription)
                for annual in [true, false] {
                    if let product = purchases.product(.plus, annual: annual),
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
        guard let price = purchases.displayPrice(.plus, annual: selectedPlanIsAnnual) else {
            return priceUnavailableText
        }
        if let trial = eligibleTrialDescription(annual: selectedPlanIsAnnual) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return "Subscribe for \(price)"
    }

    private func eligibleTrialDescription(annual: Bool) -> String? {
        guard let product = purchases.product(.plus, annual: annual),
              trialEligibleProductIDs.contains(product.id) else { return nil }
        return purchases.trialDescription(.plus, annual: annual)
    }

    private var priceUnavailableText: String {
        purchases.isLoadingProducts ? "Loading price…" : "Price unavailable"
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
        guard let monthly = purchases.product(.plus, annual: false), let annual = purchases.product(.plus, annual: true),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        guard saving > 0 else { return nil }
        return "Save \(Int(NSDecimalNumber(decimal: saving).doubleValue.rounded()))%"
    }

    private func purchase() async {
        guard let tier = await purchases.purchase(.plus, annual: selectedPlanIsAnnual) else { return }
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
