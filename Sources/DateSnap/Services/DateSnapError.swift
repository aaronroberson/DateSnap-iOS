import Foundation

// MARK: - DateSnap Root Domain Error
public enum DateSnapError: LocalizedError, Sendable, CustomStringConvertible {
    case photoLibrary(PhotoLibraryError)
    case ocr(OCRError)
    case extraction(ExtractionError)
    case calendar(CalendarError)
    case reminders(ReminderError)
    case notifications(NotificationError)
    case subscription(SubscriptionError)
    case persistence(String)
    case general(String)

    public var description: String {
        errorDescription ?? "An unknown DateSnap error occurred."
    }

    public var errorDescription: String? {
        switch self {
        case .photoLibrary(let err): return err.errorDescription
        case .ocr(let err): return err.errorDescription
        case .extraction(let err): return err.errorDescription
        case .calendar(let err): return err.errorDescription
        case .reminders(let err): return err.errorDescription
        case .notifications(let err): return err.errorDescription
        case .subscription(let err): return err.errorDescription
        case .persistence(let msg): return "Data persistence error: \(msg)"
        case .general(let msg): return msg
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .photoLibrary(let err): return err.recoverySuggestion
        case .ocr(let err): return err.recoverySuggestion
        case .extraction(let err): return err.recoverySuggestion
        case .calendar(let err): return err.recoverySuggestion
        case .reminders(let err): return err.recoverySuggestion
        case .notifications(let err): return err.recoverySuggestion
        case .subscription(let err): return err.recoverySuggestion
        default: return nil
        }
    }
}

// MARK: - PhotoLibrary Domain Errors
public enum PhotoLibraryError: LocalizedError, Sendable {
    case accessDenied
    case accessRestricted
    case limitedAccess
    case assetNotFound(String)
    case imageConversionFailed
    case smartAlbumNotFound

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo Library access was denied."
        case .accessRestricted:
            return "Photo Library access is restricted on this device (e.g. parental controls)."
        case .limitedAccess:
            return "Photo Library access is limited to selected photos only."
        case .assetNotFound(let id):
            return "Unable to locate photo or screenshot with ID '\(id)'."
        case .imageConversionFailed:
            return "Failed to convert the photo asset into a processable image."
        case .smartAlbumNotFound:
            return "The Screenshots smart album could not be located on this device."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied, .accessRestricted, .limitedAccess:
            return "Open DateSnap Settings or iOS System Settings to grant full Photo Library permissions."
        case .assetNotFound, .imageConversionFailed:
            return "Please ensure the screenshot exists in your Photos app and try again."
        case .smartAlbumNotFound:
            return "Take a screenshot using your device buttons, then retry scanning."
        }
    }
}

// MARK: - OCR Domain Errors
public enum OCRError: LocalizedError, Sendable {
    case imageProcessingFailed
    case visionRequestFailed(String)
    case noTextRecognized
    case insufficientConfidence(Float)

    public var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Unable to render image for on-device OCR."
        case .visionRequestFailed(let reason):
            return "Apple Vision OCR request failed: \(reason)"
        case .noTextRecognized:
            return "No readable text was detected in this screenshot."
        case .insufficientConfidence(let score):
            return "Text confidence was too low (\(Int(score * 100))%) to reliably extract dates."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noTextRecognized, .insufficientConfidence:
            return "Try cropping or choosing a higher-contrast screenshot of the flyer or event."
        default:
            return "Please try scanning another photo or entering the event manually."
        }
    }
}

// MARK: - Event Extraction Domain Errors
public enum ExtractionError: LocalizedError, Sendable {
    case emptyText
    case noDateDetected
    case unparseableDateString(String)
    case ambiguousDateResolutionFailed

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Cannot extract event details from empty OCR text."
        case .noDateDetected:
            return "No dates or event time windows were detected in the text."
        case .unparseableDateString(let fragment):
            return "Could not parse date fragment: '\(fragment)'."
        case .ambiguousDateResolutionFailed:
            return "Unable to determine the correct month/day order for the specified locale."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noDateDetected:
            return "Verify that the screenshot contains a visible date, month, or day of the week."
        default:
            return "Review the OCR text or enter the event details directly."
        }
    }
}

// MARK: - Calendar Domain Errors
public enum CalendarError: LocalizedError, Sendable {
    case accessDenied
    case noWritableCalendarFound
    case eventCreationFailed(String)
    case calendarStoreUnavailable

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar permission is denied or restricted."
        case .noWritableCalendarFound:
            return "No writable Apple Calendar was found on this device."
        case .eventCreationFailed(let reason):
            return "Failed to save event to Apple Calendar: \(reason)"
        case .calendarStoreUnavailable:
            return "EventKit Calendar Store is currently unavailable."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Go to iOS Settings > DateSnap > Calendars and select 'Full Access'."
        case .noWritableCalendarFound:
            return "Ensure you have at least one editable calendar in the Apple Calendar app."
        default:
            return "Check your calendar setup in iOS Settings."
        }
    }
}

// MARK: - Reminder Domain Errors
public enum ReminderError: LocalizedError, Sendable {
    case accessDenied
    case noListFound
    case reminderCreationFailed(String)
    case maxOffsetsExceeded

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders permission is denied or restricted."
        case .noListFound:
            return "No writable Apple Reminders list was found."
        case .reminderCreationFailed(let reason):
            return "Failed to save reminder in Apple Reminders: \(reason)"
        case .maxOffsetsExceeded:
            return "DateSnap supports a maximum of 3 staggered reminder offsets per event."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Go to iOS Settings > DateSnap > Reminders and grant full access."
        default:
            return "Verify your Reminders lists in the Apple Reminders app."
        }
    }
}

// MARK: - Notification Domain Errors
public enum NotificationError: LocalizedError, Sendable {
    case accessDenied
    case schedulingFailed(String)
    case invalidTriggerDate

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Local notifications permission was denied."
        case .schedulingFailed(let reason):
            return "Failed to schedule local notification: \(reason)"
        case .invalidTriggerDate:
            return "Cannot schedule an alert in the past."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Enable notifications in iOS Settings > Notifications > DateSnap."
        default:
            return "Ensure the reminder time is in the future."
        }
    }
}

// MARK: - Subscription Domain Errors
public enum SubscriptionError: LocalizedError, Sendable {
    case productNotFound(String)
    case purchaseFailed(String)
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .productNotFound(let id):
            return "StoreKit product '\(id)' was not found in App Store Connect."
        case .purchaseFailed(let reason):
            return "Subscription purchase failed: \(reason)"
        case .purchaseCancelled:
            return "The purchase was cancelled."
        case .purchasePending:
            return "The transaction is pending approval (e.g. Ask to Buy)."
        case .verificationFailed:
            return "StoreKit transaction verification failed cryptographic validation."
        case .networkUnavailable:
            return "Network is unavailable for App Store receipt validation."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .verificationFailed:
            return "Restore purchases to re-verify your subscription with Apple."
        case .purchaseCancelled:
            return nil
        default:
            return "Please check your Apple ID settings and try again."
        }
    }
}
