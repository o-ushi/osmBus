import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/missing_number.dart';
import '../models/route_catalog.dart';
import '../state/trip_controller.dart';
import 'stop_order_editor.dart';
import 'theme.dart';

/// 番号表から、この区間に無い番号を入れて路線の確認を開く。
Future<void> showMissingNumber(BuildContext context, TripController controller) async {
  final origin = controller.origin;
  final destination = controller.destination?.point;
  if (origin == null || destination == null) return;
  final relationId = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackground,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final height = (media.size.height * 0.72 - media.viewInsets.bottom).clamp(280.0, media.size.height * 0.72);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: height,
          child: MissingNumberSheet(
            routes: controller.visibleCatalog.routes,
            origin: origin,
            destination: destination,
          ),
        ),
      );
    },
  );
  if (relationId == null || !context.mounted) return;
  await showRouteReview(context, controller, relationId);
}

class MissingNumberSheet extends StatefulWidget {
  const MissingNumberSheet({
    super.key,
    required this.routes,
    required this.origin,
    required this.destination,
  });

  final List<RouteRecord> routes;
  final GeoPoint origin;
  final GeoPoint destination;

  @override
  State<MissingNumberSheet> createState() => _MissingNumberSheetState();
}

class _MissingNumberSheetState extends State<MissingNumberSheet> {
  final TextEditingController _input = TextEditingController();
  MissingNumberResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search() {
    final result = MissingNumber.find(
      widget.routes,
      _input.text,
      origin: widget.origin,
      destination: widget.destination,
    );
    if (result.onSegment.length == 1 && result.numberOnly.isEmpty) {
      Navigator.pop(context, result.onSegment.single.relationId);
      return;
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(l10n.missingNumberTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(l10n.missingNumberHint, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.missingNumberField,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: Text(l10n.missingNumberSearch)),
            ],
          ),
        ),
        Expanded(child: result == null ? const SizedBox.shrink() : _results(l10n, result)),
      ],
    );
  }

  Widget _results(AppLocalizations l10n, MissingNumberResult result) {
    if (result.onSegment.isEmpty && result.numberOnly.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(l10n.missingNumberNone, style: const TextStyle(fontSize: 15, color: AppTheme.secondaryText)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (result.onSegment.isNotEmpty) ...[
          _heading(l10n.missingNumberOnSegment),
          for (final route in result.onSegment) _tile(route),
        ],
        if (result.numberOnly.isNotEmpty) ...[
          _heading(l10n.missingNumberOthers),
          for (final route in result.numberOnly) _tile(route),
        ],
      ],
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryText)),
      );

  Widget _tile(RouteRecord route) {
    final direction = route.directionText;
    return Material(
      color: Colors.white,
      child: ListTile(
        title: Text(route.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: direction == null ? null : Text(direction, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => Navigator.pop(context, route.relationId),
      ),
    );
  }
}
