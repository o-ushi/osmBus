import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/route_catalog.dart';
import '../state/places_store.dart';
import '../state/trip_controller.dart';
import 'destination_picker_screen.dart';
import 'grouped_list.dart';
import 'sheet_page.dart';
import 'theme.dart';

/// 登録済みの場所を開き、選んだ場所を返す。
Future<Destination?> showSavedPlaces(BuildContext context, TripController controller) =>
    showSheetNavigator<Destination>(context, (_) => SavedPlacesScreen(controller: controller));

/// 目的地の履歴を開き、選んだ目的地を返す。
Future<Destination?> showHistory(BuildContext context, TripController controller) =>
    showSheetNavigator<Destination>(context, (_) => HistoryScreen(controller: controller));

/// 目的地が無いときは座標を読まない。
/// 一覧の構築に混ぜると、未設定のまま先に緯度を読んで iOS が落ちる。
@pragma('vm:never-inline')
bool _marksActive(GeoPoint? active, GeoPoint point) {
  if (active == null) return false;
  return Destination.samePoint(active, point);
}

void _choose(BuildContext context, Destination destination) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop(destination);
    return;
  }
  Navigator.of(context, rootNavigator: true).pop(destination);
}

/// 登録済みの場所（Swift の `SavedPlacesView`）。タップで目的地に、長押しで今の目的地を登録。
class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key, required this.controller, this.onBack, this.onSelected});

  final TripController controller;

  /// 行き先シートの中で開いているとき、地図へ戻す。
  final VoidCallback? onBack;

  /// 指定したときは、シートを閉じずにこの場所を選んだことにする。
  final ValueChanged<Destination>? onSelected;

  PlacesStore get _places => controller.places;

  Future<void> _add(BuildContext context) async {
    await SheetPage.push<void>(context, (_) => _PlaceEditor(controller: controller));
  }

  Future<void> _registerCurrent(BuildContext context, Destination destination) async {
    await _places.addPlace(SavedPlace.from(destination, label: destination.name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_places, controller]),
      builder: (context, _) {
        // 描画中に同期で中身が差し替わっても、このフレームは同じ一覧を使う。
        final places = List<SavedPlace>.of(_places.places);
        final current = controller.destination;
        final active = current?.point;
        return SheetPage(
          title: l10n.savedPlaces,
          onBack: onBack,
          trailing: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _add(context),
            child: Semantics(label: l10n.addPlace, child: const Icon(CupertinoIcons.add, size: 26)),
          ),
          children: [
            if (places.isEmpty)
              _EmptyState(
                icon: CupertinoIcons.map_pin_ellipse,
                title: l10n.savedPlacesEmpty,
                detail: l10n.savedPlacesEmptyDetail,
              )
            else
              GroupedSection(
                title: l10n.savedPlaces,
                footer: l10n.savedPlacesFooter,
                children: [
                  for (final place in places)
                    Dismissible(
                      key: ValueKey(place.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: CupertinoColors.destructiveRed,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(CupertinoIcons.trash, color: Colors.white),
                      ),
                      onDismissed: (_) => _places.deletePlace(place.id),
                      child: GroupedRow(
                        title: place.label,
                        subtitle: place.detailLine,
                        onTap: () => onSelected != null ? onSelected!(place.toDestination()) : _choose(context, place.toDestination()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_marksActive(active, place.point)) _ActiveBadge(l10n.active),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(36, 36),
                              onPressed: () => SheetPage.push<void>(
                                context,
                                (_) => _PlaceEditor(controller: controller, editing: place),
                              ),
                              child: Semantics(
                                label: l10n.edit,
                                child: const Icon(CupertinoIcons.pencil, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            if (current != null)
              GroupedSection(
                title: l10n.currentDestination,
                footer: l10n.longPressToRegisterFooter,
                children: [
                  GestureDetector(
                    onLongPress: () => _registerCurrent(context, current),
                    child: GroupedRow(
                      title: current.name,
                      subtitle: [if (current.subtitle != null) current.subtitle!, l10n.longPressToRegister].join('\n'),
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

/// 場所の追加・編集。名前（自宅・会社・学校の候補つき）と地点。
class _PlaceEditor extends StatefulWidget {
  const _PlaceEditor({required this.controller, this.editing});

  final TripController controller;
  final SavedPlace? editing;

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late final TextEditingController _label = TextEditingController(text: widget.editing?.label ?? '');
  late Destination? _place = widget.editing == null
      ? widget.controller.destination
      : Destination(
          name: widget.editing!.placeName,
          subtitle: widget.editing!.subtitle,
          point: widget.editing!.point,
        );

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _canSave => _label.text.trim().isNotEmpty && _place != null;

  Future<void> _pickPlace() async {
    final picked = await showDestinationPicker(
      context,
      initialCenter: _place?.point ?? widget.controller.origin,
      searchCenter: widget.controller.origin,
      showsRoleToggle: false,
    );
    if (picked != null) setState(() => _place = picked.place);
  }

  Future<void> _save() async {
    final place = _place;
    if (place == null) return;
    final label = _label.text.trim();
    final store = widget.controller.places;
    final editing = widget.editing;
    if (editing != null) {
      await store.updatePlace(editing.copyWith(
        label: label,
        placeName: place.name,
        subtitle: place.subtitle,
        point: place.point,
      ));
    } else {
      await store.addPlace(SavedPlace.from(place, label: label));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quickLabels = [l10n.labelHome, l10n.labelWork, l10n.labelSchool];
    return SheetPage(
      title: widget.editing == null ? l10n.addPlace : l10n.edit,
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onPressed: _canSave ? _save : null,
        child: Semantics(label: l10n.save, child: const Icon(CupertinoIcons.checkmark_alt, size: 28)),
      ),
      children: [
        GroupedSection(
          title: l10n.placeName,
          footer: l10n.placeNameFooter,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: CupertinoTextField.borderless(
                controller: _label,
                placeholder: l10n.placeNamePlaceholder,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 17),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final quick in quickLabels)
                    ChoiceChip(
                      label: Text(quick),
                      selected: _label.text.trim() == quick,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _label.text = quick),
                    ),
                ],
              ),
            ),
          ],
        ),
        GroupedSection(
          title: l10n.place,
          footer: l10n.placeFooter,
          children: [
            if (_place != null) GroupedRow(title: _place!.name, subtitle: _place!.subtitle),
            GroupedRow(
              title: _place == null ? l10n.pickOnMap : l10n.choosePlaceAgain,
              leading: CupertinoIcons.search,
              action: true,
              onTap: _pickPlace,
            ),
          ],
        ),
      ],
    );
  }
}

/// 目的地の履歴（Swift の `DestinationHistoryView`）。
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller, this.onBack, this.onSelected});

  final TripController controller;

  /// 行き先シートの中で開いているとき、地図へ戻す。
  final VoidCallback? onBack;

  /// 指定したときは、シートを閉じずにこの場所を選んだことにする。
  final ValueChanged<Destination>? onSelected;

  Future<void> _clear(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.clearHistoryConfirm),
        content: Text(l10n.cannotBeUndone),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearHistory),
          ),
        ],
      ),
    );
    if (ok == true) await controller.places.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = MaterialLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller.places, controller]),
      builder: (context, _) {
        final entries = List<HistoryEntry>.of(controller.places.history);
        final active = controller.destination?.point;
        return SheetPage(
          title: l10n.history,
          onBack: onBack,
          children: [
            if (entries.isEmpty)
              _EmptyState(icon: CupertinoIcons.clock, title: l10n.historyEmpty, detail: l10n.historyEmptyDetail)
            else ...[
              GroupedSection(
                title: l10n.destinationHistory,
                footer: l10n.historyTapFooter,
                children: [
                  for (final entry in entries)
                    GroupedRow(
                      title: entry.destination.name,
                      subtitle: [
                        if (entry.destination.subtitle != null) entry.destination.subtitle!,
                        '${m.formatShortDate(entry.setAt.toLocal())} '
                            '${m.formatTimeOfDay(TimeOfDay.fromDateTime(entry.setAt.toLocal()), alwaysUse24HourFormat: true)}',
                      ].join('\n'),
                      onTap: () => onSelected != null ? onSelected!(entry.destination) : _choose(context, entry.destination),
                      trailing: _marksActive(active, entry.destination.point)
                          ? _ActiveBadge(l10n.active)
                          : null,
                    ),
                ],
              ),
              GroupedSection(
                footer: l10n.clearHistoryFooter,
                children: [
                  GroupedRow(
                    title: l10n.clearHistory,
                    leading: CupertinoIcons.trash,
                    destructive: true,
                    onTap: () => _clear(context),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppTheme.secondaryText),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.secondaryText)),
          ],
        ),
      );
}
