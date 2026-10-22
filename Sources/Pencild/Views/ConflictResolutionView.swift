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
        case .syllabusCascadeConflict: return "Schedule cascade conflict"
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
                            labeled("Starts", context.incoming.start.formatted(date: .abbreviated, time: .shortened))
                            labeled("Ends", context.incoming.end.formatted(date: .abbreviated, time: .shortened))
                            if let location = context.incoming.location, !location.isEmpty {
                                labeled("Location", location)
                            }
                        }
                        Section("Detected local conflicts") {
                            ForEach(context.conflicts) { conflict in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(conflict.event.title)
                                        .font(PDFont.labelMD)
                                    Text(detail(for: conflict))
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        Section {
                            Text("Choose an adjustment in the review form, then save only after the conflict is resolved.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                            Button("Resolve conflict in review") {
                                onResolve()
                                dismiss()
                            }
                            Button("Save to Calendar anyway", role: .destructive) {
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

    private func detail(for conflict: ScheduleConflict) -> String {
        switch conflict.kind {
        case .overlap:
            return "Overlaps this event from \(conflict.event.start.formatted(date: .omitted, time: .shortened)) to \(conflict.event.end.formatted(date: .omitted, time: .shortened))."
        case .insufficientGap:
            let minutes = Int((conflict.gap ?? 0) / 60)
            return "Only \(minutes) minutes between events."
        }
    }
}
