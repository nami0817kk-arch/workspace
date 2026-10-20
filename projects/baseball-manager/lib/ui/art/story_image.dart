import 'package:flutter/material.dart';

import '../../game/career.dart';

/// 画像素材(`assets/images/`)を、16:9 の角丸で見せる。読み込めなければ `fallback` を出す。
/// 素材は Gemini で作ったイラスト(人物は後ろ姿・文字や実在のロゴ・チームの意匠は無し)。
class StoryImage extends StatelessWidget {
  const StoryImage({
    super.key,
    required this.asset,
    required this.semanticLabel,
    required this.fallback,
  });

  final String asset;
  final String semanticLabel;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

/// 同梱の絵のパス。
const homeHeroAsset = 'assets/images/home_hero.jpg';
const retireImageAsset = 'assets/images/ending_retire.jpg';
const draftImageAsset = 'assets/images/ms_draft.jpg';
const championImageAsset = 'assets/images/ms_champion.jpg';

/// 段階ごとの背景の絵(育成画面の見出し)。段階が変わると、背景も変わる。
String backdropAssetOf(Stage s) => switch (s) {
      Stage.youth => 'assets/images/bg_youth.jpg',
      Stage.juniorHigh => 'assets/images/bg_junior.jpg',
      Stage.highSchool => 'assets/images/bg_high.jpg',
      Stage.pathChoice => 'assets/images/bg_college.jpg',
      Stage.pro || Stage.retired => 'assets/images/bg_pro.jpg',
    };
