import SwiftUI

// MARK: - iCloud & Remote Downloads Settings Card
/// The Settings UI for `ICloudDownloadPreference`. Lives under Settings › Scanning Options and is
/// also surfaced from the iCloud confirmation prompts ("Change this anytime in Settings ›
/// Scanning Options › iCloud & remote downloads"). Kept in its own file so the preference enum
/// (`RemoteAssetGate.swift`), the confirmation flow (`ICloudDownloadConfirmationView.swift`), and
/// this settings card each stay focused on one concern.
struct ICloudDownloadSettingsCard: View {
    @AppStorage(ICloudDownloadPreference.key) private var preferenceRaw = ICloudDownloadPreference.ask.rawValue

    private var preference: ICloudDownloadPreference {
        ICloudDownloadPreference(rawValue: preferenceRaw) ?? .ask
    }

    var body: some View {
        PDCard {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "icloud.fill", tint: .pdPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud & remote downloads")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Pencil’d only scans items already on this device by default.")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("When a photo, PDF, or file is stored in iCloud and isn’t downloaded, choose what happens before Pencil’d reads it.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(ICloudDownloadPreference.allCases, id: \.self) { option in
                        Button {
                            preferenceRaw = option.rawValue
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: preference == option ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(preference == option ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.displayName)
                                        .font(PDFont.labelLG)
                                        .foregroundStyle(Color.pdOnSurface)
                                    Text(description(for: option))
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(preference == option ? .isSelected : [])
                    }
                }

                Text("Apple downloads iCloud items through its built-in process before Pencil’d reads them on this device. Nothing is uploaded afterward.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func description(for option: ICloudDownloadPreference) -> String {
        switch option {
        case .ask: return "Ask before each batch with iCloud-only items."
        case .allow: return "Download iCloud-only items without asking."
        case .skip: return "Never download; skip iCloud-only items with a message."
        }
    }
}
