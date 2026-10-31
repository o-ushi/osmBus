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
import '../services/location_authorization.dart';
import '../services/route_catalog_downloader.dart';
import '../services/route_catalog_store.dart';
import '../services/sound_player.dart';
import '../services/official_order_matcher.dart';
import '../services/stop_order_repair.dart';
import '../services/stop_order_source.dart';
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

/// 乗車中に降車停を ＋／− でずらすための停留所列（今乗っている路線のカタログ上の停留所）。
class AlightChoice {
  const AlightChoice({required this.route, required this.boardIndex, required this.alightIndex});

  final RouteRecord route;
  final int boardIndex;
  final int alightIndex;

  List<RouteStop> get stops => route.stops;
  RouteStop get alightStop => stops[alightIndex];

  /// 乗車停留所の次より手前には行かない。
  bool get canPrevious => alightIndex - 1 > boardIndex;

  /// 終点より先には行かない。
  bool get canNext => alightIndex + 1 < stops.length;
}

/// 路線図に出す、公式の停留所順との関係。
enum OfficialOrderState {
  /// 自信を持って対応でき、今の表示順と違う。
  differs,

  /// この路線へ公式の順を適用している。
  applied,
}

class OfficialOrderStatus {
  const OfficialOrderStatus({required this.state, required this.osmOrder, required this.officialOrder});

  final OfficialOrderState state;

  /// 公式の順を被せる前の並び（OSM の並び。線と逆行していれば端末内で直したもの）。
  final List<RouteStop> osmOrder;

  /// 公式の順に並べた OSM の停留所。
  final List<RouteStop> officialOrder;
}

/// 「停留所順を点検」の結果。適用するまで何も変えない。
class StopOrderInspection {
  const StopOrderInspection({required this.fixable, required this.unsure, required this.officialRouteCount});

  /// 自信を持って違いがある路線と、その公式の順。
  final List<(RouteRecord, OfficialOrderMatch)> fixable;

  /// 公式データに同じ系統があるが、自信を持って対応できなかった路線。
  final List<RouteRecord> unsure;

  /// 照合に使った停留所順のファイルにある系統・方向の数。
  final int officialRouteCount;
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
    StopOrderSource? stopOrder,
    this.requestsLocationOnLaunch = true,
  })  : store = store ?? RouteCatalogStore(),
        stopOrder = stopOrder ?? StopOrderSource(),
        settings = settings ?? AppSettings(prefs),
        places = places ?? PlacesStore(prefs: prefs) {
    this.sync = sync ?? CatalogSync.forPlatform(this.store);
    downloader = RouteCatalogDownloader(store: this.store, consentGranted: () => consentGranted)
      ..addListener(notifyListeners);
  }

  static const _consentKey = 'privacy.thirdPartyConsent.version';
  static const _consentVersion = 1;
  static const _destinationKey = 'destination';
  static const _ridingKey = 'riding.session';
  static const _officialOrderKey = 'stopOrder.applied';
  static const _routeOriginKey = 'navigation.routeOrigin';
  static const _iCloudKey = 'sync.iCloudEnabled';
  static const _lastSyncKey = 'sync.lastSyncedAt';
  static const _sortModeKey = 'table.sortMode';
  static const _metricKey = 'table.distanceMetric';
  static const inputDebounce = Duration(milliseconds: 200);
  static const syncDebounce = Duration(seconds: 2);

  /// 乗車中に位置ストリームが切れたら、これだけ待って張り直す。
  static const streamRestartDelay = Duration(seconds: 3);

  final SharedPreferences prefs;

  /// 画面表示時に位置の許可を求めるか。UI テストでは false にして GPS の代わりを入れる。
  final bool requestsLocationOnLaunch;
  final RouteCatalogStore store;
  final AppSettings settings;
  final SoundPlayer? sound;
  final AlertNotifier? notifier;
  final PlacesStore places;

  /// 公式の停留所順のファイル（同梱か、更新で取得したもの）。
  final StopOrderSource stopOrder;

  /// 通知などに使う文言。言語が変わるたびに UI から入れ直す。
  RidingTexts texts = const RidingTexts();
  late final CatalogSync sync;
  late final RouteCatalogDownloader downloader;
  final PlannerCache _planner = PlannerCache();

  /// 読み込んだカタログ（線と逆行する停留所順だけ端末内で直したもの）。
  CatalogSnapshot _base = CatalogSnapshot.empty;

  /// [_base] に、ユーザーが適用した公式の停留所順を被せたもの。プランナーと地図はこれを見る。
  CatalogSnapshot _snapshot = CatalogSnapshot.empty;
  final Map<int, (RouteRecord, String, OfficialOrderMatch?)> _matchCache = {};
  StopOrderUpdateResult? _stopOrderResult;
  bool _stopOrderUpdating = false;
  GeoPoint? _gps;

  /// ナビ中（目的地があるあいだ）に経路を引く出発地。GPS 更新では動かさない。
  GeoPoint? _routeOrigin;

  /// ↻ で「次に届いた 1 点を経路用の出発地にする」。
  bool _adoptNextFix = false;
  Destination? _manualOrigin;
  LocationStatus _locationStatus = LocationStatus.unknown;
  Destination? _destination;
  String _input = '';
  List<LocalItinerary>? _itineraries;
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
  Timer? _streamRestartTimer;
  StreamSubscription<CatalogSaveSource>? _saveSub;
  StreamSubscription<void>? _placesSub;
  Timer? _inputTimer;
  Timer? _syncTimer;
  int _planGeneration = 0;

  // MARK: - 公開状態

  bool get consentGranted => prefs.getInt(_consentKey) == _consentVersion;
  bool get consentDecided => (prefs.getInt(_consentKey) ?? 0).abs() == _consentVersion;

  /// 同意がオフなら空。ファイルは消さない。
  CatalogSnapshot get visibleCatalog => consentGranted ? _snapshot : CatalogSnapshot.empty;

  /// 経路を引く出発地。地図で選んだ地点があればそれ。なければ、ナビ中はナビを始めたときに
  /// 固定した地点（↻ を押すまで動かない）、ナビ中でなければ GPS（Swift の `effectiveOrigin`）。
  GeoPoint? get origin => _manualOrigin?.point ?? (_destination != null ? _routeOrigin : _gps);

  /// 地図に出す出発地のピン。手動の出発地か、GPS の丸と離れた固定の出発地。
  GeoPoint? get originPin {
    final origin = this.origin;
    if (origin == null) return null;
    return _manualOrigin != null || origin != _gps ? origin : null;
  }

  /// GPS の現在地。手動の出発地ではない。地図の現在地の丸と「現在地に移動」に使う。
  GeoPoint? get gps => _gps;

  /// 地図で選んだ出発地。null なら現在地を使っている。保存はしない（Swift と同じ）。
  Destination? get manualOrigin => _manualOrigin;
  LocationStatus get locationStatus => _locationStatus;
  Destination? get destination => _destination;
  String get input => _input;
  BoardingDecision get decision => _decision;
  RidingSession? get riding => _riding;
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
    if (riding != null && riding.fromRouteMap && _destination == null && !riding.alightAdjusted) return null;
    // 未乗車でも、手動の出発地が無ければライブの GPS から測る（固定した経路用の出発地ではない）。
    final origin = riding != null ? (_gps ?? this.origin) : (_manualOrigin?.point ?? _gps ?? this.origin);
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
    _routeOrigin = _destination == null ? null : _readRouteOrigin();
    _restoreRiding();
    await stopOrder.load();
    _setCatalog(await store.load());
    _saveSub = store.onSaved.listen(_onCatalogSaved);
    _placesSub = places.localChanges.listen((_) => _scheduleSync());
    await sync.checkAvailability();
    notifyListeners();
    unawaited(_replan());
    if (iCloudEnabled) unawaited(syncNow());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _streamRestartTimer?.cancel();
    _saveSub?.cancel();
    _placesSub?.cancel();
    _inputTimer?.cancel();
    _syncTimer?.cancel();
    downloader.dispose();
    super.dispose();
  }

  void _setCatalog(CatalogSnapshot loaded) {
    _base = _repaired(loaded);
    _snapshot = _withOfficialOrder(_base);
  }

  // MARK: - 公式の停留所順

  /// 適用した公式の順（relationId → 停留所 ID の順）。カタログのファイルは書き換えない。
  Map<int, List<int>> get _appliedOrders {
    final raw = prefs.getString(_officialOrderKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final MapEntry(:key, :value) in json.entries)
          int.parse(key): [for (final id in value as List) (id as num).toInt()],
      };
    } catch (_) {
      return {};
    }
  }

  void _saveAppliedOrders(Map<int, List<int>> orders) {
    if (orders.isEmpty) {
      unawaited(prefs.remove(_officialOrderKey));
      return;
    }
    unawaited(prefs.setString(_officialOrderKey, jsonEncode({for (final e in orders.entries) '${e.key}': e.value})));
  }

  /// 適用した路線だけ、覚えた ID の順の停留所にする。ID が路線から無くなっていたら記憶を捨てる。
  CatalogSnapshot _withOfficialOrder(CatalogSnapshot base) {
    final orders = _appliedOrders;
    if (orders.isEmpty) return base;
    var dropped = false;
    final routes = <RouteRecord>[];
    for (final route in base.routes) {
      final ids = orders[route.relationId];
      final stops = ids == null ? null : OfficialOrderMatcher.reorder(route, ids);
      if (ids != null && stops == null) {
        AppLog.i('stopOrder', 'forget ${route.ref} (${route.relationId}): stops changed');
        orders.remove(route.relationId);
        dropped = true;
      }
      routes.add(stops == null ? route : route.copyWith(stops: stops));
    }
    if (dropped) _saveAppliedOrders(orders);
    return base.copyWith(routes: routes);
  }

  bool isOfficialOrderApplied(int relationId) => _appliedOrders.containsKey(relationId);

  /// 公式の順と対応させた結果（[_base] の路線と停留所順のファイルが同じあいだは使い回す）。
  OfficialOrderMatch? _match(RouteRecord base) {
    final cached = _matchCache[base.relationId];
    if (cached != null && identical(cached.$1, base) && cached.$2 == stopOrder.current.updated) return cached.$3;
    final match = OfficialOrderMatcher.match(base, stopOrder.current.routes);
    _matchCache[base.relationId] = (base, stopOrder.current.updated, match);
    return match;
  }

  static bool _sameOrder(List<RouteStop> stops, List<int> ids) {
    if (stops.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (stops[i].id != ids[i]) return false;
    }
    return true;
  }

  /// 路線図・経路地図のヒント。違いがあるか適用済みのときだけ。一致または自信なしなら null。
  OfficialOrderStatus? officialOrderStatus(int relationId) {
    final base = _base.routes.where((r) => r.relationId == relationId).firstOrNull;
    if (base == null) return null;
    if (isOfficialOrderApplied(relationId)) {
      final shown = _snapshot.routes.where((r) => r.relationId == relationId).firstOrNull;
      if (shown == null) return null;
      return OfficialOrderStatus(state: OfficialOrderState.applied, osmOrder: base.stops, officialOrder: shown.stops);
    }
    final match = _match(base);
    if (match == null || _sameOrder(base.stops, match.orderedIds)) return null;
    final official = OfficialOrderMatcher.reorder(base, match.orderedIds);
    if (official == null) return null;
    return OfficialOrderStatus(state: OfficialOrderState.differs, osmOrder: base.stops, officialOrder: official);
  }

  /// この路線を公式の順にする。
  void applyOfficialOrder(int relationId) {
    final base = _base.routes.where((r) => r.relationId == relationId).firstOrNull;
    final match = base == null ? null : _match(base);
    if (match == null) return;
    _applyOrders({relationId: match.orderedIds});
  }

  /// 元に戻す。その路線の記憶を消し、OSM の並びに戻す。
  void revertOfficialOrder(int relationId) {
    final orders = _appliedOrders;
    if (orders.remove(relationId) == null) return;
    AppLog.i('stopOrder', 'revert $relationId');
    _saveAppliedOrders(orders);
    _onOrderChanged();
  }

  void _applyOrders(Map<int, List<int>> add) {
    if (add.isEmpty) return;
    AppLog.i('stopOrder', 'apply ${add.keys.toList()}');
    _saveAppliedOrders({..._appliedOrders, ...add});
    _onOrderChanged();
  }

  void _onOrderChanged() {
    _snapshot = _withOfficialOrder(_base);
    _planner.invalidate();
    notifyListeners();
    unawaited(_replan());
  }

  /// 全路線を照合する。まだ適用しない。
  StopOrderInspection inspectStopOrder() {
    final official = stopOrder.current.routes;
    final refs = {for (final o in official) OfficialOrderMatcher.normalizeRef(o.ref)};
    final fixable = <(RouteRecord, OfficialOrderMatch)>[];
    final unsure = <RouteRecord>[];
    for (final route in _base.routes) {
      if (isOfficialOrderApplied(route.relationId)) continue;
      if (!refs.contains(OfficialOrderMatcher.normalizeRef(route.ref))) continue;
      final match = _match(route);
      if (match == null) {
        unsure.add(route);
      } else if (!_sameOrder(route.stops, match.orderedIds)) {
        fixable.add((route, match));
      }
    }
    return StopOrderInspection(fixable: fixable, unsure: unsure, officialRouteCount: official.length);
  }

  /// 点検で直せた路線だけ公式の順にする。自信がなかった路線は変えない。
  void applyInspection(StopOrderInspection inspection) =>
      _applyOrders({for (final (route, match) in inspection.fixable) route.relationId: match.orderedIds});

  /// 「停留所順を更新」の最後の結果。
  StopOrderUpdateResult? get stopOrderUpdateResult => _stopOrderResult;
  bool get stopOrderUpdating => _stopOrderUpdating;

  /// 押したときだけ取りにいく。新しい日付のときだけ差し替える。
  Future<void> updateStopOrder() async {
    if (_stopOrderUpdating) return;
    _stopOrderUpdating = true;
    notifyListeners();
    try {
      _stopOrderResult = await stopOrder.update();
    } finally {
      _stopOrderUpdating = false;
      _matchCache.clear();
      notifyListeners();
    }
  }

  /// 読み込んだ路線の停留所順を、線と明らかに逆行しているものだけ端末内で直す。
  /// 番号表・路線図・降車停の ＋／− はどれもこの順を使う。ファイルには書き戻さない。
  CatalogSnapshot _repaired(CatalogSnapshot loaded) {
    final (snapshot, count) = StopOrderRepair.snapshot(loaded);
    if (count > 0) AppLog.i('catalog', 'reordered stops of $count routes');
    return snapshot;
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

  /// アプリが前面に戻った。乗車中で測位が止まっていれば張り直す。
  void onResumed() {
    _foreground = true;
    AppLog.i('app', 'resumed riding=${_riding?.ref ?? '-'} stream=${_positionSub != null}');
    if (_riding != null && _positionSub == null && _locationStatus == LocationStatus.ok) {
      unawaited(_listenPositions());
    }
    if (iCloudEnabled) unawaited(syncNow());
  }

  /// アプリが裏に回った。乗車は続け、乗車中のアラートは通知で出す。
  void onPaused() {
    _foreground = false;
    AppLog.i('app', 'paused riding=${_riding?.ref ?? '-'} backgroundTracking=$_backgroundTracking');
    unawaited(AppLog.instance.flush());
  }

  // MARK: - 現在地

  /// 位置の許可を確かめて測位を始める。[refreshOrigin] は現在地行の ↻（次に届いた 1 点を
  /// ナビ中の経路用の出発地にして、経路を引き直す）。
  Future<void> requestLocation({bool refreshOrigin = false}) async {
    if (refreshOrigin) adoptNextFixAsOrigin();
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
    _streamRestartTimer?.cancel();
    await _positionSub?.cancel();
    _positionSub = null;
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
    late final StreamSubscription<Position> sub;
    sub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      _updateOrigin,
      onError: (Object e) {
        AppLog.w('location', 'stream error $e');
        if (_riding != null) _restartStream(sub);
      },
      onDone: () {
        AppLog.w('location', 'stream done');
        _restartStream(sub);
      },
    );
    _positionSub = sub;
  }

  /// 位置ストリームが切れた。乗車中なら少し待って張り直す（降車にはしない）。
  void _restartStream(StreamSubscription<Position> sub) {
    if (!identical(sub, _positionSub)) return;
    unawaited(sub.cancel());
    _positionSub = null;
    if (_riding == null) return;
    _streamRestartTimer?.cancel();
    _streamRestartTimer = Timer(streamRestartDelay, () {
      if (_riding != null && _positionSub == null) unawaited(_listenPositions());
    });
  }

  Future<void> _setBackgroundTracking(bool enabled) async {
    if (_backgroundTracking == enabled) return;
    AppLog.i('location', 'background tracking $enabled');
    _backgroundTracking = enabled;
    // 切れたストリームも、乗車を始めるときは張り直す。
    if (_positionSub != null || (enabled && _locationStatus == LocationStatus.ok)) await _listenPositions();
  }

  void _updateOrigin(Position position) {
    final point = GeoPoint(position.latitude, position.longitude);
    AppLog.d('location', 'fix ${AppLog.coord(point)} acc=${position.accuracy.round()}m');
    _locating = false;
    _onFix(point);
  }

  /// テストで同意に関係なく今の並び（公式の順を被せたもの）を見る。
  @visibleForTesting
  CatalogSnapshot get debugCatalog => _snapshot;

  /// テストで路線データを直接入れる（読み込みと同じく停留所順を直す）。
  @visibleForTesting
  void debugSetCatalog(CatalogSnapshot snapshot) {
    _setCatalog(snapshot);
    notifyListeners();
  }

  /// UI テストで GPS の代わりに位置を入れる。
  @visibleForTesting
  void debugSetOrigin(GeoPoint origin, {DateTime? now}) => _onFix(origin, now: now);

  /// GPS の 1 点。現在地の丸・乗車中の距離・アラートはいつも動かす。
  /// 経路は、ナビ中でなければ毎回、ナビ中は経路用の出発地が変わったときだけ引き直す。
  void _onFix(GeoPoint point, {DateTime? now}) {
    _gps = point;
    final replan = _pinRouteOrigin(point);
    _checkRiding(point, now: now);
    notifyListeners();
    if (replan) unawaited(_replan());
  }

  /// ナビ中に経路用の出発地をこの点にするか。まだ無いときと ↻ のあとの 1 点だけ採用する。
  bool _pinRouteOrigin(GeoPoint point) {
    if (_destination == null) {
      _adoptNextFix = false;
      return true;
    }
    if (_routeOrigin != null && !_adoptNextFix) return false;
    _adoptNextFix = false;
    _setRouteOrigin(point);
    return true;
  }

  /// ↻。次に届いた GPS の 1 点を経路用の出発地にする（その後の点では動かさない）。
  void adoptNextFixAsOrigin() {
    if (_destination == null) return;
    AppLog.i('trip', 'adopt next fix as origin');
    _adoptNextFix = true;
  }

  void _setRouteOrigin(GeoPoint? point) {
    _routeOrigin = point;
    AppLog.i('trip', 'route origin ${AppLog.coord(point)}');
    if (point == null) {
      unawaited(prefs.remove(_routeOriginKey));
    } else {
      unawaited(prefs.setString(_routeOriginKey, jsonEncode(point.toJson())));
    }
  }

  GeoPoint? _readRouteOrigin() {
    final raw = prefs.getString(_routeOriginKey);
    if (raw == null) return null;
    try {
      return GeoPoint.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // MARK: - 出発地

  void setManualOrigin(Destination place) {
    _manualOrigin = place;
    notifyListeners();
    unawaited(_replan());
  }

  /// 手動の出発地を消す。ナビ中は固定してある経路用の出発地に、そうでなければ GPS に戻す。
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
    // ナビを始めた瞬間の GPS を経路用の出発地に固定する。まだ無ければ最初に届いた 1 点。
    _adoptNextFix = false;
    _setRouteOrigin(_gps);
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
    _adoptNextFix = false;
    _setRouteOrigin(null);
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
    }
    _judge();
  }

  // MARK: - 乗車

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
    _startRiding(RidingSession.fromRoute(
      route,
      destination: _destination?.point,
      now: now ?? DateTime.now(),
      position: _gps,
    ));
  }

  // MARK: - 降車停の変更

  /// 今乗っている路線と、降車停を選べる範囲。番号表・路線図のどちらから乗っても同じ列を使う。
  AlightChoice? get alightChoice {
    final riding = _riding;
    if (riding == null) return null;
    final relationId = riding.itinerary?.legs[riding.legIndex].relationId ?? riding.routeId;
    if (relationId == null) return null;
    final route = visibleCatalog.routes.where((r) => r.relationId == relationId).firstOrNull;
    if (route == null || route.stops.length < 2) return null;
    final stops = route.stops;
    final leg = riding.itinerary?.legs[riding.legIndex];
    var board = riding.boardStopId == null ? -1 : stops.indexWhere((s) => s.id == riding.boardStopId);
    if (board < 0 && leg != null && leg.boardIndex < stops.length) board = leg.boardIndex;
    if (board < 0) board = 0;
    if (board >= stops.length - 1) return null;
    var alight = stops.indexWhere((s) => s.id == riding.alightStop.id, board + 1);
    if (alight < 0) {
      // ID が変わっていれば、位置が一番近い停留所。
      alight = board + 1;
      for (var i = board + 2; i < stops.length; i++) {
        if (Geo.distance(stops[i].point, riding.alightStop.point) <
            Geo.distance(stops[alight].point, riding.alightStop.point)) {
          alight = i;
        }
      }
    }
    return AlightChoice(route: route, boardIndex: board, alightIndex: alight);
  }

  /// 降車停を、今乗っている路線に沿って [delta] 個ずらす（＋1 は先、−1 は手前）。
  /// 乗換の先のレグは変えない。到着アラートは目標が変わったので鳴った記録を消す。
  void shiftRidingAlight(int delta) {
    final riding = _riding;
    final choice = alightChoice;
    if (riding == null || choice == null || delta == 0) return;
    final next = choice.alightIndex + delta;
    if (next <= choice.boardIndex || next >= choice.stops.length) return;
    final stop = choice.stops[next];
    final leg = LocalPlanner.legOf(choice.route, choice.boardIndex, next);
    AppLog.i('riding', 'alight ${riding.alightStop.name} -> ${stop.name} (${choice.alightIndex} -> $next)');
    _riding = riding.withAlight(stop, path: leg.path);
    _alertTracker.reset();
    _alerts.removeWhere((a) => a is DistanceRidingAlert);
    _saveRiding();
    notifyListeners();
    // 一番近いリングで裏の測位を止めていても、新しい目標のために再開する。
    unawaited(_setBackgroundTracking(true));
    final gps = _gps;
    if (gps != null) _checkRiding(gps);
  }

  /// 乗っている旅程なら、今のレグの降車停と線を [RidingSession] に合わせた旅程（経路地図用）。
  LocalItinerary ridingView(LocalItinerary itinerary) {
    final riding = _riding;
    final index = ridingLegIndexIn(itinerary);
    if (riding == null || index == null) return itinerary;
    final leg = itinerary.legs[index];
    if (leg.alightStop.id == riding.alightStop.id) return itinerary;
    final legs = [...itinerary.legs];
    legs[index] = ItineraryLeg(
      relationId: leg.relationId,
      ref: leg.ref,
      routeName: leg.routeName,
      boardIndex: leg.boardIndex,
      alightIndex: alightChoice?.alightIndex ?? leg.alightIndex,
      boardStop: leg.boardStop,
      alightStop: riding.alightStop,
      path: riding.path,
      rideMeters: Geo.polylineLength(riding.path),
    );
    return LocalItinerary(legs: legs, walkMeters: itinerary.walkMeters, bearing: itinerary.bearing);
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
    _saveRiding();
    notifyListeners();
    unawaited(notifier?.requestPermission());
    _startBackgroundTracking();
    final gps = _gps;
    if (gps != null) _checkRiding(gps);
  }

  /// 裏での測位を始める。iOS が「使用中のみ」なら「常に許可」を求める（Swift と同じ時機）。
  void _startBackgroundTracking() {
    unawaited(LocationAuthorization.requestAlwaysIfWhenInUse());
    unawaited(_setBackgroundTracking(true));
  }

  void endRiding() {
    if (_riding == null) return;
    AppLog.i('riding', 'end ${_riding!.ref}');
    _riding = null;
    _alertTracker.reset();
    _alerts.clear();
    _saveRiding();
    notifyListeners();
    unawaited(_setBackgroundTracking(false));
  }

  /// 乗車を保存する。降車・ナビ中止・同意撤回まで消さない。
  void _saveRiding() {
    final riding = _riding;
    if (riding == null) {
      unawaited(prefs.remove(_ridingKey));
      return;
    }
    unawaited(prefs.setString(
      _ridingKey,
      jsonEncode({
        'session': riding.toJson(),
        'alerts': _alertTracker.toJson(),
        'wrongDirectionShown': _wrongDirectionShown,
      }),
    ));
  }

  /// 前回の起動で乗っていた乗車に戻す。一番近いアラートの前なら裏での測位も再開する。
  void _restoreRiding() {
    final raw = prefs.getString(_ridingKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _riding = RidingSession.fromJson(json['session'] as Map<String, dynamic>);
      _alertTracker.restore(json['alerts'] as Map<String, dynamic>? ?? const {});
      _wrongDirectionShown = json['wrongDirectionShown'] as bool? ?? false;
    } catch (e) {
      AppLog.w('riding', 'restore failed $e');
      unawaited(prefs.remove(_ridingKey));
      return;
    }
    AppLog.i('riding', 'restored ${_riding!.ref} leg=${_riding!.legIndex} nearest=${_alertTracker.nearestReached}');
    if (!_alertTracker.nearestReached) _startBackgroundTracking();
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
      _saveRiding();
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
    _saveRiding();
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
    _setCatalog(CatalogSnapshot.empty);
    _planner.invalidate();
    endRiding();
    await _replan();
  }

  /// すべてのデータを削除。目的地・履歴・登録地・同意と路線データを消す。
  /// 一般設定と路線の保管庫は残す。
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
    _setCatalog(await store.load());
    notifyListeners();
    unawaited(_replan());
    if (source == CatalogSaveSource.local) _scheduleSync();
  }

  void _scheduleSync() {
    if (!iCloudEnabled) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(syncDebounce, () => unawaited(syncNow()));
  }

  // MARK: - バックアップ

  static String backupFileName(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'osmBus-backup-${date.year}${two(date.month)}${two(date.day)}.json';
  }

  /// 路線の正本に、登録済みの場所と目的地の履歴を `personal` として足す。
  /// 路線だけを読む側（Swift 版など）は `personal` を無視する。
  Future<String> exportBackupText() async {
    final snapshot = await store.load();
    return jsonEncode({...snapshot.toJson(), 'personal': places.data.toJson()});
  }

  Future<void> exportBackup() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${backupFileName(DateTime.now())}');
    await file.writeAsString(await exportBackupText(), flush: true);
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

  /// 検証に失敗したら正本も場所・履歴も変えない。`personal` の無い古いファイルは路線だけ読む。
  Future<ImportResult> importBackupText(String text, ImportMode mode) async {
    final CatalogSnapshot imported;
    final PersonalData? personal;
    try {
      final decoded = jsonDecode(text);
      imported = CatalogSnapshot.fromJson(decoded, strict: true);
      final rawPersonal = decoded is Map ? decoded['personal'] : null;
      personal = rawPersonal == null ? null : PersonalData.fromJson(rawPersonal);
    } on FormatException catch (e) {
      return ImportResult.failed(e.message);
    }
    final now = DateTime.now().toUtc();
    final result = await store.update((local) => switch (mode) {
          ImportMode.replace => imported.copyWith(syncedAt: now),
          ImportMode.merge => CatalogOps.merge(local, imported, now: now),
        });
    if (personal != null) {
      final local = places.data;
      await places.apply(switch (mode) {
        // 消した印は手元のまま残す（他の端末で消したものを戻さないため）。
        ImportMode.replace => PersonalData(
            places: personal.places,
            history: personal.history,
            deletedPlaces: local.deletedPlaces,
            historyClearedAt: local.historyClearedAt,
          ),
        ImportMode.merge => PersonalData.merge(local, personal, now: now),
      });
      _scheduleSync();
    }
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
      await places.apply(await sync.mergePersonal(places.data));
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
