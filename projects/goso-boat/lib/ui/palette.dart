import 'package:flutter/material.dart';

import '../app/settings.dart';

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

/// 舞台ごとの時間帯（昼 → 午後 → 夕方 → 夕暮れ → 夜）。進んでいる実感を出す。
class SceneTheme {
  const SceneTheme({
    required this.background,
    required this.sand,
    required this.sandEdge,
    required this.grass,
    required this.grassDark,
    required this.river,
    required this.riverDeep,
    this.wave = 0.45,
    this.stars = false,
  });

  /// 画面の地の色（上の見出しの字は Palette.ink なので、明るめに保つ）。
  final Color background;
  final Color sand;
  final Color sandEdge;
  final Color grass;
  final Color grassDark;
  final Color river;
  final Color riverDeep;
  final double wave;

  /// 川面に星を映す（夜だけ）。
  final bool stars;

  static const day = SceneTheme(
    background: Palette.sky, sand: Palette.sand, sandEdge: Palette.sandEdge,
    grass: Palette.grass, grassDark: Palette.grassDark, river: Palette.river, riverDeep: Palette.riverDeep,
  );
  static const afternoon = SceneTheme(
    background: Color(0xFFCDE7EE), sand: Color(0xFFF2D49A), sandEdge: Color(0xFFDDB872),
    grass: Color(0xFF7CC152), grassDark: Color(0xFF58973D), river: Color(0xFF3A9AD9), riverDeep: Color(0xFF2677C2),
  );
  static const evening = SceneTheme(
    background: Color(0xFFF7DDC4), sand: Color(0xFFF0C48E), sandEdge: Color(0xFFD9A263),
    grass: Color(0xFF8FB85A), grassDark: Color(0xFF6A9142), river: Color(0xFF4A86C8), riverDeep: Color(0xFF2F5FA6), wave: 0.4,
  );
  static const dusk = SceneTheme(
    background: Color(0xFFE3D6EE), sand: Color(0xFFD9B98F), sandEdge: Color(0xFFBC9A6E),
    grass: Color(0xFF5E9A5C), grassDark: Color(0xFF437646), river: Color(0xFF4B6FB5), riverDeep: Color(0xFF33477F), wave: 0.35,
  );
  static const night = SceneTheme(
    background: Color(0xFFC9D2EA), sand: Color(0xFFB9A58A), sandEdge: Color(0xFF9A876D),
    grass: Color(0xFF3E6B4A), grassDark: Color(0xFF2B4F36), river: Color(0xFF26406E), riverDeep: Color(0xFF16294D), wave: 0.3, stars: true,
  );

  static SceneTheme forWorld(int world) => switch (world) {
        1 || 2 => day,
        3 || 4 => afternoon,
        5 => evening,
        6 || 7 => dusk,
        _ => night,
      };
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
    this.silent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadow;
  final double fontSize;
  final EdgeInsets padding;
  final IconData? icon;

  /// タップ音を鳴らさない（押したあとに別の音を鳴らすボタン用）。
  final bool silent;

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
                if (!widget.silent) AppScope.maybeOf(context)?.play(Sfx.tap);
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
