import SwiftUI
import EventKit

// MARK: - Default Calendar View
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Default-Calendar/design.html`.
/// Connects directly to EventKit via Pencil’d Services and `DefaultCalendarStore`.
struct DefaultCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services

    private let store = DefaultCalendarStore()
    /// Mirrors the persisted choice so the list re-renders on tap (the store is a plain UserDefaults wrapper).
    @State private var selectedID: String?
    @State private var asksEveryTime = false
    @State private var writableCalendars: [EKCalendar] = []
    @State private var systemDefault: EKCalendar? = nil
    @State private var authorization: EKAuthorizationStatus = .notDetermined
    @State private var loadFailed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Default Calendar", showsBack: true) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pdOnPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.pdPrimary))
                        .accessibilityHidden(true)
                }

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Default Calendar",
                    subtitle: "Choose where new events go. Pick a calendar to send every new event there, or leave Automatic on."
                )

                // Highlighted Calendar Sync Overview Card
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack(spacing: PDSpacing.sm) {
                            PDIconTile(systemName: "arrow.triangle.2.circlepath.circle.fill", tint: .pdPrimary, size: .large)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Where new events go")
                                    .font(PDFont.headlineSM)
                                    .foregroundStyle(Color.pdOnSurface)
                                HStack(spacing: 5) {
                                    Circle().fill(Color.pdSuccess).frame(width: 6, height: 6)
                                    Text(asksEveryTime ? "Ask every time" : selectedID == nil ? "Automatic" : "Always \(store.defaultCalendarTitle() ?? "your chosen calendar")")
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                            }
                        }

                        Text("Nothing is added until you confirm it in review. A calendar you pick here overrides the automatic order for every new event; saved events keep their calendar.")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .lineSpacing(2)

                    }
                }

                // Calendar Selection List
                if writableCalendars.isEmpty {
                    fallbackCalendarList
                } else {
                    automaticRow
                    realCalendarGroups
                }

                // Per-event override note: the default is preselected, never prompted for.
                PDCard {
                    HStack(alignment: .top, spacing: PDSpacing.sm) {
                        PDIconTile(systemName: "hand.tap.fill", tint: .pdSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change it for any event")
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdOnSurface)
                            Text(asksEveryTime ? "Review shows the calendar list with nothing selected, and Save waits until you pick one." : "Your default is preselected when you review a scan. Pick a different calendar there for just that event.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .task {
            selectedID = store.defaultCalendarIdentifier()
            asksEveryTime = store.asksEveryTime()
            await refresh()
        }
    }

    // MARK: - Automatic (priority order)
    /// Selected until the user picks a calendar. A picked calendar overrides this order for every new event.
    private var automaticRow: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pdPrimary)
                Text("PRIORITY ORDER")
                    .font(PDFont.labelSM)
                    .tracking(0.6)
                    .foregroundStyle(Color.pdPrimary)
            }
            .padding(.horizontal, PDSpacing.xxs)

            calendarRow(
                title: "Automatic",
                subtitle: "Your usual calendar for that kind of event, then the iOS default\(systemDefault.map { " (\($0.title))" } ?? "")",
                dotColor: .pdPrimary,
                isSelected: selectedID == nil && !asksEveryTime,
                subtitleLines: 2
            ) {
                store.reset()
                selectedID = nil
                asksEveryTime = false
            }

            calendarRow(
                title: "Ask every time",
                subtitle: "No calendar is preselected. Pick one for each event before it saves.",
                dotColor: .pdSecondary,
                isSelected: asksEveryTime,
                subtitleLines: 2
            ) {
                store.setAsksEveryTime()
                selectedID = nil
                asksEveryTime = true
            }
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
                iconColor: .pdSecondary,
                calendars: icloud
            )
        }

        if !others.isEmpty {
            calendarGroupSection(
                title: "Other Calendars",
                icon: "calendar",
                iconColor: .pdPrimary,
                calendars: others
            )
        }
    }

    private func calendarGroupSection(title: String, icon: String, iconColor: Color, calendars: [EKCalendar]) -> some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                Text(title.uppercased())
                    .font(PDFont.labelSM)
                    .tracking(0.6)
                    .foregroundStyle(iconColor)
                Spacer()
                Text("\(calendars.count) calendars")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .padding(.horizontal, PDSpacing.xxs)

            VStack(spacing: PDSpacing.sm) {
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    calendarRow(
                        title: cal.title,
                        subtitle: cal.calendarIdentifier == systemDefault?.calendarIdentifier ? "iOS Default • Read & Write" : "Connected • Read & Write",
                        dotColor: Color(cgColor: cal.cgColor),
                        isSelected: isSelected(cal.calendarIdentifier)
                    ) {
                        store.setDefaultCalendarIdentifier(cal.calendarIdentifier, title: cal.title)
                        selectedID = cal.calendarIdentifier
                        asksEveryTime = false
                    }
                }
            }
        }
    }

    // MARK: - No calendars available
    private var fallbackCalendarList: some View {
        PDCard {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                Text(loadFailed || authorization == .denied || authorization == .restricted
                     ? "Calendar access is off. Allow Calendar access in Settings to choose a default calendar."
                     : "No writable calendars found. Add a calendar in the Calendar app, then come back.")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open iOS Settings") { UIApplication.shared.open(url) }
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdPrimary)
                }
            }
        }
    }

    private func calendarRow(
        title: String,
        subtitle: String,
        dotColor: Color,
        isSelected: Bool,
        subtitleLines: Int = 1,
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
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    Text(subtitle)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .lineLimit(subtitleLines)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.pdPrimaryContainer : Color.pdSurfaceHighest)
                        .frame(width: 26, height: 26)
                        .shadow(color: isSelected ? Color.pdPrimaryContainer.opacity(0.5) : Color.clear, radius: 6)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.pdOnPrimary)
                    }
                }
            }
            .padding(PDSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.pdSelected) : AnyShapeStyle(Color.pdSurfaceLow.opacity(0.9)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .stroke(isSelected ? Color.pdPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ identifier: String) -> Bool {
        selectedID == identifier
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

        // Listing calendars needs full access; add-only can save but not list.
        let granted = authorization.canReadCalendars

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
