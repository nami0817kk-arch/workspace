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

// 2026-11-03 に足した節目の絵(Gemini で作り、900x502 にそろえた。人物・文字なし)
const titleImageAsset = 'assets/images/ms_title.jpg';
const nationalImageAsset = 'assets/images/ms_national.jpg';
const worldImageAsset = 'assets/images/ms_world.jpg';
const stageImageAsset = 'assets/images/ms_stage.jpg';
const traitImageAsset = 'assets/images/ms_trait.jpg';

// 2026-11-03 夜に足した節目の絵(Gemini。選手は後ろ姿・文字やロゴなし。1280x720)
const firstTeamImageAsset = 'assets/images/ms_firstteam.jpg';
const overseasImageAsset = 'assets/images/ms_overseas.jpg';
const missionImageAsset = 'assets/images/ms_mission.jpg';

// 山場の出来事の絵(2026-11-03 夜。Gemini。選手は後ろ姿・文字やロゴなし)
const finalMomentImageAsset = 'assets/images/ev_final.jpg';
const tryoutImageAsset = 'assets/images/ev_tryout.jpg';

/// 出来事の札に添える絵と、読み上げの説明。山場(決勝の見せ場・戦力外通告)だけ。
(String, String)? eventImageOf(String id) => switch (id) {
      'final-moment' => (
          finalMomentImageAsset,
          '夕暮れの満員の球場。マウンドの投手が帽子のつばに手をやり、打者と向き合う'
        ),
      'tryout' => (
          tryoutImageAsset,
          '冬の夕方、誰もいない球場のスタンドにひとり座る選手の後ろ姿。足元にバッグとグローブ'
        ),
      _ => null,
    };

/// 段階ごとの背景の絵(育成画面の見出し)。段階が変わると、背景も変わる。
String backdropAssetOf(Stage s) => switch (s) {
      Stage.youth => 'assets/images/bg_youth.jpg',
      Stage.juniorHigh => 'assets/images/bg_junior.jpg',
      Stage.highSchool => 'assets/images/bg_high.jpg',
      Stage.pathChoice => 'assets/images/bg_college.jpg',
      Stage.pro || Stage.retired => 'assets/images/bg_pro.jpg',
    };
