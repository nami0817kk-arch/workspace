// 画面確認用の入り口（アプリには入らない）。CI の web_preview が、写しの lib/main.dart をこれに差し替えて Web 版を作る。
// 何も付けなければ普段どおり。
// ?auto=<種> で、その種の人生を最後まで自動で選んで終わりの画面を出す。
// ?auto=<種>&stop=<歳> で、その歳の「今年の重点」で止める（遊ぶ画面を見る用）。
// ?auto=<seed> で、その種の人生を最後まで自動で選んで終わりの画面を出す。
// ?minage=15 で、15歳を超えて生きた人生が出るまで引き直す。
import 'package:flutter/material.dart';

import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/rng.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final auto = int.tryParse(q['auto'] ?? '');
  if (auto == null) {
    runApp(const RanseApp());
    return;
  }
  final minAge = int.tryParse(q['minage'] ?? '') ?? 0;
  final stop = int.tryParse(q['stop'] ?? '');
  final c = AppController(rng: Rng(auto));
  final pick = Rng(auto + 1);
  for (var tries = 0; tries < 200; tries++) {
    c.birth = rollBirth(c.rng);
    c.begin();
    var n = 0;
    while (!c.game.finished && n++ < 3000) {
      if (stop != null &&
          c.game.age >= stop &&
          c.game.prompt?.title == '今年の重点') {
        break;
      }
      c.game.choose(pick.range(0, c.game.prompt!.choices.length - 1));
    }
    if (stop != null ? !c.game.finished : c.game.age >= minAge) break;
  }
  runApp(RanseApp(controller: c));
}
