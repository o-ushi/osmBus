import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_log.dart';

/// アプリが裏にあるときの到着アラートをローカル通知で出す（Swift の `postLocalNotification`）。
/// 音と振動は [SoundPlayer] が鳴らすので、通知自体は無音にする（二重に鳴らさない）。
class AlertNotifier {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 1;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      AppLog.w('notify', 'init failed $e');
    }
  }

  /// 乗車を始めたときに許可を求める（起動直後には聞かない）。
  Future<void> requestPermission() async {
    await init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      AppLog.w('notify', 'permission request failed $e');
    }
  }

  Future<void> show(String title, String body) async {
    await init();
    if (!_ready) return;
    AppLog.i('notify', 'show "$title"');
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'arrival_alerts',
            'Arrival alerts',
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: false),
        ),
      );
    } catch (e) {
      AppLog.w('notify', 'show failed $e');
    }
  }
}
