import Foundation
import SwiftUI

// MARK: - Event Status
enum EventStatus: String, CaseIterable, Identifiable, Sendable {
    case saved = "Saved"
    case draft = "Drafts"
    case dismissed = "Archived"
    
    var id: String { rawValue }
}

// MARK: - Reminder Alert Model
struct ReminderAlert: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var label: String
    var offsetText: String
    var scheduledTimeText: String
    var channel: AlertChannel
    var iconName: String
}

extension ReminderAlert {
    /// Display model for a real scheduled offset.
    init(offset: ReminderOffset, eventStart: Date, isAllDay: Bool) {
        let fireDate = offset.triggerDate(forEventStart: eventStart, isAllDay: isAllDay)
        self.init(
            label: offset.label.capitalized,
            offsetText: offset.label,
            scheduledTimeText: fireDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()),
            channel: .calendar,
            iconName: "bell.fill"
        )
    }
}

enum AlertChannel: String, CaseIterable, Identifiable, Sendable {
    case notification = "Local Push Alert"
    case reminders = "Apple Reminders"
    case calendar = "Calendar Alarm"
    case push = "DateSnap Priority Push"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .notification: return "bell.badge.fill"
        case .reminders: return "checklist"
        case .calendar: return "calendar.badge.clock"
        case .push: return "bolt.shield.fill"
        }
    }
}

// MARK: - Reminder Preset
enum ReminderPreset: String, CaseIterable, Identifiable, Sendable {
    case defaultPreset = "Default (2 alerts)"
    case travelHeavy = "Travel Heavy (3 alerts)"
    case dayOfOnly = "Day-of Only"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .defaultPreset: return "sparkles"
        case .travelHeavy: return "airplane.departure"
        case .dayOfOnly: return "calendar.day.timeline.left"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - DateSnap Event Model
struct DateSnapEvent: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var month: String
    var day: String
    var year: String
    var dayOfWeek: String
    var timeWindow: String
    var locationName: String
    var locationAddress: String
    var confidenceScore: Int
    var confidenceLabel: String
    var status: EventStatus
    var sourceFlyerName: String
    var sourceFlyerMetadata: String
    var targetCalendar: String
    var targetRemindersList: String
    var rawOcrFragments: [String]
    var scheduledAlerts: [ReminderAlert]
    var isAllDay: Bool = false
    var notes: String = ""
    var isAmbiguousDate: Bool = false
    var ambiguousFragment: String? = nil
    var timeZoneIdentifier: String? = nil
    var dedupeKey: String = ""
}

#if DEBUG
// Sample events are only used by the DEBUG screen gallery and SwiftUI previews.
extension DateSnapEvent {
    static let sampleNeonSunset = DateSnapEvent(
        id: "event-sunset-082",
        title: "Neon Sunset Rooftop Session",
        month: "Jul",
        day: "18",
        year: "2025",
        dayOfWeek: "Friday",
        timeWindow: "7:00 PM – 11:30 PM PDT",
        locationName: "Skybar Penthouse & Lounge",
        locationAddress: "8440 Sunset Blvd, West Hollywood, Los Angeles, CA",
        confidenceScore: 99,
        confidenceLabel: "AI Accuracy",
        status: .saved,
        sourceFlyerName: "Sunset Flyer #082",
        sourceFlyerMetadata: "Captured from Instagram Stories • 1.8 MB (Lossless)",
        targetCalendar: "Personal",
        targetRemindersList: "Events & RSVPs",
        rawOcrFragments: [
            "NEON SUNSET ROOFTOP",
            "FRIDAY JULY 18 2025",
            "DOORS OPEN 7:00 PM",
            "SKYBAR 8440 SUNSET BLVD",
            "MUSIC BY DJ KAI & FRIENDS",
            "TICKETS REQUIRED AT ENTRY",
            "21+ ADMIT ONE",
            "SOUND BY VOID ACOUSTICS"
        ],
        scheduledAlerts: [
            ReminderAlert(
                label: "Alert 1 · Preparation",
                offsetText: "1 day before",
                scheduledTimeText: "Jul 17, 9:00 AM",
                channel: .reminders,
                iconName: "archivebox.fill"
            ),
            ReminderAlert(
                label: "Alert 2 · Departure",
                offsetText: "2 hours before",
                scheduledTimeText: "Jul 18, 5:00 PM",
                channel: .notification,
                iconName: "figure.walk"
            ),
            ReminderAlert(
                label: "Alert 3 · Arrival Buffer",
                offsetText: "30 minutes before",
                scheduledTimeText: "Jul 18, 6:30 PM",
                channel: .notification,
                iconName: "bell.fill"
            )
        ]
    )
    
    static let sampleDentalCheckup = DateSnapEvent(
        id: "event-dental-02",
        title: "Dr. Aris Dental Checkup",
        month: "Jul",
        day: "02",
        year: "2025",
        dayOfWeek: "Wednesday",
        timeWindow: "10:30 AM – 11:45 AM",
        locationName: "Medical Plaza Suite 402",
        locationAddress: "1200 Wilshire Blvd, Los Angeles, CA",
        confidenceScore: 96,
        confidenceLabel: "High Confidence",
        status: .saved,
        sourceFlyerName: "Appointment Card Photo",
        sourceFlyerMetadata: "Scanned yesterday from camera roll",
        targetCalendar: "Health",
        targetRemindersList: "Reminders",
        rawOcrFragments: [
            "DR. ARIS DDS",
            "ROUTINE CLEANING",
            "JULY 2 10:30 AM",
            "SUITE 402"
        ],
        scheduledAlerts: [
            ReminderAlert(
                label: "Day-prior Alert",
                offsetText: "1 day before",
                scheduledTimeText: "Jul 1, 9:00 AM",
                channel: .notification,
                iconName: "bell.fill"
            )
        ]
    )
    
    static let sampleSummerMixer = DateSnapEvent(
        id: "event-mixer-14",
        title: "Summer Rooftop Mixer",
        month: "Aug",
        day: "14",
        year: "2025",
        dayOfWeek: "Thursday",
        timeWindow: "6:00 PM – 9:00 PM",
        locationName: "Downtown Arts District",
        locationAddress: "720 E 3rd St, Los Angeles, CA",
        confidenceScore: 88,
        confidenceLabel: "Review Needed",
        status: .draft,
        sourceFlyerName: "WhatsApp Screenshot",
        sourceFlyerMetadata: "Captured 3 days ago",
        targetCalendar: "Social",
        targetRemindersList: "Events",
        rawOcrFragments: ["SUMMER MIXER", "AUG 14", "ARTS DISTRICT"],
        scheduledAlerts: []
    )
}
#endif
