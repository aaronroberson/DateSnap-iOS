import SwiftUI
import EventKit

// MARK: - Default Calendar Section (Settings → Destinations)
/// Lets the user pick the Pencil’d-wide default destination calendar (e.g. "Home" instead
/// of "Work" or "Shared"). New events reviewed from screenshots are preselected into this
/// calendar, so the user no longer has to change the drop-down every time.
struct DefaultCalendarSection: View {
    @Environment(\.services) private var services
    @State private var store = DefaultCalendarStore()
    @State private var writableCalendars: [EKCalendar] = []
    @State private var systemDefault: EKCalendar? = nil
    @State private var authorization: EKAuthorizationStatus = .notDetermined
    @State private var loadFailed = false

    private var savedIdentifier: String? { store.defaultCalendarIdentifier() }
    private var savedTitle: String? { store.defaultCalendarTitle() }

    private var selectedTitle: String? {
        if let savedTitle { return savedTitle }
        if let id = savedIdentifier {
            return writableCalendars.first { $0.calendarIdentifier == id }?.title
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "calendar.badge.checkmark", title: "Destinations", tint: .pdSecondary)

            PDCard {
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    HStack {
                        Text("DEFAULT CALENDAR FOR NEW EVENTS")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                        Spacer()
                        if savedIdentifier != nil {
                            Button("Reset") {
                                store.reset()
                            }
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdSecondary)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Reset default calendar to the iOS default")
                        }
                    }

                    picker

                    Text(statusText)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
        }
        .task { await refresh() }
    }

    @ViewBuilder
    private var picker: some View {
        if writableCalendars.isEmpty {
            HStack(spacing: PDSpacing.sm) {
                Image(systemName: loadFailed ? "exclamationmark.triangle" : "calendar")
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Text(loadFailed
                     ? "Could not load calendars — try again after granting Calendar access."
                     : "No writable calendars found. Check Calendar access in iOS Settings.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .frame(minHeight: 44)
        } else {
            Menu {
                ForEach(writableCalendars, id: \.calendarIdentifier) { calendar in
                    Button {
                        store.setDefaultCalendarIdentifier(calendar.calendarIdentifier, title: calendar.title)
                    } label: {
                        if calendar.calendarIdentifier == savedIdentifier {
                            Label(calendar.title, systemImage: "checkmark")
                        } else {
                            Text(calendar.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    PDIconTile(systemName: "calendar", tint: .pdPrimary)
                    Text(selectedTitle ?? "Follow the iOS default calendar")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .padding(PDSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PDRadius.tile)
                        .fill(Color.pdSurfaceLowest)
                )
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Default calendar for new events")
            .accessibilityValue(selectedTitle ?? "iOS default")
        }
    }

    private var statusText: String {
        if savedIdentifier == nil {
            return "New events follow the iOS default calendar. Pick one to always start here."
        }
        if writableCalendars.isEmpty {
            return "Saved: \(selectedTitle ?? "a calendar"). It will apply once Calendar access is granted."
        }
        return "New events are preselected into “\(selectedTitle ?? "")” — change per event during review."
    }

    /// Loads calendars, requesting Calendar access first if it was never asked.
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
        loadFailed = false
    }
}
