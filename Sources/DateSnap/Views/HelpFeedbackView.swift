import SwiftUI
import UIKit

// Help & Feedback — care hub with searchable FAQs, topic guides,
// support channels and a diagnostic summary. Pushed from Settings Hub.
struct HelpFeedbackView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @State private var query = ""
    @State private var expandedFAQ: FAQTopic? = nil
    @State private var topicGuide: SupportTopic? = nil

    struct FAQTopic: Identifiable {
        let id: Int
        let icon: String
        let question: String
        let answer: String
    }

    struct SupportTopic: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let body: String
    }

    let faqs: [FAQTopic] = [
        FAQTopic(id: 1, icon: "cpu.fill", question: "How does DateSnap find dates in screenshots?",
                 answer: "DateSnap utilizes CoreML and on-device natural language parsing. When you snap or select an image, the app isolates date phrases (like \"Next Thursday at 8 PM\" or \"Nov 14-16\"), extracts temporal context, and formulates standard calendar records without sending your photo to any third-party server."),
        FAQTopic(id: 2, icon: "arrow.triangle.2.circlepath", question: "Why did an event scan with the wrong time?",
                 answer: "Posters with stylized serif typography or multi-timezone notices (e.g. \"7 PM EST / 4 PM PST\") can sometimes lead to ambiguous matches. You can tap any parsed event card to manually adjust the time or date pill before saving, or use the crop preview tool to pinpoint the specific time lockup."),
        FAQTopic(id: 3, icon: "lock.shield.fill", question: "Are private photos uploaded to a cloud?",
                 answer: "Never. Your visual camera roll remains entirely localized. No screenshots, images, OCR strings, or metadata leave your physical device. We uphold a strict zero-telemetry media policy so your tickets, personal chats, and medical appointments stay private."),
        FAQTopic(id: 4, icon: "arrow.left.arrow.right", question: "How do I export to Google or Outlook?",
                 answer: "DateSnap seamlessly bridges into your default system EventKit calendar. If your iPhone already syncs with Google Calendar, Microsoft Exchange, or Outlook in iOS Settings > Calendar > Accounts, DateSnap automatically deposits your verified dates into your preferred cloud schedule."),
    ]

    let topics: [SupportTopic] = [
        SupportTopic(id: "quickStart", icon: "book.fill", title: "Quick Start",
                     subtitle: "Master screenshot capture in 2 mins",
                     body: "1. Screenshot any flyer, invite, or ticket.\n2. Open DateSnap — the Neural Intake Engine scans automatically.\n3. Review the parsed event card and adjust date or time pills if needed.\n4. Save to Apple Calendar & Reminders with 3-tier staggered alerts."),
        SupportTopic(id: "troubleshootOCR", icon: "doc.text.viewfinder.fill", title: "Troubleshoot OCR",
                     subtitle: "Fix unread or blurred flyer dates",
                     body: "Blurry or stylized dates are the most common OCR failure. Crop the scan preview to isolate the date lockup, raise the Confidence Threshold in Automation Settings to 85%+, or enable Draft Low Confidence Events so ambiguous scans land in your review tray instead of being discarded."),
        SupportTopic(id: "permissions", icon: "lock.open.fill", title: "Permissions",
                     subtitle: "Enable Calendar & Photos sync",
                     body: "DateSnap needs Photos access (read-only) to intake screenshots and Calendar access (write-only) to save events. If a permission was denied, open iOS Settings > DateSnap and toggle Photos & Calendars back on. The app works fully on-device either way."),
    ]

    var filteredFAQs: [FAQTopic] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return faqs }
        return faqs.filter { $0.question.localizedCaseInsensitiveContains(query) || $0.answer.localizedCaseInsensitiveContains(query) }
    }

    var filteredTopics: [SupportTopic] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return topics }
        return topics.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Help & Feedback", showBack: true)
                careHeader
                searchBar
                if filteredTopics.isEmpty && filteredFAQs.isEmpty {
                    emptyResults
                } else {
                    if !filteredTopics.isEmpty { quickActions }
                    privacyGuarantee
                    if !filteredFAQs.isEmpty { faqSection }
                }
                humanSupport
                appEnvironment
                bottomLinks
                SettingsFooterNote(lines: ["DateSnap respects your time and peace of mind. All data extracted remains strictly yours."])
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .sheet(item: $topicGuide) { topic in
            TopicGuideSheet(topic: topic)
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header & Search

    private var careHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATESNAP CARE HUB")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsPrimary)
            HStack(alignment: .firstTextBaseline) {
                Text("How can we help?")
                    .font(DSTypography.displayTitle())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                ValueChip(text: "Systems 100% On-Device", tint: .dsSuccess, systemImage: "checkmark.shield.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dsMutedForeground)
            TextField("Search FAQs, docs, or guides...", text: $query)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .dsGlassCard(cornerRadius: 16)
    }

    private var emptyResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(Color.dsMutedForeground)
            Text("No matches for \"\(query)\"")
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
            Text("Try \"OCR\", \"privacy\", or \"billing\".")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .dsGlassCard()
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "wrench.and.screwdriver.fill", title: "Quick Troubleshooting",
                                  tint: .dsSecondary, trailing: "Tap to view")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(filteredTopics) { topic in
                    Button {
                        if topic.id == "manageBilling" {
                            settings.pendingRoute = SettingsRoute.managePlan.rawValue
                        } else {
                            topicGuide = topic
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: topic.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.dsPrimary)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsPrimary.opacity(0.12)))
                            Text(topic.title)
                                .font(DSTypography.bodyCompact().weight(.semibold))
                                .foregroundStyle(Color.dsForeground)
                                .lineLimit(1)
                            Text(topic.subtitle)
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .dsGlassCard(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }
                billingQuickAction
            }
        }
    }

    private var billingQuickAction: some View {
        Button {
            settings.pendingRoute = SettingsRoute.managePlan.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dsAccent)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsAccent.opacity(0.12)))
                Text("Manage Billing")
                    .font(DSTypography.bodyCompact().weight(.semibold))
                    .foregroundStyle(Color.dsForeground)
                    .lineLimit(1)
                Text("Restore purchase or manage Pro")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .dsGlassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Privacy Guarantee

    private var privacyGuarantee: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The DateSnap Privacy Guarantee")
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsForeground)
            Text("Unlike cloud scanners, DateSnap processes your personal screenshots strictly on-device utilizing the local Apple Neural Engine.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
            HStack(spacing: 10) {
                guaranteeStat("Processing", "0.12s", "Local NPU")
                guaranteeStat("Cloud Upload", "0 Bytes", "Air-Gapped")
                guaranteeStat("Accuracy", "99.4%", "Temporal AI")
            }
        }
        .padding(16)
        .dsGlassCard(borderColor: Color.dsSuccess.opacity(0.3))
    }

    private func guaranteeStat(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.dsMutedForeground)
            Text(value)
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsSuccess)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Color.dsMutedForeground.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsMuted))
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "questionmark.bubble.fill", title: "Frequently Asked",
                                  tint: .dsPrimary, trailing: "\(filteredFAQs.count) key topics")
            VStack(spacing: 4) {
                ForEach(filteredFAQs) { faq in
                    faqRow(faq)
                    if faq.id != filteredFAQs.last?.id {
                        Divider().overlay(Color.dsBorder)
                    }
                }
            }
            .padding(.horizontal, 16)
            .dsGlassCard()
        }
    }

    private func faqRow(_ faq: FAQTopic) -> some View {
        let isExpanded = expandedFAQ?.id == faq.id
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                expandedFAQ = isExpanded ? nil : faq
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: faq.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dsSecondary)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.dsSecondary.opacity(0.14)))
                    Text(faq.question)
                        .font(DSTypography.bodyCompact().weight(.semibold))
                        .foregroundStyle(Color.dsForeground)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.dsMutedForeground)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                if isExpanded {
                    Text(faq.answer)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Human Support

    private var humanSupport: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "headphones", title: "Get Human Support",
                                  tint: .dsInfo, trailing: "Reply < 2 hrs")
            VStack(spacing: 14) {
                Button {
                    if let url = URL(string: "mailto:support@datesnap.app?subject=DateSnap%20Support%20Request") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    SettingRow(icon: "envelope.fill", iconTint: .dsPrimary,
                               title: "Send Message to Support",
                               subtitle: "Direct access to DateSnap core engineers") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    topicGuide = SupportTopic(id: "bugReport", icon: "ant.fill", title: "Submit a Bug Report",
                                              subtitle: "Attach sanitized diagnostic capture logs",
                                              body: "Email support@datesnap.app with your diagnostic summary (copied below), the iOS version, and a screenshot of the failing scan. Diagnostic captures are sanitized on-device — no photo content is ever attached.")
                } label: {
                    SettingRow(icon: "ant.fill", iconTint: .dsError,
                               title: "Submit a Bug Report",
                               subtitle: "Attach sanitized diagnostic capture logs") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    topicGuide = SupportTopic(id: "featureRequest", icon: "lightbulb.fill", title: "Request a Feature",
                                              subtitle: "Help shape our next scheduled release",
                                              body: "Feature requests go straight to the engineering backlog. Send your idea to support@datesnap.app with the subject \"Feature Request\" — the roadmap for the next scheduled release is shaped by the most-requested items each cycle.")
                } label: {
                    SettingRow(icon: "lightbulb.fill", iconTint: .dsWarning,
                               title: "Request a Feature",
                               subtitle: "Help shape our next scheduled release") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - App Environment

    private var appEnvironment: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "terminal", title: "App Environment",
                                  tint: .dsSuccess, trailing: "Ready")
            VStack(spacing: 12) {
                envRow("Client Version", "v4.2.1 (Build 4802)")
                envRow("Core Engine", "Apple Neural v18.2")
                envRow("Local Vision OCR", "Hardware Accelerated")
                envRow("Calendar Bridge", "Connected (Full Sync)")

                Divider().overlay(Color.dsBorder)

                Button {
                    UIPasteboard.general.string = diagnosticSummary
                    appState.showToast("Diagnostic data copied")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy Diagnostic Summary")
                    }
                    .font(DSTypography.labelChip())
                    .foregroundStyle(Color.dsPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.dsPrimary.opacity(0.1)))
                    .overlay(Capsule().stroke(Color.dsPrimary.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private func envRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
            Spacer()
            Text(value)
                .font(DSTypography.labelChip())
                .foregroundStyle(Color.dsForeground)
        }
    }

    private var diagnosticSummary: String {
        """
        DateSnap Diagnostic Summary
        ---------------------------
        Client: v4.2.1 (Build 4802)
        Core Engine: Apple Neural v18.2
        Local Vision OCR: Hardware Accelerated
        Calendar Bridge: Connected (Full Sync)
        Scan Profile: \(settings.scanProfile.rawValue)
        Confidence: \(Int(settings.confidence))%
        Zero-Cloud: Enabled
        """
    }

    private var bottomLinks: some View {
        HStack(spacing: 14) {
            Button {
                appState.showToast("Community Discord invite copied")
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                    Text("Community Discord")
                }
            }
            Text("|").foregroundStyle(Color.dsMutedForeground.opacity(0.4))
            Button {
                appState.showToast("Opening Release Notes…")
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.fill")
                    Text("Release Notes")
                }
            }
        }
        .font(DSTypography.caption())
        .foregroundStyle(Color.dsSecondary)
    }
}

// MARK: - Topic Guide Sheet (from the design's "Topic Guide / Got it" pattern)

private struct TopicGuideSheet: View {
    let topic: HelpFeedbackView.SupportTopic
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Topic Guide")
                    .font(DSTypography.headlineSection())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dsPrimary)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsPrimary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    Text(topic.subtitle)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }
            Text(topic.body)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsMutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Button {
                dismiss()
                appState.showToast("✓ Guide completed")
            } label: {
                Text("Got it")
            }
            .buttonStyle(DSPrimaryButtonStyle(minHeight: 48))
        }
        .padding(20)
        .dsScreenBackground()
    }
}
