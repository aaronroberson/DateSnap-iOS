import SwiftUI

#if DEBUG
// MARK: - Interpretation Diagnostics (DEBUG only)
/// Developer view of how a scan was interpreted: route, fallback, the applied hypothesis, alternatives,
/// field provenance, corrections and the numbered OCR evidence lines. Never compiled into Release.
struct InterpretationDiagnosticsView: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.toggle()
            } label: {
                Label("Diagnostics (DEBUG)", systemImage: "ladybug")
                    .font(DSTypography.labelChip())
                    .foregroundStyle(Color.dsMutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    let record = viewModel.candidate.interpretation
                    line("route", viewModel.engineRoute?.rawValue ?? "none")
                    line("fallback", record?.fallbackReason ?? "—")
                    line("schema", record.map { "v\($0.schemaVersion)" } ?? "—")
                    line("applied", viewModel.appliedInterpretationID ?? "—")
                    line("alternatives", viewModel.understanding?.alternatives.map(\.id).joined(separator: ", ") ?? "—")
                    line("corrected", record?.correctedFields.joined(separator: ", ") ?? "—")
                    ForEach(EventReviewViewModel.ReviewField.allCases, id: \.self) { field in
                        let source = viewModel.provenance(for: field)
                        line(field.rawValue, source.map { "\($0.provenance.rawValue)\($0.needsCheck ? " (check)" : "")" } ?? "—")
                    }
                    if let applied = viewModel.appliedInterpretation {
                        line("evidence", "title \(applied.title.evidence.map(\.lineID)) start \(applied.start.evidence.map(\.lineID)) venue \(applied.venue.evidence.map(\.lineID))")
                        line("scores", String(format: "rank %.2f · title %.2f · start %.2f", applied.rankScore, applied.title.score, applied.start.score))
                    }
                    Divider()
                    ForEach(viewModel.evidenceLines) { evidence in
                        Text("[\(evidence.id)] b\(evidence.blockID) r\(evidence.fontRank) \(String(format: "%.2f", evidence.confidence))  \(evidence.text)")
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.dsSecondary)
                .textSelection(.enabled)
            }
        }
        .padding(14)
        .dsGlassCard(cornerRadius: 20)
    }

    private func line(_ label: String, _ value: String) -> some View {
        Text("\(label): \(value)")
    }
}
#endif
