import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../services/sound_player.dart';
import '../state/app_settings.dart';
import '../state/trip_controller.dart';
import 'grouped_list.dart';
import 'settings_screen.dart';
import 'sheet_page.dart';
import 'theme.dart';

String formatAlertMeters(int m) {
  if (m >= 1000) return m % 1000 == 0 ? '${m ~/ 1000}km' : '${(m / 1000).toStringAsFixed(1)}km';
  return '${m}m';
}

String alertSoundName(AppLocalizations l10n, String id) => switch (id) {
      'alarm' => l10n.soundTriTone,
      'chime' => l10n.soundChime,
      'ding' => l10n.soundDing,
      'message' => l10n.soundMessage,
      'confirm' => l10n.soundConfirm,
      'tock' => l10n.soundTock,
      'bell' => l10n.soundBell,
      _ => l10n.soundTiptoes,
    };

/// 到着アラートの設定（Swift の `StopAlertSettingsView`）。
class AlertSettingsScreen extends StatelessWidget {
  const AlertSettingsScreen({super.key, required this.controller});

  final TripController controller;

  Future<void> _pickMeters(BuildContext context, DistanceAlertSlot slot) async {
    final settings = controller.settings;
    final picked = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(AppLocalizations.of(context).distanceAlertMeters),
        actions: [
          for (final preset in DistanceAlertSlot.presets)
            CupertinoActionSheetAction(
              isDefaultAction: preset == slot.meters,
              onPressed: () => Navigator.pop(context, preset),
              child: Text(formatAlertMeters(preset)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ),
    );
    if (picked != null) await settings.setSlotMeters(slot.index, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = controller.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final alarm = settings.isAlertEnabled(StopAlertMode.alarm);
        final vibration = settings.isAlertEnabled(StopAlertMode.vibration);
        return SheetPage(
          title: l10n.arrivalAlerts,
          children: [
            GroupedSection(
              title: l10n.distanceAlerts,
              footer: l10n.distanceAlertsFooter,
              children: [
                for (final slot in settings.distanceSlots) ...[
                  GroupedRow(
                    title: l10n.distanceAlertN(slot.index + 1),
                    trailing: CupertinoSwitch(
                      value: slot.enabled,
                      onChanged: (on) => settings.setSlotEnabled(slot.index, on),
                    ),
                  ),
                  if (slot.enabled)
                    GroupedLinkRow(
                      title: l10n.distanceAlertMeters,
                      value: formatAlertMeters(slot.meters),
                      onTap: () => _pickMeters(context, slot),
                    ),
                ],
              ],
            ),
            GroupedSection(
              title: l10n.alertAlarm,
              children: [
                GroupedRow(
                  title: l10n.alertAlarm,
                  trailing: CupertinoSwitch(
                    value: alarm,
                    onChanged: (on) => settings.setAlertEnabled(StopAlertMode.alarm, on),
                  ),
                ),
                if (alarm) ...[
                  GroupedLinkRow(
                    title: l10n.alertSound,
                    value: alertSoundName(l10n, settings.alertSoundId),
                    onTap: () => SheetPage.push<void>(context, (_) => _SoundPickerScreen(controller: controller)),
                  ),
                  GroupedRow(
                    title: l10n.alertFollowSystemVolume,
                    trailing: CupertinoSwitch(
                      value: settings.alertFollowsSystemVolume,
                      onChanged: settings.setAlertFollowsSystemVolume,
                    ),
                  ),
                  if (!settings.alertFollowsSystemVolume) ...[
                    VolumeSlider(
                      title: l10n.volume,
                      value: settings.alertVolume,
                      onChanged: settings.setAlertVolume,
                    ),
                    _PreviewButton(
                      icon: CupertinoIcons.speaker_2,
                      onPressed: () => controller.sound
                          ?.previewAlert(settings.alertSoundId, volume: settings.alertVolume),
                    ),
                  ],
                ],
              ],
            ),
            GroupedSection(
              title: l10n.alertVibration,
              children: [
                GroupedRow(
                  title: l10n.alertVibration,
                  trailing: CupertinoSwitch(
                    value: vibration,
                    onChanged: (on) => settings.setAlertEnabled(StopAlertMode.vibration, on),
                  ),
                ),
                if (vibration) ...[
                  StrengthPicker(
                    title: l10n.alertVibrationStrength,
                    value: settings.alertVibrationStrength,
                    onChanged: settings.setAlertVibrationStrength,
                  ),
                  _PreviewButton(
                    icon: CupertinoIcons.device_phone_portrait,
                    onPressed: () => SoundPlayer.haptic(settings.alertVibrationStrength),
                  ),
                ],
              ],
            ),
            GroupedSection(
              title: l10n.alertNotification,
              footer: l10n.alertNotificationFooter,
              children: [
                GroupedRow(
                  title: l10n.alertNotification,
                  trailing: CupertinoSwitch(
                    value: settings.isAlertEnabled(StopAlertMode.alert),
                    onChanged: (on) => settings.setAlertEnabled(StopAlertMode.alert, on),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: CupertinoButton.tinted(
          sizeStyle: CupertinoButtonSize.small,
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context).preview),
            ],
          ),
        ),
      ),
    );
  }
}

/// サウンドの選択。行をタップで選んで試聴、スピーカーで試聴だけ。
class _SoundPickerScreen extends StatelessWidget {
  const _SoundPickerScreen({required this.controller});

  final TripController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = controller.settings;
    double volume() => settings.alertFollowsSystemVolume ? 1.0 : settings.alertVolume;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SheetPage(
        title: l10n.chooseSound,
        children: [
          GroupedSection(
            children: [
              for (final sound in AlertSound.all)
                GroupedRow(
                  title: alertSoundName(l10n, sound.id),
                  onTap: () {
                    settings.setAlertSoundId(sound.id);
                    controller.sound?.previewAlert(sound.id, volume: volume());
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () => controller.sound?.previewAlert(sound.id, volume: volume()),
                        child: const Icon(CupertinoIcons.speaker_2_fill, size: 20),
                      ),
                      SizedBox(
                        width: 28,
                        child: settings.alertSoundId == sound.id
                            ? const Icon(CupertinoIcons.checkmark_alt, color: AppTheme.accent, size: 20)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
