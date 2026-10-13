import SwiftUI
import UIKit

struct CalendarPermissionDeniedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDTopBar(title: "Calendar access")
                    hero
                    PDCard(highlighted: true) {
                        HStack(alignment: .top, spacing: 12) {
                            PDIconTile(systemName: "lock.shield", tint: .pdSecondary, size: .large)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Review first. Save when you're ready.")
                                    .font(PDFont.headlineSM)
                                    .foregroundStyle(Color.pdOnSurface)
                                Text("Pencil'd requests permission to add the events you approve. Scanning and reviewing don't require Calendar access.")
                                    .font(PDFont.bodyMD)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                        }
                    }
                    PDSectionHeader(title: "What still works right now")
                    PDCard {
                        VStack(alignment: .leading, spacing: 16) {
                            abilityRow(icon: "doc.text.viewfinder", title: "Scan and review", description: "Read dates from an image and edit the extracted details on your device.")
                            abilityRow(icon: "tray.full", title: "Keep a draft", description: "Leave the event in Review and come back when you're ready to save.")
                            abilityRow(icon: "checklist", title: "Other destinations", description: "Apple Reminders and Pencil'd alerts use their own permissions. Calendar access does not control them.")
                        }
                    }
                    PDCard {
                        VStack(alignment: .leading, spacing: 12) {
                            PDSectionHeader(title: "Enable Calendar access")
                            stepRow(number: "1", text: "Open iOS Settings.")
                            stepRow(number: "2", text: "Select Pencil'd, then Calendars.")
                            stepRow(number: "3", text: "Choose Add Events Only or Full Access, then return to Pencil'd.")
                        }
                    }
                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            Label("Open iOS Settings", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        Button {
                            appState.showToast("You can keep reviewing without Calendar access")
                            dismiss()
                        } label: {
                            Label("Not Now — Keep in Review", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(DSSecondaryButtonStyle())
                    }
                    Text("You can change Calendar access anytime in iOS Settings.")
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(LinearGradient.pdSignature)
                .frame(width: 96, height: 96)
                .background(Color.pdSurfaceContainerHigh, in: RoundedRectangle(cornerRadius: PDRadius.plan))
                .accessibilityHidden(true)
            PDScreenIntro(
                eyebrow: "Calendar permission",
                title: "Calendar Access is Off",
                subtitle: "Allow access to add the dates you review to Apple Calendar. Until then, your scans can stay in Review."
            )
        }
    }

    private func abilityRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PDIconTile(systemName: icon, tint: .pdSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                Text(description).font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdPrimary)
                .frame(width: 24, height: 24)
                .background(Color.pdPrimary.opacity(0.12), in: Circle())
            Text(text).font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }
}
