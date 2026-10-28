import SwiftUI

struct ConflictResolutionView: View {
    let context: ConflictResolutionContext?
    let state: AppModalScreen
    var onResolve: () -> Void = {}
    var onSaveAnyway: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    private var stateTitle: String {
        switch state {
        case .transmeridianConflict: return "Time and travel conflict"
        case .syllabusCascadeConflict: return "Calendar conflict"
        case .ambientAudioConflict: return "Uncertain event conflict"
        case .festivalWeatherConflict: return "Contingency conflict"
        default: return "Calendar conflict"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let context {
                    List {
                        Section("Incoming event") {
                            labeled("Title", context.incoming.title)
                            if let confidence = context.incomingTitleConfidence, confidence < 0.65 {
                                Label("Title needs review", systemImage: "exclamationmark.triangle.fill")
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdWarning)
                                    .accessibilityLabel("The extracted title has low confidence and needs review")
                            }
                            labeled("Starts", formatted(context.incoming.start, timeZoneIdentifier: context.incomingTimeZoneIdentifier))
                            labeled("Ends", formatted(context.incoming.end, timeZoneIdentifier: context.incomingTimeZoneIdentifier))
                            if let location = context.incoming.location, !location.isEmpty {
                                labeled("Location", location)
                            }
                            Text("Draft extracted from the source image. Verify the details before saving.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                        Section("Detected local conflicts") {
                            ForEach(context.conflicts) { conflict in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(conflict.event.title)
                                        .font(PDFont.labelMD)
                                    Text(detail(for: conflict, incoming: context.incoming, timeZoneIdentifier: context.incomingTimeZoneIdentifier))
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        Section {
                            Text("Edit the incoming event to resolve the conflict, or explicitly keep the overlap.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                            Button("Edit incoming event") {
                                onResolve()
                                dismiss()
                            }
                            Button("Keep overlap and save", role: .destructive) {
                                onSaveAnyway()
                                dismiss()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No conflict is being reviewed",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("This screen opens from a detected local schedule conflict during event review.")
                    )
                }
            }
            .navigationTitle(stateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func detail(for conflict: ScheduleConflict, incoming: ScheduleInterval, timeZoneIdentifier: String?) -> String {
        switch conflict.kind {
        case .overlap:
            guard let overlap = ScheduleConflictAnalyzer.overlap(for: incoming, with: conflict.event) else {
                return "Overlapping time could not be calculated."
            }
            return "Overlaps from \(formatted(overlap.start, timeZoneIdentifier: timeZoneIdentifier)) to \(formatted(overlap.end, timeZoneIdentifier: timeZoneIdentifier))."
        case .insufficientGap:
            let minutes = Int((conflict.gap ?? 0) / 60)
            return "Only \(minutes) minutes between events."
        }
    }

    private func formatted(_ date: Date, timeZoneIdentifier: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if let timeZoneIdentifier, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: date)
    }
}
