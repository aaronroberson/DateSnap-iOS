import SwiftUI
import EventKit

// MARK: - Default Calendar Section (Settings → Destinations)
/// Lets the user pick the DateSnap-wide default destination calendar (e.g. "Home" instead
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
            SettingsSectionHeader(icon: "calendar.badge.checkmark", title: "Destinations", tint: .dsSecondary)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("DEFAULT CALENDAR FOR NEW EVENTS")
                            .font(DSTypography.overlineConfidence())
                            .foregroundStyle(Color.dsMutedForeground)
                        Spacer()
                        if savedIdentifier != nil {
                            Button("Reset") {
                                store.reset()
                            }
                            .font(DSTypography.labelChip())
                            .foregroundStyle(Color.dsSecondary)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Reset default calendar to the iOS default")
                        }
                    }

                    picker

                    Text(statusText)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }
            .padding(16)
            .dsGlassCard()
        }
        .task { await refresh() }
    }

    @ViewBuilder
    private var picker: some View {
        if writableCalendars.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: loadFailed ? "exclamationmark.triangle" : "calendar")
                    .foregroundStyle(Color.dsMutedForeground)
                Text(loadFailed
                     ? "Could not load calendars — try again after granting Calendar access."
                     : "No writable calendars found. Check Calendar access in iOS Settings.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
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
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dsPrimary)
                    Text(selectedTitle ?? "Follow the iOS default calendar")
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dsCard)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
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
