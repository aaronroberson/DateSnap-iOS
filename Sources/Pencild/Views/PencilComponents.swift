import SwiftUI

// Shared Pencil'd building blocks ("Luminous Precision"). Built only from the tokens in
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
    let eyebrow: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PDSpacing.xs) {
            PDEyebrow(text: eyebrow)
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

// MARK: - Top bar (back circle, title, optional trailing)
struct PDTopBar<Trailing: View>: View {
    let title: String
    var showsBack: Bool = true
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: PDSpacing.sm) {
            if showsBack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.pdSurfaceContainer))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            Text(title)
                .font(PDFont.headlineSM)
                .foregroundStyle(Color.pdOnSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: 44)
    }
}

extension PDTopBar where Trailing == EmptyView {
    init(title: String, showsBack: Bool = true) {
        self.init(title: title, showsBack: showsBack) { EmptyView() }
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
    let detail: String
    let price: String
    var showsPerMonth = false
    let isSelected: Bool
    let action: () -> Void

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
                        if let badge {
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.plan)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.pdAction) : AnyShapeStyle(Color.pdSurfaceLow))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
            }
            Text(text).font(PDFont.labelMD)
        }
        .foregroundStyle(selected ? Color.pdPrimary : Color.pdOnSurfaceVariant)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(selected ? AnyShapeStyle(Color.pdPrimary.opacity(0.15)) : AnyShapeStyle(Color.pdSurfaceHighest))
        )
        .frame(minHeight: 44)
        .contentShape(Capsule())
        .accessibilityAddTraits(selected ? .isSelected : [])
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
