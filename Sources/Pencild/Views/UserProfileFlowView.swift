import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Profile
/// Account-light profile. Pencil'd has no server, so identity is exactly what Sign in with Apple
/// returns (Apple verifies the Apple ID and its email), stored on this device. There are no
/// email/phone verification steps. Plan comes from StoreKit; activity is counted from saved events.
struct UserProfileFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]

    @AppStorage("account.appleUserID") private var appleUserID = ""
    @AppStorage("account.displayName") private var displayName = ""
    @AppStorage("account.email") private var email = ""
    @AppStorage("account.linkedAt") private var linkedAt: Double = 0
    @AppStorage("settings.automaticCaptureEnabled") private var autoCaptureEnabled = true

    private enum EditField: String, Identifiable {
        case name
        var id: String { rawValue }
        var title: String { "Name" }
        var keyboard: UIKeyboardType { .default }
    }
    @State private var editField: EditField?
    @State private var draft = ""
    private let calendarStore = DefaultCalendarStore()

    private var isSignedInWithApple: Bool { !appleUserID.isEmpty }

    private var tier: SubscriptionTier { appState.subscriptionTier }

    private var savedCount: Int { savedEvents.filter { $0.status == .saved }.count }
    private var archivedCount: Int { savedEvents.filter { $0.status == .archived }.count }
    private var thisWeekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return savedEvents.filter { $0.createdAt >= cutoff }.count
    }
    private var remindersCount: Int { savedEvents.reduce(0) { $0 + $1.externalReminderIds.count } }
    private var firstSavedDate: Date? { savedEvents.last?.createdAt }

    private var planTitle: String { tier == .starter ? "Pencil’d Free" : "Pencil’d \(tier.displayName)" }
    private var planSummary: String {
        switch tier {
        case .starter: return "Upgrade to Plus for auto-detect and unlimited screenshot scans."
        case .plus: return "Unlimited screenshot scans and multi-stage reminders."
        case .premium: return "PDF import, multi-page documents and batch scanning."
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header
                intro
                identityCard
                planCard
                activityGrid
                credentialsCard
                preferencesCard
                privacyCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .dsScreenBackground()
        .task { await validateAppleCredential() }
        .alert(
            editField?.title ?? "",
            isPresented: Binding(get: { editField != nil }, set: { if !$0 { editField = nil } })
        ) {
            TextField(editField?.title ?? "", text: $draft)
                .keyboardType(editField?.keyboard ?? .default)
            Button("Save") { commitEdit() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved on this device only.")
        }
    }

    // MARK: Account actions
    private func beginEdit(_ field: EditField) {
        switch field {
        case .name: draft = displayName
        }
        editField = field
    }

    private func commitEdit() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch editField {
        case .name: displayName = value
        case nil: break
        }
        editField = nil
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            appleUserID = credential.user
            linkedAt = Date().timeIntervalSince1970
            if let components = credential.fullName {
                let formatted = PersonNameComponentsFormatter().string(from: components)
                if !formatted.isEmpty { displayName = formatted }
            }
            // Apple only returns name/email on the first authorization.
            if let appleEmail = credential.email, !appleEmail.isEmpty {
                email = appleEmail
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                appState.showToast("Sign in with Apple didn’t complete")
            }
        }
    }

    private func signOut() {
        appleUserID = ""
        displayName = ""
        email = ""
        linkedAt = 0
    }

    /// If the person revoked Pencil’d in Apple ID settings, drop the stale link.
    private func validateAppleCredential() async {
        guard !appleUserID.isEmpty else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: appleUserID)
        if state == .revoked || state == .notFound { signOut() }
    }

    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "" : String(parts).uppercased()
    }

    // MARK: Sections
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.dsForeground)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.dsCard))
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Profile")
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsForeground)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(Color.dsPrimary).frame(width: 6, height: 6)
                Text("PROFILE")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsPrimary)
            }
            Text("Your Pencil’d")
                .font(DSTypography.displayTitle())
                .foregroundStyle(Color.dsForeground)
            Text("Your plan and capture activity, kept on this device.")
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: tier == .starter ? "sparkles" : "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dsPrimary)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsPrimary.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    Text(planSummary)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                Spacer()
            }
            Button {
                appState.activeModal = .premiumPaywall
            } label: {
                Text(tier == .starter ? "See plans" : "Manage subscription")
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsSurfaceElevated))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .dsGlassCard()
    }

    private var activityGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(title: "Saved events", value: savedCount, icon: "calendar.badge.plus", tint: .dsPrimary)
                metricTile(title: "Added this week", value: thisWeekCount, icon: "doc.viewfinder.fill", tint: .dsSecondary)
                metricTile(title: "Reminders set", value: remindersCount, icon: "bell.fill", tint: .dsAccent)
                metricTile(title: "Archived", value: archivedCount, icon: "archivebox.fill", tint: .dsMutedForeground)
            }
        }
    }

    private var identityCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.dsBrandGradient, lineWidth: 2).frame(width: 68, height: 68)
                    Circle().fill(Color.dsBackground).frame(width: 64, height: 64)
                    if initials.isEmpty {
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.dsMutedForeground)
                    } else {
                        Text(initials)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.dsBrandGradient)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName.isEmpty ? (isSignedInWithApple ? "Apple ID linked" : "Not signed in") : displayName)
                        .font(DSTypography.headlineCard())
                        .foregroundStyle(displayName.isEmpty ? Color.dsMutedForeground : Color.dsForeground)
                    if isSignedInWithApple {
                        Text(email.isEmpty ? "Email hidden by Apple" : email)
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: isSignedInWithApple ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark")
                            .font(.system(size: 11))
                            .foregroundStyle(isSignedInWithApple ? Color.dsPrimary : Color.dsMutedForeground)
                        Text(isSignedInWithApple ? "Verified by Apple" : "Sign in to link your Apple ID")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                }
                Spacer()
            }

            if isSignedInWithApple {
                Button(action: signOut) {
                    Text("Sign out")
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsSurfaceElevated))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("Signing out clears these details from this device. Your saved events stay on this device.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            } else {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                Text("Optional. Pencil’d works without an account; signing in shows your Apple ID name and email here.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
        }
        .padding(16)
        .dsGlassCard()
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCOUNT DETAILS")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                editableRow(icon: "person.text.rectangle", title: "Name", value: displayName, placeholder: isSignedInWithApple ? "Add" : "—", badge: nil) {
                    if isSignedInWithApple { beginEdit(.name) }
                }
                Divider().overlay(Color.dsBorder)
                detailRow(
                    icon: "envelope", title: "Email",
                    value: isSignedInWithApple ? (email.isEmpty ? "Hidden by Apple" : email) : "—"
                )
                Divider().overlay(Color.dsBorder)
                detailRow(icon: "apple.logo", title: "Apple ID", value: isSignedInWithApple ? "Linked · verified" : "Not linked")
                Divider().overlay(Color.dsBorder)
                detailRow(
                    icon: "clock", title: "Signed in",
                    value: linkedAt > 0 ? Date(timeIntervalSince1970: linkedAt).formatted(date: .abbreviated, time: .omitted) : "—"
                )
                Divider().overlay(Color.dsBorder)
                detailRow(icon: "lock.shield", title: "Data storage", value: "On this device")
                Divider().overlay(Color.dsBorder)
                detailRow(
                    icon: "calendar",
                    title: "First event saved",
                    value: firstSavedDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "None yet"
                )
            }
            .dsGlassCard()
            Text("Name and email come from your Apple ID. Apple shares them only the first time you sign in, and they stay on this device.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)
        }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PIPELINE & PREFERENCES")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                navRow(icon: "alarm.fill", title: "Reminder defaults", value: "Smart, by event type", route: .reminderSettings)
                Divider().overlay(Color.dsBorder)
                navRow(icon: "calendar.badge.checkmark", title: "Target calendar", value: calendarStore.defaultCalendarTitle() ?? "iOS default", route: .defaultCalendar)
                Divider().overlay(Color.dsBorder)
                navRow(icon: "camera.viewfinder", title: "Automatic capture", value: autoCaptureEnabled ? "On" : "Off", route: .automationSettings)
                Divider().overlay(Color.dsBorder)
                detailRow(icon: "checkmark.rectangle", title: "Capture pipeline", value: "Review before saving")
            }
            .dsGlassCard()
        }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 22))
                .foregroundStyle(Color.dsSuccess)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.dsSuccess.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design")
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text("Pencil’d reads your screenshots and flyers on your device. There is no Pencil’d account to sign in to.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard()
    }

    // MARK: Helpers
    private func metricTile(title: String, value: Int, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(DSTypography.displayTitle())
                .foregroundStyle(Color.dsForeground)
            Text(title)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard()
        .accessibilityElement(children: .combine)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurfaceElevated)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.dsPrimary))
            Text(title)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
            Spacer()
            Text(value)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
    }

    private func editableRow(icon: String, title: String, value: String, placeholder: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dsSurfaceElevated)
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.dsPrimary))
                Text(title)
                    .font(DSTypography.bodyCompact())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value.isEmpty ? placeholder : value)
                        .font(DSTypography.caption())
                        .foregroundStyle(value.isEmpty ? Color.dsPrimary : Color.dsMutedForeground)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(DSTypography.labelChip())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .padding(14)
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    private func navRow(icon: String, title: String, value: String, route: SettingsRoute) -> some View {
        Button { settings.pendingRoute = route.rawValue } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dsSurfaceElevated)
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.dsPrimary))
                Text(title)
                    .font(DSTypography.bodyCompact())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                Text(value)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .padding(14)
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}
