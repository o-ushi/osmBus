import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/alert_notifier.dart';
import 'services/app_log.dart';
import 'services/google_maps_config.dart';
import 'services/sound_player.dart';
import 'state/app_settings.dart';
import 'state/trip_controller.dart';

Future<void> main() async {
  // 捕まえ損ねた例外もログに残す（送ってもらって原因を追うため）。
  runZonedGuarded(_run, (error, stack) => AppLog.e('crash', 'uncaught', error, stack));
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    AppLog.e('flutter', details.exceptionAsString(), null, details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.e('platform', 'uncaught', error, stack);
    return true;
  };

  await AppLog.instance.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  await GoogleMapsConfig.instance.load(prefs);
  AppLog.instance.verbose = settings.verboseLog;
  try {
    final info = await PackageInfo.fromPlatform();
    AppLog.i('app', 'start ${info.version} (${info.buildNumber}) ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  } catch (_) {
    AppLog.i('app', 'start');
  }

  final controller = TripController(
    prefs: prefs,
    settings: settings,
    sound: SoundPlayer(settings: settings),
    notifier: AlertNotifier(),
  );
  controller.purchases.start();
  runApp(OsmBusApp(controller: controller));
  await controller.start();
}
