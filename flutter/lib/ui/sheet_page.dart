import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';

/// シートを開き、その中で画面を進めたり戻ったりできるようにする（Swift の NavigationStack 付きシート）。
Future<T?> showSheetNavigator<T>(BuildContext context, WidgetBuilder root) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.94,
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: root),
      ),
    ),
  );
}

/// シート内の 1 画面。戻れるときは左上に「‹」、右上に任意のボタン。
class SheetPage extends StatelessWidget {
  const SheetPage({super.key, required this.title, required this.children, this.trailing, this.closesSheet = false});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// 一番上の画面に「完了」を出してシートを閉じる。
  final bool closesSheet;

  /// シートの中で次の画面へ進む。
  static Future<T?> push<T>(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = Navigator.of(context).canPop();
    return Material(
      color: AppTheme.groupedBackground,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 72),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                if (canPop)
                  Positioned(
                    left: 0,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.chevron_back, size: 26),
                    ),
                  ),
                if (trailing != null)
                  Positioned(right: 8, child: trailing!)
                else if (closesSheet && !canPop)
                  Positioned(
                    right: 8,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      child: Semantics(label: l10n.done, child: const Icon(CupertinoIcons.xmark, size: 24)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
