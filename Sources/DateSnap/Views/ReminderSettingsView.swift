import SwiftUI

struct ReminderSettingsView: View {
    @State private var previewEventStart = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Reminder Preview", showBack: true)

                VStack(alignment: .leading, spacing: 10) {
                    SettingsSectionHeader(icon: "bell.badge.fill", title: "Preview", tint: .dsPrimary)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("New reviewed events start with the default alerts shown below. This date is only used to preview their timing.")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)

                        DatePicker(
                            "Example event",
                            selection: $previewEventStart,
                            in: Date.now...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(DSTypography.bodyCompact())
                        .tint(Color.dsPrimary)
                        .frame(minHeight: 44)

                        Divider().overlay(Color.dsBorder)

                        ForEach(ReminderOffset.defaultStaggered) { offset in
                            HStack(spacing: 10) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(Color.dsPrimary)
                                    .frame(width: 24)
                                Text(offset.label.capitalized)
                                    .font(DSTypography.bodyCompact().weight(.semibold))
                                    .foregroundStyle(Color.dsForeground)
                                Spacer()
                                Text(offset.triggerDate(forEventStart: previewEventStart, isAllDay: false)
                                    .formatted(date: .abbreviated, time: .shortened))
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                            .frame(minHeight: 44)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(16)
                    .dsGlassCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
    }
}
