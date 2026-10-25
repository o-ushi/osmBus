import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/bus_identifier.dart';
import '../models/bus_matrix.dart';
import '../state/trip_controller.dart';
import 'theme.dart';

String compassLabel(AppLocalizations l10n, int index) => switch (index % 8) {
      0 => l10n.compassN,
      1 => l10n.compassNE,
      2 => l10n.compassE,
      3 => l10n.compassSE,
      4 => l10n.compassS,
      5 => l10n.compassSW,
      6 => l10n.compassW,
      _ => l10n.compassNW,
    };

/// トップのバス番号表（方向 × 乗換）。タップ＝路線図、長押し＝乗車／降車。
class BusNumberTable extends StatelessWidget {
  const BusNumberTable({
    super.key,
    required this.state,
    required this.sortMode,
    required this.rows,
    required this.flatEntries,
    required this.ridingRef,
    required this.onReload,
    required this.onTap,
    required this.onLongPress,
  });

  final TableState state;
  final TableSortMode sortMode;
  final List<MatrixRow> rows;
  final List<MatrixEntry> flatEntries;
  final String? ridingRef;
  final VoidCallback onReload;
  final ValueChanged<MatrixEntry> onTap;
  final ValueChanged<MatrixEntry> onLongPress;

  static const _cellStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BusCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.busNumberTable,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: l10n.reload,
                onPressed: onReload,
                icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: AppTheme.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(width: double.infinity, child: _content(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (state) {
      TableState.consentRequired => l10n.tableConsentRequired,
      TableState.noLocation => l10n.noLocation,
      TableState.noDestination => l10n.destinationUnset,
      TableState.noRouteData => l10n.noRouteData,
      TableState.calculating => l10n.tableCalculating,
      TableState.noRoutes => l10n.tableNoRoutes,
      TableState.ready => null,
    };
    if (message != null) return _statusText(message);
    if (sortMode == TableSortMode.direction) {
      return rows.isEmpty ? _statusText(l10n.tableNoRoutes) : _directionGrid(context);
    }
    return flatEntries.isEmpty ? _statusText(l10n.tableNoRoutes) : _flatGrid(context);
  }

  Widget _statusText(String text) => Text(
        text,
        style: const TextStyle(fontSize: 15, color: AppTheme.secondaryText),
      );

  static const _divider = BorderSide(color: Color(0x333C3C43), width: 0.5);

  Widget _headerIcon(IconData icon, String semantics) => Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Icon(icon, size: 16, color: AppTheme.secondaryText),
      );

  Widget _transferHeader(String digits, String semantics) => Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.arrow_swap, size: 13, color: AppTheme.secondaryText),
            const SizedBox(width: 3),
            Text(digits, style: _cellStyle),
          ],
        ),
      );

  Widget _cell(Widget child) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
        child: Align(alignment: Alignment.topLeft, child: child),
      );

  String _categoryLabel(AppLocalizations l10n, int column) => switch (column) {
        0 => l10n.headerDirect,
        1 => l10n.headerTransfer1,
        _ => l10n.headerTransfer2,
      };

  Widget _badge(AppLocalizations l10n, MatrixEntry entry, String text) => BusBadge(
        text: text,
        riding: ridingRef != null && ridingRef!.toUpperCase() == entry.firstRef.toUpperCase(),
        onTap: () => onTap(entry),
        onLongPress: () => onLongPress(entry),
        semanticsLabel: '${_categoryLabel(l10n, entry.column)} $text. ${l10n.tableTapHint}',
      );

  Widget _directionGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget cell(List<MatrixEntry> entries) {
      if (entries.isEmpty) {
        return const Text('—', style: TextStyle(fontSize: 12, color: AppTheme.tertiaryText));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) const SizedBox(height: 4),
            _badge(l10n, entry, entry.token),
          ],
        ],
      );
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
      },
      border: const TableBorder(horizontalInside: _divider, bottom: _divider),
      children: [
        TableRow(children: [
          _cell(_headerIcon(CupertinoIcons.compass, l10n.headerDirection)),
          _cell(_transferHeader('0', l10n.headerDirect)),
          _cell(_transferHeader('1', l10n.headerTransfer1)),
          _cell(_transferHeader('2+', l10n.headerTransfer2)),
        ]),
        for (final row in rows)
          TableRow(children: [
            _cell(Text(compassLabel(l10n, row.compassIndex), style: _cellStyle)),
            for (final entries in row.cells) _cell(cell(entries)),
          ]),
      ],
    );
  }

  Widget _flatGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transferFirst = sortMode == TableSortMode.transfers;

    Widget direction(MatrixEntry e) => Text(compassLabel(l10n, e.compassIndex), style: _cellStyle);
    Widget transfers(MatrixEntry e) =>
        _transferHeader(e.column >= 2 ? '2+' : '${e.column}', _categoryLabel(l10n, e.column));
    Widget chain(MatrixEntry e) {
      final tokens = [
        for (final leg in e.itinerary.legs) BusIdentifierParts.displayTokenForRef(leg.ref),
      ];
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final (i, token) in tokens.indexed) ...[
            if (i > 0) const Icon(CupertinoIcons.arrow_right, size: 11, color: AppTheme.tertiaryText),
            _badge(l10n, e, token),
          ],
        ],
      );
    }

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: FlexColumnWidth(),
      },
      border: const TableBorder(horizontalInside: _divider, bottom: _divider),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          if (transferFirst) ...[
            _cell(_headerIcon(CupertinoIcons.arrow_swap, l10n.transfersHeader)),
            _cell(_headerIcon(CupertinoIcons.compass, l10n.headerDirection)),
          ] else ...[
            _cell(_headerIcon(CupertinoIcons.compass, l10n.headerDirection)),
            _cell(_headerIcon(CupertinoIcons.arrow_swap, l10n.transfersHeader)),
          ],
          _cell(Text(
            l10n.busNumberHeader,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
          )),
        ]),
        for (final e in flatEntries)
          TableRow(children: [
            if (transferFirst) ...[_cell(transfers(e)), _cell(direction(e))] else ...[
              _cell(direction(e)),
              _cell(transfers(e)),
            ],
            _cell(chain(e)),
          ]),
      ],
    );
  }
}
