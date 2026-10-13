import SwiftUI
import SwiftData
import UIKit

struct NoDatesFoundView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @State private var showImage: Bool = false
    
    @State private var showRawWords: Bool = false
    
    /// Text fragments Vision recognized in the last scan.
    private var rawFragments: [String] {
        appState.lastScanRawText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDTopBar(title: "Scan result") {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Close scan result")
                    }

                    PDScreenIntro(
                        eyebrow: "No dates found",
                        title: "Couldn't find any dates",
                        subtitle: "Pencil'd read this image on your device, but didn't find a date or time to review. Try a clearer image or enter the details yourself."
                    )

                    PDCard {
                        VStack(alignment: .leading, spacing: 16) {
                            if let image = appState.lastScanImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                                    .accessibilityLabel("Scanned image")
                            }
                            PDStatusBadge(text: "No date or time detected", icon: "calendar.badge.minus", tone: .warning)
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(rawFragments.count) text line\(rawFragments.count == 1 ? "" : "s") read")
                                        .font(PDFont.labelLG)
                                        .foregroundStyle(Color.pdOnSurface)
                                    Label("Text recognition on your device", systemImage: "lock.shield")
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                Spacer()
                                if appState.lastScanImage != nil {
                                    Button { showImage = true } label: {
                                        PDChip(text: "Inspect", icon: "viewfinder", selected: true)
                                            .frame(minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Inspect scanned image")
                                }
                            }
                        }
                    }

                    PDSectionHeader(title: "Quick tips for better scans")
                    PDCard(highlighted: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            diagnosticRow(
                                icon: "crop", title: "Focus on the schedule",
                                description: "Use Photos to crop around the date and time, then select the edited image to scan again."
                            )
                            diagnosticRow(
                                icon: "sun.max", title: "Use clear, readable text",
                                description: "Choose a sharper image with good lighting and contrast. Small or stylized lettering can be harder to read."
                            )
                            diagnosticRow(
                                icon: "calendar", title: "Check for a date or time",
                                description: "An announcement without a date may need manual entry. Review the detected words below to see what Pencil'd could read."
                            )
                        }
                    }

                    VStack(spacing: 12) {
                        Button { createManualEvent() } label: {
                            Label("Create Event Manually", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(PDPrimaryButtonStyle())

                        Button {
                            dismiss()
                            appState.selectedTab = .home
                            appState.requestPhotoPicker = true
                        } label: {
                            Label("Try Another Image", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(PDSecondaryButtonStyle())

                        Button { dismiss() } label: {
                            Text("Discard & Return Home")
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }

                    PDCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button { showRawWords.toggle() } label: {
                                HStack(spacing: 12) {
                                    PDIconTile(systemName: "doc.text.magnifyingglass", tint: .pdSecondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Inspect OCR Text")
                                            .font(PDFont.labelLG)
                                            .foregroundStyle(Color.pdOnSurface)
                                        Text(rawFragments.isEmpty ? "No readable text was found" : "\(rawFragments.count) recognized text lines")
                                            .font(PDFont.bodySM)
                                            .foregroundStyle(Color.pdOnSurfaceVariant)
                                    }
                                    Spacer()
                                    Image(systemName: showRawWords ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(showRawWords ? "Expanded" : "Collapsed")

                            if showRawWords {
                                Divider().overlay(Color.pdOutlineVariant)
                                Text(rawFragments.isEmpty ? "No readable text was found in this scan." : appState.lastScanRawText)
                                    .font(PDFont.bodySM.monospaced())
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.pdSurfaceLowest, in: RoundedRectangle(cornerRadius: PDRadius.tile))
                                if !rawFragments.isEmpty {
                                    Button {
                                        UIPasteboard.general.string = appState.lastScanRawText
                                        appState.showToast("Copied scan text to clipboard")
                                    } label: {
                                        Label("Copy Raw OCR", systemImage: "doc.on.doc")
                                            .font(PDFont.labelMD)
                                            .foregroundStyle(Color.pdPrimary)
                                            .frame(minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PDSpacing.margin)
                .padding(.top, PDSpacing.sm)
                .padding(.bottom, PDSpacing.lg)
            }
            .pdScreenBackground()
            .sheet(isPresented: $showImage) {
                if let image = appState.lastScanImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                    }
                    .background(Color.pdSurface)
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    /// Creates an unsaved review carrying the scan text. The current time is an editable starting value.
    private func createManualEvent() {
        let start = Date()
        let candidate = EventCandidate(
            title: rawFragments.first ?? "",
            startDate: start,
            endDate: EventDurationPolicy.fallbackEnd(for: start),
            confidenceScore: 0,
            rawTextSnippet: appState.lastScanRawText,
            confidenceTierRaw: ConfidenceTier.low.rawValue
        )
        let result = MutationResult.perform {
            modelContext.insert(candidate)
            try modelContext.save()
        }
        guard case .success = result else {
            modelContext.delete(candidate)
            if case .failure(let error) = result {
                appState.showToast(error.localizedDescription)
            }
            return
        }
        appState.rememberSourceImage(appState.lastScanImage, for: [candidate])
        Task { await appState.present(.eventReviewEdit(candidate.toPencildEvent())) }
    }
    
    private func diagnosticRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PDIconTile(systemName: icon, tint: .pdPrimary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text(description)
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
