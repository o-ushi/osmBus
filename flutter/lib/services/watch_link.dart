import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/trip_controller.dart';
import '../ui/theme.dart';
import 'app_log.dart';

/// Apple Watch への橋渡し（iOS の `WatchBridge`）。iPhone が正で、Watch は表示・長押し・手首のバイブだけ。
/// 乗車状態の写しは表示が変わったときだけ送る（毎秒の測位では送らない）。
class WatchLink {
  WatchLink(this.controller, {MethodChannel? channel}) : _channel = channel ?? const MethodChannel('osmbus/watch');

  final TripController controller;
  final MethodChannel _channel;

  Map<String, Object?>? _lastSent;
  StreamSubscription<int>? _alerts;

  void start() {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler(_onCall);
    controller.addListener(_publish);
    _alerts = controller.vibrationAlerts.listen((count) => _invoke('alert', count));
    _publish();
  }

  void dispose() {
    controller.removeListener(_publish);
    _alerts?.cancel();
    _channel.setMethodCallHandler(null);
  }

  /// Watch に出す内容。キーは iOS の `WatchRideSnapshot` と同じ。
  static Map<String, Object?> snapshotOf(TripController controller) {
    final riding = controller.riding;
    final meters = controller.distanceLeftMeters;
    return {
      'isRiding': riding != null,
      'busNumber': riding?.ref,
      'nextTransferBusNumber': controller.nextTransferRef,
      'boardBusNumber': controller.boardableRef,
      // 距離バッジと同じ文字。未乗車では出さない。
      'distanceText': riding == null || meters == null ? null : DistanceColorBand.format(meters),
    };
  }

  void _publish() {
    final snapshot = snapshotOf(controller);
    if (mapEquals(snapshot, _lastSent)) return;
    _lastSent = snapshot;
    _invoke('snapshot', snapshot);
  }

  void _invoke(String method, Object? arguments) {
    unawaited(_channel.invokeMethod<void>(method, arguments).catchError((Object e) {
      AppLog.w('watch', '$method failed $e');
    }));
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'longPress') throw MissingPluginException(call.method);
    final number = call.arguments as String?;
    if (number == null) return false;
    final handled = controller.longPressBusNumber(number);
    AppLog.i('watch', 'long press $number handled=$handled');
    return handled;
  }
}
