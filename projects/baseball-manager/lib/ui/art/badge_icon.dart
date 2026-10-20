import 'package:flutter/material.dart';

import '../../game/life.dart';

/// 丸いバッジのアイコン(`assets/icons/`)。読み込めなければ `fallback` を出す。
/// 素材は Gemini で作ったイラスト(文字・ロゴ無し)を、円形に切って小さくしたもの。
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({
    super.key,
    required this.asset,
    required this.size,
    required this.fallback,
    this.dim = false,
  });

  final String asset;
  final double size;
  final Widget fallback;

  /// 選ばれていない状態(少し薄くする)。
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback,
    );
    return dim ? Opacity(opacity: 0.6, child: image) : image;
  }
}

/// 行動(練習・特訓…)のバッジ絵。
String planBadgeAsset(Plan a) => switch (a) {
      Plan.train => 'assets/icons/plan_train.png',
      Plan.special => 'assets/icons/plan_special.png',
      Plan.rest => 'assets/icons/plan_rest.png',
      Plan.study => 'assets/icons/plan_study.png',
      Plan.social => 'assets/icons/plan_social.png',
      Plan.match => 'assets/icons/plan_match.png',
      Plan.lesson => 'assets/icons/plan_lesson.png',
    };

const autoYearBadgeAsset = 'assets/icons/plan_auto.png';

/// 下のタブ(育成・能力・キャリア・関係)のバッジ絵。
const tabBadgeAssets = <String>[
  'assets/icons/tab_train.png',
  'assets/icons/tab_ability.png',
  'assets/icons/tab_career.png',
  'assets/icons/tab_cast.png',
];
