import SwiftUI

// Shared building blocks for the Settings cluster screens
// (Settings Hub, Privacy Center, Automation, Reminder Defaults, Manage Plan).

// MARK: - Screen header with optional custom back button (pushed screens)
struct SettingsScreenHeader: View {
    let title: String
    var showBack: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                SettingsBackButton()
            }
            Text(title)
                .font(DSTypography.headlineSection())
                .foregroundStyle(Color.dsForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Image(systemName: "person.crop.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.dsMutedForeground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.dsMuted))
                .overlay(Circle().stroke(Color.dsBorder, lineWidth: 1))
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.dsForeground)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.dsMuted))
                .overlay(Circle().stroke(Color.dsBorder, lineWidth: 1))
        }
    }
}

// MARK: - Uppercase section header with icon tile + trailing chip
struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    var tint: Color = .dsMutedForeground
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Capsule().fill(tint.opacity(0.12)))
                .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
            Text(title)
                .font(DSTypography.overlineConfidence())
                .tracking(1.3)
                .foregroundStyle(Color.dsForeground)
                .textCase(.uppercase)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsMutedForeground)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.dsMuted))
            }
        }
    }
}

// MARK: - Small tinted value chip
struct ValueChip: View {
    let text: String
    var tint: Color = .dsPrimary
    var filled: Bool = false
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(DSTypography.overlineConfidence())
        }
        .foregroundStyle(filled ? Color.dsPrimaryForeground : tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(filled ? tint : tint.opacity(0.14))
                .overlay(Capsule().stroke(tint.opacity(filled ? 1 : 0.3), lineWidth: 1))
        )
        .fixedSize()
    }
}

struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.dsMutedForeground.opacity(0.7))
    }
}

// MARK: - Standard settings row
struct SettingRow<Trailing: View>: View {
    let icon: String
    var iconTint: Color = .dsSecondary
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconTint.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(iconTint.opacity(0.25), lineWidth: 1)
                        )
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.bodyCompact())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dsForeground)
                if let subtitle {
                    Text(subtitle)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 2)
    }
}

extension SettingRow where Trailing == SettingsChevron {
    init(icon: String, iconTint: Color = .dsSecondary, title: String, subtitle: String? = nil) {
        self.init(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle) { SettingsChevron() }
    }
}

// MARK: - Toggle row with the design system's success-green switch
struct SettingToggleRow: View {
    let icon: String
    var iconTint: Color = .dsSecondary
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.dsSuccess)
                .fixedSize()
        }
    }
}

// MARK: - Footer caption block
struct SettingsFooterNote: View {
    let lines: [String]
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dsPrimary)
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
