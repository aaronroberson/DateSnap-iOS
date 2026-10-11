import SwiftUI
import EventKit

// MARK: - Default Calendar View
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Default-Calendar/design.html`.
/// Connects directly to EventKit via Pencil'd Services and `DefaultCalendarStore`.
struct DefaultCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @AppStorage("settings.askEveryTimeCalendar") private var askEveryTime = false

    private let store = DefaultCalendarStore()
    /// Mirrors the persisted choice so the list re-renders on tap (the store is a plain UserDefaults wrapper).
    @State private var selectedID: String?
    @State private var writableCalendars: [EKCalendar] = []
    @State private var systemDefault: EKCalendar? = nil
    @State private var authorization: EKAuthorizationStatus = .notDetermined
    @State private var loadFailed = false


    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.dsForeground)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.dsCard))
                    }

                    Spacer()

                    Text("Default Calendar")
                        .font(DSTypography.headlineCard())
                        .foregroundStyle(Color.dsForeground)

                    Spacer()

                    Circle()
                        .fill(Color.dsPrimary)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.dsBackground)
                        }
                }
                .padding(.top, 8)

                // Title Intro
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.dsPrimary)
                            .frame(width: 6, height: 6)
                        Text("SETTINGS")
                            .font(DSTypography.overlineConfidence())
                            .foregroundStyle(Color.dsPrimary)
                    }

                    Text("Default Calendar")
                        .font(DSTypography.displayTitle())
                        .foregroundStyle(Color.dsForeground)

                    Text("Choose which connected calendar account receives newly reviewed and confirmed schedules by default.")
                        .font(DSTypography.bodyCompact())
                        .foregroundStyle(Color.dsMutedForeground)
                        .lineSpacing(2)
                }

                // Highlighted Calendar Sync Overview Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dsSurfaceElevated)
                                .frame(width: 44, height: 44)
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.dsPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Seamless Zero-Conflict Sync")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            HStack(spacing: 5) {
                                Circle().fill(Color.dsSuccess).frame(width: 6, height: 6)
                                Text("All connected accounts ready")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                        }
                    }

                    Text("Events approved during review are automatically committed to your chosen default target without duplicate entries.")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                        .lineSpacing(2)
                }
                .padding(16)
                .dsGlassCard()

                // Calendar Selection List
                if writableCalendars.isEmpty {
                    fallbackCalendarList
                } else {
                    realCalendarGroups
                }

                // Ask Every Time Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask Every Time")
                            .font(DSTypography.bodyStrong())
                            .foregroundStyle(Color.dsForeground)
                        Text("Prompt for destination calendar when reviewing multi-event scans.")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    Spacer()
                    Toggle("", isOn: $askEveryTime)
                        .labelsHidden()
                        .tint(Color.dsPrimary)
                }
                .padding(16)
                .dsGlassCard()
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .task {
            selectedID = store.defaultCalendarIdentifier()
            await refresh()
        }
    }

    // MARK: - Real EventKit Calendar Groups
    @ViewBuilder
    private var realCalendarGroups: some View {
        let icloud = writableCalendars.filter { $0.source.title.localizedCaseInsensitiveContains("iCloud") }
        let others = writableCalendars.filter { !$0.source.title.localizedCaseInsensitiveContains("iCloud") }

        if !icloud.isEmpty {
            calendarGroupSection(
                title: "iCloud Calendars",
                icon: "icloud.fill",
                iconColor: .dsSecondary,
                calendars: icloud
            )
        }

        if !others.isEmpty {
            calendarGroupSection(
                title: "Other Calendars",
                icon: "calendar",
                iconColor: .dsPrimary,
                calendars: others
            )
        }
    }

    private func calendarGroupSection(title: String, icon: String, iconColor: Color, calendars: [EKCalendar]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                Text(title.uppercased())
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(iconColor)
                Spacer()
                Text("\(calendars.count) calendars")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    calendarRow(
                        title: cal.title,
                        subtitle: cal.calendarIdentifier == systemDefault?.calendarIdentifier ? "iOS Default • Read & Write" : "Connected • Read & Write",
                        dotColor: Color(cgColor: cal.cgColor),
                        isSelected: isSelected(cal.calendarIdentifier)
                    ) {
                        store.setDefaultCalendarIdentifier(cal.calendarIdentifier, title: cal.title)
                        selectedID = cal.calendarIdentifier
                    }
                }
            }
        }
    }

    // MARK: - No calendars available
    private var fallbackCalendarList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loadFailed || authorization == .denied || authorization == .restricted
                 ? "Calendar access is off. Allow Calendar access in Settings to choose a default calendar."
                 : "No writable calendars found. Add a calendar in the Calendar app, then come back.")
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsMutedForeground)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open iOS Settings") { UIApplication.shared.open(url) }
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard()
    }

    private func calendarRow(
        title: String,
        subtitle: String,
        dotColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: isSelected ? dotColor.opacity(0.8) : Color.clear, radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    Text(subtitle)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.dsPrimary : Color.dsSurfaceElevated)
                        .frame(width: 26, height: 26)
                        .shadow(color: isSelected ? Color.dsPrimary.opacity(0.5) : Color.clear, radius: 6)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.dsBackground)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.dsPrimary.opacity(0.12) : Color.dsCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.dsPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ identifier: String) -> Bool {
        if let saved = selectedID {
            return saved == identifier
        }
        return identifier == systemDefault?.calendarIdentifier
    }

    private func refresh() async {
        authorization = services.calendar.authorizationStatus()
        if authorization == .notDetermined {
            do {
                _ = try await services.calendar.requestEventAccess()
            } catch {
                loadFailed = true
                return
            }
            authorization = services.calendar.authorizationStatus()
        }

        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = authorization == .fullAccess
        } else {
            granted = authorization == .authorized
        }

        guard granted else {
            writableCalendars = []
            systemDefault = nil
            return
        }

        writableCalendars = services.calendar.fetchWritableCalendars()
        systemDefault = services.calendar.defaultCalendar()
        // Drop a stale choice (calendar deleted, or an old placeholder id) so the UI and saves agree.
        if let saved = selectedID, !writableCalendars.contains(where: { $0.calendarIdentifier == saved }) {
            store.reset()
            selectedID = nil
        }
        loadFailed = false
    }
}
