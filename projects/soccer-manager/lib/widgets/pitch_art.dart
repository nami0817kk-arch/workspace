import 'package:flutter/material.dart';

/// 芝の描き方。スタメン画面(縦)と試合画面(横)の両方から呼ぶ。
///
/// ピッチは2か所で別々に描いている。スタメン画面は `CustomPainter`、試合画面は
/// Flame のコンポーネントで、土台が違うので widget を共有できない。**芝だけは
/// 見た目が揃っていないと別のゲームに見える**ので、`Canvas` を受け取る関数に
/// 切り出してここに集めている。ラインの引き方は画面ごとに違う(縦と横)ので、
/// それぞれの側に残してある。
class PitchArt {
  const PitchArt._();

  /// 芝の地の色。上を明るく、下を暗くして奥行きを作る。
  static const _turfTop = Color(0xFF368F3D);
  static const _turfBottom = Color(0xFF1F6227);

  /// ラインの色。
  static const line = Color(0xCCFFFFFF);

  /// 芝を敷く。[horizontalStripes] が真なら縞を横方向に引く(縦長のピッチ)。
  ///
  /// **縞を2色のベタ塗りにしない。** 以前は濃い緑と薄い緑を交互に置いて
  /// いたので、全体のグラデーションが縞に消され、平らな板に見えていた。
  /// 下地のグラデーションの上に、薄い白を重ねる形にすると両方残る。
  static void paintTurf(
    Canvas canvas,
    Size size, {
    required bool horizontalStripes,
    int stripes = 10,
  }) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_turfTop, _turfBottom],
        ).createShader(rect),
    );

    final band = (horizontalStripes ? size.height : size.width) / stripes;
    final stripe = Paint()..color = const Color(0x16FFFFFF);
    for (var i = 0; i < stripes; i += 2) {
      canvas.drawRect(
        horizontalStripes
            ? Rect.fromLTWH(0, band * i, size.width, band + 0.5)
            : Rect.fromLTWH(band * i, 0, band + 0.5, size.height),
        stripe,
      );
    }

    // 四隅を落とす。中央に目が行き、縁がにじんで見える。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.85,
          colors: [Color(0x00000000), Color(0x3A000000)],
          stops: [0.5, 1.0],
        ).createShader(rect),
    );
  }
}
