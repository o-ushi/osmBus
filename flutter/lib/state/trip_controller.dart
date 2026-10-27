import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/boarding_decision.dart';
import '../models/destination.dart';
import '../models/bus_identifier.dart';
import '../models/bus_matrix.dart';
import '../models/local_itinerary.dart';
import '../models/riding_session.dart';
import '../models/route_catalog.dart';
import '../services/alert_notifier.dart';
import '../services/app_log.dart';
import '../services/catalog_sync.dart';
import '../services/geo.dart';
import '../services/local_planner.dart';
import '../services/purchase_service.dart';
import '../services/route_catalog_downloader.dart';
import '../services/route_catalog_store.dart';
import '../services/sound_player.dart';
import 'app_settings.dart';
import 'places_store.dart';

export '../models/destination.dart';

enum LocationStatus { unknown, ok, denied, deniedForever, serviceDisabled }

/// 番号表の状態。[ready] のときだけ旅程を描画する。
enum TableState { consentRequired, noLocation, noDestination, noRouteData, calculating, noRoutes, ready }

enum ImportMode { replace, merge }

/// 読み込みの結果。[error] があれば正本は変えていない。
class ImportResult {
  const ImportResult.ok(this.routeCount) : error = null;
  const ImportResult.failed(this.error) : routeCount = 0;
  const ImportResult.cancelled()
      : error = null,
        routeCount = -1;

  final String? error;
  final int routeCount;

  bool get isCancelled => routeCount < 0 && error == null;
}

/// 乗車中に画面へ出すアラート（Swift の `ActiveRidingAlert` と逆方向の警告）。
sealed class RidingAlert {
  const RidingAlert();
}

class DistanceRidingAlert extends RidingAlert {
  const DistanceRidingAlert(this.meters);
  final int meters;
}

class WrongDirectionRidingAlert extends RidingAlert {
  const WrongDirectionRidingAlert({required this.fromRouteMap});
  final bool fromRouteMap;
}

/// 画面の外でも出す文言。UI 側が言語に合わせて入れる。
class RidingTexts {
  const RidingTexts({
    this.distanceTitle = 'Arrival alert',
    this.distanceBody = _defaultDistanceBody,
    this.wrongDirectionTitle = 'Wrong direction?',
    this.wrongDirectionBody = 'You may be heading away from your destination.',
    this.trackingTitle = 'osmBus',
    this.trackingBody = 'Tracking your ride for arrival alerts.',
  });

  static String _defaultDistanceBody(int meters) => '$meters m to your stop.';

  final String distanceTitle;
  final String Function(int meters) distanceBody;
  final String wrongDirectionTitle;
  final String wrongDirectionBody;
  final String trackingTitle;
  final String trackingBody;
}

/// トップと設定の状態をまとめる。
class TripController extends ChangeNotifier {
  TripController({
    required this.prefs,
    RouteCatalogStore? store,
    CatalogSync? sync,
    AppSettings? settings,
    this.sound,
    this.notifier,
    PlacesStore? places,
    PurchaseService? purchases,
    this.requestsLocationOnLaunch = true,
  })  : store = store ?? RouteCatalogStore(),
        settings = settings ?? AppSettings(prefs),
        places = places ?? PlacesStore(prefs: prefs, plan: PlanStore(prefs)) {
    this.purchases = purchases ?? PurchaseService(plan: this.places.plan);
    this.sync = sync ?? CatalogSync.forPlatform(this.store);
    downloader = RouteCatalogDownloader(store: this.store, consentGranted: () => consentGranted)
      ..addListener(notifyListeners);
  }

  static const _consentKey = 'privacy.thirdPartyConsent.version';
  static const _consentVersion = 1;
  static const _destinationKey = 'destination';
  static const _iCloudKey = 'sync.iCloudEnabled';
  static const _lastSyncKey = 'sync.lastSyncedAt';
  static const _sortModeKey = 'table.sortMode';
  static const _metricKey = 'table.distanceMetric';
  static const inputDebounce = Duration(milliseconds: 200);
  static const syncDebounce = Duration(seconds: 2);

  final SharedPreferences prefs;

  /// 画面表示時に位置の許可を求めるか。UI テストでは false にして GPS の代わりを入れる。
  final bool requestsLocationOnLaunch;
  final RouteCatalogStore store;
  final AppSettings settings;
  final SoundPlayer? sound;
  final AlertNotifier? notifier;
  final PlacesStore places;
  late final PurchaseService purchases;
  PlanStore get plan => places.plan;

  /// 通知などに使う文言。言語が変わるたびに UI から入れ直す。
  RidingTexts texts = const RidingTexts();
  late final CatalogSync sync;
  late final RouteCatalogDownloader downloader;
  final PlannerCache _planner = PlannerCache();

  CatalogSnapshot _snapshot = CatalogSnapshot.empty;
  GeoPoint? _gps;
  Destination? _manualOrigin;
  LocationStatus _locationStatus = LocationStatus.unknown;
  Destination? _destination;
  String _input = '';
  List<LocalItinerary>? _itineraries;
  bool _planning = false;
  BoardingDecision _decision = const BoardingIdle();
  RidingSession? _riding;
  final DistanceAlertTracker _alertTracker = DistanceAlertTracker();
  final List<RidingAlert> _alerts = [];
  bool _wrongDirectionShown = false;
  bool _foreground = true;
  bool _backgroundTracking = false;
  bool _clearOnNextDigit = false;
  bool _locating = false;
  bool _syncing = false;
  String? _syncError;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CatalogSaveSource>? _saveSub;
  Timer? _inputTimer;
  Timer? _syncTimer;
  int _planGeneration = 0;

  // MARK: - 公開状態

  bool get consentGranted => prefs.getInt(_consentKey) == _consentVersion;
  bool get consentDecided => (prefs.getInt(_consentKey) ?? 0).abs() == _consentVersion;

  /// 同意がオフなら空。ファイルは消さない。
  CatalogSnapshot get visibleCatalog => consentGranted ? _snapshot : CatalogSnapshot.empty;

  /// 出発地。地図で選んだ地点があればそれ、なければ GPS（Swift の `effectiveOrigin`）。
  GeoPoint? get origin => _manualOrigin?.point ?? _gps;

  /// 地図で選んだ出発地。null なら現在地を使っている。保存はしない（Swift と同じ）。
  Destination? get manualOrigin => _manualOrigin;
  LocationStatus get locationStatus => _locationStatus;
  Destination? get destination => _destination;
  String get input => _input;
  BoardingDecision get decision => _decision;
  RidingSession? get riding => _riding;
  String? get ridingRef => _riding?.ref;
  LocalItinerary? get ridingItinerary => _riding?.itinerary;
  String? get ridingAlightStop => _riding?.alightStop.name;

  /// 画面に出す順番待ちのアラート。先頭を出し、閉じたら [dismissAlert]。
  RidingAlert? get pendingAlert => _alerts.firstOrNull;

  /// 現在地の取得を始めてから最初の位置が届くまで true。
  bool get locating => _locating;

  /// 「あと」バッジの距離。乗車中は降車停留所まで、そうでなければ目的地まで（直線）。
  /// 乗車中は手動の出発地ではなく GPS で測る（バスが動いても距離が固まらないように）。
  /// 路線図から目的地なしで乗ったときは出さない（終点は行き先ではないため。Swift と同じ）。
  double? get distanceLeftMeters {
    final riding = _riding;
    if (riding != null && riding.fromRouteMap && _destination == null) return null;
    final origin = riding != null ? (_gps ?? this.origin) : this.origin;
    if (origin == null) return null;
    final target = riding?.alightStop.point ?? _destination?.point;
    return target == null ? null : Geo.distance(origin, target);
  }
  List<LocalItinerary> get itineraries => _itineraries ?? const [];

  TableSortMode get sortMode =>
      TableSortMode.values.asNameMap()[prefs.getString(_sortModeKey)] ?? TableSortMode.direction;
  DistanceMetric get distanceMetric =>
      DistanceMetric.values.asNameMap()[prefs.getString(_metricKey)] ?? DistanceMetric.walkFirst;

  bool get iCloudEnabled => sync.isSupported && (prefs.getBool(_iCloudKey) ?? false);
  bool get syncing => _syncing;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => DateTime.tryParse(prefs.getString(_lastSyncKey) ?? '');

  TableState get tableState {
    if (!consentGranted) return TableState.consentRequired;
    if (_destination == null) return TableState.noDestination;
    if (origin == null) return TableState.noLocation;
    if (visibleCatalog.geometryCount == 0) return TableState.noRouteData;
    if (_itineraries == null) return TableState.calculating;
    if (_itineraries!.isEmpty) return TableState.noRoutes;
    return TableState.ready;
  }

  List<MatrixRow> get matrixRows => BusMatrix.byDirection(itineraries);

  List<MatrixEntry> get flatEntries =>
      BusMatrix.flat(itineraries, mode: sortMode, metric: distanceMetric);

  // MARK: - 起動

  Future<void> start() async {
    await _adoptSwiftConsent();
    _destination = _readDestination();
    _snapshot = await store.load();
    _saveSub = store.onSaved.listen(_onCatalogSaved);
    await sync.checkAvailability();
    notifyListeners();
    unawaited(_replan());
    if (iCloudEnabled) unawaited(syncNow());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _saveSub?.cancel();
    _inputTimer?.cancel();
    _syncTimer?.cancel();
    downloader.dispose();
    super.dispose();
  }

  /// Swift 版（同じバンドル ID）の同意を引き継ぐ。Swift は接頭辞なしの UserDefaults に書く。
  Future<void> _adoptSwiftConsent() async {
    if (prefs.containsKey(_consentKey)) return;
    try {
      final swift = await SharedPreferencesAsync().getInt(_consentKey);
      if (swift != null && swift.abs() == _consentVersion) await prefs.setInt(_consentKey, swift);
    } catch (_) {}
  }

  /// Swift 版と同じ場所にも書き、どちらの版から見ても同じ同意状態にする。
  Future<void> _writeSwiftConsent(int? value) async {
    try {
      final async = SharedPreferencesAsync();
      if (value == null) {
        await async.remove(_consentKey);
      } else {
        await async.setInt(_consentKey, value);
      }
    } catch (_) {}
  }

  /// アプリが前面に戻った。
  void onResumed() {
    _foreground = true;
    AppLog.i('app', 'resumed');
    if (iCloudEnabled) unawaited(syncNow());
  }

  /// アプリが裏に回った。乗車中のアラートは通知で出す。
  void onPaused() {
    _foreground = false;
    AppLog.i('app', 'paused riding=${_riding?.ref ?? '-'} backgroundTracking=$_backgroundTracking');
    unawaited(AppLog.instance.flush());
  }

  // MARK: - 現在地

  Future<void> requestLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationStatus(LocationStatus.serviceDisabled);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationStatus(LocationStatus.deniedForever);
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _setLocationStatus(LocationStatus.denied);
        return;
      }
      _locating = _gps == null;
      _setLocationStatus(LocationStatus.ok);
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _updateOrigin(last);
      await _listenPositions();
    } catch (e, st) {
      AppLog.e('location', 'request failed', e, st);
      _locating = false;
      _setLocationStatus(LocationStatus.denied);
    }
  }

  void _setLocationStatus(LocationStatus status) {
    if (status != _locationStatus) AppLog.i('location', 'status ${status.name}');
    _locationStatus = status;
    notifyListeners();
  }

  /// 乗車中はバックグラウンドでも測位を続ける（Swift の `startContinuousTracking(allowsBackground:)`）。
  /// iOS は画面上部の青い表示、Android は常駐通知が出る。
  Future<void> _listenPositions() async {
    await _positionSub?.cancel();
    final background = _backgroundTracking;
    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: background ? 10 : 20,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: !background,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: background ? 10 : 20,
        foregroundNotificationConfig: background
            ? ForegroundNotificationConfig(
                notificationTitle: texts.trackingTitle,
                notificationText: texts.trackingBody,
                enableWakeLock: true,
              )
            : null,
      );
    } else {
      locationSettings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20);
    }
    AppLog.i('location', 'stream background=$background');
    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(_updateOrigin, onError: (Object e) => AppLog.w('location', 'stream error $e'));
  }

  Future<void> _setBackgroundTracking(bool enabled) async {
    if (_backgroundTracking == enabled) return;
    AppLog.i('location', 'background tracking $enabled');
    _backgroundTracking = enabled;
    if (_positionSub != null) await _listenPositions();
  }

  void _updateOrigin(Position position) {
    _gps = GeoPoint(position.latitude, position.longitude);
    AppLog.d('location', 'fix ${AppLog.coord(_gps)} acc=${position.accuracy.round()}m');
    _locating = false;
    _checkRiding(_gps!);
    notifyListeners();
    unawaited(_replan());
  }

  /// UI テストで GPS の代わりに出発地を入れる。
  @visibleForTesting
  void debugSetOrigin(GeoPoint origin, {DateTime? now}) {
    _gps = origin;
    _checkRiding(origin, now: now);
    notifyListeners();
    unawaited(_replan());
  }

  // MARK: - 出発地

  void setManualOrigin(Destination place) {
    _manualOrigin = place;
    notifyListeners();
    unawaited(_replan());
  }

  /// 現在地（GPS）に戻す。
  void clearManualOrigin() {
    if (_manualOrigin == null) return;
    _manualOrigin = null;
    notifyListeners();
    unawaited(_replan());
  }

  // MARK: - 目的地

  Destination? _readDestination() {
    final raw = prefs.getString(_destinationKey);
    if (raw == null) return null;
    try {
      return Destination.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setDestination(Destination destination) async {
    _destination = destination;
    await prefs.setString(_destinationKey, jsonEncode(destination.toJson()));
    AppLog.i('trip', 'destination ${AppLog.coord(destination.point)}');
    await places.addHistory(destination);
    _wrongDirectionShown = false;
    notifyListeners();
    await _replan();
  }

  /// ナビ中止。乗車を終え、目的地と入力を消す（Swift の `cancelNavigation`）。
  Future<void> cancelNavigation() async {
    AppLog.i('trip', 'cancel navigation');
    endRiding();
    _destination = null;
    _input = '';
    _decision = const BoardingIdle();
    await prefs.remove(_destinationKey);
    notifyListeners();
    await _replan();
  }

  // MARK: - テンキー

  void appendDigit(String digit) {
    if (_clearOnNextDigit) {
      _clearOnNextDigit = false;
      _input = '';
    }
    if (!BusNumberInput.canAppend(digit, _input)) return;
    _input += digit;
    _onInputChanged();
  }

  void deleteDigit() {
    if (_input.isEmpty) return;
    _input = _input.substring(0, _input.length - 1);
    _onInputChanged();
  }

  void clearInput() {
    _clearOnNextDigit = false;
    if (_input.isEmpty) return;
    _input = '';
    _onInputChanged();
  }

  /// 決定。待たずに判定する。
  void submitInput() {
    _inputTimer?.cancel();
    _clearOnNextDigit = settings.keypadInputMode == KeypadInputMode.clearBeforeNewInput && _input.isNotEmpty;
    _judge();
  }

  void _onInputChanged() {
    notifyListeners();
    _inputTimer?.cancel();
    _inputTimer = Timer(inputDebounce, _judge);
  }

  void _judge() {
    _decision = _computeDecision();
    notifyListeners();
  }

  BoardingDecision _computeDecision() {
    if (_input.isEmpty) return const BoardingIdle();
    if (!consentGranted) return const BoardingConsentRequired();
    if (origin == null) return const BoardingNoLocation();
    if (_destination == null) return const BoardingNoDestination();
    if (visibleCatalog.geometryCount == 0) return const BoardingNoRouteData();
    final itineraries = _itineraries;
    if (itineraries == null) return const BoardingCalculating();
    return BoardingJudge.decide(_input, itineraries);
  }

  // MARK: - 計画

  /// 再読み込み。キャッシュを捨てて再計算する。通信しない。
  Future<void> reload() async {
    _planner.invalidate();
    await _replan();
  }

  Future<void> _replan() async {
    final origin = this.origin;
    final destination = _destination?.point;
    final routes = visibleCatalog.routes;
    final generation = ++_planGeneration;
    if (origin == null || destination == null || !consentGranted) {
      _itineraries = null;
      _judge();
      return;
    }
    final version = store.version;
    final cached = _planner.cached(origin: origin, destination: destination, catalogVersion: version);
    if (cached != null) {
      if (!identical(cached, _itineraries)) {
        _itineraries = cached;
        _judge();
      }
      return;
    }
    if (visibleCatalog.geometryCount == 0) {
      _itineraries = null;
      _judge();
      return;
    }
    _planning = true;
    _itineraries = null;
    _judge();
    try {
      final result = await _planner.compute(
        routes: routes,
        origin: origin,
        destination: destination,
        catalogVersion: version,
      );
      if (generation != _planGeneration) return;
      _itineraries = result;
    } catch (_) {
      if (generation != _planGeneration) return;
      _itineraries = const [];
    } finally {
      if (generation == _planGeneration) _planning = false;
    }
    _judge();
  }

  bool get planning => _planning;

  // MARK: - 乗車

  bool isRiding(String ref) => _riding?.ref == ref;

  /// 番号表から乗っている旅程のうち、今乗っているレグ。乗っていなければ null。
  int? ridingLegIndexIn(LocalItinerary itinerary) {
    final riding = _riding?.itinerary;
    return riding != null && riding.sameLegs(itinerary) ? _riding!.legIndex : null;
  }

  /// 番号表のバッジを乗車中（橙）にするか。乗っている旅程の行ならそのレグ、
  /// ほかの行は第 1 レグの番号が乗っている番号と同じとき。
  bool isRidingLeg(LocalItinerary itinerary, int legIndex) {
    final riding = _riding;
    if (riding == null) return false;
    final inRiding = ridingLegIndexIn(itinerary);
    if (inRiding != null) return inRiding == legIndex;
    return legIndex == 0 && riding.ref.toUpperCase() == itinerary.firstLeg.ref.toUpperCase();
  }

  /// 長押し。[legIndex] 番目のバスの乗車開始／終了。
  /// 乗っている旅程の先のレグと同じ番号なら、乗り換えたとみなして同じ旅程のまま次のレグへ進む
  /// （番号表は動くたびに作り直されるので、押した行の旅程ではなく乗っている旅程を使う）。
  void toggleRiding(MatrixEntry entry, {int legIndex = 0}) => toggleRidingLeg(entry.itinerary, legIndex);

  /// 番号表・ルート図の長押し。[itinerary] の [legIndex] 番目のバスについて [toggleRiding] と同じ。
  void toggleRidingLeg(LocalItinerary itinerary, int legIndex) {
    final ref = itinerary.legs[legIndex].ref;
    final riding = _riding;
    if (riding?.ref == ref) {
      endRiding();
      return;
    }
    final current = riding?.itinerary;
    if (riding != null && current != null) {
      final next = current.legs.indexWhere((leg) => leg.ref == ref, riding.legIndex + 1);
      if (next >= 0) {
        _startRiding(RidingSession.fromItinerary(
          current,
          legIndex: next,
          destination: _destination?.point,
          now: DateTime.now(),
        ));
        return;
      }
    }
    _startRiding(RidingSession.fromItinerary(
      itinerary,
      legIndex: legIndex,
      destination: _destination?.point,
      now: DateTime.now(),
    ));
  }

  /// 判定の「乗車開始」。その系統の旅程のうち直通を優先し、徒歩が短いもの。
  void startRiding(String ref) {
    final candidates = itineraries.where((i) => i.firstLeg.ref == ref).toList()
      ..sort((a, b) {
        final transfers = a.transferCount.compareTo(b.transferCount);
        return transfers != 0 ? transfers : LocalItinerary.compareByWalk(a, b);
      });
    if (candidates.isEmpty) return;
    _startRiding(RidingSession.fromItinerary(
      candidates.first,
      destination: _destination?.point,
      now: DateTime.now(),
    ));
  }

  /// 路線図から乗る。降車は終点（Swift の `startFromOSMMap`）。
  void startRidingRoute(RouteRecord route, {DateTime? now}) {
    if (route.stops.isEmpty) return;
    _startRiding(RidingSession.fromRoute(route, destination: _destination?.point, now: now ?? DateTime.now()));
  }

  void _startRiding(RidingSession session) {
    AppLog.i(
      'riding',
      'start ${session.ref} leg=${session.legIndex} fromRouteMap=${session.fromRouteMap} alight=${AppLog.coord(session.alightStop.point)} '
          'rings=${settings.activeThresholds} alarm=${settings.isAlertEnabled(StopAlertMode.alarm)} '
          'vibration=${settings.isAlertEnabled(StopAlertMode.vibration)} alert=${settings.isAlertEnabled(StopAlertMode.alert)}',
    );
    _riding = session;
    _alertTracker.reset();
    _wrongDirectionShown = false;
    notifyListeners();
    unawaited(notifier?.requestPermission());
    unawaited(_setBackgroundTracking(true));
    final gps = _gps;
    if (gps != null) _checkRiding(gps);
  }

  void endRiding() {
    if (_riding == null) return;
    AppLog.i('riding', 'end ${_riding!.ref}');
    _riding = null;
    _alertTracker.reset();
    _alerts.clear();
    notifyListeners();
    unawaited(_setBackgroundTracking(false));
  }

  void dismissAlert() {
    if (_alerts.isEmpty) return;
    _alerts.removeAt(0);
    notifyListeners();
  }

  /// 位置が届くたびに、距離アラートと逆方向を確かめる（Swift の `checkProgress`）。
  void _checkRiding(GeoPoint position, {DateTime? now}) {
    final riding = _riding;
    if (riding == null) return;
    now ??= DateTime.now();

    if (!_wrongDirectionShown &&
        WrongDirection.detect(session: riding, position: position, destination: _destination?.point, now: now)) {
      _wrongDirectionShown = true;
      AppLog.w('riding', 'wrong direction at ${AppLog.coord(position)}');
      _raise(
        WrongDirectionRidingAlert(fromRouteMap: riding.fromRouteMap),
        texts.wrongDirectionTitle,
        texts.wrongDirectionBody,
      );
    }

    final distance = Geo.distance(position, riding.alightStop.point);
    AppLog.d('riding', 'distance ${distance.round()}m');
    final fire = _alertTracker.update(distance, settings.activeThresholds);
    if (fire == null) return;
    AppLog.i(
      'alert',
      'fire ${fire.meters}m x${fire.repeatCount} at ${distance.round()}m foreground=$_foreground nearest=${fire.isNearest}',
    );
    final alarm = settings.isAlertEnabled(StopAlertMode.alarm);
    final vibration = settings.isAlertEnabled(StopAlertMode.vibration);
    if (alarm) unawaited(sound?.playAlarm(fire.repeatCount));
    if (vibration) sound?.vibrateAlert();
    if (alarm || vibration || settings.isAlertEnabled(StopAlertMode.alert)) {
      _raise(DistanceRidingAlert(fire.meters), texts.distanceTitle, texts.distanceBody(fire.meters));
    }
    // 一番近いリングまで来たら、降車の押し忘れで測位が続かないよう裏での追跡をやめる。
    if (fire.isNearest) unawaited(_setBackgroundTracking(false));
  }

  void _raise(RidingAlert alert, String title, String body) {
    if (_foreground) {
      _alerts.add(alert);
      notifyListeners();
    } else {
      unawaited(notifier?.show(title, body));
    }
  }

  // MARK: - 表の並び

  Future<void> setSortMode(TableSortMode mode) async {
    await prefs.setString(_sortModeKey, mode.name);
    notifyListeners();
  }

  Future<void> setDistanceMetric(DistanceMetric metric) async {
    await prefs.setString(_metricKey, metric.name);
    notifyListeners();
  }

  // MARK: - 同意

  Future<void> setConsent(bool granted) async {
    AppLog.i('privacy', 'consent $granted');
    final value = granted ? _consentVersion : -_consentVersion;
    await prefs.setInt(_consentKey, value);
    await _writeSwiftConsent(value);
    if (!granted) downloader.cancel();
    _planner.invalidate();
    notifyListeners();
    await _replan();
  }

  /// 同意撤回。このときだけ正本を削除する。
  Future<void> withdrawConsent() async {
    AppLog.i('privacy', 'withdraw consent');
    downloader.cancel();
    await prefs.remove(_consentKey);
    await _writeSwiftConsent(null);
    await store.delete();
    _snapshot = CatalogSnapshot.empty;
    _planner.invalidate();
    endRiding();
    await _replan();
  }

  /// すべてのデータを削除（Swift の `PrivacyDataView`）。目的地・履歴・登録地・同意と路線データを消す。
  /// 購入状態・一般設定・路線の保管庫は残す。
  Future<void> deleteAllData() async {
    await cancelNavigation();
    clearManualOrigin();
    await places.clearAll();
    await withdrawConsent();
  }

  // MARK: - 取得

  Future<void> downloadAll() async {
    final origin = this.origin;
    if (origin == null || !consentGranted) return;
    await downloader.downloadAll(origin);
  }

  Future<void> updateCatalog() async {
    final origin = this.origin;
    if (origin == null || !consentGranted) return;
    await downloader.update(origin);
  }

  Future<void> _onCatalogSaved(CatalogSaveSource source) async {
    _snapshot = await store.load();
    notifyListeners();
    unawaited(_replan());
    if (source == CatalogSaveSource.local && iCloudEnabled) {
      _syncTimer?.cancel();
      _syncTimer = Timer(syncDebounce, () => unawaited(syncNow()));
    }
  }

  // MARK: - バックアップ

  static String backupFileName(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'osmBus-routes-${date.year}${two(date.month)}${two(date.day)}.json';
  }

  Future<void> exportBackup() async {
    final snapshot = await store.load();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${backupFileName(DateTime.now())}');
    await file.writeAsString(RouteCatalogStore.encode(snapshot), flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')]));
  }

  Future<ImportResult> importBackup(ImportMode mode) async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    } catch (e) {
      return ImportResult.failed('$e');
    }
    if (picked.isEmpty) return const ImportResult.cancelled();
    try {
      return await importBackupText(await picked.first.xFile.readAsString(), mode);
    } catch (e) {
      return ImportResult.failed('$e');
    }
  }

  /// 検証に失敗したら正本を変えない。
  Future<ImportResult> importBackupText(String text, ImportMode mode) async {
    final CatalogSnapshot imported;
    try {
      imported = CatalogSnapshot.fromJson(jsonDecode(text), strict: true);
    } on FormatException catch (e) {
      return ImportResult.failed(e.message);
    }
    final now = DateTime.now().toUtc();
    final result = await store.update((local) => switch (mode) {
          ImportMode.replace => imported.copyWith(syncedAt: now),
          ImportMode.merge => CatalogOps.merge(local, imported, now: now),
        });
    return ImportResult.ok(result.routes.length);
  }

  // MARK: - 保管庫

  /// 保管庫にある形状付き路線の数。
  Future<int> archivedRouteCount() async => (await store.loadArchive()).routes.length;

  /// 保管庫の路線を正本へマージで戻す。
  Future<ImportResult> restoreFromArchive() async {
    final archive = await store.loadArchive();
    if (archive.routes.isEmpty) return const ImportResult.ok(0);
    final now = DateTime.now().toUtc();
    final result = await store.update((local) => CatalogOps.merge(local, archive, now: now));
    return ImportResult.ok(result.routes.length);
  }

  Future<void> exportArchive() async {
    final file = await store.archiveFile();
    if (!await file.exists()) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')]));
  }

  // MARK: - iCloud

  Future<void> setICloudEnabled(bool enabled) async {
    if (!sync.isSupported) return;
    await prefs.setBool(_iCloudKey, enabled);
    notifyListeners();
    if (enabled) await syncNow();
  }

  Future<void> syncNow() async {
    if (!iCloudEnabled || _syncing) return;
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await sync.mergeAndPush();
      await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      _syncError = '$e';
      AppLog.w('sync', 'failed $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
