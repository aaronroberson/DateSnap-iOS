import SwiftUI

// MARK: - Scan Progress Overlay
struct ScanProgressOverlay: View {
    @ObservedObject var scan: ScanViewModel

    private var step: Int {
        switch scan.stage {
        case .fetchingImage: return 0
        case .processingOCR: return 1
        case .extractingEvents: return 2
        case .interpreting: return 3
        default: return 0
        }
    }

    var body: some View {
        if scan.isProcessing {
            ZStack {
                Color.pdSurface.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: PDSpacing.lg) {
                        HStack {
                            PDEyebrow(text: "ON-DEVICE SCAN")
                            Spacer()
                            Button(scan.isCancelling ? "Canceling…" : "Cancel") { scan.cancelScan() }
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdPrimary)
                                .frame(minWidth: 44, minHeight: 44)
                                .disabled(scan.isCancelling)
                                .accessibilityIdentifier("scan.cancel")
                        }
                        PDScreenIntro(
                            eyebrow: "SCANNED. REVIEWED. PENCIL'D.",
                            title: scan.isCancelling ? "Stopping this scan" : "Finding your event",
                            subtitle: "Nothing is added to your calendar until you review and confirm it."
                        )
                        if let image = scan.currentProcessingImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                                .accessibilityLabel("Source being scanned")
                        }
                        if let detail = scan.progressDetail {
                            PDStatusBadge(text: detail, icon: "doc.on.doc", tone: .info)
                        }
                        PDCard {
                            VStack(spacing: PDSpacing.md) {
                                PDScanStepRow(title: "Load source", icon: "photo", complete: step > 0, active: step == 0)
                                PDScanStepRow(title: "Read text on device", icon: "text.viewfinder", complete: step > 1, active: step == 1)
                                PDScanStepRow(title: "Find dates and places", icon: "calendar.badge.magnifyingglass", complete: step > 2, active: step == 2)
                                if scan.stage == .interpreting {
                                    PDScanStepRow(title: "Interpret event details", icon: "sparkles", complete: false, active: true)
                                }
                            }
                        }
                        if scan.stage == .interpreting && !scan.isCancelling {
                            Button("Skip — use standard result") { scan.skipInterpretation() }
                                .buttonStyle(DSSecondaryButtonStyle())
                                .accessibilityHint("Stops Apple Intelligence and shows the rules-based result")
                                .accessibilityIdentifier("scan.skipInterpretation")
                        }
                        Label("Private, on-device processing", systemImage: "lock.shield.fill")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    .padding(PDSpacing.md)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

private struct PDScanStepRow: View {
    let title: String
    let icon: String
    let complete: Bool
    let active: Bool

    var body: some View {
        HStack(spacing: PDSpacing.sm) {
            PDIconTile(systemName: complete ? "checkmark" : icon, tint: complete ? .pdSuccess : (active ? .pdPrimary : .pdOnSurfaceVariant))
            Text(title)
                .font(PDFont.bodyMD)
                .foregroundStyle(active || complete ? Color.pdOnSurface : Color.pdOnSurfaceVariant)
            Spacer(minLength: 0)
            if active {
                ProgressView().tint(Color.pdPrimary)
            } else if complete {
                Text("Done").font(PDFont.labelMD).foregroundStyle(Color.pdSuccess)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(complete ? "Complete" : (active ? "In progress" : "Waiting"))
    }
}
