import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../state/trip_controller.dart';
import 'grouped_list.dart';
import 'sheet_page.dart';
import 'theme.dart';

/// プライバシーとデータ（Swift の `PrivacyDataView`）。Google には何も送らない。
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.controller});

  final TripController controller;

  Future<void> _deleteAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.privacyDeleteAllConfirm),
        content: Text(l10n.privacyDeleteAllDetail),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteAllData();
  }

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SheetPage(
        title: l10n.privacyTitle,
        children: [
          GroupedSection(title: l10n.privacyRecipients, children: [_body(l10n.privacyRecipientsBody)]),
          GroupedSection(title: l10n.privacyStorage, children: [_body(l10n.privacyStorageBody)]),
          GroupedSection(
            title: l10n.privacyConsent,
            children: [
              GroupedRow(
                title: l10n.consentTitle,
                subtitle: controller.consentGranted ? l10n.privacyConsentOn : l10n.privacyConsentOff,
                trailing: CupertinoSwitch(value: controller.consentGranted, onChanged: controller.setConsent),
              ),
            ],
          ),
          GroupedSection(
            footer: l10n.privacyDeleteAllDetail,
            children: [
              GroupedRow(
                title: l10n.privacyDeleteAll,
                leading: CupertinoIcons.trash,
                destructive: true,
                onTap: () => _deleteAll(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.routeDataAttribution, style: const TextStyle(fontSize: 12, color: AppTheme.tertiaryText)),
        ],
      ),
    );
  }
}
