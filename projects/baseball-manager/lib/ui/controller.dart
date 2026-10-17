import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game.dart';
import '../game/life.dart';
import '../game/path.dart';
import '../game/player.dart';

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
    g.choose(a, focus);
    _commit();
  }

  void spend(Ability a) {
    if (game!.spend(a)) _commit();
  }

  void autoSpend() {
    game!.autoSpend();
    _commit();
  }

  void chooseEvent(int i) {
    game!.resolveEvent(i);
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
