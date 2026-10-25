import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Swift 版 `AppTheme` / `BusCardBackground` / `SceneBackgroundLayer` と同じ見た目。
abstract final class AppTheme {
  static const brandBlue = Color.fromRGBO(61, 89, 147, 1);
  static const sceneLight = Color.fromRGBO(253, 252, 240, 1);
  static const accent = Color(0xFF007AFF);
  static const cardFill = Color.fromRGBO(255, 250, 242, 1);
  static const cardBorder = Color.fromRGBO(245, 199, 153, 1);
  static const cardAccentStrip = Color.fromRGBO(255, 153, 51, 1);
  static const verdictYellow = Color.fromRGBO(219, 158, 10, 1);
  static const verdictGreen = Color(0xFF248A3D);
  static const verdictRed = Color(0xFFD70015);
  static const secondaryText = Color(0x993C3C43);
  static const tertiaryText = Color(0x4D3C3C43);
  static const groupedBackground = Color(0xFFF2F2F7);

  static const double cornerRadius = 14;
  static const double keypadCornerRadius = 12;
  static const double screenPadding = 14;
  static const double cardPaddingH = 12;
  static const double sectionSpacing = 12;
  static const double locationRowHeight = 56;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: accent).copyWith(primary: accent);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: sceneLight,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: accent,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x333C3C43), thickness: 0.5, space: 0.5),
    );
  }
}

/// オレンジ枠と左のアクセント帯のカード。
class BusCard extends StatelessWidget {
  const BusCard({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 10,
            bottom: 10,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardAccentStrip,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// シーン色＋方眼ドット。
class SceneBackground extends StatelessWidget {
  const SceneBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.sceneLight,
      child: CustomPaint(painter: _PaperGridPainter(), size: Size.infinite),
    );
  }
}

class _PaperGridPainter extends CustomPainter {
  const _PaperGridPainter();

  static const double step = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color.fromRGBO(140, 115, 71, 0.12)
      ..strokeWidth = 0.45;
    for (var x = 0.0; x <= size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y <= size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final dot = Paint()..color = const Color.fromRGBO(51, 140, 89, 0.09);
    for (var y = 0.0; y <= size.height + step; y += step) {
      for (var x = 0.0; x <= size.width + step; x += step) {
        canvas.drawCircle(Offset(x, y), 0.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// バス番号のバッジ。乗車中の番号はオレンジ。
class BusBadge extends StatelessWidget {
  const BusBadge({
    super.key,
    required this.text,
    this.riding = false,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  });

  final String text;
  final bool riding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: riding ? Colors.orange : AppTheme.brandBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            maxLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// 押すと少し縮むボタン（Swift の `KeypadButtonStyle`）。
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 距離欄の色帯（3km / 1km / 500m / 200m）。
abstract final class DistanceColorBand {
  static (Color background, Color text) colors(double meters) {
    if (meters >= 3000) return (Colors.blue, Colors.white);
    if (meters >= 1000) return (Colors.green, Colors.white);
    if (meters >= 500) return (Colors.yellow, Colors.black);
    if (meters >= 200) return (Colors.orange, Colors.black);
    return (Colors.red, Colors.white);
  }

  /// 10 km 以上は小数を落とす。
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }
}
