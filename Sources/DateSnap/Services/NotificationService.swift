import Foundation
import UserNotifications

// MARK: - Notification Service Protocol
public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func scheduleLocalNotifications(
        title: String,
        body: String,
        triggerDates: [Date],
        eventId: String?
    ) async throws -> [String]
    func removePendingNotifications(identifiers: [String])
    func setupNotificationCategories()
}

// MARK: - Production Notification Service
public final class NotificationService: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let categoryIdentifier = "DATESNAP_EVENT_ALERT"
    public static let viewEventActionIdentifier = "VIEW_EVENT_ACTION"
    public static let dismissActionIdentifier = "DISMISS_ACTION"

    private let notificationCenter: UNUserNotificationCenter

    public init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
        super.init()
        self.notificationCenter.delegate = self
        setupNotificationCategories()
    }

    // MARK: - Authorization
    public func requestAuthorization() async throws -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            return granted
        } catch {
            throw DateSnapError.notifications(.accessDenied)
        }
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Setup Actionable Notification Categories
    public func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: Self.viewEventActionIdentifier,
            title: "View Event Details",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: Self.dismissActionIdentifier,
            title: "Dismiss",
            options: [.destructive]
        )

        let eventCategory = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([eventCategory])
    }

    // MARK: - Schedule Local Notifications
    public func scheduleLocalNotifications(
        title: String,
        body: String,
        triggerDates: [Date],
        eventId: String? = nil
    ) async throws -> [String] {
        let status = await authorizationStatus()
        if status != .authorized && status != .provisional {
            let granted = try await requestAuthorization()
            guard granted else {
                throw DateSnapError.notifications(.accessDenied)
            }
        }

        var scheduledIds: [String] = []
        let calendar = Calendar.current
        let now = Date()

        for (index, triggerDate) in triggerDates.enumerated() {
            // Guard against past dates
            guard triggerDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            var userInfo: [String: String] = [
                "type": "datesnap_event_reminder",
                "offsetIndex": "\(index)"
            ]
            if let id = eventId {
                userInfo["eventId"] = id
            }
            content.userInfo = userInfo

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "datesnap-\(eventId ?? UUID().uuidString)-offset\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await notificationCenter.add(request)
                scheduledIds.append(identifier)
            } catch {
                throw DateSnapError.notifications(.schedulingFailed(error.localizedDescription))
            }
        }

        return scheduledIds
    }

    // MARK: - Remove Notifications
    public func removePendingNotifications(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner and play sound even if app is foregrounded
        return [.banner, .sound, .badge]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let dismissed = response.actionIdentifier == Self.dismissActionIdentifier
            || response.actionIdentifier == UNNotificationDismissActionIdentifier
        guard !dismissed,
              let eventId = response.notification.request.content.userInfo["eventId"] as? String else { return }
        await DeepLinkInbox.shared.deliver(eventId: eventId)
    }
}

// MARK: - Deep-Link Inbox

/// Holds the event a notification tap asked to open until the UI consumes it, so taps that
/// cold-launch the app are not lost before `ContentView` starts listening.
@MainActor
public final class DeepLinkInbox: ObservableObject {
    public static let shared = DeepLinkInbox()
    public static let notificationName = NSNotification.Name("DateSnapDeepLinkEvent")

    @Published public private(set) var pendingEventId: String?

    public func deliver(eventId: String) {
        pendingEventId = eventId
        NotificationCenter.default.post(name: Self.notificationName, object: nil, userInfo: ["eventId": eventId])
    }

    public func consume() -> String? {
        defer { pendingEventId = nil }
        return pendingEventId
    }
}
