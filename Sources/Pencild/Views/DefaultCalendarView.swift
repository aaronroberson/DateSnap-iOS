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
                    subtitle: "Choose which connected calendar account receives newly reviewed and confirmed schedules by default."
                )

                // Highlighted Calendar Sync Overview Card
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack(spacing: PDSpacing.sm) {
                            PDIconTile(systemName: "arrow.triangle.2.circlepath.circle.fill", tint: .pdPrimary, size: .large)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Seamless Zero-Conflict Sync")
                                    .font(PDFont.headlineSM)
                                    .foregroundStyle(Color.pdOnSurface)
                                HStack(spacing: 5) {
                                    Circle().fill(Color.pdSuccess).frame(width: 6, height: 6)
                                    Text("All connected accounts ready")
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                            }
                        }

                        Text("Events approved during review are automatically committed to your chosen default target without duplicate entries.")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .lineSpacing(2)

                        if selectedID != nil {
                            Button("Reset to iOS default") {
                                store.reset()
                                selectedID = nil
                            }
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdPrimary)
                            .padding(.top, 4)
                        }
                    }
                }

                // Calendar Selection List
                if writableCalendars.isEmpty {
                    fallbackCalendarList
                } else {
                    realCalendarGroups
                }

                // Ask Every Time Toggle Card
                PDCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ask Every Time")
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdOnSurface)
                            Text("Prompt for destination calendar when reviewing multi-event scans.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                        Spacer()
                        Toggle("Ask Every Time", isOn: $askEveryTime)
                            .labelsHidden()
                            .toggleStyle(PDToggleStyle())
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
                        .lineLimit(1)
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
