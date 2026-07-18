import SwiftUI

struct StopAlertSettingsView: View {
    @Environment(\.locale) private var locale

    // MARK: - Distance alert slots
    @AppStorage("osmBus_dist_alert_0_enabled") private var dist0Enabled = true
    @AppStorage("osmBus_dist_alert_0_meters")  private var dist0Meters  = 1000
    @AppStorage("osmBus_dist_alert_1_enabled") private var dist1Enabled = true
    @AppStorage("osmBus_dist_alert_1_meters")  private var dist1Meters  = 400
    @AppStorage("osmBus_dist_alert_2_enabled") private var dist2Enabled = true
    @AppStorage("osmBus_dist_alert_2_meters")  private var dist2Meters  = 100

    // MARK: - Stop count alert
    @AppStorage("osmBus_alert_alarm")          private var alarmEnabled    = false
    @AppStorage("osmBus_alert_soundID")        private var soundID         = AlertSoundCatalog.defaultID
    @AppStorage("osmBus_alert_followsSystem")  private var followsSystem   = true
    @AppStorage("osmBus_alert_soundVolume")    private var soundVolume     = 0.8
    @AppStorage("osmBus_alert_alert")          private var alertEnabled    = true
    @AppStorage("osmBus_alert_vibration")      private var vibrationEnabled = true
    @AppStorage("osmBus_alert_vibStyle")       private var vibStyleRaw     = AlertVibrationStyle.heavy.rawValue

    private static let distancePresets = [50, 100, 150, 200, 300, 400, 500, 750, 1000, 1500, 2000]

    var body: some View {
        Form {
            distanceAlertSection
            alarmSection
            vibrationSection
            alertDisplaySection
        }
        .navigationTitle(AppLocaleString.text("設定_到着アラート", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenBackButtonWithSwipe()
    }

    // MARK: - Distance alerts

    private var distanceAlertSection: some View {
        Section {
            distanceSlotRow(
                index: 1, enabled: $dist0Enabled, meters: $dist0Meters
            )
            distanceSlotRow(
                index: 2, enabled: $dist1Enabled, meters: $dist1Meters
            )
            distanceSlotRow(
                index: 3, enabled: $dist2Enabled, meters: $dist2Meters
            )
        } header: {
            Text(AppLocaleString.text("設定_距離アラート", locale: locale))
        } footer: {
            Text(AppLocaleString.text("設定_距離アラート_フッター", locale: locale))
        }
    }

    @ViewBuilder
    private func distanceSlotRow(index: Int, enabled: Binding<Bool>, meters: Binding<Int>) -> some View {
        Toggle(
            AppLocaleString.formatted("設定_距離アラート_%d", locale: locale, index),
            isOn: enabled
        )
        if enabled.wrappedValue {
            Picker(
                AppLocaleString.text("設定_距離アラート_距離", locale: locale),
                selection: meters
            ) {
                ForEach(Self.distancePresets, id: \.self) { preset in
                    Text(formatMeters(preset)).tag(preset)
                }
            }
        }
    }

    // MARK: - Alarm sound

    private var alarmSection: some View {
        Section {
            Toggle(AppLocaleString.text("設定_アラート_アラーム", locale: locale),
                   isOn: $alarmEnabled)
            if alarmEnabled {
                NavigationLink {
                    AlertSoundPickerView(
                        selectedID: $soundID,
                        followsSystem: followsSystem,
                        volume: soundVolume
                    )
                    .environment(\.locale, locale)
                } label: {
                    HStack {
                        Text(AppLocaleString.text("設定_アラート_サウンド", locale: locale))
                        Spacer()
                        Text(soundDisplayName(for: soundID))
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(AppLocaleString.text("設定_アラート_音量_システム", locale: locale),
                       isOn: $followsSystem)
                if !followsSystem {
                    volumeRow(volume: $soundVolume, soundID: soundID, followsSystem: false)
                }
            }
        } header: {
            Text(AppLocaleString.text("設定_アラート_アラーム", locale: locale))
        }
    }

    // MARK: - Vibration

    private var vibrationSection: some View {
        Section {
            Toggle(AppLocaleString.text("設定_アラート_バイブ", locale: locale),
                   isOn: $vibrationEnabled)
            if vibrationEnabled {
                Picker(AppLocaleString.text("設定_アラート_バイブ強さ", locale: locale),
                       selection: $vibStyleRaw) {
                    ForEach(AlertVibrationStyle.allCases) { style in
                        Text(AppLocaleString.text(style.titleKey, locale: locale))
                            .tag(style.rawValue)
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        let s = AlertVibrationStyle(rawValue: vibStyleRaw) ?? .heavy
                        StopAlertPlayer.shared.previewVibration(s)
                    } label: {
                        Label(AppLocaleString.text("サウンド_プレビュー", locale: locale),
                              systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
        } header: {
            Text(AppLocaleString.text("設定_アラート_バイブ", locale: locale))
        }
    }

    // MARK: - On-screen alert

    private var alertDisplaySection: some View {
        Section {
            Toggle(AppLocaleString.text("設定_アラート_通知", locale: locale),
                   isOn: $alertEnabled)
        } header: {
            Text(AppLocaleString.text("設定_アラート_通知", locale: locale))
        } footer: {
            Text(AppLocaleString.text("設定_アラート_通知フッター", locale: locale))
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func volumeRow(volume: Binding<Double>, soundID: String, followsSystem: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(AppLocaleString.text("設定_アラート_音量", locale: locale))
                Spacer()
                Text("\(Int(volume.wrappedValue * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: volume, in: 0.05...1.0, step: 0.05)
            HStack {
                Spacer()
                Button {
                    StopAlertPlayer.shared.preview(
                        id: soundID,
                        followsSystem: followsSystem,
                        volume: volume.wrappedValue
                    )
                } label: {
                    Label(AppLocaleString.text("サウンド_プレビュー", locale: locale),
                          systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private func soundDisplayName(for id: String) -> String {
        guard let entry = AlertSoundCatalog.entry(for: id) else { return id }
        return AppLocaleString.text(entry.nameKey, locale: locale)
    }

    private func formatMeters(_ m: Int) -> String {
        if m >= 1000 {
            if m % 1000 == 0 { return "\(m / 1000)km" }
            return String(format: "%.1fkm", Double(m) / 1000.0)
        }
        return "\(m)m"
    }
}

// MARK: - Sound Picker

fileprivate struct AlertSoundPickerView: View {
    @Binding var selectedID: String
    let followsSystem: Bool
    let volume: Double
    @Environment(\.locale) private var locale

    var body: some View {
        List(AlertSoundCatalog.all) { sound in
            HStack {
                Text(AppLocaleString.text(sound.nameKey, locale: locale))
                Spacer()
                Button {
                    StopAlertPlayer.shared.preview(
                        id: sound.id,
                        followsSystem: followsSystem,
                        volume: volume
                    )
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                if selectedID == sound.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                        .padding(.leading, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedID = sound.id
                StopAlertPlayer.shared.preview(
                    id: sound.id,
                    followsSystem: followsSystem,
                    volume: volume
                )
            }
        }
        .navigationTitle(AppLocaleString.text("サウンド選択_タイトル", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenBackButtonWithSwipe()
    }
}
