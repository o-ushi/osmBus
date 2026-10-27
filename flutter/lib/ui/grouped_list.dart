import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// iOS の inset grouped セクション。
class GroupedSection extends StatelessWidget {
  const GroupedSection({super.key, this.title, required this.children, this.footer});

  final String? title;
  final List<Widget> children;

  /// セクションの下の説明。
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, title == null ? 0 : 6),
          child: title == null
              ? null
              : Text(title!.toUpperCase(), style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(indent: 16, height: 0.5),
                child,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(footer!, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
          ),
      ],
    );
  }
}

/// 選択肢の行。選ばれていれば右にチェック（Swift の設定の言語・並び順の行）。
class GroupedChoiceRow extends StatelessWidget {
  const GroupedChoiceRow({super.key, required this.title, required this.selected, required this.onTap});

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      title: title,
      bold: selected,
      onTap: onTap,
      trailing: selected ? const Icon(CupertinoIcons.checkmark_alt, color: AppTheme.accent, size: 20) : null,
    );
  }
}

/// 別の画面へ進む行（右に ›）。
class GroupedLinkRow extends StatelessWidget {
  const GroupedLinkRow({super.key, required this.title, required this.onTap, this.leading, this.value});

  final String title;
  final VoidCallback onTap;
  final IconData? leading;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      title: title,
      leading: leading,
      leadingColor: AppTheme.accent,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!, style: const TextStyle(fontSize: 17, color: AppTheme.secondaryText)),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_forward, size: 16, color: AppTheme.tertiaryText),
        ],
      ),
    );
  }
}

class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.bold = false,
    this.leadingColor,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.action = false,
    this.destructive = false,
    this.muted = false,
    this.enabled = true,
  });

  final String title;
  final bool bold;
  final Color? leadingColor;
  final String? subtitle;
  final Widget? trailing;
  final IconData? leading;
  final VoidCallback? onTap;
  final bool action;
  final bool destructive;
  final bool muted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppTheme.tertiaryText
        : destructive
            ? CupertinoColors.destructiveRed
            : action
                ? AppTheme.accent
                : muted
                    ? AppTheme.secondaryText
                    : Colors.black;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 20, color: enabled ? leadingColor ?? color : color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 17, color: color, fontWeight: bold ? FontWeight.w600 : null),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
