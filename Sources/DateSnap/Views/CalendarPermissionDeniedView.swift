import SwiftUI
import UIKit

struct CalendarPermissionDeniedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Top Bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.dsForeground)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.dsCardElevated))
                        }
                        
                        Spacer()
                        
                        Text("Permission Paused")
                            .font(DSTypography.overlineConfidence())
                            .foregroundStyle(Color.dsWarning)
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.dsMutedForeground)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.dsMuted))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // Hero Visual Warning Header
                    VStack(spacing: 14) {
                        ZStack {
                            // Atmospheric Glows
                            Circle()
                                .fill(Color(red: 255/255, green: 138/255, blue: 61/255).opacity(0.18))
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)
                            
                            // Elevated Glass Badge Card
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.dsCardElevated)
                                    .frame(width: 110, height: 110)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                    .shadow(radius: 16)
                                
                                // Apple Calendar Replica Glass Tile
                                VStack(spacing: 0) {
                                    Text("APR")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.dsPrimaryForeground)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 18)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(red: 255/255, green: 138/255, blue: 61/255), Color.dsWarning],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("24")
                                        .font(DSTypography.headlineSection())
                                        .foregroundStyle(Color.dsForeground)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.white.opacity(0.06))
                                }
                                .frame(width: 54, height: 56)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                
                                // Floating Lock / Warning Accent Shield
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color.dsCardElevated)
                                                .frame(width: 32, height: 32)
                                            Circle()
                                                .fill(Color.dsWarning.opacity(0.2))
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "lock.shield.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.dsWarning)
                                        }
                                        .offset(x: 6, y: 6)
                                    }
                                }
                                .frame(width: 110, height: 110)
                            }
                        }
                        
                        Text("Calendar access is turned off")
                            .font(DSTypography.displayTitle())
                            .foregroundStyle(Color.dsForeground)
                            .multilineTextAlignment(.center)
                        
                        Text("DateSnap needs access to write detected dates into your calendar. Don’t worry — your existing events remain completely private and are never read or stored.")
                            .font(DSTypography.bodyBase())
                            .foregroundStyle(Color.dsMutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.horizontal)
                    
                    // What you can still do right now
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.dsPrimary)
                            Text("What you can still do right now")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Spacer()
                            Text("Available")
                                .font(DSTypography.overlineConfidence())
                                .foregroundStyle(Color.dsSuccess)
                        }
                        
                        Divider().background(Color.dsBorder)
                        
                        abilityRow(
                            icon: "checklist",
                            title: "Apple Reminders Export",
                            description: "Export deadlines, tickets, and alerts directly to your native Reminders app without calendar access."
                        )
                        
                        abilityRow(
                            icon: "bell.badge.fill",
                            title: "DateSnap Local Push Alerts",
                            description: "Receive intelligent on-device notifications & pre-event sound cues for snapped screenshots."
                        )
                        
                        abilityRow(
                            icon: "square.and.pencil",
                            title: "Manual & Draft Saving",
                            description: "Parse flyers, copy formatted event info with 1-tap, or save smart drafts to review whenever ready."
                        )
                    }
                    .padding(18)
                    .dsGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // Instructions on how to enable
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(Color.dsInfo)
                            Text("To enable Calendar syncing:")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            stepRow(number: "1", text: "Open iPhone Settings")
                            stepRow(number: "2", text: "Scroll down to select DateSnap")
                            stepRow(number: "3", text: "Tap Calendars → select 'Add Events Only' or 'Full Access'")
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 18, elevated: true, borderColor: Color.dsInfo.opacity(0.3))
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Text("Open iPhone Settings")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        
                        Button {
                            appState.showToast("Your event is waiting in Review")
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down")
                                Text("Not Now — Keep in Review")
                            }
                        }
                        .buttonStyle(DSSecondaryButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .dsScreenBackground()
        }
    }
    
    @ViewBuilder
    private func abilityRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.dsSuccess)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text(description)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
        }
    }
    
    @ViewBuilder
    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dsInfo)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.dsInfo.opacity(0.16)))
            Text(text)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsForeground)
        }
    }
}
