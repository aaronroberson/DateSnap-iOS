import SwiftUI
import SwiftData

/// Cards and sections displaying why Pencil’d interpreted an event's date and time,
/// including engine route badges, user correction indicators, and evidence quotes.
struct EventInterpretationDetailCard: View {
    let candidate: EventCandidate?
    let event: PencildEvent

    var body: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Source artifact")
            PDCard {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    if let candidate {
                        PDScanSourceThumbnail(candidate: candidate, width: nil, height: 180, contentMode: .fit)
                        Text(event.sourceFlyerMetadata)
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    } else {
                        Label("Source details are no longer available", systemImage: "photo")
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }

                    Text("Why Pencil’d chose these details")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)

                    interpretationExplanation

                    if !event.notes.isEmpty {
                        Text(event.notes)
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }

                    if let asset = candidate?.scannedAsset, !asset.rawOcrText.isEmpty {
                        DisclosureGroup("Recognized scan text") {
                            Text(asset.rawOcrText)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, PDSpacing.sm)
                        }
                        .font(PDFont.labelLG)
                        .tint(.pdPrimary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var interpretationExplanation: some View {
        if let record = candidate?.interpretation, let stored = record.stored {
            let selected = stored.understanding.allCandidates.first { $0.id == record.selectedInterpretationID } ?? stored.understanding.best
            EngineRouteBadge(route: stored.route)
            if record.correctedFields.contains("date") {
                Label("You edited the date during review.", systemImage: "pencil")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdSecondary)
            } else if let reason = selected.start.reason, !reason.isEmpty {
                Text(reason)
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            } else if !selected.explanations.isEmpty {
                ForEach(Array(selected.explanations.enumerated()), id: \.offset) { _, explanation in
                    Text(explanation)
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            } else {
                Text("No date explanation was stored for this scan.")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            if !record.correctedFields.contains("date") {
                ProvenanceChip(provenance: selected.start.provenance, needsCheck: selected.start.isAmbiguous || selected.yearAssumed)
                ForEach(selected.start.evidence, id: \.lineID) { reference in
                    if let evidence = stored.evidence.first(where: { $0.id == reference.lineID }) {
                        Text("“\(evidence.text)”")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdPrimary)
                            .textSelection(.enabled)
                    }
                }
            }
        } else {
            Text("No interpretation explanation was stored for this event.")
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }
}
