import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/boarding_decision.dart';
import 'bus_number_table.dart';
import 'theme.dart';

/// Swift 版 `ResultBannerView`。乗れる系統は黄、見送りは赤、乗車中は緑。
class ResultBanner extends StatelessWidget {
  const ResultBanner({
    super.key,
    required this.decision,
    required this.input,
    required this.ridingAlightStop,
    required this.onStartRiding,
    required this.onStopRiding,
  });

  final BoardingDecision decision;
  final String input;

  /// 乗車中なら降車停留所名。null なら乗車していない。
  final String? ridingAlightStop;
  final ValueChanged<String> onStartRiding;
  final VoidCallback onStopRiding;

  static const double _verdictSize = 30;

  static String _time(BuildContext context, int minutes) {
    final arrival = TimeOfDay.fromDateTime(DateTime.now().add(Duration(minutes: minutes)));
    return MaterialLocalizations.of(context).formatTimeOfDay(arrival, alwaysUse24HourFormat: true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: _content(context),
          ),
        ),
      ),
    );
  }

  Widget _verdictText(String text, Color color) => Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        style: TextStyle(fontSize: _verdictSize, fontWeight: FontWeight.w900, color: color, height: 1.15),
      );

  /// 判定の大きな文字。長押しで乗車・降車する（ボタンだとスクロールの下に隠れて押しにくいため）。
  Widget _pressableVerdict(String text, Color color, {required String hint, required VoidCallback onLongPress}) =>
      Semantics(
        onLongPressHint: hint,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          child: _verdictText(text, color),
        ),
      );

  Widget _caption(String text, {IconData? icon}) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondaryText);
    final label = Text(text, textAlign: TextAlign.center, style: style);
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.secondaryText),
        const SizedBox(width: 4),
        Flexible(child: label),
      ],
    );
  }

  Widget _centered(List<Widget> children) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 8), c],
          ],
        ),
      );

  Widget _notice(String text, {IconData icon = CupertinoIcons.exclamationmark_triangle_fill}) => Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Future<void> _chooseVariant(BuildContext context, List<String> names) async {
    if (names.length == 1) {
      onStartRiding(names.single);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final chosen = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.chooseVariant),
        actions: [
          for (final name in names)
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, name), child: Text(name)),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (chosen != null) onStartRiding(chosen);
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alight = ridingAlightStop;
    if (alight != null) {
      return _centered([
        _pressableVerdict(l10n.ridingLabel, AppTheme.verdictGreen, hint: l10n.getOff, onLongPress: onStopRiding),
        _caption(l10n.alightAt(alight)),
        _caption(l10n.longPressToGetOff, icon: CupertinoIcons.hand_point_right),
      ]);
    }

    return switch (decision) {
      BoardingIdle() => _idle(l10n),
      BoardingConsentRequired() => _notice(l10n.tableConsentRequired),
      BoardingNoLocation() => _notice(l10n.noLocation),
      BoardingNoDestination() => _notice(l10n.destinationUnset),
      BoardingNoRouteData() => _notice(l10n.noRouteData),
      BoardingCalculating() => Row(
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: 10),
            Text(l10n.tableCalculating, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      DoNotBoard() => Center(child: _verdictText(l10n.doNotBoard, AppTheme.verdictRed)),
      BoardIfVariant(:final names, :final itinerary, :final direction) => _centered([
          _pressableVerdict(
            l10n.boardVariant(names.join('・')),
            AppTheme.verdictYellow,
            hint: l10n.startRiding,
            onLongPress: () => _chooseVariant(context, names),
          ),
          _caption(l10n.alightAt(itinerary.firstLeg.alightStop.name)),
          _caption(
            direction.isAny
                ? l10n.directionAny
                : l10n.directionToward(compassLabel(l10n, direction.compassIndex!)),
            icon: direction.isAny ? CupertinoIcons.arrow_right_arrow_left : CupertinoIcons.location_north_fill,
          ),
          _caption(l10n.estimatedArrival(_time(context, itinerary.estimatedMinutes), itinerary.estimatedMinutes)),
          _caption(l10n.longPressToBoard, icon: CupertinoIcons.hand_point_right),
        ]),
    };
  }

  Widget _idle(AppLocalizations l10n) {
    return Row(
      children: [
        const Icon(CupertinoIcons.bus, size: 36, color: AppTheme.secondaryText),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.enterBusNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(l10n.busNumberHint, style: const TextStyle(fontSize: 16, color: AppTheme.secondaryText)),
            ],
          ),
        ),
      ],
    );
  }
}
