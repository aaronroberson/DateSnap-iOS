import SwiftUI
import SwiftData
import Photos
import UIKit

struct SavedEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState

    /// Opening snapshot; persisted details remain the source of truth after edits.
    let snapshot: PencildEvent

    init(event: PencildEvent) { snapshot = event }

    private var candidate: EventCandidate? { SavedEventActions.candidate(id: snapshot.id, in: modelContext) }
    private var saved: SavedEvent? { candidate?.savedEvent }
    private var event: PencildEvent { candidate?.toPencildEvent() ?? snapshot }
    private var hasCalendarRecord: Bool { saved?.externalCalendarEventId != nil }
    private var hasReminder: Bool { !(saved?.externalReminderIds.isEmpty ?? true) || saved?.deadlineReminderId != nil }
    private var offsets: [ReminderOffset] { (saved?.alertOffsets ?? []).map(ReminderOffset.forInterval).sorted { $0.timeInterval < $1.timeInterval } }

    private var mapsURL: URL? {
        let query = [event.locationName, event.locationAddress]
            .filter { !$0.isEmpty && $0 != "Location TBA" }.joined(separator: ", ")
        guard !query.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    private var shareText: String {
        var lines = [event.title, "\(event.dayOfWeek), \(event.month) \(event.day), \(event.year) · \(event.timeWindow)"]
        if event.locationName != "Location TBA" { lines.append(event.locationName) }
        if !event.locationAddress.isEmpty && event.locationAddress != event.locationName { lines.append(event.locationAddress) }
        if !event.notes.isEmpty { lines.append(event.notes) }
        return lines.joined(separator: "\n")
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .pdScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var iPhoneLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Event details", showsBack: false) {
                    PDCloseButton(accessibilityLabel: "Close event details")
                }
                // Same order as Event Review: details, calendar & reminders, actions, then the source.
                saveStatus
                hero
                destinations
                reminders
                actions
                source
            }
            .padding(PDSpacing.md)
            .padding(.bottom, PDSpacing.lg)
        }
    }

    private var iPadLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            PDTopBar(title: "Event details", showsBack: false) {
                PDCloseButton(accessibilityLabel: "Close event details")
            }
            .padding(.horizontal, PDSpacing.lg)
            .padding(.top, PDSpacing.md)
            .padding(.bottom, PDSpacing.sm)

            HStack(alignment: .top, spacing: PDSpacing.lg) {
                // Left Column: Hero Overview, Status & Source Artifact
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PDSpacing.lg) {
                        saveStatus
                        hero
                        source
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, PDSpacing.xl)
                }
                .frame(maxWidth: .infinity)

                // Right Column: Destinations, Alerts/Reminders & Primary Actions
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PDSpacing.lg) {
                        destinations
                        reminders
                        actions
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, PDSpacing.xl)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, PDSpacing.lg)
        }
    }

    @ViewBuilder
    private var saveStatus: some View {
        if saved?.status == .archived {
            PDStatusBadge(text: "Archived in Pencil’d", icon: "archivebox.fill")
        } else if hasCalendarRecord {
            PDStatusBadge(text: "Saved to Apple Calendar", icon: "checkmark.circle.fill", tone: .success)
        } else {
            PDStatusBadge(text: saved?.status == .draft ? "Draft · not in Calendar" : "Not saved to Calendar", icon: "bookmark", tone: .warning)
        }
    }

    private var hero: some View {
        PDCard(highlighted: true) {
            VStack(alignment: .leading, spacing: PDSpacing.md) {
                HStack(alignment: .top, spacing: PDSpacing.md) {
                    PDDateBadge(month: event.month, day: event.day, highlighted: true)
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        if candidate != nil {
                            PDStatusBadge(text: "\(event.confidenceScore)% · \(event.confidenceLabel)", icon: "sparkles", tone: event.confidenceScore >= 80 ? .success : .warning)
                        }
                        Text(event.title)
                            .font(PDFont.headlineLG)
                            .foregroundStyle(Color.pdOnSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Label("\(event.dayOfWeek), \(event.month) \(event.day), \(event.year)", systemImage: "calendar")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurface)
                Label(event.timeWindow, systemImage: "clock")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                if let timeZone = event.timeZoneIdentifier {
                    Text(timeZone).font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                }
                HStack(alignment: .top, spacing: PDSpacing.sm) {
                    PDIconTile(systemName: "mappin.and.ellipse", tint: .pdTertiary)
                    VStack(alignment: .leading, spacing: PDSpacing.xxs) {
                        Text(event.locationName).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                        if !event.locationAddress.isEmpty && event.locationAddress != event.locationName {
                            Text(event.locationAddress).font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                    Spacer(minLength: 0)
                    if let mapsURL {
                        Button { openURL(mapsURL) } label: {
                            Label("Directions", systemImage: "arrow.up.right")
                                .font(PDFont.labelMD).foregroundStyle(Color.pdPrimary).frame(minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    private var destinations: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Calendar & reminders")
            PDGroupedList {
                PDListRow(icon: "calendar", title: "Apple Calendar", subtitle: saved?.targetCalendar) {
                    PDStatusBadge(text: hasCalendarRecord ? "Saved" : "Not saved", icon: hasCalendarRecord ? "checkmark.circle" : "minus.circle", tone: hasCalendarRecord ? .success : .neutral)
                }
                PDRowDivider()
                PDListRow(icon: "checklist", tint: .pdSecondary, title: "Apple Reminders", subtitle: hasReminder ? saved?.targetRemindersList : "No reminder saved") {
                    PDStatusBadge(text: hasReminder ? "Saved" : "Not saved", icon: hasReminder ? "checkmark.circle" : "minus.circle", tone: hasReminder ? .success : .neutral)
                }
            }
        }
    }

    private var source: some View {
        EventInterpretationDetailCard(candidate: candidate, event: event)
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Alerts", trailing: "\(offsets.count) alert\(offsets.count == 1 ? "" : "s")")
            PDCard {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    if offsets.isEmpty {
                        Text("No alerts configured. Open Alerts to add a reminder.")
                            .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    if let candidate {
                        ForEach(offsets) { offset in
                            let fireDate = offset.triggerDate(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay)
                            HStack(spacing: PDSpacing.sm) {
                                PDIconTile(systemName: "bell", tint: .pdSecondary)
                                VStack(alignment: .leading, spacing: PDSpacing.xxs) {
                                    Text(offset.label).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                                    Text(fireDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                Spacer()
                                if fireDate < Date() {
                                    PDStatusBadge(text: "Passed", icon: "clock")
                                }
                            }
                        }
                    }
                    if let saved {
                        Text(saved.status == .archived ? "Pencil’d notifications were cancelled when this event was archived. Calendar and Reminders entries remain." : "\(saved.scheduledNotificationIds.count) Pencil’d notification\(saved.scheduledNotificationIds.count == 1 ? "" : "s") scheduled when this event was saved.")
                            .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: PDSpacing.sm) {
            Button {
                if let start = candidate?.startDate, let url = URL(string: "calshow:\(start.timeIntervalSinceReferenceDate)") { openURL(url) }
            } label: {
                Label("Open in Apple Calendar", systemImage: "calendar")
            }
            .buttonStyle(PDPrimaryButtonStyle())
            .disabled(!hasCalendarRecord)
            HStack(spacing: PDSpacing.sm) {
                Button { Task { await appState.present(.eventReviewEdit(event)) } } label: {
                    Label("Edit", systemImage: "pencil").frame(maxWidth: .infinity, minHeight: 48)
                }
                Button { Task { await appState.present(.reminderScheduleEditor(event)) } } label: {
                    Label("Alerts", systemImage: "bell").frame(maxWidth: .infinity, minHeight: 48)
                }
                ShareLink(item: shareText, subject: Text(event.title)) {
                    Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .font(PDFont.labelMD).foregroundStyle(Color.pdSecondary)
            .buttonStyle(.plain)
            .background(Color.pdSurfaceLow, in: RoundedRectangle(cornerRadius: PDRadius.card))
            if let saved {
                Button {
                    let restoring = saved.status == .archived
                    let status: SavedEventStatus = restoring ? (saved.externalCalendarEventId != nil ? .saved : .draft) : .archived
                    let result = SavedEventActions(services: services, modelContext: modelContext).setStatus(status, for: saved)
                    switch result {
                    case .success: appState.showToast(restoring ? "Event restored" : "Event archived"); dismiss()
                    case .partial(let issues): appState.showToast(issues.joined(separator: "; "))
                    case .failure(let error): appState.showToast(error.localizedDescription)
                    }
                } label: {
                    Label(saved.status == .archived ? "Restore event" : "Archive event", systemImage: saved.status == .archived ? "arrow.uturn.backward" : "archivebox")
                        .font(PDFont.labelLG).foregroundStyle(Color.pdOnSurfaceVariant).frame(minHeight: 44)
                }
            }
        }
    }
}

/// Displays a real scan image from the in-session cache or an already-authorized local Photos asset.
/// Imported images without a retained local artifact show an honest absence state after the cache expires.
struct PDScanSourceThumbnail: View {
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState
    let candidate: EventCandidate
    var width: CGFloat? = 64
    var height: CGFloat = 76
    var contentMode: ContentMode = .fill
    @State private var fetchedImage: UIImage?
    @State private var loading = false

    private var image: UIImage? { appState.sourceImages[candidate.id] ?? fetchedImage }

    var body: some View {
        ZStack {
            Color.pdSurfaceHighest
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                VStack(spacing: PDSpacing.xxs) {
                    if loading { ProgressView().tint(.pdPrimary) }
                    else { Image(systemName: candidate.scannedAsset == nil ? "calendar.badge.plus" : "photo").font(.system(size: 20)) }
                    if width == nil {
                        Text(candidate.scannedAsset == nil ? "Manually entered event" : "Original image unavailable")
                            .font(PDFont.bodySM)
                    }
                }
                .foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
        .accessibilityLabel(image != nil ? "Original scan image" : (candidate.scannedAsset == nil ? "Manually entered event" : "Original image unavailable"))
        .task(id: candidate.scannedAsset?.assetIdentifier) { await loadImage() }
    }

    @MainActor
    private func loadImage() async {
        fetchedImage = nil
        guard appState.sourceImages[candidate.id] == nil,
              let identifier = candidate.scannedAsset?.assetIdentifier else { return }
        let authorization = services.photoLibrary.authorizationStatus(for: .readWrite)
        guard authorization == .authorized || authorization == .limited,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
        loading = true
        defer { loading = false }
        do {
            let result = try await services.photoLibrary.fetchImage(for: asset, targetSize: CGSize(width: 720, height: 960))
            guard !Task.isCancelled else { return }
            fetchedImage = result
        } catch {
            fetchedImage = nil
        }
    }
}
