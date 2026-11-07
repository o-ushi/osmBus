import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/trip_controller.dart';
import 'theme.dart';

/// 乗車中の降車停留所を − と ＋ で 1 つずつずらす。経路地図と路線図で同じものを出す。
/// どちらも [TripController.shiftRidingAlight] を呼び、停留所の列は [TripController.alightChoice]。
/// 列が取れなければ（路線データが無いなど）降車停の名前だけ出す。
class AlightStepper extends StatelessWidget {
  const AlightStepper({super.key, required this.controller, this.fallbackStopName, this.style});

  final TripController controller;

  /// 列が取れないときに出す降車停の名前。
  final String? fallbackStopName;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choice = controller.alightChoice;
    final name = choice?.alightStop.name ?? controller.riding?.alightStop.name ?? fallbackStopName;
    final label = Text(
      name == null ? '' : l10n.alightAt(name),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: choice == null ? TextAlign.start : TextAlign.center,
      style: style,
    );
    if (choice == null) return label;
    return Row(
      children: [
        _button(
          icon: CupertinoIcons.minus_circle_fill,
          tooltip: l10n.alightPreviousStop,
          onPressed: choice.canPrevious ? () => controller.shiftRidingAlight(-1) : null,
        ),
        Expanded(child: label),
        _button(
          icon: CupertinoIcons.plus_circle_fill,
          tooltip: l10n.alightNextStop,
          onPressed: choice.canNext ? () => controller.shiftRidingAlight(1) : null,
        ),
      ],
    );
  }

  Widget _button({required IconData icon, required String tooltip, required VoidCallback? onPressed}) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 26),
        color: Colors.orange,
        disabledColor: AppTheme.tertiaryText,
      );
}
