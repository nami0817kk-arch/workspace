import 'package:flutter/material.dart';

import '../game/career.dart';
import '../game/exp.dart';
import '../game/life.dart';
import '../game/player.dart';

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

String actionHint(Plan a) => switch (a) {
      Plan.train => '重点の経験点が貯まる',
      Plan.special => 'たくさん貯まる。疲れて怪我しやすい',
      Plan.rest => '疲れを取る',
      Plan.study => '気持ちが上がり、少し貯まる',
      Plan.social => '気持ちが上がる。家族・恋人との絆',
      Plan.match => '全体に少し貯まる',
      Plan.lesson => 'コツが貯まる(4回で特性を習得)',
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
