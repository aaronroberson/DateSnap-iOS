import SwiftUI

// Shared building blocks for the Settings cluster screens.
// Wraps the canonical Pencil'd design system components in `PencilComponents.swift`
// while keeping existing call sites working.

// MARK: - Screen header with optional custom back button (pushed screens)
struct SettingsScreenHeader: View {
    let title: String
    var showBack: Bool = false

    var body: some View {
        PDTopBar(title: title, showsBack: showBack) {
            Image(systemName: "person.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.pdOnPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.pdPrimary))
                .accessibilityHidden(true)
        }
    }
}

struct SettingsBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
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
}

// MARK: - Uppercase section header with icon tile + trailing chip
struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    var tint: Color = .pdPrimary
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: PDSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Capsule().fill(tint.opacity(0.15)))
            Text(title)
                .font(PDFont.labelSM)
                .tracking(0.6)
                .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
                .textCase(.uppercase)
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

// MARK: - Small tinted value chip
struct ValueChip: View {
    let text: String
    var tint: Color = .pdPrimary
    var filled: Bool = false
    var systemImage: String? = nil

    var body: some View {
        PDStatusBadge(
            text: text,
            icon: systemImage,
            tone: tint == .pdSuccess ? .success :
                  tint == .pdWarning ? .warning :
                  tint == .pdInfo ? .info :
                  tint == .pdError ? .error : .neutral
        )
    }
}

struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.pdOutline)
    }
}

// MARK: - Standard settings row
struct SettingRow<Trailing: View>: View {
    let icon: String
    var iconTint: Color = .pdPrimary
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        PDListRow(icon: icon, tint: iconTint, title: title, subtitle: subtitle, trailing: trailing)
    }
}

extension SettingRow where Trailing == SettingsChevron {
    init(icon: String, iconTint: Color = .pdPrimary, title: String, subtitle: String? = nil) {
        self.init(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle) { SettingsChevron() }
    }
}

// MARK: - Toggle row
struct SettingToggleRow: View {
    let icon: String
    var iconTint: Color = .pdPrimary
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        PDToggleRow(icon: icon, tint: iconTint, title: title, subtitle: subtitle, isOn: $isOn)
    }
}

// MARK: - Footer caption block
struct SettingsFooterNote: View {
    let lines: [String]
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: PDSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.pdPrimary)
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PDSpacing.xxs)
    }
}
