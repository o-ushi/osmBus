import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/official_order_matcher.dart';
import '../state/trip_controller.dart';
import 'theme.dart';

/// 今見ている路線の停留所順が公式と違う、または公式の順を適用しているときだけ出す 1 行。
/// タップで違いの説明と、適用・元に戻すのシートを開く。経路地図と路線図で同じものを出す。
class OfficialOrderHintRow extends StatelessWidget {
  const OfficialOrderHintRow({super.key, required this.controller, required this.relationId, this.anchorStopId});

  final TripController controller;
  final int relationId;

  /// 説明の基準にする停留所（今の降車停）。null なら最初に順が違う箇所。
  final int? anchorStopId;

  @override
  Widget build(BuildContext context) {
    final status = controller.officialOrderStatus(relationId);
    if (status == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final applied = status.state == OfficialOrderState.applied;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              applied ? CupertinoIcons.checkmark_seal : CupertinoIcons.exclamationmark_circle,
              size: 16,
              color: applied ? AppTheme.verdictGreen : Colors.orange,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                applied ? l10n.stopOrderUsingOfficial : l10n.stopOrderDiffers,
                style: TextStyle(fontSize: 13, color: applied ? AppTheme.verdictGreen : Colors.orange.shade800),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppTheme.tertiaryText),
          ],
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppTheme.groupedBackground,
        builder: (sheetContext) {
          final l10n = AppLocalizations.of(sheetContext);
          final status = controller.officialOrderStatus(relationId);
          if (status == null) return const SizedBox(height: 120);
          final applied = status.state == OfficialOrderState.applied;
          final lines = OfficialOrderMatcher.hint(
            current: status.osmOrder,
            official: status.officialOrder,
            anchorId: anchorStopId,
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    applied ? l10n.stopOrderUsingOfficial : l10n.stopOrderDiffers,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(orderHintText(l10n, line, applied: applied)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      if (applied) {
                        controller.revertOfficialOrder(relationId);
                      } else {
                        controller.applyOfficialOrder(relationId);
                      }
                    },
                    child: Text(applied ? l10n.stopOrderRevert : l10n.stopOrderApply),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

/// 前後の違い 1 行の文。[applied] なら公式の順として説明する。
String orderHintText(AppLocalizations l10n, OrderHintLine line, {required bool applied}) {
  final current = line.current ?? l10n.orderHintNone;
  final official = line.official ?? l10n.orderHintNone;
  if (applied) {
    return line.before
        ? l10n.orderHintAppliedBefore(line.anchor, current, official)
        : l10n.orderHintAppliedAfter(line.anchor, current, official);
  }
  return line.before
      ? l10n.orderHintBefore(line.anchor, current, official)
      : l10n.orderHintAfter(line.anchor, current, official);
}

/// 設定の「停留所順を点検」。照合結果だけを出し、ボタンを押したときだけ直せる路線に適用する。
Future<void> showStopOrderInspection(BuildContext context, TripController controller) {
  final inspection = controller.inspectStopOrder();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackground,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final unsure = [
        for (final route in inspection.unsure)
          route.directionText == null ? route.ref : '${route.ref}  ${route.directionText}',
      ];
      return FractionallySizedBox(
        heightFactor: 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.stopOrderInspect, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (inspection.officialRouteCount == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.inspectNoData, style: const TextStyle(color: AppTheme.secondaryText)),
                ),
              Text(l10n.inspectFixable(inspection.fixable.length)),
              const SizedBox(height: 6),
              Text(l10n.inspectUnsure(inspection.unsure.length)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  children: [
                    for (final line in unsure)
                      Text(line, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: inspection.fixable.isEmpty
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        controller.applyInspection(inspection);
                      },
                child: Text(l10n.inspectApply),
              ),
            ],
          ),
        ),
      );
    },
  );
}
