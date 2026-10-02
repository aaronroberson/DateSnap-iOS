import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchases = PurchaseViewModel()
    
    @State private var selectedPlanIsAnnual: Bool = true
    
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
                    
                    // Eyebrow & Hero Header
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text("DATESNAP PREMIUM")
                                .font(DSTypography.overlineConfidence())
                        }
                        .foregroundStyle(Color.dsWarning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.dsWarning.opacity(0.12))
                                .overlay(Capsule().stroke(Color.dsWarning.opacity(0.3), lineWidth: 1))
                        )
                        
                        Text("Turn flyers and files into plans.")
                            .font(DSTypography.displayTitle())
                            .foregroundStyle(Color.dsForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                        
                        Text("Import event PDFs and images from Files, then save the important dates in seconds.")
                            .font(DSTypography.bodyBase())
                            .foregroundStyle(Color.dsMutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Hero Visual Showcase Card
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dsAccent.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Color.dsAccent)
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SUMMIT_2025.PDF")
                                    .font(DSTypography.bodyStrong())
                                    .foregroundStyle(Color.dsForeground)
                                Text("3 Pages · Multi-day Conference Schedule")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            Spacer()
                        }
                        
                        Divider().background(Color.dsBorder)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.dsPrimary)
                                    Text("Keynote & Panels Extracted")
                                        .font(DSTypography.bodyCompact())
                                        .foregroundStyle(Color.dsForeground)
                                }
                                Text("Oct 24 · 09:30 AM · Moscone Center SF")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            Spacer()
                            DSConfidencePill(score: 99, label: "MATCH")
                        }
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 20, elevated: true, borderColor: Color.dsWarning.opacity(0.4))
                    .padding(.horizontal)
                    
                    // Feature List
                    VStack(spacing: 12) {
                        featureRow(
                            icon: "infinity",
                            iconColor: Color.dsPrimary,
                            title: "Everything in DateSnap Plus",
                            subtitle: "Unlimited screenshot scans, 3-tiered reminders, and automated Apple Calendar synchronization."
                        )
                        
                        featureRow(
                            icon: "folder.badge.plus",
                            iconColor: Color.dsInfo,
                            title: "Files & Cloud Drive Import",
                            subtitle: "Import PDFs, itineraries, and flyers directly from iOS Files, iCloud Drive, and Dropbox."
                        )
                        
                        featureRow(
                            icon: "doc.on.doc.fill",
                            iconColor: Color.dsAccent,
                            title: "Multi-Page PDF Scanning",
                            subtitle: "Extract multi-day conference agendas, school schedules, and sports tourneys with one tap."
                        )
                        
                        featureRow(
                            icon: "square.stack.3d.up.fill",
                            iconColor: Color.dsSecondary,
                            title: "Batch Document Scanning",
                            subtitle: "Queue up to 10 event flyers, passes, or tickets at once with lightning on-device OCR."
                        )
                        
                        featureRow(
                            icon: "slider.horizontal.3",
                            iconColor: Color.dsSuccess,
                            title: "Advanced Calendar Rules",
                            subtitle: "Custom calendar color tagging, recurring scan routines, and location geofence alerts."
                        )
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // Pricing Selector Cards
                    VStack(spacing: 12) {
                        // Annual Card
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
                                    
                                    Text(annualPrice.isEmpty ? "Price unavailable" : "\(annualPrice) billed annually\(purchases.trialDescription(.premium, annual: true).map { " (includes \($0) free trial)" } ?? "")")
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                
                                Spacer()
                                
                                if !annualPrice.isEmpty {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(purchases.monthlyEquivalent(.premium))
                                            .font(DSTypography.headlineCard())
                                            .foregroundStyle(Color.dsForeground)
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
                        
                        // Monthly Card
                        Button {
                            selectedPlanIsAnnual = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly")
                                        .font(DSTypography.bodyStrong())
                                        .foregroundStyle(Color.dsForeground)
                                    
                                    Text(monthlyPrice.isEmpty ? "Price unavailable" : "\(monthlyPrice) billed monthly, cancel anytime")
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                
                                Spacer()
                                
                                if !monthlyPrice.isEmpty {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(monthlyPrice)
                                            .font(DSTypography.headlineCard())
                                            .foregroundStyle(Color.dsForeground)
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
                    .disabled(purchases.isPurchasing || purchases.isLoadingProducts || appState.isPremiumMember || !canPurchaseSelectedPlan)
                    .padding(.horizontal)
                    
                    // Reassurance & Terms
                    VStack(spacing: 12) {
                        if !selectedPrice.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dsSuccess)
                                Text("Renews at \(selectedPrice)/\(selectedPlanIsAnnual ? "yr" : "mo") until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions.")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            .padding(.horizontal)
                        }
                        
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
        if appState.isPremiumMember { return "Premium Is Active" }
        if appState.isPlusMember { return "Upgrade to Premium" }
        guard canPurchaseSelectedPlan else { return "Subscribe" }
        if let trial = purchases.trialDescription(.premium, annual: selectedPlanIsAnnual) {
            return "Start \(trial.capitalized) Free Trial"
        }
        return "Subscribe for \(selectedPrice)"
    }

    private var annualPrice: String { purchases.displayPrice(.premium, annual: true) }
    private var monthlyPrice: String { purchases.displayPrice(.premium, annual: false) }
    private var selectedPrice: String { purchases.displayPrice(.premium, annual: selectedPlanIsAnnual) }
    private var canPurchaseSelectedPlan: Bool { purchases.canPurchase(.premium, annual: selectedPlanIsAnnual) }

    private var savingsText: String? {
        guard let monthly = purchases.product(.premium, annual: false), let annual = purchases.product(.premium, annual: true),
              monthly.price > 0 else { return nil }
        let yearlyAtMonthly = monthly.price * 12
        let saving = (yearlyAtMonthly - annual.price) / yearlyAtMonthly * 100
        return "SAVE \(NSDecimalNumber(decimal: saving).intValue)%"
    }

    private func purchase() async {
        guard await purchases.purchase(.premium, annual: selectedPlanIsAnnual) != nil else { return }
        appState.showToast("🎉 Welcome to DateSnap Premium!")
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
