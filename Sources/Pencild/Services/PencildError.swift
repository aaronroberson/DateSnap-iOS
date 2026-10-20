import Foundation

// MARK: - Pencild Root Domain Error
public enum PencildError: LocalizedError, Sendable, CustomStringConvertible {
    case photoLibrary(PhotoLibraryError)
    case ocr(OCRError)
    case extraction(ExtractionError)
    case calendar(CalendarError)
    case reminders(ReminderError)
    case notifications(NotificationError)
    case subscription(SubscriptionError)
    case fileImport(FileImportError)
    case persistence(String)
    case general(String)

    public var description: String {
        errorDescription ?? "An unknown Pencil’d error occurred."
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
        case .fileImport(let err): return err.errorDescription
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
        case .fileImport(let err): return err.recoverySuggestion
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
    /// The asset's original is only in iCloud and the user has not allowed downloading it. Pencil'd
    /// only scans on-device assets by default; a scan that needs the full-resolution iCloud original
    /// must ask the user first (see Settings › Scanning Options › iCloud & remote downloads).
    case iCloudDownloadRequired
    /// An iCloud download was attempted (user-approved) but failed or was interrupted.
    case iCloudDownloadFailed(String)

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
        case .iCloudDownloadRequired:
            return "This photo is stored in iCloud and isn't downloaded to your device."
        case .iCloudDownloadFailed(let reason):
            return "Could not download this photo from iCloud: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied, .accessRestricted, .limitedAccess:
            return "Open Pencil’d Settings or iOS System Settings to grant full Photo Library permissions."
        case .assetNotFound, .imageConversionFailed:
            return "Please ensure the screenshot exists in your Photos app and try again."
        case .smartAlbumNotFound:
            return "Take a screenshot using your device buttons, then retry scanning."
        case .iCloudDownloadRequired:
            return "Allow iCloud downloads in Settings › Scanning Options, or open the photo in Photos to download it first."
        case .iCloudDownloadFailed:
            return "Check your connection and try again, or open the photo in Photos to download it first."
        }
    }
}

// MARK: - File Import Domain Errors
/// Errors for the Files / iCloud Drive / PDF import path. Like `PhotoLibraryError`, a file that
/// lives in iCloud Drive but isn't downloaded locally is reported explicitly so the user can choose
/// to download it via Apple's built-in process (see `RemoteAssetGate` and `ICloudDownloadPreference`).
public enum FileImportError: LocalizedError, Sendable {
    case fileNotDownloadedLocally
    case fileDownloadFailed(String)
    case fileUnreadable(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotDownloadedLocally:
            return "This file is stored in iCloud Drive and isn't downloaded to your device."
        case .fileDownloadFailed(let reason):
            return "Could not download this file from iCloud: \(reason)"
        case .fileUnreadable(let reason):
            return "This file could not be read: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .fileNotDownloadedLocally:
            return "Allow iCloud downloads in Settings › Scanning Options, or open the file in Files to download it first."
        case .fileDownloadFailed:
            return "Check your connection and try again, or open the file in Files to download it first."
        case .fileUnreadable:
            return "Pick a different file or export a copy into Pencil'd."
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
            return "Go to iOS Settings > Pencil’d > Calendars and select 'Full Access'."
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
            return "Pencil’d supports a maximum of 3 staggered reminder offsets per event."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Go to iOS Settings > Pencil’d > Reminders and grant full access."
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
            return "Enable notifications in iOS Settings > Notifications > Pencil’d."
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
    case restoreFailed
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
        case .restoreFailed:
            return "Couldn't restore purchases. Check your connection and sign in with the Apple Account used to subscribe, then try again."
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
