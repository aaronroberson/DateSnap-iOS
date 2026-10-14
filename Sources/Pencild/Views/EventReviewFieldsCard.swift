import SwiftUI
import EventKit

/// Card containing all extracted event editable fields:
/// Title, Date/Time picker, Location & Maps link, Notes & Details,
/// along with ambiguity and provenance badges.
struct EventReviewFieldsCard: View {
    @ObservedObject var viewModel: EventReviewViewModel
    let onOpenURL: (URL) -> Void

    private var mapsURL: URL? {
        PencildLinks.maps([viewModel.venueName, viewModel.location])
    }

    var body: some View {
        PDGroupedList {
            titleField
                .padding(PDSpacing.md)
            PDRowDivider()
            dateCard
            PDRowDivider()
            locationCard
            PDRowDivider()
            notesCard
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("EVENT TITLE")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Spacer()
                if let source = viewModel.provenance(for: .title) {
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
            }

            HStack(spacing: 10) {
                TextField("Enter event name...", text: $viewModel.title)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)

                if !viewModel.title.isEmpty {
                    Button {
                        viewModel.title = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Clear title")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.tile)
                    .fill(Color.pdSurfaceLowest)
            )
        }
    }

    private var dateCard: some View {
        VStack(spacing: 12) {
            if let source = viewModel.provenance(for: .date) {
                HStack {
                    Text("WHEN")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Spacer()
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
            }
            dateRow(icon: "calendar", label: viewModel.isAllDay ? "DATE" : "STARTS") {
                DatePicker(
                    "Start",
                    selection: $viewModel.startDate,
                    displayedComponents: viewModel.isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .labelsHidden()
                .onChange(of: viewModel.startDate) { oldValue, _ in
                    viewModel.startDateChanged(from: oldValue)
                }
            }

            if !viewModel.isAllDay {
                Divider().background(Color.pdSurfaceHighest)

                dateRow(icon: "clock", label: "ENDS") {
                    DatePicker(
                        "End",
                        selection: $viewModel.endDate,
                        in: viewModel.startDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }
            }

            if viewModel.yearAssumed {
                Label("Year wasn't on the flyer — Pencil’d picked the next upcoming one.", systemImage: "info.circle")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdWarning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Color.pdSurfaceHighest)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("All-Day Event")
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Date only; no start or end time")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }

                Spacer()

                Toggle("All-Day Event", isOn: $viewModel.isAllDay)
                    .labelsHidden()
                    .toggleStyle(PDToggleStyle())
            }
        }
        .padding(PDSpacing.md)
    }

    @ViewBuilder
    private func dateRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            PDIconTile(systemName: icon, tint: .pdPrimary)

            Text(label)
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)

            Spacer()

            content()
                .tint(Color.pdPrimary)
                .colorScheme(.dark)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOCATION")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                if let source = viewModel.provenance(for: .venue) {
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
                Spacer()
                if let mapsURL {
                    Button {
                        onOpenURL(mapsURL)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 10))
                            Text("Open in Maps")
                                .font(PDFont.bodySM)
                        }
                        .foregroundStyle(Color.pdInfo)
                        .frame(minHeight: 44)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                PDIconTile(systemName: "mappin.and.ellipse", tint: .pdTertiary)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Venue name", text: $viewModel.venueName)
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    TextField("Address", text: $viewModel.location)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }

            if !viewModel.rsvpUrl.isEmpty || viewModel.candidate.rsvpUrl != nil {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(Color.pdSecondary)
                    TextField("Tickets / RSVP link", text: $viewModel.rsvpUrl)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurface)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                .padding(.top, 4)
            }
        }
        .padding(PDSpacing.md)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES & DETAILS")
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)

            TextEditor(text: $viewModel.notes)
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurface)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(8)
                .overlay(alignment: .topLeading) {
                    if viewModel.notes.isEmpty {
                        Text("Add notes (door times, dress code, tickets)…")
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(PDSpacing.md)
    }
}
