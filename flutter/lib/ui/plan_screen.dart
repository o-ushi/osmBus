import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/purchase_service.dart';
import '../state/places_store.dart';
import '../state/trip_controller.dart';
import 'grouped_list.dart';
import 'sheet_page.dart';

Future<void> showPlanSheet(BuildContext context, TripController controller) =>
    showSheetNavigator<void>(context, (_) => PlanScreen(controller: controller));

/// プラン管理（Swift の `PlanManagementView`）。PREMIUM は買い切りで、登録地と履歴が無制限。
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.controller});

  final TripController controller;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  PurchaseService get _store => widget.controller.purchases;
  PlanStore get _plan => widget.controller.plan;

  @override
  void initState() {
    super.initState();
    if (_store.product == null && !_store.loading) _store.loadProducts();
  }

  Future<void> _message(String title, String body) => showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).ok),
            ),
          ],
        ),
      );

  Future<void> _purchase() async {
    final l10n = AppLocalizations.of(context);
    final outcome = await _store.purchase();
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        await _message(l10n.planPremium, l10n.planUpgradeDone);
      case PurchaseOutcome.pending:
        await _message(l10n.planUpgrade, l10n.iapPending);
      case PurchaseOutcome.failed:
        await _message(l10n.planUpgrade, _store.product == null ? l10n.iapProductMissing : l10n.iapPurchaseFailed);
      case PurchaseOutcome.cancelled:
        break;
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    final outcome = await _store.restore();
    if (!mounted) return;
    switch (outcome) {
      case RestoreOutcome.restored:
        await _message(l10n.planRestore, l10n.planRestored);
      case RestoreOutcome.nothingToRestore:
        await _message(l10n.planRestore, l10n.planNothingToRestore);
      case RestoreOutcome.failed:
        await _message(l10n.planRestore, l10n.iapRestoreFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_store, _plan]),
      builder: (context, _) {
        final paid = _plan.isPaid;
        final limit = _plan.itemLimit;
        final limitText = limit == null ? l10n.unlimited : l10n.itemCount(limit);
        final busy = _store.purchasing || _store.loading;
        final product = _store.product;
        final productStatus = _store.loading
            ? l10n.iapLoading
            : product?.price ?? (_store.loadFailed ? l10n.iapLoadFailed : l10n.iapProductMissing);
        return SheetPage(
          title: l10n.planManagement,
          closesSheet: true,
          children: [
            GroupedSection(
              footer: paid ? null : l10n.planFreeDescription,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      PlanIcon(paid: paid, size: 60),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.planCurrent, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(
                            paid ? l10n.planPremium : l10n.planFree,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: paid ? Colors.orange : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            GroupedSection(
              footer: paid ? l10n.planPremiumLimitFooter : l10n.planFreeLimitFooter(PlanStore.freeItemLimit),
              children: [
                GroupedRow(
                  title: l10n.history,
                  leading: CupertinoIcons.clock,
                  trailing: _LimitText(limitText, highlighted: !paid),
                ),
                GroupedRow(
                  title: l10n.savedPlaces,
                  leading: CupertinoIcons.map_pin_ellipse,
                  trailing: _LimitText(limitText, highlighted: !paid),
                ),
              ],
            ),
            if (!paid)
              GroupedSection(
                children: [
                  GroupedRow(
                    title: l10n.planUpgrade,
                    subtitle: productStatus,
                    leading: Icons.workspace_premium,
                    leadingColor: Colors.orange,
                    bold: true,
                    enabled: !busy && product != null,
                    onTap: _purchase,
                    trailing: busy ? const CupertinoActivityIndicator() : null,
                  ),
                  if (product == null && !_store.loading)
                    GroupedRow(
                      title: l10n.iapReload,
                      leading: CupertinoIcons.arrow_clockwise,
                      action: true,
                      onTap: _store.loadProducts,
                    ),
                ],
              ),
            GroupedSection(
              footer: l10n.planRestoreFooter,
              children: [
                GroupedRow(
                  title: l10n.planRestore,
                  action: true,
                  enabled: !_store.restoring && !_store.purchasing,
                  onTap: _restore,
                  trailing: _store.restoring ? const CupertinoActivityIndicator() : null,
                ),
              ],
            ),
            if (kDebugMode)
              GroupedSection(
                title: l10n.developerMenu,
                footer: l10n.planSwitchDescription,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<AppPlan>(
                        groupValue: _plan.plan,
                        onValueChanged: (plan) {
                          if (plan != null) _plan.setPlan(plan);
                        },
                        children: {
                          AppPlan.free: Text(l10n.planFree),
                          AppPlan.paid: Text(l10n.planPremium),
                        },
                      ),
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

class _LimitText extends StatelessWidget {
  const _LimitText(this.text, {required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 17,
          color: highlighted ? Colors.orange : Colors.black54,
          fontWeight: highlighted ? FontWeight.w600 : null,
        ),
      );
}

/// プランごとのアプリアイコン（Swift の `ImageFree` / `ImagePremium`）。
class PlanIcon extends StatelessWidget {
  const PlanIcon({super.key, required this.paid, required this.size});

  final bool paid;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(paid ? 'assets/images/plan_premium.png' : 'assets/images/plan_free.png', fit: BoxFit.cover),
        ),
      );
}
