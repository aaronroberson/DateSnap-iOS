import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Profile
/// Account-light profile. Pencil’d has no server, so identity is exactly what Sign in with Apple
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
    @AppStorage(AutoDetectPreference.key) private var autoCaptureEnabled = true

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

    private var planTitle: String { tier.displayName }
    private var planSummary: String {
        switch tier {
        case .starter: return "Upgrade to Plus for auto-detect and unlimited screenshot scans."
        case .plus: return "Unlimited screenshot scans and multi-stage reminders."
        case .premium: return "PDF import, multi-page documents and batch scanning."
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Profile", showsBack: true)

                PDScreenIntro(
                    eyebrow: "Profile",
                    title: "Your Pencil’d",
                    subtitle: "Your plan and capture activity, kept on this device."
                )

                identityCard
                planCard
                activityGrid
                credentialsCard
                preferencesCard
                privacyCard
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
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

    private var planCard: some View {
        PDCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    PDIconTile(systemName: tier == .starter ? "sparkles" : "crown.fill", tint: .pdPrimary, size: .large)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planTitle)
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text(planSummary)
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Spacer()
                }
                Button {
                    Task { await appState.present(.paywall(opening: .premium)) }
                } label: {
                    Text(tier == .starter ? "See plans" : "Manage subscription")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceHighest.opacity(0.7)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activityGrid: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Activity")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(title: "Saved events", value: savedCount, icon: "calendar.badge.plus", tint: .pdPrimary)
                metricTile(title: "Added this week", value: thisWeekCount, icon: "doc.viewfinder.fill", tint: .pdSecondary)
                metricTile(title: "Reminders set", value: remindersCount, icon: "bell.fill", tint: .pdTertiaryContainer)
                metricTile(title: "Archived", value: archivedCount, icon: "archivebox.fill", tint: .pdOutline)
            }
        }
    }

    private var identityCard: some View {
        PDCard(highlighted: true) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(LinearGradient.pdSignature, lineWidth: 2).frame(width: 68, height: 68)
                        Circle().fill(Color.pdSurfaceLow).frame(width: 64, height: 64)
                        if initials.isEmpty {
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.pdOutline)
                        } else {
                            Text(initials)
                                .font(PDFont.jakarta(22, .heavy, relativeTo: .title2))
                                .foregroundStyle(LinearGradient.pdAction)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName.isEmpty ? (isSignedInWithApple ? "Apple ID linked" : "Not signed in") : displayName)
                            .font(PDFont.headlineSM)
                            .foregroundStyle(displayName.isEmpty ? Color.pdOutline : Color.pdOnSurface)
                        if isSignedInWithApple {
                            Text(email.isEmpty ? "Email hidden by Apple" : email)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                        HStack(spacing: 4) {
                            if isSignedInWithApple {
                                PDStatusBadge(text: "Verified by Apple", icon: "checkmark.seal.fill", tone: .success)
                            } else {
                                PDStatusBadge(text: "Sign in to link your Apple ID", icon: "person.crop.circle.badge.questionmark", tone: .neutral)
                            }
                        }
                    }
                    Spacer()
                }

                if isSignedInWithApple {
                    Button(action: signOut) {
                        Text("Sign out")
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdError)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceHighest.opacity(0.7)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Text("Signing out clears these details from this device. Your saved events stay on this device.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                } else {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    Text("Optional. Pencil’d works without an account; signing in shows your Apple ID name and email here.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
        }
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Account Details")

            PDGroupedList {
                Button {
                    if isSignedInWithApple { beginEdit(.name) }
                } label: {
                    PDListRow(
                        icon: "person.text.rectangle",
                        tint: .pdPrimary,
                        title: "Name"
                    ) {
                        PDValueChevron(value: displayName.isEmpty ? (isSignedInWithApple ? "Add" : "—") : displayName)
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                PDListRow(
                    icon: "envelope",
                    tint: .pdPrimary,
                    title: "Email"
                ) {
                    Text(isSignedInWithApple ? (email.isEmpty ? "Hidden by Apple" : email) : "—")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }

                PDRowDivider()

                PDListRow(
                    icon: "apple.logo",
                    tint: .pdPrimary,
                    title: "Apple ID"
                ) {
                    PDStatusBadge(
                        text: isSignedInWithApple ? "Linked · verified" : "Not linked",
                        icon: isSignedInWithApple ? "checkmark.seal.fill" : nil,
                        tone: isSignedInWithApple ? .success : .neutral
                    )
                }

                PDRowDivider()

                PDListRow(
                    icon: "clock",
                    tint: .pdPrimary,
                    title: "Signed in"
                ) {
                    Text(linkedAt > 0 ? Date(timeIntervalSince1970: linkedAt).formatted(date: .abbreviated, time: .omitted) : "—")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }

                PDRowDivider()

                PDListRow(
                    icon: "lock.shield",
                    tint: .pdPrimary,
                    title: "Data storage"
                ) {
                    Text("On this device")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }

                PDRowDivider()

                PDListRow(
                    icon: "calendar",
                    tint: .pdPrimary,
                    title: "First event saved"
                ) {
                    Text(firstSavedDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "None yet")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }

            Text("Name and email come from your Apple ID. Apple shares them only the first time you sign in, and they stay on this device.")
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .padding(.horizontal, 4)
        }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Pipeline & Preferences")

            PDGroupedList {
                Button { settings.pendingRoute = .reminderSettings } label: {
                    PDListRow(
                        icon: "alarm.fill",
                        tint: .pdPrimary,
                        title: "Reminder defaults"
                    ) {
                        PDValueChevron(value: "Smart, by event type")
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button { settings.pendingRoute = .defaultCalendar } label: {
                    PDListRow(
                        icon: "calendar.badge.checkmark",
                        tint: .pdPrimary,
                        title: "Target calendar"
                    ) {
                        PDValueChevron(value: calendarStore.asksEveryTime() ? "Ask every time" : (calendarStore.defaultCalendarTitle() ?? "Automatic"))
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button { settings.pendingRoute = .automationSettings } label: {
                    PDListRow(
                        icon: "camera.viewfinder",
                        tint: .pdPrimary,
                        title: "Auto-detect screenshots"
                    ) {
                        PDValueChevron(value: autoCaptureEnabled ? "On" : "Off")
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                PDListRow(
                    icon: "checkmark.rectangle",
                    tint: .pdPrimary,
                    title: "Capture pipeline"
                ) {
                    Text("Review before saving")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
        }
    }

    private var privacyCard: some View {
        PDCard {
            HStack(alignment: .top, spacing: 12) {
                PDIconTile(systemName: "shield.checkered", tint: .pdSuccess, size: .large)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private by design")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Pencil’d reads your screenshots and flyers on your device. There is no Pencil’d account to sign in to.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .lineSpacing(2)
                }
            }
        }
    }

    // MARK: Helpers
    private func metricTile(title: String, value: Int, icon: String, tint: Color) -> some View {
        PDCard {
            VStack(alignment: .leading, spacing: 8) {
                PDIconTile(systemName: icon, tint: tint)
                Text("\(value)")
                    .font(PDFont.headlineXL)
                    .foregroundStyle(Color.pdOnSurface)
                Text(title)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
