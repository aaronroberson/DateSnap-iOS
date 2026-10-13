import SwiftUI
import SwiftData

/// Dedicated iPad inspector displaying the source document, interactive zoom/pan controls,
/// neural OCR provenance indicator, and on-device privacy guarantee.
struct EventReviewSourceInspector: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @Binding var viewport: SourceViewport

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
                                    .scaleEffect(viewport.scale)
                                    .offset(viewport.offset)
                                    .frame(maxHeight: 460)
                                    .clipped()
                                    .gesture(panGesture)
                                    .accessibilityLabel("Original scanned document")
                            } else {
                                PDScanSourceThumbnail(candidate: viewModel.candidate, width: nil, height: 460, contentMode: .fit)
                                    .scaleEffect(viewport.scale)
                                    .offset(viewport.offset)
                                    .clipped()
                                    .gesture(panGesture)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))

                        // Floating Viewport Zoom Controls Toolbar
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.25)) { viewport.zoomOut() }
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.pdOnSurface)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Zoom out")

                            Text("\(viewport.percent)%")
                                .font(PDFont.labelSM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(minWidth: 44)

                            Button {
                                withAnimation(.spring(response: 0.25)) { viewport.zoomIn() }
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
                                withAnimation(.spring(response: 0.25)) { viewport.reset() }
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
                viewport.pan(to: value.translation)
            }
            .onEnded { _ in
                viewport.endPan()
            }
    }
}

/// Zoom and pan state of the source document viewport. Kept as a value type so the
/// clamping and pan rules are shared by the controls, the drag gesture, and tests.
struct SourceViewport: Equatable {
    static let minScale: CGFloat = 0.8
    static let maxScale: CGFloat = 2.5
    static let step: CGFloat = 0.2

    private(set) var scale: CGFloat = 1
    private(set) var offset: CGSize = .zero

    var percent: Int { Int((scale * 100).rounded()) }

    mutating func zoomIn() { scale = min(Self.maxScale, scale + Self.step) }

    mutating func zoomOut() {
        scale = max(Self.minScale, scale - Self.step)
        if scale <= 1 { offset = .zero }
    }

    mutating func reset() { self = SourceViewport() }

    /// Panning is only meaningful while the document is magnified.
    mutating func pan(to translation: CGSize) {
        guard scale > 1 else { return }
        offset = translation
    }

    mutating func endPan() {
        if scale <= 1 { offset = .zero }
    }
}
