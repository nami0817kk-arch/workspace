import 'package:flutter/material.dart';

/// 横画面のとき、画面全体を少し小さく描く(バスケGM と同じ作り)。
///
/// 844 幅のスマホを約 993 幅の画面として組み、0.85 倍に縮めて映す。同じ画面に
/// 入る行と列が増え、表や札が窮屈にならず、一覧で縦にスクロールする量も減る。
/// 縦画面と、幅が狭い端末ではそのまま描く。
///
/// 縮めるのは描画だけで、文字の大きさの設定(textScaler)はそのまま効く。
class LandscapeScale extends StatelessWidget {
  const LandscapeScale({super.key, required this.child});

  final Widget child;

  /// 組むときの基準の幅(スマホの横画面の標準)。
  static const designWidth = 844.0;

  /// スマホ(844 幅)での描く倍率。
  static const uiScale = 0.85;

  /// 小さいスマホ(667 幅)でも、これより小さくはしない(字が読めなくなる)。
  static const minScale = 0.8;

  /// 画面の大きさから、描く倍率を決める。1 なら縮めない。
  static double scaleFor(Size size) {
    if (size.width <= size.height) return 1;
    return (size.width / (designWidth / uiScale)).clamp(minScale, 1.8);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = scaleFor(mq.size);
    if ((scale - 1).abs() < 0.001) return child;
    final size = mq.size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
