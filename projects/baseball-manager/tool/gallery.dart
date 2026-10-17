// 絵の確認用: 全部の段階・季節・表情を一画面に並べる。
//
//   flutter build web --base-href / --no-web-resources-cdn -t tool/gallery.dart
//
// アプリ本体には入らない。見た目を変えたら、これで一通り見る。
import 'package:flutter/material.dart';

import 'package:baseball_manager/game/calendar.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/art/avatar.dart';
import 'package:baseball_manager/ui/art/career_chart.dart';
import 'package:baseball_manager/ui/art/radar.dart';
import 'package:baseball_manager/ui/art/scene.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/milestone_dialog.dart';

void main() => runApp(const _Gallery());

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final p = Player(
      name: 'ギャラリー',
      role: Role.batter,
      age: 22,
      potential: 70,
      abilities: {
        Ability.contact: 72,
        Ability.power: 58,
        Ability.speed: 44,
        Ability.fielding: 66,
        Ability.eye: 81,
      },
    );
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2E7D32), fontFamily: 'NotoSansJP'),
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in [Stage.youth, Stage.juniorHigh, Stage.highSchool, Stage.pathChoice, Stage.pro])
              Container(
                color: const Color(0xFFE8F5E9),
                child: PlayerAvatar(stage: s, role: s == Stage.pro ? Role.twoWay : Role.pitcher, mood: Mood.happy, height: 110),
              ),
            for (final m in Mood.values)
              Container(color: const Color(0xFFE8F5E9), child: PlayerAvatar(stage: Stage.highSchool, role: Role.batter, mood: m, height: 110)),
          ]),
          const SizedBox(height: 12),
          for (final s in Season.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SceneBanner(season: s, stage: Stage.highSchool, role: Role.batter, mood: Mood.happy, label: s.name),
            ),
          AbilityRadar(player: p),
          CareerChart(history: [10, 14, 19, 25, 28, 33, 38, 43, 47, 52, 55, 58, 62, 65, 70, 74, 79, 83, 81, 78, 75, 70, 66], proStartAge: 19),
          const SizedBox(height: 12),
          const SizedBox(
            height: 330,
            child: MilestoneDialog(milestone: Milestone(MilestoneKind.draft, 'ドラフト指名!', 'ギャラリーは、プロの世界へ飛び込む。')),
          ),
        ]),
      ),
    );
  }
}
