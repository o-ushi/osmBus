import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../state/places_store.dart';
import 'app_log.dart';

enum PurchaseOutcome { success, cancelled, pending, failed }

enum RestoreOutcome { restored, nothingToRestore, failed }

/// PREMIUM（買い切り）の購入と復元（Swift の `StorePurchaseManager`）。
class PurchaseService extends ChangeNotifier {
  PurchaseService({required this.plan, this.store});

  /// App Store Connect / Play Console の商品 ID と完全一致させる。
  static const String premiumId = 'com.osamushikubo.osmBus.upgrade';

  final PlanStore plan;
  /// テストで差し替える。null なら端末のストア。
  final InAppPurchase? store;
  InAppPurchase get _iap => store ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _loading = false;
  bool _purchasing = false;
  bool _restoring = false;
  bool _productMissing = false;
  bool _loadFailed = false;
  Completer<PurchaseOutcome>? _purchaseWaiter;
  Completer<bool>? _restoreWaiter;

  ProductDetails? get product => _product;
  bool get loading => _loading;
  bool get purchasing => _purchasing;
  bool get restoring => _restoring;
  bool get productMissing => _productMissing;
  bool get loadFailed => _loadFailed;

  /// 起動時に購入の更新を受け始める。未完了の取引もここで届く。
  void start() {
    try {
      _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    } catch (_) {}
  }

  Future<void> loadProducts() async {
    _loading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      if (!await _iap.isAvailable()) throw StateError('store unavailable');
      final response = await _iap.queryProductDetails({premiumId});
      _product = response.productDetails.where((p) => p.id == premiumId).firstOrNull;
      _productMissing = _product == null;
    } catch (e) {
      AppLog.w('purchase', 'load products failed $e');
      _product = null;
      _loadFailed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<PurchaseOutcome> purchase() async {
    if (_product == null) await loadProducts();
    final product = _product;
    if (product == null) return PurchaseOutcome.failed;
    _purchasing = true;
    notifyListeners();
    final waiter = _purchaseWaiter = Completer<PurchaseOutcome>();
    try {
      final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) return PurchaseOutcome.failed;
      return await waiter.future;
    } catch (_) {
      return PurchaseOutcome.failed;
    } finally {
      _purchaseWaiter = null;
      _purchasing = false;
      notifyListeners();
    }
  }

  /// 復元の結果は購入の更新として届く。しばらく待って届かなければ「復元できる購入なし」。
  Future<RestoreOutcome> restore({Duration wait = const Duration(seconds: 8)}) async {
    _restoring = true;
    notifyListeners();
    final waiter = _restoreWaiter = Completer<bool>();
    try {
      await _iap.restorePurchases();
      final restored = await waiter.future.timeout(wait, onTimeout: () => plan.isPaid);
      return restored ? RestoreOutcome.restored : RestoreOutcome.nothingToRestore;
    } catch (_) {
      return RestoreOutcome.failed;
    } finally {
      _restoreWaiter = null;
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      AppLog.i('purchase', '${p.productID} ${p.status.name}${p.error == null ? '' : ' ${p.error!.code} ${p.error!.message}'}');
      if (p.productID != premiumId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await plan.setPlan(AppPlan.paid);
          _purchaseWaiter?.complete(PurchaseOutcome.success);
          _purchaseWaiter = null;
          if (_restoreWaiter case final w? when !w.isCompleted) w.complete(true);
        case PurchaseStatus.pending:
          _purchaseWaiter?.complete(PurchaseOutcome.pending);
          _purchaseWaiter = null;
        case PurchaseStatus.canceled:
          _purchaseWaiter?.complete(PurchaseOutcome.cancelled);
          _purchaseWaiter = null;
        case PurchaseStatus.error:
          _purchaseWaiter?.complete(PurchaseOutcome.failed);
          _purchaseWaiter = null;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
