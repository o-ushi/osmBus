import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Swift 版 `BusKeypadView`。数字のみ、CLR と判定（⏎）。
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.input,
    required this.onDigit,
    required this.onClear,
    required this.onSubmit,
    this.onKeyFeedback,
    this.onEnterFeedback,
  });

  final String input;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  /// キーを押したときの音・振動。null なら軽い振動だけ。
  final VoidCallback? onKeyFeedback;
  final VoidCallback? onEnterFeedback;

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSubmit = input.isNotEmpty;

    Widget key(String title, {bool clear = false}) => Expanded(
          child: PressScale(
            onTap: () {
              (onKeyFeedback ?? HapticFeedback.selectionClick)();
              clear ? onClear() : onDigit(title);
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: clear ? 0.05 : 0.08),
                borderRadius: BorderRadius.circular(AppTheme.keypadCornerRadius),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: clear ? FontWeight.w700 : FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );

    Widget enter() => Expanded(
          child: Semantics(
            button: true,
            label: l10n.keypadSubmit,
            child: PressScale(
              onTap: canSubmit
                  ? () {
                      (onEnterFeedback ?? HapticFeedback.mediumImpact)();
                      onSubmit();
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canSubmit ? Colors.green : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.keypadCornerRadius),
                ),
                child: Icon(
                  CupertinoIcons.return_icon,
                  size: 24,
                  color: canSubmit ? Colors.white : AppTheme.secondaryText,
                ),
              ),
            ),
          ),
        );

    Widget row(List<Widget> keys) => Expanded(
          child: Row(
            children: [
              for (final (i, k) in keys.indexed) ...[if (i > 0) const SizedBox(width: _gap), k],
            ],
          ),
        );

    return BusCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final displayHeight = (constraints.maxHeight * 0.2).clamp(28.0, 58.0);
          return Column(
            children: [
              SizedBox(
                height: displayHeight,
                child: Center(
                  child: FittedBox(
                    child: Text(
                      input.isEmpty ? '—' : input,
                      style: TextStyle(
                        fontSize: displayHeight * 0.83,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              row([key('1'), key('2'), key('3')]),
              const SizedBox(height: _gap),
              row([key('4'), key('5'), key('6')]),
              const SizedBox(height: _gap),
              row([key('7'), key('8'), key('9')]),
              const SizedBox(height: _gap),
              row([key('CLR', clear: true), key('0'), enter()]),
            ],
          );
        },
      ),
    );
  }
}
