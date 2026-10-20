import SwiftUI
import StoreKit

/// Tells the member their plan is ending or has a payment problem, with the Apple sheet that
/// fixes it. Shows nothing for healthy plans. Icon, label, and color carry the state together.
struct SubscriptionStatusBanner: View {
    @EnvironmentObject private var appState: AppState
    @State private var showManageSubscriptions = false

    private var notice: SubscriptionNotice {
        _ = appState.entitlementSnapshot // re-evaluate whenever the entitlement changes
        return SubscriptionNotice.derive(from: EntitlementCache.load())
    }

    var body: some View {
        Group {
            switch notice {
            case .none:
                EmptyView()
            case .endsSoon(let tier, let date):
                banner(
                    icon: "hourglass", tone: .warning, badge: "Ending soon",
                    title: "\(tier.displayName) ends \(date.formatted(date: .abbreviated, time: .omitted))",
                    detail: "You keep full access until then. Renew to keep it.",
                    action: "Renew"
                )
            case .paymentIssue(let tier, let date):
                banner(
                    icon: "creditcard.trianglebadge.exclamationmark", tone: .error, badge: "Payment issue",
                    title: "Apple couldn’t renew \(tier.displayName)",
                    detail: "Update your payment method by \(date.formatted(date: .abbreviated, time: .omitted)) to keep access.",
                    action: "Update payment"
                )
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    private func banner(icon: String, tone: PDStatusBadge.Tone, badge: String, title: String, detail: String, action: String) -> some View {
        PDCard {
            VStack(alignment: .leading, spacing: PDSpacing.xs) {
                PDStatusBadge(text: badge, icon: icon, tone: tone)
                Text(title)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text(detail)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action) { showManageSubscriptions = true }
                    .buttonStyle(PDSecondaryButtonStyle(minHeight: 44))
            }
        }
        .accessibilityElement(children: .contain)
    }
}
