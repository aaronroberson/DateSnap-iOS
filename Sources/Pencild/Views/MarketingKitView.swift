import SwiftUI
import UIKit

#if DEBUG
// Launch Marketing Kit — approved campaign copy: social angles,
// ad headlines, CTAs and the launch email sequence.
struct MarketingKitView: View {
    @EnvironmentObject private var appState: AppState

    let subjectLine = "Stop losing dates in your camera roll 📸 ➔ 🗓️"
    let previewText = "Pencil’d's on-device AI turns your flyers and screenshots into Apple Calendar events in seconds."

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Marketing Kit", showBack: true)
                hero
                socialAngles
                adHeadlines
                emailCampaign
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .pdScreenBackground()
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(colors: [Color.pdSecondary.opacity(0.35), Color.pdTertiaryContainer.opacity(0.22), Color.pdSurface.opacity(0.4)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                // Floating calendar cards echoing the hero artwork
                PDDateBadge(month: "OCT", day: "24", highlighted: true)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -78, y: -8)
                PDDateBadge(month: "OCT", day: "18")
                    .rotationEffect(.degrees(9))
                    .offset(x: 82, y: 14)
                VStack(spacing: 4) {
                    Text("Pencil’d")
                        .font(PDFont.display)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Precision Temporal AI")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(LinearGradient.pdSignature)
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)

            ValueChip(text: "OFFICIAL LAUNCH & MARKETING KIT", tint: .pdTertiaryContainer, systemImage: "megaphone.fill")

            VStack(spacing: 8) {
                Text("Never Miss a Moment You Saved.")
                    .font(PDFont.headlineMD)
                    .foregroundStyle(Color.pdOnSurface)
                    .multilineTextAlignment(.center)
                Text("Turn concert flyers, event screenshots, and chat invites into calibrated calendar reminders in 0.12 seconds — 100% on-device.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .pdGlassCard()
    }

    // MARK: - 01 Social Media Angles

    private var socialAngles: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "number", title: "01 · Social Media Angles", tint: .pdSecondary)
            VStack(spacing: 14) {
                copyBlock("Headline Hook", "X / Instagram",
                          quote: "“Your camera roll is where event plans go to die. We fixed that.”",
                          body: "Pencil’d reads dates from concert posters, festival lineups, and group chats like a human. 0.12s on-device OCR, zero cloud lag, zero privacy compromises.")
                Divider().overlay(Color.pdOutlineVariant)
                copyBlock("Feature Spotlight", "LinkedIn / Tech",
                          quote: "“Introducing Temporal AI: Instant Natural Language Extraction on iOS.”",
                          body: "'Tomorrow 10am', 'Next Friday at 9' — parsed instantly into structured Apple Calendar events with 3-tier staggered alerts.")
            }
            .padding(16)
            .pdGlassCard()
        }
    }

    private func copyBlock(_ title: String, _ channel: String, quote: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(PDFont.bodyMD.weight(.semibold))
                    .foregroundStyle(Color.pdOnSurface)
                ValueChip(text: channel, tint: .pdSecondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = "\(quote)\n\n\(body)"
                    appState.showToast("Copy copied to clipboard")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            Text(quote)
                .font(PDFont.bodyMD.weight(.semibold))
                .foregroundStyle(Color.pdPrimary)
            Text(body)
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }

    // MARK: - 02 Ad Headlines & CTAs

    private var adHeadlines: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "megaphone.fill", title: "02 · Ad Headlines & CTAs", tint: .pdTertiaryContainer)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRIMARY AD HEADLINE")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Text("“Screenshot Today. Scheduled Forever.”")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(["100% On-Device Neural Processing",
                             "Instant Apple Calendar & Reminders Sync",
                             "3-Tier Smart Alert Staging"], id: \.self) { bullet in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(PDFont.labelSM)
                                .foregroundStyle(Color.pdOnPrimaryFixed)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Color.pdSuccess))
                            Text(bullet)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                }

                Divider().overlay(Color.pdOutlineVariant)

                Text("HIGH-CONVERSION CALL TO ACTIONS")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                HStack(spacing: 10) {
                    Button {
                        appState.showToast("App Store campaign link opened")
                    } label: {
                        Text("Try Free on App Store")
                    }
                    .buttonStyle(PDPrimaryButtonStyle(minHeight: 42))
                    Button {
                        appState.showToast("7-day trial claim link opened")
                    } label: {
                        Text("Claim 7-Day Trial")
                    }
                    .buttonStyle(PDSecondaryButtonStyle(minHeight: 42))
                }
            }
            .padding(16)
            .pdGlassCard()
        }
    }

    // MARK: - Email Campaign

    private var emailCampaign: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "envelope.fill", title: "Email Campaign",
                                  tint: .pdInfo, trailing: "3-Touch Announcement")
            VStack(alignment: .leading, spacing: 12) {
                Text("Product Launch Email Announcement")
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)

                copyableRow("SUBJECT", subjectLine)
                copyableRow("PREVIEW TEXT", previewText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hey there,")
                    Text("How many times have you screenshotted a festival flyer, a party invitation, or a ticket drop date... only to completely forget about it until the day after?")
                    Text("We built Pencil’d to end that frustration forever. Using local CoreML and Apple's Neural Engine, Pencil’d scans any screenshot in 0.12 seconds, extracts relative dates like \"Next Friday at 9\", and schedules 3-tier custom alerts across Apple Calendar and Reminders.")
                    Text("✨ What you get:")
                    VStack(alignment: .leading, spacing: 5) {
                        emailBullet("100% On-Device Privacy", "Zero cloud uploads, zero telemetry. Your photos stay strictly in local memory.")
                        emailBullet("3-Tier Staggered Alerts", "24h outfit/ticket prep, departure transit alarms, and gate-opening push pings.")
                        emailBullet("Zero Manual Typing", "Automatic titles, locations, links, and auto-purged screenshot storage.")
                    }
                    Text("Download Pencil’d on the iOS App Store today and experience seamless screenshot-to-calendar superpowers.")
                }
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)

                Button {
                    appState.showToast("App Store campaign link opened")
                } label: {
                    HStack {
                        Text("Get Pencil’d on the App Store")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PDPrimaryButtonStyle(minHeight: 46))
            }
            .padding(16)
            .pdGlassCard()
        }
    }

    private func emailBullet(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.pdTertiaryContainer)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PDFont.bodySM.weight(.bold))
                    .foregroundStyle(Color.pdOnSurface)
                Text(body)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
    }

    private func copyableRow(_ label: String, _ content: String) -> some View {
        Button {
            UIPasteboard.general.string = content
            appState.showToast("\(label.lowercased()) copied to clipboard")
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(label)
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .frame(width: 80, alignment: .leading)
                Text(content)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurface)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pdPrimary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.pdSurfaceHighest))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
