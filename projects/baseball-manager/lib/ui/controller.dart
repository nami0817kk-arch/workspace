import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/exp.dart';
import '../game/career.dart';
import '../game/game.dart';
import '../game/life.dart';
import '../game/path.dart';
import '../game/player.dart';
import 'history.dart';
import 'labels.dart';

const saveKey = 'baseball_manager_save_v1';
const historyKey = 'baseball_manager_history_v1';

enum MilestoneKind { draft, champion, trait, stage }

/// 人生の節目。ダイアログで大きく見せる。
class Milestone {
  const Milestone(this.kind, this.title, this.body);
  final MilestoneKind kind;
  final String title;
  final String body;
}

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

  Future<List<HistoryEntry>> loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(historyKey);
      if (s == null) return [];
      return [
        for (final e in jsonDecode(s) as List) HistoryEntry.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> h) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(historyKey, jsonEncode([for (final e in h) e.toJson()]));
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

  /// まだ見せていない節目。画面が1つずつ取り出して見せる。
  final List<Milestone> pending = [];

  /// 直前の操作で増えた記録(画面の「いまの結果」に出す)。
  List<String> recent = const [];

  /// いま重点にしている能力。
  Ability focus = Ability.contact;

  /// 殿堂(過去の選手)。新しい順。
  List<HistoryEntry> history = const [];

  Future<bool> loadSaved() async {
    history = await store.loadHistory();
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
    final before = g.stage;
    g.choose(a, focus);
    recent = [_summary(a, g), ...g.log.sublist(start)];
    _detect(before, g, g.log.sublist(start));
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

  /// 今回のできごとから、見せる価値のある節目を拾う。
  void _detect(Stage before, Game g, List<String> lines) {
    final name = g.player.name;
    if (lines.any((l) => l.contains('ドラフトで指名された'))) {
      pending.add(Milestone(MilestoneKind.draft, 'ドラフト指名!', '$nameは、プロの世界へ飛び込む。'));
    }
    final after = g.stage;
    if (after != before && g.phase != Phase.retired && after != Stage.pro && after != Stage.pathChoice) {
      pending.add(Milestone(MilestoneKind.stage, '${stageLabel(after)}へ',
          '${g.player.age}歳。新しい仲間とコーチが待っている。'));
    }
    if (lines.any((l) => l.contains('優勝'))) {
      pending.add(Milestone(MilestoneKind.champion, '優勝!', '夏の大会を制した。'));
    }
    for (final l in lines.where((l) => l.contains('を習得'))) {
      pending.add(Milestone(MilestoneKind.trait, 'コツをつかんだ!', l));
    }
  }

  /// 見せ終わった節目を1つ取り除く。
  void dismissMilestone() {
    if (pending.isNotEmpty) pending.removeAt(0);
    notifyListeners();
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
    final before = game!.stage;
    game!.resolveEvent(i);
    recent = game!.log.sublist(start);
    _detect(before, game!, recent);
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
    final g = game;
    // 引退したら、殿堂に1度だけ書き込む。
    if (g != null && g.phase == Phase.retired && !g.archived) {
      g.archived = true;
      history = [HistoryEntry.of(g), ...history].take(historyLimit).toList();
      store.saveHistory(history);
    }
    notifyListeners();
    if (g != null) store.save(g.toJson());
  }
}
