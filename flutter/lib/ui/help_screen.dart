import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../state/places_store.dart';
import 'grouped_list.dart';
import 'plan_screen.dart';
import 'sheet_page.dart';
import 'theme.dart';

Future<void> showHelpSheet(BuildContext context, PlanStore plan) =>
    showSheetNavigator<void>(context, (_) => HelpScreen(plan: plan));

/// ヘルプ（Swift の `HelpView`）。Google に関する項目は、この版の動きに合わせて書き換えた。
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.plan});

  final PlanStore plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget item(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        );

    return SheetPage(
      title: l10n.help,
      closesSheet: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Row(
            children: [
              PlanIcon(paid: plan.isPaid, size: 72),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('osmBus', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, info) => Text(
                      info.hasData ? l10n.versionLabel(info.data!.version, info.data!.buildNumber) : '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.secondaryText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(l10n.helpIntro, style: const TextStyle(fontSize: 15, height: 1.4)),
        ),
        GroupedSection(
          title: l10n.helpBasics,
          children: [
            item(CupertinoIcons.square_grid_2x2, l10n.helpTopTitle, l10n.helpTopBody),
            item(CupertinoIcons.location_circle_fill, l10n.helpDestinationTitle, l10n.helpDestinationBody),
            item(CupertinoIcons.location_fill, l10n.helpLocationTitle, l10n.helpLocationBody),
            item(CupertinoIcons.map_pin_ellipse, l10n.helpSavedPlacesTitle, l10n.helpSavedPlacesBody),
            item(CupertinoIcons.number, l10n.helpBusNumberTitle, l10n.helpBusNumberBody),
            item(CupertinoIcons.table, l10n.helpTableTitle, l10n.helpTableBody),
          ],
        ),
        GroupedSection(
          title: l10n.helpResults,
          children: [
            item(CupertinoIcons.checkmark_circle_fill, l10n.helpBoardTitle, l10n.helpBoardBody),
            item(CupertinoIcons.xmark_circle_fill, l10n.helpSkipTitle, l10n.helpSkipBody),
            item(CupertinoIcons.arrow_left_right, l10n.helpDistanceTitle, l10n.helpDistanceBody),
            item(CupertinoIcons.bus, l10n.helpRidingTitle, l10n.helpRidingBody),
          ],
        ),
        GroupedSection(
          title: l10n.helpRoutes,
          children: [
            item(CupertinoIcons.map, l10n.helpLineMapTitle, l10n.helpLineMapBody),
          ],
        ),
        GroupedSection(
          title: l10n.settings,
          children: [
            item(CupertinoIcons.gear_alt_fill, l10n.helpSettingsTitle, l10n.helpSettingsBody),
            item(Icons.workspace_premium, l10n.helpPlanTitle, l10n.helpPlanBody(PlanStore.freeItemLimit)),
          ],
        ),
        GroupedSection(
          title: l10n.helpTroubleshooting,
          children: [
            item(CupertinoIcons.exclamationmark_triangle_fill, l10n.helpNoRouteTitle, l10n.helpNoRouteBody),
            item(CupertinoIcons.wifi_slash, l10n.helpNetworkTitle, l10n.helpNetworkBody),
          ],
        ),
      ],
    );
  }
}
