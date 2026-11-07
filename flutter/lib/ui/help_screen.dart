import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../state/trip_controller.dart';
import '../l10n/app_localizations.dart';
import 'expand_card.dart';
import 'privacy_screen.dart';
import 'sheet_page.dart';
import 'theme.dart';

Future<void> showHelpSheet(BuildContext context, TripController controller) =>
    showSheetNavigator<void>(context, (_) => HelpScreen(controller: controller));

/// ヘルプ。上から 登録 → 閲覧 → 困った時 → その他 の順。色はまとまりごとに揃える。
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, required this.controller});

  final TripController controller;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  /// 開いている節。
  final Set<String> _open = {};

  List<_HelpItem> _items(AppLocalizations l10n) => [
      _HelpItem('Dest', CupertinoIcons.location_circle_fill, Colors.orange, l10n.helpDestTitle, [l10n.helpDest1, l10n.helpDest2, l10n.helpDest3]),
      _HelpItem('Origin', CupertinoIcons.location_fill, Colors.orange, l10n.helpOriginTitle, [l10n.helpOrigin1, l10n.helpOrigin2, l10n.helpOrigin3]),
      _HelpItem('Place', CupertinoIcons.map_pin_ellipse, Colors.orange, l10n.helpPlaceTitle, [l10n.helpPlace1, l10n.helpPlace2]),
      _HelpItem('Ride', CupertinoIcons.bus, Colors.orange, l10n.helpRideTitle, [l10n.helpRide1, l10n.helpRide2]),
      _HelpItem('Number', CupertinoIcons.number, Colors.orange, l10n.helpNumberTitle, [l10n.helpNumber1, l10n.helpNumber2, l10n.helpNumber3]),
      _HelpItem('Table', CupertinoIcons.table, AppTheme.accent, l10n.helpTableTitle, [l10n.helpTable1, l10n.helpTable2, l10n.helpTable3]),
      _HelpItem('Distance', CupertinoIcons.arrow_left_right, AppTheme.accent, l10n.helpDistanceTitle, [l10n.helpDistance1, l10n.helpDistance2, l10n.helpDistance3]),
      _HelpItem('LineMap', CupertinoIcons.map, AppTheme.accent, l10n.helpLineMapTitle, [l10n.helpLineMap1, l10n.helpLineMap2, l10n.helpLineMap3]),
      _HelpItem('NoRoute', CupertinoIcons.exclamationmark_triangle_fill, Colors.purple, l10n.helpNoRouteTitle, [l10n.helpNoRoute1, l10n.helpNoRoute2]),
      _HelpItem('Missing', CupertinoIcons.question_circle, Colors.purple, l10n.helpMissingTitle, [l10n.helpMissing1, l10n.helpMissing2]),
      _HelpItem('Stop', CupertinoIcons.xmark_circle_fill, Colors.purple, l10n.helpStopTitle, [l10n.helpStop1]),
      _HelpItem('Network', CupertinoIcons.wifi_slash, Colors.purple, l10n.helpNetworkTitle, [l10n.helpNetwork1, l10n.helpNetwork2]),
    ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetPage(
      title: l10n.help,
      closesSheet: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Row(
            children: [
              const _AppMark(size: 72),
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
        const SizedBox(height: 16),
        for (final item in _items(l10n))
          Padding(
            key: ValueKey('help-section-${item.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: OsmExpandCard(
              title: item.title,
              icon: item.icon,
              accent: item.accent,
              open: _open.contains(item.id),
              onToggle: () => setState(() {
                if (!_open.remove(item.id)) _open.add(item.id);
              }),
              child: OsmStepList(steps: item.steps, color: item.accent),
            ),
          ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const ValueKey('help-privacy'),
            leading: const Icon(CupertinoIcons.hand_raised_fill, color: Colors.teal),
            title: Text(l10n.privacyTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppTheme.secondaryText),
            onTap: () => SheetPage.push<void>(context, (_) => PrivacyScreen(controller: widget.controller)),
          ),
        ),
      ],
    );
  }
}

class _HelpItem {
  const _HelpItem(this.id, this.icon, this.accent, this.title, this.steps);

  final String id;
  final IconData icon;
  final Color accent;
  final String title;
  final List<String> steps;
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});

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
          child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
        ),
      );
}
