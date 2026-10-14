import SwiftUI
import EventKit

/// Card allowing selection of target Apple Calendar, Reminders list, and alert schedules.
struct EventReviewDestinationCard: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @Binding var showScheduleEditor: Bool

    var body: some View {
        VStack(spacing: 12) {
            calendarPickerRow

            if !viewModel.availableReminderLists.isEmpty {
                remindersListRow
            }

            alertScheduleButton
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private var calendarPickerRow: some View {
        HStack {
            PDIconTile(systemName: "calendar", tint: .pdPrimary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Saving To Calendar")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    if viewModel.needsCalendarChoice {
                        PDStatusBadge(text: "Required", icon: "exclamationmark.circle.fill", tone: .warning)
                    }
                }
                if viewModel.availableCalendars.isEmpty {
                    Text("Default calendar (access requested on save)")
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                } else {
                    Menu {
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Button(calendar.title) { viewModel.selectedCalendar = calendar }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedCalendar?.title ?? "Choose a calendar")
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                        }
                        .font(PDFont.bodyMD)
                        .foregroundStyle(viewModel.needsCalendarChoice ? Color.pdWarning : Color.pdOnSurface)
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(viewModel.selectedCalendar.map { "Calendar, \($0.title)" } ?? "Calendar, required. Choose a calendar")
                }
            }

            Spacer()
        }
    }

    private var remindersListRow: some View {
        HStack {
            PDIconTile(systemName: "checklist", tint: .pdSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Reminders List")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Menu {
                    ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                        Button(list.title) { viewModel.selectedReminderList = list }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedReminderList?.title ?? "Choose list")
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                    }
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurface)
                    .frame(minHeight: 44)
                }
            }
            Spacer()
        }
    }

    private var alertScheduleButton: some View {
        Button {
            showScheduleEditor = true
        } label: {
            HStack {
                PDIconTile(systemName: "bell.badge.fill", tint: .pdSecondary)
                Text(viewModel.selectedOffsets.isEmpty ? "No alerts" : viewModel.selectedOffsets.map(\.label).joined(separator: " · "))
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurface)
                    .lineLimit(1)
                Spacer()
                Text("\(viewModel.selectedOffsets.count) Alert\(viewModel.selectedOffsets.count == 1 ? "" : "s")")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.pdSurfaceHighest))
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            .frame(minHeight: 44)
        }
        .accessibilityLabel("Edit alerts, \(viewModel.selectedOffsets.count) selected")
    }
}
