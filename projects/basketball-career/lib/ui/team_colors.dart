import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/season.dart';

/// チームの色。`sprite` は選手の絵の色名(`assets/art/players/<絵>_<色名>.png`)、
/// `jersey` はコードで描くときのユニフォームの色、`accent` は画面の差し色(白い字が読める濃さ)。
enum TeamColor {
  blue('blue', Color(0xFF1565C0), Color(0xFF1565C0)),
  yellow('yellow', Color(0xFFF9A825), Color(0xFFB26A00)),
  red('red', Color(0xFFC62828), Color(0xFFC62828)),
  green('green', Color(0xFF2E7D32), Color(0xFF2E7D32)),
  teal('teal', Color(0xFF00838F), Color(0xFF00838F)),
  purple('purple', Color(0xFF6A1B9A), Color(0xFF6A1B9A)),
  orange('orange', Color(0xFFEF6C00), Color(0xFFE65100)),
  pink('pink', Color(0xFFD81B60), Color(0xFFC2185B)),
  sky('sky', Color(0xFF29B6F6), Color(0xFF0277BD)),
  lime('lime', Color(0xFF7CB342), Color(0xFF558B2F)),
  navy('navy', Color(0xFF283593), Color(0xFF283593));

  const TeamColor(this.sprite, this.jersey, this.accent);
  final String sprite;
  final Color jersey;
  final Color accent;
}

/// チーム名の頭(地名)ごとの色。名前の字から連想する色にした。
const teamPrefixColors = <String, TeamColor>{
  '北嶺': TeamColor.navy,
  '南陽': TeamColor.yellow,
  '東雲': TeamColor.purple,
  '西浜': TeamColor.sky,
  '青葉': TeamColor.lime,
  '白鷺': TeamColor.blue,
  '紅葉': TeamColor.red,
  '朝日': TeamColor.orange,
  '双葉': TeamColor.green,
  '桜台': TeamColor.pink,
  '星丘': TeamColor.navy,
  '翠山': TeamColor.green,
  '蒼海': TeamColor.blue,
  '大和': TeamColor.purple,
  '緑風': TeamColor.teal,
};

/// 段階ごとの色(チーム名が無い古いセーブ・知らない名前のとき)。代表は青。
TeamColor stageColor(League l) => switch (l) {
      League.minibasket => TeamColor.yellow,
      League.juniorHigh || League.national => TeamColor.blue,
      League.highSchool => TeamColor.red,
      League.university => TeamColor.green,
      League.corporate => TeamColor.teal,
      League.proDomestic || League.proAbroad => TeamColor.purple,
    };

/// そのチームの色。代表戦は代表の青。
TeamColor teamColorOf(String team, League league) {
  if (league == League.national) return TeamColor.blue;
  for (final e in teamPrefixColors.entries) {
    if (team.startsWith(e.key)) return e.value;
  }
  return stageColor(league);
}

/// いまの所属の色(代表戦の前は代表の青)。
TeamColor teamColorOfGame(Game g) {
  final national = g.nationalPending && g.slot == 3 && g.track == Track.pro;
  return teamColorOf(g.teamName, national ? League.national : g.league);
}

/// 相手の色。名前から決め、こちらと同じ色にはしない。
TeamColor opponentColor(String name, TeamColor ours) {
  final all = TeamColor.values;
  var i = name.codeUnits.fold(0, (s, c) => (s * 31 + c) & 0x7fffffff) % all.length;
  if (all[i] == ours) i = (i + 1) % all.length;
  return all[i];
}
