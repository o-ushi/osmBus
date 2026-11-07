import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/app_log.dart';

void main() {
  test('詳細ログはオンのときだけ残し、位置は 0.001 度に丸める', () async {
    final log = AppLog.instance;
    await log.clear();
    log.verbose = false;
    AppLog.d('location', 'fix');
    AppLog.i('riding', 'start ${AppLog.coord(const GeoPoint(21.028512, 105.854218))}');
    AppLog.e('sound', 'failed', StateError('boom'));
    expect(log.recent.map((e) => e.category), ['riding', 'sound']);
    expect(log.recent.first.message, 'start 21.029,105.854');
    expect(log.recent.last.message, contains('boom'));
    log.verbose = true;
    AppLog.d('location', 'fix');
    expect(log.recent.last.level, LogLevel.debug);
  });

  test('メモリには新しい 500 件まで', () async {
    final log = AppLog.instance;
    await log.clear();
    for (var i = 0; i < AppLog.memoryLimit + 20; i++) {
      AppLog.i('t', '$i');
    }
    expect(log.recent, hasLength(AppLog.memoryLimit));
    expect(log.recent.first.message, '20');
  });
}
