import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game.dart';
import '../game/life.dart';
import '../game/match.dart';
import '../game/path.dart';
import '../game/player.dart';
import 'labels.dart';

const saveKey = 'basketball_career_save_v1';

/// セーブの読み書き。端末ごと(クラウド同期はしない)。
class SaveStore {
  Future<Map<String, dynamic>?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(saveKey);
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null; // 壊れたセーブは無いものとして扱う
    }
  }

  // 書き込みは順番に行う。操作が速いと古い状態が後から書かれて、新しい方を上書きしてしまう。
  Future<void> _tail = Future.value();

  Future<void> save(Map<String, dynamic> json) {
    final text = jsonEncode(json); // 呼んだ時点の状態を固める
    return _tail = _tail.then((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(saveKey, text);
      } catch (_) {}
    });
  }

  Future<void> clear() {
    return _tail = _tail.then((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove(saveKey);
      } catch (_) {}
    });
  }
}

/// 今のおすすめ。怪我・疲れていれば休養、気持ちが沈んでいれば交流、それ以外は練習。
Action recommendedAction(Game g) {
  final c = g.condition;
  if (c.injured || c.fatigue >= 70) return Action.rest;
  if (c.morale < 35) return Action.social;
  return Action.practice;
}

/// 画面とゲームをつなぐ。操作のたびに保存する。
class GameController extends ChangeNotifier {
  GameController({SaveStore? store, Random? rng})
      : store = store ?? SaveStore(),
        _rng = rng ?? Random();

  final SaveStore store;
  final Random _rng;
  Game? game;

  /// いま重点にしている能力。
  Ability focus = Ability.threePoint;

  /// 勝負どころの方針。null なら成功率の高いプレーを自動で選ぶ。
  Clutch? clutchPolicy;

  /// 直前の操作で起きたこと(画面の「いまの結果」に出す)。
  List<String> recent = const [];

  /// 直前の進路選択の結果メッセージ。
  String? pathMessage;

  Future<bool> loadSaved() async {
    final j = await store.load();
    if (j == null) return false;
    try {
      game = Game.fromJson(j, rng: _rng);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void newGame(String name) {
    final n = name.trim().isEmpty ? '名無し' : name.trim();
    game = Game.start(n, rng: _rng);
    recent = const [];
    pathMessage = null;
    _commit();
  }

  void setFocus(Ability a) {
    focus = a;
    notifyListeners();
  }

  void setClutchPolicy(Clutch? c) {
    clutchPolicy = c;
    notifyListeners();
  }

  /// 過ごし方を1つ選んで季節を進める。
  void act(Action a) {
    final g = game!;
    final ageBefore = g.player.age;
    final r = g.choose(
      a,
      focus,
      chooseClutch: clutchPolicy == null ? null : (_) => clutchPolicy!,
    );
    final lines = <String>['${a.label}した。'];
    if (r.gotInjured) lines.add('怪我をしてしまった…');
    if (r.satOut) lines.add('怪我で大会に出られなかった。');
    final t = r.tournament;
    if (t != null) {
      lines.add('【${leagueLabel(t.league)}の大会】${t.wins}勝${t.games - t.wins}敗'
          '${t.champion ? ' 優勝!' : ''}  実績 ${t.achievement.round()}(${achievementWord(t.achievement)})');
      for (var i = 0; i < t.matches.length; i++) {
        final m = t.matches[i];
        lines.add(matchLine(i, m.won, m.teamScore, m.oppScore, m.points,
            m.rebounds, m.assists,
            clutch: m.clutch == null
                ? null
                : '${m.clutch!.label}${m.clutchSuccess == true ? '成功' : '失敗'}'));
      }
    }
    if (r.yearEnded && g.player.age != ageBefore) {
      lines.add('${g.player.age}歳になった。身長 ${g.player.heightCm.toStringAsFixed(1)}cm。');
    }
    recent = lines;
    pathMessage = null;
    _commit();
  }

  /// おすすめの過ごし方で、今年(年が変わるまで)を進める。
  void autoYear() {
    final g = game;
    if (g == null) return;
    final age = g.player.age;
    final lines = <String>[];
    while (g.phase == Phase.season && g.player.age == age) {
      act(recommendedAction(g));
      lines.addAll(recent.skip(1));
    }
    recent = ['おすすめの過ごし方で1年進めた。', ...lines];
    notifyListeners();
  }

  void chooseRoute(Route r) {
    final g = game!;
    final ok = g.chooseRoute(r);
    pathMessage = switch ((r, ok)) {
      (Route.pro, true) => 'プロ契約を勝ち取った!',
      (Route.pro, false) => g.retired
          ? 'プロ契約には届かなかった…'
          : 'プロ契約には届かなかった。大学か実業団で力をつけよう。',
      (Route.university, _) => '大学へ進んだ。4年間で力をつけよう。',
      (Route.corporate, _) => '実業団に入った。3年間で力をつけよう。',
    };
    recent = const [];
    _commit();
  }

  void giveUp() {
    game!.giveUp();
    _commit();
  }

  void goAbroad() {
    game!.goAbroad();
    recent = ['海外挑戦を決めた。相手は格段に強い。'];
    _commit();
  }

  void retire() {
    game!.retire();
    _commit();
  }

  /// 引退後、新しく始める。
  Future<void> reset() async {
    game = null;
    recent = const [];
    pathMessage = null;
    await store.clear();
    notifyListeners();
  }

  void _commit() {
    notifyListeners();
    final g = game;
    if (g != null) store.save(g.toJson());
  }
}
