import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/exp.dart';
import '../game/game.dart';
import '../game/life.dart';
import '../game/path.dart';
import '../game/player.dart';
import 'labels.dart';

const saveKey = 'baseball_manager_save_v1';

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

  Future<void> save(Map<String, dynamic> json) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(saveKey, jsonEncode(json));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(saveKey);
    } catch (_) {}
  }
}

/// 画面とゲームをつなぐ。操作のたびに保存する。
class GameController extends ChangeNotifier {
  GameController({SaveStore? store, Random? rng})
      : store = store ?? SaveStore(),
        _rng = rng ?? Random();

  final SaveStore store;
  final Random _rng;
  Game? game;

  /// 直前の操作で増えた記録(画面の「いまの結果」に出す)。
  List<String> recent = const [];

  /// いま重点にしている能力。
  Ability focus = Ability.contact;

  Future<bool> loadSaved() async {
    final j = await store.load();
    if (j == null) return false;
    try {
      game = Game.fromJson(j, _rng);
      focus = abilitiesOf(game!.player.role).first;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void newGame(String name, Role role) {
    game = Game.newGame(name: name.trim().isEmpty ? '名無し' : name.trim(), role: role, rng: _rng);
    recent = const [];
    focus = abilitiesOf(role).first;
    _commit();
  }

  /// 進行中のゲームを差し込む(続きから・テスト用)。
  void adopt(Game g) {
    game = g;
    focus = abilitiesOf(g.player.role).first;
    notifyListeners();
  }

  void setFocus(Ability a) {
    focus = a;
    notifyListeners();
  }

  void act(Plan a) {
    final g = game!;
    if (!abilitiesOf(g.player.role).contains(focus)) {
      focus = abilitiesOf(g.player.role).first;
    }
    final start = g.log.length;
    g.choose(a, focus);
    recent = [_summary(a, g), ...g.log.sublist(start)];
    _commit();
  }

  /// 「練習: 打撃経験点 +25 / …」のような、直前のターンの一行まとめ。
  String _summary(Plan a, Game g) {
    final gains = [
      for (final c in Category.values)
        if ((g.lastGain[c] ?? 0) > 0) '${c.label}経験点 +${g.lastGain[c]}',
    ];
    return gains.isEmpty ? '${actionLabel(a)}した' : '${actionLabel(a)}: ${gains.join(' / ')}';
  }

  void spend(Ability a) {
    if (game!.spend(a)) _commit();
  }

  void autoSpend() {
    game!.autoSpend();
    _commit();
  }

  void chooseEvent(int i) {
    final start = game!.log.length;
    game!.resolveEvent(i);
    recent = game!.log.sublist(start);
    _commit();
  }

  void chooseRoute(Course r) {
    game!.chooseRoute(r);
    _commit();
  }

  void giveUp() {
    game!.giveUp();
    _commit();
  }

  void retire() {
    game!.retire();
    _commit();
  }

  void changeRole(Role r) {
    game!.changeRole(r);
    if (!abilitiesOf(r).contains(focus)) focus = abilitiesOf(r).first;
    _commit();
  }

  Future<void> reset() async {
    game = null;
    await store.clear();
    notifyListeners();
  }

  void _commit() {
    notifyListeners();
    final g = game;
    if (g != null) store.save(g.toJson());
  }
}
