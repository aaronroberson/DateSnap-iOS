import SwiftUI
import SwiftData

struct SavedEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    
    /// Snapshot used to open the screen; the live record is re-read so edits show immediately.
    let snapshot: DateSnapEvent

    init(event: DateSnapEvent) {
        self.snapshot = event
    }

    private var candidate: EventCandidate? { SavedEventActions.candidate(id: snapshot.id, in: modelContext) }
    private var saved: SavedEvent? { candidate?.savedEvent }
    private var event: DateSnapEvent { candidate?.toDateSnapEvent() ?? snapshot }
    private var isInCalendar: Bool { saved?.externalCalendarEventId != nil && saved?.status == .saved }
    private var hasReminder: Bool { !(saved?.externalReminderIds.isEmpty ?? true) }

    private var mapsURL: URL? {
        let query = [event.locationName, event.locationAddress]
            .filter { !$0.isEmpty && $0 != "Location TBA" }
            .joined(separator: ", ")
        guard !query.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    private var shareText: String {
        var lines = [event.title, "\(event.dayOfWeek), \(event.month) \(event.day), \(event.year) · \(event.timeWindow)"]
        if event.locationName != "Location TBA" { lines.append(event.locationName) }
        if !event.locationAddress.isEmpty && event.locationAddress != event.locationName { lines.append(event.locationAddress) }
        if !event.notes.isEmpty { lines.append(event.notes) }
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Top Bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.dsSecondary)
                                    .frame(width: 44, height: 44)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.dsPrimary)
                                Text("DateSnap")
                                    .font(DSTypography.headlineCard())
                                    .foregroundStyle(Color.dsForeground)
                            }
                            
                            Spacer()
                            
                            Text("Extraction Success Summary")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Reassuring Confirmed Toast Badge
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.dsSuccess)
                                    .frame(width: 20, height: 20)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 4/255, green: 27/255, blue: 16/255))
                            }
                            Text(isInCalendar ? (hasReminder ? "SAVED TO APPLE CALENDAR & REMINDERS" : "SAVED TO APPLE CALENDAR") : (saved?.status == .archived ? "ARCHIVED IN DATESNAP" : "NOT YET IN CALENDAR"))
                                .font(DSTypography.overlineConfidence())
                                .foregroundStyle(Color.dsSuccess)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.dsSuccess.opacity(0.12))
                                .overlay(Capsule().stroke(Color.dsSuccess.opacity(0.3), lineWidth: 1))
                        )
                        
                        // Event Hero Card: Luminous Glass Showcase
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                // Dimensional Date Badge
                                VStack(spacing: 0) {
                                    Text(event.month.uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.dsMutedForeground)
                                        .padding(.top, 6)
                                    Text("\(event.day)")
                                        .font(DSTypography.displayTitle())
                                        .foregroundStyle(Color.dsForeground)
                                        .padding(.bottom, 6)
                                }
                                .frame(width: 58, height: 68)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dsSuccess)
                                        Text("\(event.confidenceScore)% \(event.confidenceLabel.uppercased())")
                                            .font(DSTypography.overlineConfidence())
                                            .foregroundStyle(Color.dsSuccess)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.dsSuccess.opacity(0.15)))
                                    
                                    Text(event.title)
                                        .font(DSTypography.headlineSection())
                                        .foregroundStyle(Color.dsForeground)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            // Time & Recurrence Info
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.dsSecondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(event.dayOfWeek), \(event.month) \(event.day), \(event.year)")
                                        .font(DSTypography.bodyCompact())
                                        .foregroundStyle(Color.dsForeground)
                                    Text(event.timeWindow)
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                            }
                            
                            // Location Pill with Direction Link
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 255/255, green: 138/255, blue: 61/255).opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(red: 255/255, green: 138/255, blue: 61/255))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.locationName)
                                        .font(DSTypography.bodyCompact())
                                        .foregroundStyle(Color.dsForeground)
                                    if !event.locationAddress.isEmpty && event.locationAddress != event.locationName {
                                        Text(event.locationAddress)
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                }
                                
                                Spacer()
                                
                                if let mapsURL {
                                Button {
                                    openURL(mapsURL)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Directions")
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                }
                                }
                            }
                        }
                        .padding(18)
                        .dsGlassCard(cornerRadius: 24, elevated: true, borderColor: Color.dsPrimary.opacity(0.2))
                        .padding(.horizontal)
                        
                        // Saved Sync Targets (Apple Ecosystem Destination Matrix)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ECOSYSTEM DESTINATION")
                                    .font(DSTypography.overlineConfidence())
                                    .foregroundStyle(Color.dsMutedForeground)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: isInCalendar ? "checkmark.circle.fill" : "exclamationmark.circle")
                                        .font(.system(size: 10))
                                    Text(isInCalendar ? "Saved" : "Not saved")
                                        .font(DSTypography.caption())
                                }
                                .foregroundStyle(isInCalendar ? Color.dsSuccess : Color.dsWarning)
                            }
                            
                            VStack(spacing: 10) {
                                // Apple Calendar Target
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.dsError.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "calendar")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.dsError)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Apple Calendar")
                                            .font(DSTypography.bodyCompact())
                                            .foregroundStyle(Color.dsForeground)
                                        Text("Calendar: \(event.targetCalendar)")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isInCalendar ? "checkmark.circle.fill" : "minus.circle")
                                        .foregroundStyle(isInCalendar ? Color.dsSuccess : Color.dsMutedForeground)
                                        .font(.system(size: 18))
                                        .accessibilityLabel(isInCalendar ? "Saved" : "Not saved")
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(14)
                                
                                // Apple Reminders Target
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.dsInfo.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "checklist")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.dsInfo)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Apple Reminders")
                                            .font(DSTypography.bodyCompact())
                                            .foregroundStyle(Color.dsForeground)
                                        Text("List: \(event.targetRemindersList)")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: hasReminder ? "checkmark.circle.fill" : "minus.circle")
                                        .foregroundStyle(hasReminder ? Color.dsSuccess : Color.dsMutedForeground)
                                        .font(.system(size: 18))
                                        .accessibilityLabel(hasReminder ? "Saved" : "Not saved")
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(14)
                            }
                        }
                        .padding(16)
                        .dsGlassCard(cornerRadius: 20)
                        .padding(.horizontal)
                        
                        // Configured Reminders Timeline Card with Vertical Guide Line
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundStyle(Color.dsSecondary)
                                    Text("Scheduled Alerts")
                                        .font(DSTypography.bodyStrong())
                                        .foregroundStyle(Color.dsForeground)
                                }
                                Spacer()
                                Text("\(event.scheduledAlerts.count) Active")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            
                            // Vertical Timeline
                            ZStack(alignment: .leading) {
                                // Guide line
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 2)
                                    .padding(.leading, 15)
                                    .padding(.vertical, 10)
                                
                                VStack(spacing: 12) {
                                    if event.scheduledAlerts.isEmpty {
                                        Text("No alerts scheduled. Tap Alerts below to add up to 3.")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsMutedForeground)
                                            .padding(.leading, 42)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    ForEach(Array(event.scheduledAlerts.enumerated()), id: \.element.id) { index, alert in
                                        let tint = [Color.dsInfo, Color(red: 255/255, green: 138/255, blue: 61/255), Color.dsSuccess][index % 3]
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(tint.opacity(0.2))
                                                    .frame(width: 30, height: 30)
                                                Circle()
                                                    .fill(tint)
                                                    .frame(width: 10, height: 10)
                                            }
                                            
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(alert.offsetText)
                                                        .font(DSTypography.bodyCompact())
                                                        .foregroundStyle(Color.dsForeground)
                                                    Text("\(alert.scheduledTimeText) · Calendar, Reminders & alert")
                                                        .font(DSTypography.caption())
                                                        .foregroundStyle(Color.dsMutedForeground)
                                                }
                                                Spacer()
                                                Image(systemName: "alarm")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Color.dsMutedForeground)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .dsGlassCard(cornerRadius: 20)
                        .padding(.horizontal)
                        
                        // Extracted Source Screenshot & Intelligence Notes Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("EXTRACTED INTELLIGENCE & CONTEXT")
                                    .font(DSTypography.overlineConfidence())
                                    .foregroundStyle(Color.dsMutedForeground)
                                Spacer()
                                Text(event.sourceFlyerName)
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 255/255, green: 79/255, blue: 179/255), Color(red: 91/255, green: 124/255, blue: 255/255)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 74)
                                    
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .padding(.bottom, 4)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SCANNED DETAILS")
                                        .font(DSTypography.overlineConfidence())
                                        .foregroundStyle(Color.dsSecondary)
                                    
                                    Text(event.notes.isEmpty ? (event.rawOcrFragments.prefix(4).joined(separator: " · ").isEmpty ? "No extra details captured." : event.rawOcrFragments.prefix(4).joined(separator: " · ")) : event.notes)
                                        .font(DSTypography.caption())
                                        .foregroundStyle(Color.dsForeground)
                                        .lineSpacing(3)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.dsPrimary)
                                        Text("Extracted by DateSnap OCR Engine")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(14)
                        }
                        .padding(16)
                        .dsGlassCard(cornerRadius: 20)
                        .padding(.horizontal)
                        
                        // Floating Sticky Action Buttons Cluster
                        VStack(spacing: 12) {
                            // Primary Glowing Capsule CTA
                            Button {
                                if let start = candidate?.startDate,
                                   let url = URL(string: "calshow:\(start.timeIntervalSinceReferenceDate)") {
                                    openURL(url)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                    Text("Open in Apple Calendar")
                                    Image(systemName: "arrow.up.right")
                                }
                            }
                            .buttonStyle(DSPrimaryButtonStyle())
                            .disabled(!isInCalendar)
                            
                            // Secondary Action Row (3 Glass Pills)
                            HStack(spacing: 10) {
                                Button {
                                    Task { await appState.present(.eventReviewEdit(event)) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                            .foregroundStyle(Color.dsSecondary)
                                        Text("Edit Event")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsForeground)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(14)
                                }
                                
                                Button {
                                    Task { await appState.present(.reminderScheduleEditor(event)) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bell")
                                            .foregroundStyle(Color.dsSecondary)
                                        Text("Alerts")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsForeground)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(14)
                                }
                                
                                ShareLink(item: shareText, subject: Text(event.title)) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundStyle(Color.dsSecondary)
                                        Text("Share")
                                            .font(DSTypography.caption())
                                            .foregroundStyle(Color.dsForeground)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(14)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .dsScreenBackground()
        }
    }
}
