import SwiftUI
import SwiftData

/// Dedicated iPad inspector displaying the source document, interactive zoom/pan controls,
/// neural OCR provenance indicator, and on-device privacy guarantee.
struct EventReviewSourceInspector: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize

    var body: some View {
        VStack(spacing: PDSpacing.sm) {
            PDCard(highlighted: true) {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    HStack {
                        Label("Source Ingestion", systemImage: "document.viewfinder")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Spacer()
                        PDStatusBadge(
                            text: "\(Int((viewModel.confidenceScore * 100).rounded()))% · \(viewModel.confidenceTier.label)",
                            icon: viewModel.confidenceTier.iconName,
                            tone: viewModel.confidenceTier == .high ? .success : .warning
                        )
                    }

                    // Scalable Inspection Viewport
                    ZStack(alignment: .bottom) {
                        ZStack {
                            RoundedRectangle(cornerRadius: PDRadius.card)
                                .fill(Color.pdSurfaceLowest)
                                .frame(height: 480)

                            if let image = viewModel.sourceImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(zoomScale)
                                    .offset(panOffset)
                                    .frame(maxHeight: 460)
                                    .clipped()
                                    .gesture(panGesture)
                                    .accessibilityLabel("Original scanned document")
                            } else {
                                PDScanSourceThumbnail(candidate: viewModel.candidate, width: nil, height: 460, contentMode: .fit)
                                    .scaleEffect(zoomScale)
                                    .offset(panOffset)
                                    .clipped()
                                    .gesture(panGesture)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))

                        // Floating Viewport Zoom Controls Toolbar
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.25)) { zoomScale = max(0.8, zoomScale - 0.2) }
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.pdOnSurface)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Zoom out")

                            Text("\(Int(zoomScale * 100))%")
                                .font(PDFont.labelSM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(minWidth: 44)

                            Button {
                                withAnimation(.spring(response: 0.25)) { zoomScale = min(2.5, zoomScale + 0.2) }
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.pdOnSurface)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Zoom in")

                            Divider()
                                .frame(height: 16)
                                .background(Color.pdOutlineVariant)

                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    zoomScale = 1.0
                                    panOffset = .zero
                                }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Reset document view")
                        }
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.pdSurfaceContainerHigh.opacity(0.92))
                                .shadow(radius: 8)
                        )
                        .padding(.bottom, 12)
                    }

                    // Hardware & Privacy Guarantee Footer
                    HStack {
                        Label("Neural OCR On-Device", systemImage: "cpu")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdSecondary)
                        Spacer()
                        Label("Zero Cloud Leak", systemImage: "lock.shield.fill")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdPrimary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard zoomScale > 1 else { return }
                panOffset = value.translation
            }
            .onEnded { _ in
                if zoomScale <= 1 { panOffset = .zero }
            }
    }
}
