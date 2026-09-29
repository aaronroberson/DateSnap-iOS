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
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Top Bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.dsForeground)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.dsCardElevated))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                            Text("Scanned on-device")
                        }
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.dsMutedForeground)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.dsMuted))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // Screenshot Preview Box with Optical Reticle
                    VStack(spacing: 12) {
                        ZStack {
                            if let image = appState.lastScanImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .opacity(0.55)
                                    .accessibilityLabel("Scanned image")
                            }
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.dsCardElevated, Color.dsCard],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 180)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            
                            // Laser Reticle Corners (Accent Orange)
                            VStack {
                                HStack {
                                    RoundedCornerBracket(corner: .topLeft)
                                        .stroke(Color(red: 255/255, green: 138/255, blue: 61/255), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    Spacer()
                                    RoundedCornerBracket(corner: .topRight)
                                        .stroke(Color(red: 255/255, green: 138/255, blue: 61/255), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                }
                                Spacer()
                                HStack {
                                    RoundedCornerBracket(corner: .bottomLeft)
                                        .stroke(Color(red: 255/255, green: 138/255, blue: 61/255), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    Spacer()
                                    RoundedCornerBracket(corner: .bottomRight)
                                        .stroke(Color(red: 255/255, green: 138/255, blue: 61/255), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(14)
                            .frame(height: 180)
                            
                            // Stationary Laser Beam
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 255/255, green: 138/255, blue: 61/255), Color.dsAccent, Color(red: 123/255, green: 97/255, blue: 255/255)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 2)
                                .padding(.horizontal, 24)
                                .shadow(color: Color(red: 255/255, green: 138/255, blue: 61/255), radius: 6)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.minus")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color.dsWarning)
                                
                                Text("NO DATES DETECTED")
                                    .font(DSTypography.overlineConfidence())
                                    .foregroundStyle(Color.dsWarning)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.dsWarning.opacity(0.16)))
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scanned Image")
                                    .font(DSTypography.bodyStrong())
                                    .foregroundStyle(Color.dsForeground)
                                Text("\(rawFragments.count) text line\(rawFragments.count == 1 ? "" : "s") read • 100% on-device")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            Spacer()
                            Button {
                                showImage = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "viewfinder")
                                    Text("Inspect")
                                }
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.dsPrimary.opacity(0.12)))
                            }
                        }
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Explanation Title
                    VStack(spacing: 8) {
                        Text("Couldn't find any dates")
                            .font(DSTypography.displayTitle())
                            .foregroundStyle(Color.dsForeground)
                        
                        Text("DateSnap analyzed this screenshot through local OCR layers, but found no calendar anchors, timestamps, or reservation syntax.")
                            .font(DSTypography.bodyBase())
                            .foregroundStyle(Color.dsMutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Diagnostics: Why did this happen?
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(Color.dsWarning)
                            Text("Why did this happen?")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Spacer()
                            Text("Diagnostics")
                                .font(DSTypography.overlineConfidence())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        
                        diagnosticRow(
                            icon: "pencil.tip.crop.circle",
                            title: "Handwriting or heavy stylization",
                            description: "Graffiti, brush scripts, or stylized logo typefaces often disguise standard numeric dates."
                        )
                        
                        diagnosticRow(
                            icon: "clock.arrow.2.circlepath",
                            title: "Relative or speculative phrasing",
                            description: "Phrases like 'Coming this Fall', 'Next weekend', or 'TBA' lack absolute calendar timestamps."
                        )
                        
                        diagnosticRow(
                            icon: "photo.on.rectangle.angled",
                            title: "Pure imagery, memes, or screenshots",
                            description: "If the image contains scenery, chat banter, or product receipts without dates, detection yields zero."
                        )
                    }
                    .padding(18)
                    .dsGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // Detected Words Drawer
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRawWords.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(Color.dsPrimary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("View Detected Words")
                                        .font(DSTypography.bodyStrong())
                                        .foregroundStyle(Color.dsForeground)
                                    Text(rawFragments.isEmpty ? "No readable text was found" : "\(rawFragments.count) raw text fragments extracted")
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                                
                                Spacer()
                                
                                Image(systemName: showRawWords ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                        }
                        
                        if showRawWords {
                            Divider().background(Color.dsBorder)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(rawFragments.enumerated()), id: \.offset) { _, word in
                                    HStack {
                                        Text("• \(word)")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundStyle(Color.dsForeground)
                                        Spacer()
                                    }
                                }
                                
                                Button {
                                    UIPasteboard.general.string = rawFragments.joined(separator: "\n")
                                    appState.showToast("Copied \(rawFragments.count) raw OCR fragments to clipboard")
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Raw OCR")
                                    }
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsPrimary)
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 18)
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            createManualEvent()
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Create Event Manually from Image")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        
                        Button {
                            dismiss()
                            appState.selectedTab = .home
                            appState.requestPhotoPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                Text("Scan a Different Image")
                            }
                        }
                        .buttonStyle(DSSecondaryButtonStyle())
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Discard & Return to Dashboard")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .dsScreenBackground()
            .sheet(isPresented: $showImage) {
                if let image = appState.lastScanImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                    }
                    .background(Color.dsBackground)
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    /// Starts a blank review (tomorrow 7 PM) carrying the scanned text, so the user can fill in the details.
    private func createManualEvent() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let start = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let candidate = EventCandidate(
            title: rawFragments.first ?? "",
            startDate: start,
            endDate: start.addingTimeInterval(7200),
            confidenceScore: 0.5,
            rawTextSnippet: appState.lastScanRawText,
            confidenceTierRaw: ConfidenceTier.low.rawValue
        )
        modelContext.insert(candidate)
        try? modelContext.save()
        appState.rememberSourceImage(appState.lastScanImage, for: [candidate])
        Task { await appState.present(.eventReviewEdit(candidate.toDateSnapEvent())) }
    }
    
    @ViewBuilder
    private func diagnosticRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dsMuted)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsWarning)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text(description)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
        }
    }
}
