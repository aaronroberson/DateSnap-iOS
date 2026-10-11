import SwiftUI
import UIKit

struct NotificationPermissionDeniedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDTopBar(title: "Notification access")
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(LinearGradient.pdSignature)
                            .frame(width: 96, height: 96)
                            .background(Color.pdSurfaceContainerHigh, in: RoundedRectangle(cornerRadius: PDRadius.plan))
                            .accessibilityHidden(true)
                        PDScreenIntro(
                            eyebrow: "Notification permission",
                            title: "Pencil'd Alerts Are Turned Off",
                            subtitle: "Allow notifications to receive the local alerts you choose for your saved events. Your Calendar events are still available."
                        )
                    }
                    PDCard(highlighted: true) {
                        benefitRow(icon: "bell.badge", title: "A reminder before your event", description: "Choose alert times while reviewing an event or editing its reminder schedule. Pencil'd schedules those alerts on your device.")
                    }
                    PDSectionHeader(title: "What still works without Pencil'd alerts")
                    PDCard {
                        VStack(alignment: .leading, spacing: 16) {
                            benefitRow(icon: "calendar", title: "Apple Calendar", description: "Saved Calendar events stay in Apple Calendar. Calendar alarms follow your Calendar settings and permissions.")
                            benefitRow(icon: "checklist", title: "Apple Reminders", description: "Tasks saved to Apple Reminders remain there. Their notifications follow the Reminders app's settings.")
                            benefitRow(icon: "doc.text.viewfinder", title: "Scan and review", description: "Read an image, review its dates, and choose what to save without enabling Pencil'd notifications.")
                        }
                    }
                    PDCard {
                        VStack(alignment: .leading, spacing: 8) {
                            PDSectionHeader(title: "Enable notifications")
                            Text("Open iOS Settings, select Pencil'd → Notifications, and turn on Allow Notifications.")
                                .font(PDFont.bodyMD)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            Label("Enable in iOS Settings", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        Button {
                            appState.showToast("Pencil'd local alerts remain muted")
                            dismiss()
                        } label: {
                            Text("Keep Pencil'd Alerts Muted")
                        }
                        .buttonStyle(DSSecondaryButtonStyle())
                    }
                    Text("You can change notification access anytime in iOS Settings.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, PDSpacing.margin)
                .padding(.top, PDSpacing.sm)
                .padding(.bottom, PDSpacing.lg)
            }
            .dsScreenBackground()
        }
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PDIconTile(systemName: icon, tint: .pdPrimary, size: .large)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                Text(description).font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
