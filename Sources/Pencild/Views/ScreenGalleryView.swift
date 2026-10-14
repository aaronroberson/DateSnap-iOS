import SwiftUI

#if DEBUG
// Developer screen gallery: jumps straight to any screen with sample data. Not shipped in Release.

struct ScreenGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsState: SettingsState

    struct ScreenItem: Identifiable {
        let id: Int
        let title: String
        let stitchId: String
        let description: String
        let category: String
        // nil for screens that live inside the Settings cluster tab.
        let modal: AppModalScreen?
        // Non-nil routes jump into the Settings cluster's navigation stack.
        var settingsRoute: SettingsRoute? = nil
        // Opens the Settings tab at its hub.
        var opensSettingsHub = false
    }
    
    let screens: [ScreenItem] = [
        ScreenItem(
            id: 1,
            title: "Premium Paywall",
            stitchId: "6c145dff8ec540b9a51f806629e55c70",
            description: "Files & Cloud Drive import, multi-page PDF scanning, batch docs & advanced rules.",
            category: "Monetization",
            modal: .paywall(opening: .premium)
        ),
        ScreenItem(
            id: 2,
            title: "Plus Paywall",
            stitchId: "df7a78364bd54941ad1d7bb6ca34d449",
            description: "Unlimited screenshot scans, up to 3 reminders per event & triple-destination sync.",
            category: "Monetization",
            modal: .paywall(opening: .plus)
        ),
        ScreenItem(
            id: 3,
            title: "History & Archive",
            stitchId: "e5fc50914c2f4a788389e8aa94806f45",
            description: "Saved, drafts, dismissed timeline with search and date badges.",
            category: "Navigation",
            modal: .screenGallery
        ),
        ScreenItem(
            id: 4,
            title: "Calendar Permission Denied",
            stitchId: "7d2a6476acc841b7be7374273debbf8b",
            description: "Guidance when calendar access is off, fallbacks to reminders and settings guide.",
            category: "Permissions",
            modal: .calendarPermissionDenied
        ),
        ScreenItem(
            id: 5,
            title: "Notification Permission Denied",
            stitchId: "1a0a6dacd22344d797031c2746da9b37",
            description: "Explains lead-time alert loss, background screenshot prompt loss, and iOS settings path.",
            category: "Permissions",
            modal: .notificationPermissionDenied
        ),
        ScreenItem(
            id: 6,
            title: "No Dates Found",
            stitchId: "d973f4ad48f2487ea6be61abce9b19ae",
            description: "Diagnostics for stylized text/memes, raw OCR word drawer, and manual event creation.",
            category: "Fallback",
            modal: .noDatesFound
        ),
        ScreenItem(
            id: 7,
            title: "Home Empty State",
            stitchId: "b04278172768466ead0f77aec1e7fefe",
            description: "Main dashboard first launch: quick screenshot scan, sample flyer demo, and 3-step guide.",
            category: "Core Flow",
            modal: .screenGallery
        ),
        ScreenItem(
            id: 8,
            title: "Saved Event Detail",
            stitchId: "79edd80432f24128889607dee9d678f4",
            description: "Full event card, directions, Apple Calendar & Reminders sync status, and active alerts.",
            category: "Core Flow",
            modal: .savedEventDetail(PencildEvent.sampleNeonSunset)
        ),
        ScreenItem(
            id: 9,
            title: "Event Review and Edit",
            stitchId: "50e76e9e2a6743a98d1f320729a3738a",
            description: "Editable title/date/time/location, original flyer preview, raw OCR, and target calendar.",
            category: "Core Flow",
            modal: .eventReviewEdit(PencildEvent.sampleNeonSunset)
        ),
        ScreenItem(
            id: 10,
            title: "Reminder Schedule Editor",
            stitchId: "fc49f1067442461dbf28c683626a3b70",
            description: "Multi-tier alert timing, smart presets (Default, Travel Heavy, Day-of), and channel picker.",
            category: "Core Flow",
            modal: .reminderScheduleEditor(PencildEvent.sampleNeonSunset)
        ),
        ScreenItem(
            id: 11,
            title: "Settings Hub",
            stitchId: "13afc2c3d70b4a17af72a22eb6d95c76",
            description: "Profile, scanning & capture, destinations, privacy toggles, billing and support entry points.",
            category: "Settings",
            modal: nil,
            opensSettingsHub: true
        ),
        ScreenItem(
            id: 12,
            title: "Privacy Center",
            stitchId: "f9c7e2f1aca7421c82525f43045ab75a",
            description: "Zero-cloud extraction story, permission audits, data retention controls and guarantees.",
            category: "Settings",
            modal: nil,
            settingsRoute: .privacyCenter
        ),
        ScreenItem(
            id: 13,
            title: "Automation Settings",
            stitchId: "2105db7c14814f13942cd114af3fe62c",
            description: "Scan automation profiles, capture scope, AI confidence tuning and energy throttling.",
            category: "Settings",
            modal: nil,
            settingsRoute: .automationSettings
        ),
        ScreenItem(
            id: 14,
            title: "Default Reminder Settings",
            stitchId: "58f1bf05191345a7af2c684f224c2328",
            description: "Alert architecture presets, editable timed alerts, delivery routing and live simulation.",
            category: "Settings",
            modal: nil,
            settingsRoute: .reminderSettings
        ),
        ScreenItem(
            id: 15,
            title: "Manage Plan",
            stitchId: "a3015fd164ce4033bc657057def892b9",
            description: "Active subscription, current benefits, Premium upsell and subscription controls.",
            category: "Settings",
            modal: nil,
            settingsRoute: .managePlan
        ),
        ScreenItem(
            id: 16,
            title: "Help & Feedback",
            stitchId: "d7e9d3167382422db57b310fdab3b92e",
            description: "Searchable care hub, quick troubleshooting guides, FAQs and diagnostic summary.",
            category: "Settings",
            modal: nil,
            settingsRoute: .helpFeedback
        ),
        ScreenItem(
            id: 17,
            title: "Launch Marketing Kit & Copy",
            stitchId: "286d9e56db644afcad350ce3efb2d320",
            description: "Official launch kit: social angles, ad headlines, CTAs and the email announcement.",
            category: "Settings",
            modal: nil,
            settingsRoute: .marketingKit
        ),
        ScreenItem(
            id: 18,
            title: "User Profile",
            stitchId: "80ec0320a47a4f6f9ff8c98bec1e6a5d",
            description: "Profile persona, productivity velocity bento, credentials and Pencil’d Pro spotlight.",
            category: "Account & Security",
            modal: .userProfile,
            settingsRoute: .userProfile
        ),
        ScreenItem(
            id: 19,
            title: "Verify Phone Number",
            stitchId: "1e01d494177a4ab4bff2ef6014d788e4",
            description: "Country code (+1), mobile input, SMS/WhatsApp delivery, and zero-spam privacy guarantee.",
            category: "Account & Security",
            modal: .userProfile
        ),
        ScreenItem(
            id: 20,
            title: "Enter Phone SMS Code",
            stitchId: "b01ff3968f5a41e091549e94981e6563",
            description: "6-digit OTP boxes, native iOS Messages autofill pill (849-204), and resend timer.",
            category: "Account & Security",
            modal: .userProfile
        ),
        ScreenItem(
            id: 21,
            title: "Verify Email Address",
            stitchId: "10feefa51f1a40699d59b22ebea70b22",
            description: "Email input, quick domain chips (@icloud.com), briefing and extraction receipt toggles.",
            category: "Account & Security",
            modal: .userProfile
        ),
        ScreenItem(
            id: 22,
            title: "Check Email Inbox",
            stitchId: "cf05d2e2cc52430093ad092c8a62d76c",
            description: "Magic link sent hero card, Open Mail App button, manual OTP fallback, and expiration timer.",
            category: "Account & Security",
            modal: .userProfile
        ),
        ScreenItem(
            id: 23,
            title: "Verification Complete",
            stitchId: "a77a1855fc904c529b04aada1d00c5a7",
            description: "Celebratory radiant checkmark crest, verified channel cards (SMS + Email), and feature summary.",
            category: "Account & Security",
            modal: .userProfile
        ),
        ScreenItem(
            id: 24,
            title: "Default Calendar",
            stitchId: "f3d0483edc2a43438cfa34e37205fecd",
            description: "Seamless Zero-Conflict Sync, iCloud & Google calendar account groupings, and a note that each event can override the default.",
            category: "Settings",
            modal: .defaultCalendar,
            settingsRoute: .defaultCalendar
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PENCIL'D DESIGN SYSTEM")
                                .font(PDFont.labelSM)
                                .foregroundStyle(Color.pdPrimary)
                            Text("All 24 Stitch Screens")
                                .font(PDFont.headlineXL)
                                .foregroundStyle(Color.pdOnSurface)
                        }
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdPrimary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    Text("Select any screen below to preview the implemented SwiftUI view, test navigation links, and verify interactive states:")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .padding(.horizontal)
                    
                    ForEach(screens) { item in
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if let route = item.settingsRoute {
                                appState.selectedTab = .settings
                                settingsState.pendingRoute = route
                            } else if item.opensSettingsHub {
                                appState.selectedTab = .settings
                            } else if item.id == 7 {
                                appState.selectedTab = .home
                            } else if item.id == 3 {
                                appState.openHistory()
                            } else if let modal = item.modal {
                                Task { await appState.present(modal) }
                            }
                        }
                    } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(item.id). \(item.title)")
                                        .font(PDFont.labelLG)
                                        .foregroundStyle(Color.pdOnSurface)
                                    Spacer()
                                    Text(item.category)
                                        .font(PDFont.labelSM)
                                        .foregroundStyle(Color.pdSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.pdSecondary.opacity(0.15)))
                                }
                                
                                Text(item.description)
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Text("Stitch ID: \(item.stitchId)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("Open")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(PDFont.labelMD)
                                    .foregroundStyle(Color.pdPrimary)
                                }
                                .padding(.top, 2)
                            }
                            .padding(14)
                            .pdGlassCard(cornerRadius: PDRadius.card)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .pdScreenBackground()
        }
    }
}
#endif
