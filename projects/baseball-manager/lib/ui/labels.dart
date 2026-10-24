import 'package:flutter/material.dart';

import '../game/flavor.dart';

import '../game/career.dart';
import '../game/exp.dart';
import '../game/life.dart';
import '../game/player.dart';
import '../game/traits.dart';

/// 画面に出す日本語。ゲームのロジックは名前を持たないので、ここに集める。
String abilityLabel(Ability a) => switch (a) {
      Ability.contact => 'ミート',
      Ability.power => 'パワー',
      Ability.speed => '走力',
      Ability.fielding => '守備',
      Ability.eye => '選球眼',
      Ability.stuff => '球威',
      Ability.control => '制球',
      Ability.stamina => 'スタミナ',
    };

/// 能力が何に効くかの説明(ラベルの長押し・タップで出す)。
String abilityHint(Ability a) => switch (a) {
      Ability.contact => 'ミート: 球に当てる力。ヒットが出やすくなる。',
      Ability.power => 'パワー: 長打・ホームランの出やすさ。',
      Ability.speed => '走力: 足の速さ。二塁打・三塁打に効く。',
      Ability.fielding => '守備: 捕って投げる力。',
      Ability.eye => '選球眼: 球を見きわめる力。四球が増える。',
      Ability.stuff => '球威: 球の威力。三振が増え、打たれにくくなる。',
      Ability.control => '制球: 狙ったところへ投げる力。四球が減る。',
      Ability.stamina => 'スタミナ: 長く投げられる。疲れにくくもなる。',
    };

String roleLabel(Role r) => switch (r) {
      Role.batter => '打者',
      Role.pitcher => '投手',
      Role.twoWay => '二刀流',
    };

String stageLabel(Stage s) => switch (s) {
      Stage.youth => '少年野球',
      Stage.juniorHigh => '中学',
      Stage.highSchool => '高校',
      Stage.pathChoice => '進路(大学・社会人)',
      Stage.pro => 'プロ',
      Stage.retired => '引退',
    };

String actionLabel(Plan a) => switch (a) {
      Plan.train => '練習',
      Plan.special => '特訓',
      Plan.rest => '休養',
      Plan.study => '研究',
      Plan.social => '交流',
      Plan.match => '練習試合',
      Plan.lesson => 'コーチに教わる',
    };

/// 重点の能力に合わせた、練習の名前。「練習」なら素振りやノックなど、具体的な内容になる。
String planTitle(Plan a, Ability focus) => switch (a) {
      Plan.train => trainingMenu(focus),
      Plan.special => '特訓: ${trainingMenu(focus)}',
      _ => actionLabel(a),
    };

/// 重点の能力に合わせた、ひとこと。
String planHint(Plan a, Ability focus) => switch (a) {
      Plan.train => '${abilityLabel(focus)}の経験点が安定して貯まる',
      Plan.special => '${abilityLabel(focus)}がたくさん貯まり、調子が良いと特殊能力のコツ。疲れて怪我しやすい',
      _ => actionHint(a),
    };

String actionHint(Plan a) => switch (a) {
      Plan.train => '重点の経験点が安定して貯まる',
      Plan.special => 'たくさん貯まり、調子が良いと特殊能力のコツ。疲れて怪我しやすい',
      Plan.rest => '疲れを取る',
      Plan.study => '特殊能力のコツ+2(安く取れるようになる)。経験点はわずか',
      Plan.social => 'やる気が上がり、仲間から特殊能力のコツ。家族・恋人との絆',
      Plan.match => '全体に少し貯まり、勝負どころの特殊能力のコツ',
      Plan.lesson => 'コーチのコツが貯まる(4回で特殊能力を習得)',
    };

String categoryLabel(Category c) => c.label;

/// 能力値のランク(G〜S)。パワプロのように、数字より先にランクで強さが分かる。
String rankOf(int v) {
  if (v >= 90) return 'S';
  if (v >= 80) return 'A';
  if (v >= 70) return 'B';
  if (v >= 60) return 'C';
  if (v >= 50) return 'D';
  if (v >= 40) return 'E';
  if (v >= 30) return 'F';
  return 'G';
}

/// 生まれ持った才能の知らせ(新しく始めたときの「いまの結果」に出す)。
/// レア特性か、天賦が最大(+2)・最小(-2)の能力があるときだけ。無ければ空。
List<String> birthTalentNotes(Player p) {
  final lines = <String>[];
  for (final t in p.traits.where((t) => t.rare)) {
    lines.add('レア特性「${t.label}」を持って生まれた!');
  }
  final top = [
    for (final a in abilitiesOf(p.role))
      if (p.gift(a) >= 2) abilityLabel(a)
  ];
  final low = [
    for (final a in abilitiesOf(p.role))
      if (p.gift(a) <= -2) abilityLabel(a)
  ];
  if (top.isNotEmpty) lines.add('天賦の才: ${top.join('・')}(経験点が少なくて済む)');
  if (low.isNotEmpty) lines.add('不得手: ${low.join('・')}(経験点が多く要る)');
  return lines;
}

/// 特性のアイコンの色。レアは赤みの金、良いものは金、代償のあるものは灰青。
Color traitIconColor(Trait t) => t.rare
    ? const Color(0xFFD84315)
    : (t.positive ? const Color(0xFFF9A825) : const Color(0xFF607D8B));

/// 特性チップの背景色(明るい色。文字は暗い色で読める)。
Color traitChipColor(Trait t) => t.rare
    ? const Color(0xFFFFCCBC)
    : (t.positive ? Colors.amber.shade100 : Colors.blueGrey.shade100);

Color rankColor(String rank) => switch (rank) {
      'S' => const Color(0xFFE53935),
      'A' => const Color(0xFFFB8C00),
      'B' => const Color(0xFFFDD835),
      'C' => const Color(0xFF7CB342),
      'D' => const Color(0xFF26A69A),
      'E' => const Color(0xFF42A5F5),
      'F' => const Color(0xFF7986CB),
      _ => const Color(0xFF9E9E9E),
    };

/// 同梱の日本語フォント。`CustomPaint` の文字は Theme を引き継がないので、明示する。
const kFont = 'NotoSansJP';
