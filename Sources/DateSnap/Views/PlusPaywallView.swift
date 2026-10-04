import SwiftUI

struct PlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    
    @State private var selectedPlanIsAnnual: Bool = true
    @State private var showPremiumPaywall: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.dsMutedForeground)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.dsMuted))
                        }
                        
                        Spacer()
                        
                        Button("Restore") {
                            Task { await restore() }
                        }
                        .disabled(purchases.isPurchasing)
                        .font(DSTypography.bodyCompact())
                        .foregroundStyle(Color.dsMutedForeground)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // Eyebrow & Hero Title
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("DATESNAP PLUS")
                                .font(DSTypography.overlineConfidence())
                        }
                        .foregroundStyle(Color.dsPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.dsPrimary.opacity(0.12))
                                .overlay(Capsule().stroke(Color.dsPrimary.opacity(0.3), lineWidth: 1))
                        )
                        
                        Text("Never miss a date you saved.")
                            .font(DSTypography.displayTitle())
                            .foregroundStyle(Color.dsForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                        
                        Text("Automatically find events in screenshots and set the reminders that work for you.")
                            .font(DSTypography.bodyBase())
                            .foregroundStyle(Color.dsMutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Hero Visual Feature Highlight Card
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.viewfinder")
                                    .foregroundStyle(Color.dsSecondary)
                                Text("Screenshot Scanned")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            Spacer()
                            DSConfidencePill(score: 99, label: "AI MATCH")
                        }
                        
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dsSecondary.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(Color.dsSecondary)
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Neon Sunset Rooftop")
                                    .font(DSTypography.bodyStrong())
                                    .foregroundStyle(Color.dsForeground)
                                HStack(spacing: 6) {
                                    Text("3 reminders primed")
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsPrimary)
                                    Text("•")
                                        .foregroundStyle(Color.dsMutedForeground)
                                    Text("Apple Cal Sync")
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 20, elevated: true, borderColor: Color.dsPrimary.opacity(0.35))
                    .padding(.horizontal)
                    
                    // Feature List
                    VStack(spacing: 14) {
                        featureRow(
                            icon: "doc.text.viewfinder",
                            iconColor: Color.dsPrimary,
                            title: "Unlimited Screenshot Scans",
                            subtitle: "Scan and extract events from concert flyers, stories, and chat invites without limits."
                        )
                        
                        featureRow(
                            icon: "bell.badge.fill",
                            iconColor: Color.dsAccent,
                            title: "Up to 3 Reminders Per Event",
                            subtitle: "Fine-tune departure countdowns, ticket drop buzzers, and prep alerts with precision."
                        )
                        
                        featureRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: Color.dsSecondary,
                            title: "Calendar, Reminders & Push",
                            subtitle: "Triple-destination sync across Apple Calendar, Reminders, and DateSnap local push."
                        )
                        
                        featureRow(
                            icon: "slider.horizontal.3",
                            iconColor: Color.dsSuccess,
                            title: "Custom Defaults & Smart Drafts",
                            subtitle: "Auto-apply your favorite timing offsets and triage ambiguous dates effortlessly."
                        )
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 22)
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
                                            .font(DSTypography.bodyStrong())
                                            .foregroundStyle(Color.dsForeground)
                                        
                                        if let savingsText {
                                            Text(savingsText)
                                                .font(DSTypography.overlineConfidence())
                                                .foregroundStyle(Color.dsPrimaryForeground)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.dsPrimary))
                                        }
                                    }
                                    
                                    Text(planPriceDescription(.plus, annual: true))
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(priceAmount(.plus, annual: true))
                                        .font(DSTypography.headlineCard())
                                        .foregroundStyle(Color.dsForeground)
                                    if purchases.monthlyEquivalent(.plus) != nil {
                                        Text("/ month")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                }
                                
                                Image(systemName: selectedPlanIsAnnual ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(selectedPlanIsAnnual ? Color.dsPrimary : Color.dsMutedForeground)
                                    .padding(.leading, 8)
                            }
                            .padding(16)
                            .dsGlassCard(
                                cornerRadius: 18,
                                elevated: selectedPlanIsAnnual,
                                borderColor: selectedPlanIsAnnual ? Color.dsPrimary : Color.dsBorder,
                                borderWidth: selectedPlanIsAnnual ? 2 : 1
                            )
                        }
                        
                        // Monthly Plan
                        Button {
                            selectedPlanIsAnnual = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly")
                                        .font(DSTypography.bodyStrong())
                                        .foregroundStyle(Color.dsForeground)
                                    
                                    Text(planPriceDescription(.plus, annual: false))
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(priceAmount(.plus, annual: false))
                                        .font(DSTypography.headlineCard())
                                        .foregroundStyle(Color.dsForeground)
                                    if purchases.displayPrice(.plus, annual: false) != nil {
                                        Text("/ month")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                }
                                
                                Image(systemName: !selectedPlanIsAnnual ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(!selectedPlanIsAnnual ? Color.dsPrimary : Color.dsMutedForeground)
                                    .padding(.leading, 8)
                            }
                            .padding(16)
                            .dsGlassCard(
                                cornerRadius: 18,
                                elevated: !selectedPlanIsAnnual,
                                borderColor: !selectedPlanIsAnnual ? Color.dsPrimary : Color.dsBorder,
                                borderWidth: !selectedPlanIsAnnual ? 2 : 1
                            )
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
                                    .tint(Color.dsPrimaryForeground)
                            } else {
                                Text(ctaTitle)
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(!purchases.canPurchase(.plus, annual: selectedPlanIsAnnual) || appState.isPlusMember)
                    .padding(.horizontal)
                    
                    // Cross-link to Premium
                    Button {
                        showPremiumPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 13))
                            Text("Need Multi-Page PDF & Cloud Drive import? Explore DateSnap Premium")
                                .font(DSTypography.caption())
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.dsWarning)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showPremiumPaywall) {
                        PremiumPaywallView()
                    }
                    
                    // Legal and Privacy
                    HStack(spacing: 16) {
                        Button("Restore Purchases") {
                            Task { await restore() }
                        }
                        Text("•").foregroundStyle(Color.dsMutedForeground)
                        Button("Terms of Use") {
                            openURL(DateSnapLinks.termsOfUse)
                        }
                        Text("•").foregroundStyle(Color.dsMutedForeground)
                        Button("Privacy Policy") {
                            openURL(DateSnapLinks.privacyPolicy)
                        }
                    }
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .padding(.bottom, 24)
                }
            }
            .dsScreenBackground()
            .task { await purchases.attach(services.subscription) }
            .alert("Purchase Issue", isPresented: Binding(
                get: { purchases.errorMessage != nil },
                set: { if !$0 { purchases.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchases.errorMessage ?? "")
            }
        }
    }

    private var ctaTitle: String {
        if appState.isPlusMember { return "Plus Is Active" }
        guard let price = purchases.displayPrice(.plus, annual: selectedPlanIsAnnual) else {
            return priceUnavailableText
        }
        if let trial = purchases.trialDescription(.plus, annual: selectedPlanIsAnnual) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return "Subscribe for \(price)"
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
        let trial = purchases.trialDescription(plan, annual: annual).map { " (includes \($0) free trial)" } ?? ""
        return "\(price) \(billing)\(trial)"
    }

    private var savingsText: String? {
        guard let monthly = purchases.product(.plus, annual: false), let annual = purchases.product(.plus, annual: true),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        return "Save \(NSDecimalNumber(decimal: saving).intValue)%"
    }

    private func purchase() async {
        guard let tier = await purchases.purchase(.plus, annual: selectedPlanIsAnnual) else { return }
        appState.showToast(tier == .premium ? "🎉 DateSnap Premium is active" : "🎉 Welcome to DateSnap Plus!")
        dismiss()
    }

    private func restore() async {
        guard let tier = await purchases.restore() else { return }
        if tier == .starter {
            appState.showToast("No active subscription found to restore")
        } else {
            appState.showToast("✓ \(tier.displayName) restored")
            dismiss()
        }
    }
    
    @ViewBuilder
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text(subtitle)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
