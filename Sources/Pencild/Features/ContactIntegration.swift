import SwiftUI
import EventKit
import Foundation

// MARK: - Contact Integration Models

/// Represents a contact selected for event sharing
public struct EventContact: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let emailAddresses: [String]
    public let phoneNumbers: [String]
    
    public init(id: String, name: String, emailAddresses: [String] = [], phoneNumbers: [String] = []) {
        self.id = id
        self.name = name
        self.emailAddresses = emailAddresses
        self.phoneNumbers = phoneNumbers
    }
}

/// Represents a contact invitation for an event
public struct EventInvitation: Identifiable, Sendable {
    public let id: UUID
    public let contact: EventContact
    public let eventId: String
    public let status: InvitationStatus
    public let createdDate: Date
    
    public enum InvitationStatus: String, Sendable {
        case pending
        case sent
        case accepted
        case declined
    }
    
    public init(id: UUID = UUID(), contact: EventContact, eventId: String, status: InvitationStatus = .pending) {
        self.id = id
        self.contact = contact
        self.eventId = eventId
        self.status = status
        self.createdDate = Date()
    }
}

// MARK: - Contact Integration Service

/// Service for handling contact integration features (iOS 18+)
public protocol ContactIntegrationServiceProtocol: Sendable {
    /// Request contact access permission
    func requestContactAccess() async throws -> Bool
    
    /// Check current contact authorization status
    func contactAuthorizationStatus() -> ContactAuthorizationStatus
    
    /// Fetch contacts with optional filtering
    func fetchContacts() async throws -> [EventContact]
    
    /// Send event invitation to contact
    func sendInvitation(to contact: EventContact, for eventTitle: String, date: Date) async throws
    
    /// Create shared reminder for contact
    func createSharedReminder(for contact: EventContact, eventTitle: String, date: Date) async throws
}

public enum ContactAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorized
    case writeOnly
    @available(iOS 18.0, *)
    case fullAccess
}

// MARK: - iOS 18+ Implementation

@available(iOS 18.0, *)
public final class ContactIntegrationService: ContactIntegrationServiceProtocol, @unchecked Sendable {
    // EKEventStore is not Sendable; access is confined to this service instance —
    // same opt-out pattern as CalendarService/ReminderService/NotificationService.
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }
    
    public func requestContactAccess() async throws -> Bool {
        // iOS 18+ ContactAccessButton handles UI, but we need to check authorization
        // For now, return true if we have calendar access (contacts will be handled by ContactAccessButton)
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess {
            return true
        }
        
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            return granted
        } catch {
            throw ContactIntegrationError.accessDenied(error.localizedDescription)
        }
    }
    
    public func contactAuthorizationStatus() -> ContactAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .restricted {
            return .restricted
        }
        if status == .denied {
            return .denied
        }
        if status == .writeOnly {
            return .writeOnly
        }
        if status == .fullAccess {
            return .fullAccess
        }
        return .notDetermined
    }
    
    public func fetchContacts() async throws -> [EventContact] {
        // In a real implementation, this would fetch from Contacts framework
        // For now, return empty array - actual implementation would require ContactsUI integration
        return []
    }
    
    public func sendInvitation(to contact: EventContact, for eventTitle: String, date: Date) async throws {
        // Create calendar event with attendee
        let event = EKEvent(eventStore: eventStore)
        event.title = eventTitle
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600) // 1 hour default
        
        // Save event
        try eventStore.save(event, span: .thisEvent)
    }
    
    public func createSharedReminder(for contact: EventContact, eventTitle: String, date: Date) async throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Reminder: \(eventTitle) with \(contact.name)"
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        try eventStore.save(reminder, commit: true)
    }
}

// MARK: - Fallback Implementation (iOS 17)

public final class ContactIntegrationFallbackService: ContactIntegrationServiceProtocol {
    public init() {}
    
    public func requestContactAccess() async throws -> Bool {
        // iOS 17 doesn't have ContactAccessButton, return false to indicate feature unavailable
        return false
    }
    
    public func contactAuthorizationStatus() -> ContactAuthorizationStatus {
        return .notDetermined
    }
    
    public func fetchContacts() async throws -> [EventContact] {
        // Feature not available on iOS 17
        return []
    }
    
    public func sendInvitation(to contact: EventContact, for eventTitle: String, date: Date) async throws {
        throw ContactIntegrationError.featureUnavailable("Contact invitations require iOS 18+")
    }
    
    public func createSharedReminder(for contact: EventContact, eventTitle: String, date: Date) async throws {
        throw ContactIntegrationError.featureUnavailable("Shared reminders require iOS 18+")
    }
}

// MARK: - Factory

public enum ContactIntegrationFactory {
    public static func createService() -> ContactIntegrationServiceProtocol {
        if #available(iOS 18.0, *) {
            return ContactIntegrationService()
        } else {
            return ContactIntegrationFallbackService()
        }
    }
}

// MARK: - Errors

public enum ContactIntegrationError: LocalizedError {
    case accessDenied(String)
    case featureUnavailable(String)
    case contactNotFound
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied(let message):
            return "Contact access denied: \(message)"
        case .featureUnavailable(let message):
            return "Feature unavailable: \(message)"
        case .contactNotFound:
            return "Contact not found"
        }
    }
}
