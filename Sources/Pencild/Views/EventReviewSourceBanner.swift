import SwiftUI

/// Source banner & toggleable drawer previewing original scanned image and OCR confidence.
struct EventReviewSourceBanner: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @Binding var showOriginalDrawer: Bool

    private var tier: ConfidenceTier { viewModel.confidenceTier }
    private var scorePercent: Int { Int((viewModel.confidenceScore * 100).rounded()) }

    var body: some View {
        PDCard(highlighted: true) {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(alignment: .top, spacing: 12) {
                    PDScanSourceThumbnail(candidate: viewModel.candidate, width: 68, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                    VStack(alignment: .leading, spacing: PDSpacing.xs) {
                        Text(viewModel.candidate.scannedAsset == nil ? "Manual entry" : "Source scan")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        PDStatusBadge(
                            text: "\(scorePercent)% · \(tier.label)",
                            icon: tier.iconName,
                            tone: tier == .high ? .success : .warning
                        )
                        if let scan = viewModel.candidate.scannedAsset {
                            Text("Scanned \(scan.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                    Spacer(minLength: 0)
                }

                if let route = viewModel.engineRoute {
                    EngineRouteBadge(route: route)
                }

                if viewModel.sourceImage != nil || viewModel.candidate.scannedAsset != nil {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showOriginalDrawer.toggle()
                        }
                    } label: {
                        PDChip(
                            text: showOriginalDrawer ? "Hide original" : "View original",
                            icon: showOriginalDrawer ? "eye.slash" : "eye",
                            selected: showOriginalDrawer
                        )
                    }
                    .buttonStyle(.plain)
                }

                if showOriginalDrawer {
                    Group {
                        if let image = viewModel.sourceImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 360)
                                .accessibilityLabel("Original scanned image")
                        } else {
                            PDScanSourceThumbnail(candidate: viewModel.candidate, width: nil, height: 360, contentMode: .fit)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal)
    }
}
