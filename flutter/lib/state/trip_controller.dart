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
import '../models/bus_identifier.dart';
import '../models/bus_matrix.dart';
import '../models/local_itinerary.dart';
import '../models/route_catalog.dart';
import '../services/catalog_sync.dart';
import '../services/geo.dart';
import '../services/local_planner.dart';
import '../services/route_catalog_downloader.dart';
import '../services/route_catalog_store.dart';

class Destination {
  const Destination({required this.name, required this.point});

  final String name;
  final GeoPoint point;
}

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

/// トップと設定の状態をまとめる。
class TripController extends ChangeNotifier {
  TripController({
    required this.prefs,
    RouteCatalogStore? store,
    CatalogSync? sync,
    this.requestsLocationOnLaunch = true,
  }) : store = store ?? RouteCatalogStore() {
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
  late final CatalogSync sync;
  late final RouteCatalogDownloader downloader;
  final PlannerCache _planner = PlannerCache();

  CatalogSnapshot _snapshot = CatalogSnapshot.empty;
  GeoPoint? _origin;
  LocationStatus _locationStatus = LocationStatus.unknown;
  Destination? _destination;
  String _input = '';
  List<LocalItinerary>? _itineraries;
  bool _planning = false;
  BoardingDecision _decision = const BoardingIdle();
  String? _ridingRef;
  LocalItinerary? _ridingItinerary;
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

  GeoPoint? get origin => _origin;
  LocationStatus get locationStatus => _locationStatus;
  Destination? get destination => _destination;
  String get input => _input;
  BoardingDecision get decision => _decision;
  String? get ridingRef => _ridingRef;
  LocalItinerary? get ridingItinerary => _ridingItinerary;
  String? get ridingAlightStop => _ridingItinerary?.firstLeg.alightStop.name;

  /// 現在地の取得を始めてから最初の位置が届くまで true。
  bool get locating => _locating;

  /// 「あと」バッジの距離。乗車中は降車停留所まで、そうでなければ目的地まで（直線）。
  double? get distanceLeftMeters {
    final origin = _origin;
    if (origin == null) return null;
    final target = _ridingItinerary?.firstLeg.alightStop.point ?? _destination?.point;
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
    if (_origin == null) return TableState.noLocation;
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
    if (iCloudEnabled) unawaited(syncNow());
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
      _locating = _origin == null;
      _setLocationStatus(LocationStatus.ok);
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _updateOrigin(last);
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen(_updateOrigin, onError: (_) {});
    } catch (_) {
      _locating = false;
      _setLocationStatus(LocationStatus.denied);
    }
  }

  void _setLocationStatus(LocationStatus status) {
    _locationStatus = status;
    notifyListeners();
  }

  void _updateOrigin(Position position) {
    _origin = GeoPoint(position.latitude, position.longitude);
    _locating = false;
    notifyListeners();
    unawaited(_replan());
  }

  /// UI テストで GPS の代わりに出発地を入れる。
  @visibleForTesting
  void debugSetOrigin(GeoPoint origin) {
    _origin = origin;
    unawaited(_replan());
  }

  // MARK: - 目的地

  Destination? _readDestination() {
    final raw = prefs.getString(_destinationKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Destination(
        name: json['name'] as String,
        point: GeoPoint((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setDestination(Destination destination) async {
    _destination = destination;
    await prefs.setString(
      _destinationKey,
      jsonEncode({
        'name': destination.name,
        'latitude': destination.point.latitude,
        'longitude': destination.point.longitude,
      }),
    );
    notifyListeners();
    await _replan();
  }

  // MARK: - テンキー

  void appendDigit(String digit) {
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
    if (_input.isEmpty) return;
    _input = '';
    _onInputChanged();
  }

  /// 決定。待たずに判定する。
  void submitInput() {
    _inputTimer?.cancel();
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
    if (_origin == null) return const BoardingNoLocation();
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
    final origin = _origin;
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

  bool isRiding(String ref) => _ridingRef == ref;

  /// 長押し。その番号の乗車開始／終了。
  void toggleRiding(MatrixEntry entry) {
    if (_ridingRef == entry.firstRef) {
      endRiding();
      return;
    }
    _startRiding(entry.firstRef, entry.itinerary);
  }

  /// 判定の「乗車開始」。その系統の旅程のうち直通を優先し、徒歩が短いもの。
  void startRiding(String ref) {
    final candidates = itineraries.where((i) => i.firstLeg.ref == ref).toList()
      ..sort((a, b) {
        final transfers = a.transferCount.compareTo(b.transferCount);
        return transfers != 0 ? transfers : LocalItinerary.compareByWalk(a, b);
      });
    if (candidates.isEmpty) return;
    _startRiding(ref, candidates.first);
  }

  void _startRiding(String ref, LocalItinerary itinerary) {
    _ridingRef = ref;
    _ridingItinerary = itinerary;
    notifyListeners();
  }

  void endRiding() {
    _ridingRef = null;
    _ridingItinerary = null;
    notifyListeners();
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
    downloader.cancel();
    await prefs.remove(_consentKey);
    await _writeSwiftConsent(null);
    await store.delete();
    _snapshot = CatalogSnapshot.empty;
    _planner.invalidate();
    endRiding();
    await _replan();
  }

  // MARK: - 取得

  Future<void> downloadAll() async {
    final origin = _origin;
    if (origin == null || !consentGranted) return;
    await downloader.downloadAll(origin);
  }

  Future<void> updateCatalog() async {
    final origin = _origin;
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
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
