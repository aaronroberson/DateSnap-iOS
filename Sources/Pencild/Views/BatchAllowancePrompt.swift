import SwiftUI

/// A batch selection larger than the free plan's remaining scans. Scanning never starts in this
/// state: the user deselects items, upgrades, or discards the selection.
struct BatchOverLimit: Identifiable, Equatable {
    let id = UUID()
    let selected: Int
    let remaining: Int

    var excess: Int { selected - remaining }

    var message: String {
        remaining > 0
            ? "You selected \(selected) but have \(remaining) free scan\(remaining == 1 ? "" : "s") left this month. Deselect \(excess) to continue, or upgrade to Plus for unlimited scans."
            : "You've used this month's \(PlanLimits.freeScansPerMonth) free scans. Upgrade to Plus for unlimited scans, or discard this selection."
    }
}

extension View {
    /// Prompts to deselect, upgrade, or discard when a batch exceeds the free allowance.
    /// `deselectTitle` names the trim action for the source ("Deselect 3", "Scan First 2 Pages").
    func batchAllowancePrompt(
        _ overLimit: Binding<BatchOverLimit?>,
        deselectTitle: @escaping (BatchOverLimit) -> String,
        onDeselect: @escaping (BatchOverLimit) -> Void,
        onUpgrade: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) -> some View {
        alert(
            "Not Enough Free Scans",
            isPresented: Binding(get: { overLimit.wrappedValue != nil }, set: { if !$0 { overLimit.wrappedValue = nil } }),
            presenting: overLimit.wrappedValue
        ) { info in
            if info.remaining > 0 {
                Button(deselectTitle(info)) { onDeselect(info) }
            }
            Button("Upgrade to Plus") { onUpgrade() }
            Button("Discard Selection", role: .destructive) { onDiscard() }
        } message: { info in
            Text(info.message)
        }
    }
}
