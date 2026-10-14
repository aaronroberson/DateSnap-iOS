import SwiftUI

// Shared Pencil’d building blocks ("Luminous Precision"). Built only from the tokens in
// Theme/PencilTokens.swift so screens share one look. All tap targets are at least 44pt.

// MARK: - Eyebrow (glowing dot + uppercase label)
struct PDEyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.pdPrimaryContainer)
                .frame(width: 6, height: 6)
                .shadow(color: Color.pdPrimaryContainer.opacity(0.8), radius: 4)
                .accessibilityHidden(true)
            Text(text)
                .font(PDFont.labelSM)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.pdPrimary)
        }
    }
}

// MARK: - Screen intro (eyebrow, display title, subtitle)
struct PDScreenIntro: View {
    /// Omit when it would only repeat the title.
    let eyebrow: String?
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PDSpacing.xs) {
            if let eyebrow { PDEyebrow(text: eyebrow) }
            Text(title)
                .font(PDFont.headlineXL)
                .foregroundStyle(Color.pdOnSurface)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Top bar (labeled back button, optional title, optional trailing)
/// Name of the screen a pushed screen returns to, set by the navigation stack that pushes it
/// (e.g. "Settings", "Agenda"). Unset in sheets and anywhere the origin can vary, so the back
/// button falls back to the generic "Back".
private struct PDBackLabelKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var pdBackLabel: String? {
        get { self[PDBackLabelKey.self] }
        set { self[PDBackLabelKey.self] = newValue }
    }
}

struct PDTopBar<Trailing: View>: View {
    let title: String
    var showsBack: Bool = true
    var onBack: (() -> Void)? = nil
    /// Overrides the environment's back label for this bar only.
    var backLabel: String? = nil
    /// Off by default: almost every screen opens with a `PDScreenIntro` heading right below, and a
    /// second copy of the title in the bar is redundant. Turn on for screens without an intro.
    var showsTitle = false
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pdBackLabel) private var environmentBackLabel

    private var resolvedBackLabel: String { backLabel ?? environmentBackLabel ?? "Back" }

    var body: some View {
        HStack(spacing: PDSpacing.sm) {
            if showsBack {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text(resolvedBackLabel.uppercased())
                            .font(PDFont.labelMD)
                            .tracking(0.6)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.pdOnSurface)
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Color.pdSurfaceContainer))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel(resolvedBackLabel == "Back" ? "Back" : "Back to \(resolvedBackLabel)")
            }
            if showsTitle {
                Text(title)
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: 44)
    }
}

extension PDTopBar where Trailing == EmptyView {
    init(title: String, showsBack: Bool = true, onBack: (() -> Void)? = nil, showsTitle: Bool = false) {
        self.init(title: title, showsBack: showsBack, onBack: onBack, showsTitle: showsTitle) { EmptyView() }
    }
}

// MARK: - Interstitial header (pinned close, top-right)
/// Pinned header for interstitial sheets such as the paywalls, which can open from anywhere.
/// It keeps the close button in the top-right corner while the content scrolls beneath it.
/// The bar itself is transparent so the screen's ambient gradient reaches the top edge.
struct PDInterstitialHeader: View {
    let closeLabel: String

    var body: some View {
        HStack {
            Spacer()
            PDCloseButton(accessibilityLabel: closeLabel)
        }
        .padding(.horizontal, PDSpacing.md)
        .padding(.vertical, PDSpacing.sm)
    }
}

// MARK: - Plan option (paywall billing period)
/// Selectable billing-period row. The selected option fills with the action gradient; the
/// checkmark, label, and color together carry the selected state.
struct PDPlanOption: View {
    let title: String
    var badge: String? = nil
    /// Angled purple tag (e.g. "Intro offer") that starts at the middle of the title, just above it,
    /// and rises past the top edge of the option.
    var ribbon: String? = nil
    let detail: String
    let price: String
    var showsPerMonth = false
    let isSelected: Bool
    /// The plan the user already has: shown with a "Current plan" badge and not selectable.
    var isCurrent = false
    let action: () -> Void
    @State private var titleWidth: CGFloat = 0

    private var primaryText: Color { isSelected ? .pdOnPrimaryFixed : .pdOnSurface }
    private var secondaryText: Color { isSelected ? .pdOnPrimaryFixed.opacity(0.75) : .pdOnSurfaceVariant }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(PDFont.labelLG)
                            .foregroundStyle(primaryText)
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { titleWidth = $0 }
                        if isCurrent {
                            Text("CURRENT PLAN")
                                .font(PDFont.labelSM)
                                .tracking(0.4)
                                .foregroundStyle(Color.pdOnSurface)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.pdSurfaceHighest))
                        } else if let badge {
                            Text(badge)
                                .font(PDFont.labelSM)
                                .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnPrimaryFixed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(isSelected ? Color.pdOnPrimaryFixed : Color.pdPrimary))
                        }
                    }
                    Text(detail)
                        .font(PDFont.bodySM)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(PDFont.headlineSM)
                        .foregroundStyle(primaryText)
                    if showsPerMonth {
                        Text("/ month")
                            .font(PDFont.bodySM)
                            .foregroundStyle(secondaryText)
                    }
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? Color.pdOnPrimaryFixed : Color.pdOnSurfaceVariant)
                    .padding(.leading, 8)
                    .accessibilityHidden(true)
            }
            .padding(Self.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.plan)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.pdAction) : AnyShapeStyle(Color.pdSurfaceLow))
            )
            .overlay(alignment: .topLeading) {
                if let ribbon, !isCurrent { ribbonTag(ribbon) }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
        .opacity(isCurrent ? 0.6 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isCurrent ? "Current plan" : "")
        .accessibilityHint(isCurrent ? "" : (ribbon ?? ""))
    }

    private static let contentPadding: CGFloat = 16

    private func ribbonTag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(PDFont.labelSM)
            .tracking(0.6)
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.pdSecondaryContainer))
            .shadow(color: Color.pdSecondaryContainer.opacity(0.45), radius: 6, y: 2)
            .rotationEffect(.degrees(-10), anchor: .bottomLeading)
            // Pinned to the option's top-left, then moved so its bottom-left corner sits just above the
            // title at its horizontal middle; the tilt carries it past the option's top edge.
            .offset(x: Self.contentPadding + titleWidth / 2, y: -10)
            .accessibilityHidden(true)
    }
}

// MARK: - Close button
/// Top-right close for sheets that can open from anywhere. Pushed screens use `PDTopBar`'s
/// back chevron instead.
struct PDCloseButton: View {
    var accessibilityLabel = "Close"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.pdSurfaceHighest))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Card
struct PDCard<Content: View>: View {
    var padding: CGFloat = PDSpacing.md
    var highlighted: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(highlighted ? AnyShapeStyle(LinearGradient.pdHighlightCard)
                                      : AnyShapeStyle(Color.pdSurfaceContainer.opacity(0.85)))
                    .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
            )
    }
}

// MARK: - Icon tile
struct PDIconTile: View {
    enum Size { case small, large }
    let systemName: String
    var tint: Color = .pdPrimary
    var size: Size = .small

    var body: some View {
        let side: CGFloat = size == .small ? 32 : 48
        let radius: CGFloat = size == .small ? PDRadius.tile : PDRadius.card
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.pdSurfaceHighest.opacity(0.7))
            .frame(width: side, height: side)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size == .small ? 14 : 20, weight: .semibold))
                    .foregroundStyle(tint)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Section header
struct PDSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(PDFont.labelSM)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .padding(.horizontal, PDSpacing.xxs)
    }
}

// MARK: - Grouped list
struct PDGroupedList<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .background(Color.pdSurfaceLow.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 3)
    }
}

struct PDRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.pdSurfaceHighest.opacity(0.6))
            .frame(height: 1)
            .padding(.leading, PDSpacing.md + 32 + 12)
    }
}

// MARK: - List row (icon tile, title, subtitle, trailing)
struct PDListRow<Trailing: View>: View {
    let icon: String
    var tint: Color = .pdPrimary
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            PDIconTile(systemName: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                if let subtitle {
                    Text(subtitle)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(PDSpacing.md)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Trailing value text followed by a chevron.
struct PDValueChevron: View {
    var value: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let value {
                Text(value)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.pdOutline)
        }
    }
}

extension PDListRow where Trailing == PDValueChevron {
    init(icon: String, tint: Color = .pdPrimary, title: String, subtitle: String? = nil, value: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { PDValueChevron(value: value) }
    }
}

/// Whole-row button style: full-width hit area with press feedback.
struct PDRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color.pdPrimary.opacity(0.10) : Color.clear)
    }
}

// MARK: - Toggle
struct PDToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: configuration.$isOn) { configuration.label }
            .tint(Color.pdPrimaryContainer)
    }
}

/// A list row with a switch; the switch label is the row title for VoiceOver.
struct PDToggleRow: View {
    let icon: String
    var tint: Color = .pdPrimary
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        PDListRow(icon: icon, tint: tint, title: title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(PDToggleStyle())
        }
    }
}

// MARK: - Chip
struct PDChip: View {
    let text: String
    var icon: String? = nil
    var selected: Bool = false
    /// The plan that unlocks this control. Paid chips get the `pdPaidFeature` wash and a tier tag.
    var paidTier: SubscriptionTier? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
            }
            Text(text).font(PDFont.labelMD)
            if let paidTier {
                PDTierTag(tier: paidTier)
            }
        }
        .foregroundStyle(selected ? Color.pdPrimary : Color.pdOnSurfaceVariant)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(selected ? AnyShapeStyle(Color.pdPrimary.opacity(0.15))
                           : paidTier != nil ? AnyShapeStyle(LinearGradient.pdPaidFeature)
                           : AnyShapeStyle(Color.pdSurfaceHighest))
        )
        .frame(minHeight: 44)
        .contentShape(Capsule())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Search field
/// Shared search input (Agenda, History & Archive, Help & Support). At least 48pt tall so it is
/// never shorter than the 44pt filter chips beside it, with or without the clear button.
struct PDSearchField: View {
    @Binding var text: String
    let prompt: String
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .font(PDFont.jakarta(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(Color.pdOnSurface)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 4)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceContainer)
        )
    }
}

// MARK: - Tier tag
/// Small "PLUS" / "PREMIUM" label on paid controls, so the tier is never shown by color alone.
struct PDTierTag: View {
    let tier: SubscriptionTier

    var body: some View {
        Text(tier.badgeText)
            .font(PDFont.labelSM)
            .tracking(0.4)
            .foregroundStyle(Color.pdLavender)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.pdLavender.opacity(0.18)))
    }
}

// MARK: - Status badge (always icon + label + color)
struct PDStatusBadge: View {
    enum Tone { case success, warning, info, neutral, error }
    let text: String
    var icon: String? = nil
    var tone: Tone = .neutral

    private var color: Color {
        switch tone {
        case .success: return .pdSuccess
        case .warning: return .pdWarning
        case .info: return .pdInfo
        case .neutral: return .pdOnSurfaceVariant
        case .error: return .pdError
        }
    }

    private var statusIcon: String {
        if let icon { return icon }
        switch tone {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "circle"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon).font(.system(size: 10, weight: .bold))
            Text(text).font(PDFont.labelSM).tracking(0.4).textCase(.uppercase)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
        .fixedSize(horizontal: false, vertical: true)
    }
}
