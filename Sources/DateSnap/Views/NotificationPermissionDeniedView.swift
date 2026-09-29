import SwiftUI
import UIKit

struct NotificationPermissionDeniedView: View {
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
                        
                        Text("Alerts Paused")
                            .font(DSTypography.overlineConfidence())
                            .foregroundStyle(Color.dsAccent)
                        
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
                    
                    // Hero Muted Bell Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.dsAccent.opacity(0.15))
                                .frame(width: 110, height: 110)
                                .blur(radius: 16)
                            
                            ZStack(alignment: .bottomTrailing) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.dsCardElevated, Color.dsCard],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                    
                                    Image(systemName: "bell.slash.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                
                                // Warning status indicator dot
                                Circle()
                                    .fill(Color.dsWarning)
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().fill(Color.dsBackground).frame(width: 8, height: 8))
                                    .offset(x: 2, y: 2)
                            }
                        }
                        
                        Text("Notifications are muted")
                            .font(DSTypography.displayTitle())
                            .foregroundStyle(Color.dsForeground)
                            .multilineTextAlignment(.center)
                        
                        Text("Without notification permission, DateSnap can't alert you when new dates are detected in screenshots or remind you before an event begins.")
                            .font(DSTypography.bodyBase())
                            .foregroundStyle(Color.dsMutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.horizontal)
                    
                    // Why enable notifications?
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color.dsPrimary)
                            Text("Why enable notifications?")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                        }
                        
                        benefitRow(
                            icon: "clock.badge.checkmark.fill",
                            title: "Smart Lead-Time Alerts",
                            description: "Get notified 1 day or 2 hours prior to events so you never miss departure windows or RSVP deadlines."
                        )
                        
                        benefitRow(
                            icon: "camera.viewfinder",
                            title: "Instant Screenshot Detection",
                            description: "Immediate frictionless banner prompt right after a concert flyer, ticket, or chat invite is saved in Photos."
                        )
                    }
                    .padding(18)
                    .dsGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // What still works without alerts
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dsSuccess)
                            Text("What still works without alerts")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                        }
                        
                        stillWorksRow(
                            icon: "calendar",
                            title: "Direct Apple Calendar Sync",
                            description: "Events are still added directly into your Apple Calendar and will sound standard iOS native calendar alarms."
                        )
                        
                        stillWorksRow(
                            icon: "checklist",
                            title: "Apple Reminders Integration",
                            description: "Scheduled tasks and checklist entries continue to synchronize and trigger reminders seamlessly."
                        )
                    }
                    .padding(18)
                    .dsGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // Quick Path
                    HStack(spacing: 6) {
                        Text("Settings")
                        Image(systemName: "chevron.right").font(.system(size: 10))
                        Text("DateSnap")
                        Image(systemName: "chevron.right").font(.system(size: 10))
                        Text("Notifications")
                        Image(systemName: "chevron.right").font(.system(size: 10))
                        Text("Allow")
                            .foregroundStyle(Color.dsPrimary)
                    }
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Text("Enable in Settings")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        
                        Button {
                            appState.showToast("Continuing with Apple Calendar alarms")
                            dismiss()
                        } label: {
                            Text("Keep Alerts Muted & Rely on Calendar")
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
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dsPrimary.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dsPrimary)
            }
            
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
    private func stillWorksRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dsSuccess.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dsSuccess)
            }
            
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
}
