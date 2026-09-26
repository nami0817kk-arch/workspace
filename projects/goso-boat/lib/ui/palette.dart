import 'package:flutter/material.dart';

/// 色はここだけで決める。昼の川べりの明るい絵本調。
abstract final class Palette {
  static const skyTop = Color(0xFFD9F1FA);
  static const sky = Color(0xFFBFE6F5);
  static const sand = Color(0xFFF4DCA4);
  static const sandEdge = Color(0xFFE2C27F);
  static const grass = Color(0xFF6CC25A);
  static const grassDark = Color(0xFF4C9A3F);
  static const river = Color(0xFF3F9FEC);
  static const riverDeep = Color(0xFF2A82D4);
  static const ink = Color(0xFF1F2A44);
  static const dim = Color(0xFF5B6780);
  static const gold = Color(0xFFFFC83D);
  static const goldDeep = Color(0xFFC98A0C);
  static const bad = Color(0xFFE2463A);
  static const ok = Color(0xFF2E9D5B);
  static const card = Colors.white;
  static const starOff = Color(0xFFE7E2D4);
}

/// 太い縁取りの押せるボタン（絵本調の見た目をそろえるため自前で持つ）。
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Palette.card,
    this.shadow = Palette.ink,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadow;
  final double fontSize;
  final EdgeInsets padding;
  final IconData? icon;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = _down ? 1.0 : 3.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            margin: EdgeInsets.only(top: 3 - depth, bottom: depth),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.color,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: widget.shadow, offset: Offset(0, depth))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: widget.fontSize + 3, color: Palette.ink),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w800, color: Palette.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 星の列（★★☆）。
class StarRow extends StatelessWidget {
  const StarRow(this.stars, {super.key, this.size = 14, this.max = 3});
  final int stars;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Icon(Icons.star_rounded, size: size, color: i < stars ? Palette.gold : Palette.starOff),
        ],
      );
}
