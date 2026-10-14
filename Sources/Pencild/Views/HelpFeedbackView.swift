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
        FAQTopic(id: 1, icon: "cpu.fill", question: "How does Pencil’d find dates in screenshots?",
                 answer: "Pencil’d uses Apple Vision to recognize text. Rules-based extraction is the default; if Apple Intelligence is available and enabled, it can help interpret ambiguous flyers. Review the event details before saving."),
        FAQTopic(id: 2, icon: "arrow.triangle.2.circlepath", question: "Why did an event scan with the wrong time?",
                 answer: "Posters with stylized serif typography or multi-timezone notices (e.g. \"7 PM EST / 4 PM PST\") can sometimes lead to ambiguous matches. You can tap any parsed event card to manually adjust the time or date pill before saving, or use the crop preview tool to pinpoint the specific time lockup."),
        FAQTopic(id: 3, icon: "lock.shield.fill", question: "Are private photos uploaded to a cloud?",
                 answer: "Image text recognition runs on the device. If you save an event, Pencil’d writes it to the Calendar or Reminders destination you choose. Apple may sync those destinations according to your account settings."),
        FAQTopic(id: 4, icon: "arrow.left.arrow.right", question: "How do I export to Google or Outlook?",
                 answer: "Pencil’d can add an event to a calendar available through Apple Calendar. To use Google or Outlook calendars, add the account in iOS Settings > Calendar > Accounts and select its calendar when saving."),
    ]

    let topics: [SupportTopic] = [
        SupportTopic(id: "quickStart", icon: "book.fill", title: "Quick Start",
                     subtitle: "Scan and review an event",
                     body: "1. Choose a flyer image in Pencil’d.\n2. Review the dates and event details found in the image.\n3. Correct any details that need adjustment.\n4. Save the event to a Calendar or Reminders destination you choose."),
        SupportTopic(id: "troubleshootOCR", icon: "doc.text.viewfinder.fill", title: "Troubleshoot OCR",
                     subtitle: "Fix unread or blurred flyer dates",
                     body: "Blurred, small, or stylized text can be hard to recognize. Try a clearer image with the event details in focus. Check and correct the extracted date, time, and location before saving."),
        SupportTopic(id: "permissions", icon: "lock.open.fill", title: "Permissions",
                     subtitle: "Choose images and save destinations",
                     body: "Select an image when scanning. Calendar and Reminders access is requested when you choose to save an event there. You can review granted access in iOS Settings > Apps > Pencil’d."),
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
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Help & Feedback", showsBack: true) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pdOnPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.pdPrimary))
                        .accessibilityHidden(true)
                }

                PDScreenIntro(
                    eyebrow: "Pencil’d Help Center",
                    title: "How can we help?",
                    subtitle: "Search guides, troubleshooting advice, or get in touch with our team."
                )

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

                Text("Review extracted event details before saving.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, PDSpacing.xs)
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .sheet(item: $topicGuide) { topic in
            TopicGuideSheet(topic: topic)
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        PDSearchField(text: $query, prompt: "Search FAQs, docs, or guides...", accessibilityIdentifier: "help.search")
    }

    private var emptyResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(Color.pdOutline)
            Text("No matches for \"\(query)\"")
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurface)
            Text("Try \"OCR\", \"privacy\", or \"billing\".")
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceLow.opacity(0.9))
        )
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Quick Troubleshooting", trailing: "Tap to view")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(filteredTopics) { topic in
                    Button {
                        if topic.id == "manageBilling" {
                            settings.pendingRoute = .managePlan
                        } else {
                            topicGuide = topic
                        }
                    } label: {
                        PDCard {
                            VStack(alignment: .leading, spacing: 8) {
                                PDIconTile(systemName: topic.icon, tint: .pdPrimary)
                                Text(topic.title)
                                    .font(PDFont.labelLG)
                                    .foregroundStyle(Color.pdOnSurface)
                                    .lineLimit(1)
                                Text(topic.subtitle)
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                billingQuickAction
            }
        }
    }

    private var billingQuickAction: some View {
        Button {
            settings.pendingRoute = .managePlan
        } label: {
            PDCard {
                VStack(alignment: .leading, spacing: 8) {
                    PDIconTile(systemName: "creditcard.fill", tint: .pdTertiaryContainer)
                    Text("Manage Billing")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                        .lineLimit(1)
                    Text("Restore purchase or manage Pro")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Privacy Guarantee

    private var privacyGuarantee: some View {
        PDCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Image Processing")
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)
                Text("Text recognition uses Apple Vision on this device. Event suggestions come from rules-based extraction, with optional on-device Apple Intelligence interpretation when available.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Frequently Asked", trailing: "\(filteredFAQs.count) key topics")

            PDGroupedList {
                ForEach(filteredFAQs) { faq in
                    if faq.id != filteredFAQs.first?.id {
                        PDRowDivider()
                    }
                    faqRow(faq)
                }
            }
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
                HStack(spacing: 12) {
                    PDIconTile(systemName: faq.icon, tint: .pdSecondary)
                    Text(faq.question)
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.pdOutline)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                if isExpanded {
                    Text(faq.answer)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .padding(.leading, 32 + 12)
                }
            }
            .padding(PDSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(PDRowButtonStyle())
    }

    // MARK: - Human Support

    private var humanSupport: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Get Support")

            PDGroupedList {
                Button {
                    if let url = PencildLinks.supportMail(subject: "Pencil’d Support Request") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    PDListRow(
                        icon: "envelope.fill",
                        tint: .pdPrimary,
                        title: "Send Message to Support",
                        subtitle: "Email \(PencildLinks.supportEmail)"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.pdOutline)
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button {
                    topicGuide = SupportTopic(id: "bugReport", icon: "ant.fill", title: "Submit a Bug Report",
                                              subtitle: "Attach sanitized diagnostic capture logs",
                                              body: "Email \(PencildLinks.supportEmail) with your diagnostic summary (copied below), the iOS version, and a screenshot of the failing scan. Diagnostic captures are sanitized on-device — no photo content is ever attached.")
                } label: {
                    PDListRow(
                        icon: "ant.fill",
                        tint: .pdError,
                        title: "Submit a Bug Report",
                        subtitle: "Attach sanitized diagnostic capture logs"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.pdOutline)
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button {
                    topicGuide = SupportTopic(id: "featureRequest", icon: "lightbulb.fill", title: "Request a Feature",
                                              subtitle: "Help shape our next scheduled release",
                                              body: "Feature requests go straight to the engineering backlog. Send your idea to \(PencildLinks.supportEmail) with the subject \"Feature Request\" — the roadmap for the next scheduled release is shaped by the most-requested items each cycle.")
                } label: {
                    PDListRow(
                        icon: "lightbulb.fill",
                        tint: .pdWarning,
                        title: "Request a Feature",
                        subtitle: "Help shape our next scheduled release"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.pdOutline)
                    }
                }
                .buttonStyle(PDRowButtonStyle())
            }
        }
    }

    // MARK: - App Environment

    private var appEnvironment: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "App Environment")

            PDCard {
                VStack(spacing: 12) {
                    envRow("Pencil’d Version", appVersion)
                    envRow("iOS Version", UIDevice.current.systemVersion)

                    Button {
                        UIPasteboard.general.string = diagnosticSummary
                        appState.showToast("Diagnostic data copied")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Copy Diagnostic Summary")
                        }
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.pdPrimary.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.pdPrimary.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func envRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
            Spacer()
            Text(value)
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurface)
        }
    }

    private var diagnosticSummary: String {
        """
        Pencil’d Diagnostic Summary
        ---------------------------
        Pencil’d Version: \(appVersion)
        iOS Version: \(UIDevice.current.systemVersion)
        """
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(short) (\(build))"
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
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.pdOutline)
                }
            }
            HStack(spacing: 12) {
                PDIconTile(systemName: topic.icon, tint: .pdPrimary, size: .large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    Text(topic.subtitle)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            Text(topic.body)
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(3)
            Spacer()
            Button {
                dismiss()
                appState.showToast("✓ Guide completed")
            } label: {
                Text("Got it")
            }
            .buttonStyle(PDGradientButtonStyle())
        }
        .padding(20)
        .background(Color.pdSurface.ignoresSafeArea())
    }
}
