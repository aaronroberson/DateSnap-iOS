import SwiftUI

/// Editor section inside BatchEventCard for selecting calendar, reminders list, and alerts for an individual event.
struct BatchDestinationsEditor: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @State private var showScheduleEditor = false

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.availableCalendars.isEmpty {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "calendar", tint: .pdPrimary)
                    Text("Default calendar (access requested on save)")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "calendar", tint: .pdPrimary)
                    Menu {
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Button(calendar.title) { viewModel.selectedCalendar = calendar }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedCalendar?.title ?? "Choose calendar")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                        }
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !viewModel.availableReminderLists.isEmpty {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "checklist", tint: .pdSecondary)
                    Menu {
                        ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                            Button(list.title) { viewModel.selectedReminderList = list }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedReminderList?.title ?? "Choose list")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                        }
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                showScheduleEditor = true
            } label: {
                HStack(spacing: 6) {
                    PDIconTile(systemName: "bell.badge.fill", tint: .pdSecondary)
                    Text(viewModel.selectedOffsets.isEmpty
                         ? "No alerts"
                         : viewModel.selectedOffsets.map(\.label).joined(separator: " · "))
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurface)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Edit alerts")
        }
        .padding(PDSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceLowest)
        )
        .sheet(isPresented: $showScheduleEditor) {
            ReminderScheduleEditorView(
                title: viewModel.title,
                eventStart: viewModel.startDate,
                isAllDay: viewModel.isAllDay,
                initialOffsets: viewModel.selectedOffsets
            ) { offsets in
                viewModel.selectedOffsets = offsets
                return .success
            }
        }
    }
}

// MARK: - Titled Field
struct BatchTitledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: PDSpacing.xs) {
            Text(title)
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                TextField(placeholder, text: $text)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.tile)
                    .fill(Color.pdSurfaceLowest)
            )
        }
    }
}
