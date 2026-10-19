import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/career.dart';
import '../game/difficulty.dart';
import '../game/game.dart';
import '../game/legacy.dart';
import '../monetization/monetization.dart';
import '../game/life.dart';
import '../game/match.dart';
import '../game/path.dart';
import '../game/player.dart';
import '../game/season.dart';
import 'labels.dart';
import 'milestone_dialog.dart';

const saveKey = 'basketball_career_save_v1';
const historyKey = 'basketball_career_history_v1';
const achievementsKey = 'basketball_career_achievements_v1';
const historyLimit = 30;
const howtoKey = 'basketball_career_howto_seen_v1';

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

  Future<List<HistoryEntry>> loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(historyKey);
      if (s == null) return [];
      return [
        for (final e in jsonDecode(s) as List)
          HistoryEntry.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> h) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          historyKey, jsonEncode([for (final e in h) e.toJson()]));
    } catch (_) {}
  }

  Future<bool> loadHowtoSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(howtoKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveHowtoSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(howtoKey, true);
    } catch (_) {}
  }

  Future<Set<String>> loadAchievements() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(achievementsKey) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAchievements(Set<String> ids) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(achievementsKey, ids.toList()..sort());
    } catch (_) {}
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
  GameController(
      {SaveStore? store, Random? rng, this.events = true, this.money})
      : store = store ?? SaveStore(),
        _rng = rng ?? Random();

  /// 出来事を起こすか(テストで切る)。
  final bool events;

  /// 広告と課金。null なら広告なし(テスト・Web)。
  final Monetization? money;

  /// 動画を待っている間(ボタンを押せなくする)。
  bool recoverBusy = false;

  /// 回復の結果メッセージ(画面に1度出す)。
  String? recoverMessage;

  final SaveStore store;
  final Random _rng;
  Game? game;

  /// いま重点にしている能力。
  Ability focus = Ability.threePoint;

  /// 勝負どころの方針。null なら成功率の高いプレーを自動で選ぶ(`askClutch` が false のとき)。
  Clutch? clutchPolicy;

  /// 勝負どころをその場で選ぶか(既定)。
  bool askClutch = true;

  /// 直前の操作で起きたこと(画面の「いまの結果」に出す)。
  List<String> recent = const [];

  /// まだ見せていない節目。画面が1つずつ取り出してダイアログで見せる。
  final List<Milestone> pending = [];

  /// 見せ終わった節目を1つ取り除く。
  void dismissMilestone() {
    if (pending.isNotEmpty) pending.removeAt(0);
    notifyListeners();
  }

  /// 殿堂(過去の選手)。新しい順。
  List<HistoryEntry> history = const [];

  /// 遊び方を見たことがあるか(はじめて始めるときだけ見せる)。
  bool howtoSeen = true;

  /// 解除した実績の id(何度遊んでも残る)。
  Set<String> unlocked = {};

  /// 直前の一生で、新しく解除した実績。エンディングに出す。
  List<Achievement> newlyUnlocked = const [];

  /// 直前に終えた大会の結果(画面にカードで出す)と、それが冬の大会か。
  TournamentResult? lastTournament;
  bool lastTournamentWinter = false;

  /// 直前の進路選択の結果メッセージ。
  String? pathMessage;

  Future<bool> loadSaved() async {
    history = await store.loadHistory();
    unlocked = await store.loadAchievements();
    howtoSeen = await store.loadHowtoSeen();
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

  void newGame(String name, [Difficulty difficulty = Difficulty.normal]) {
    final n = name.trim().isEmpty ? '名無し' : name.trim();
    newlyUnlocked = const [];
    game = Game.start(n,
        rng: _rng,
        events: events,
        difficulty: difficulty,
        legacyBonus: legacyBonusFor(unlocked.length));
    focus = recommendedFocus(game!.player);
    focusAuto = true;
    recent = const [];
    pathMessage = null;
    _commit();
  }

  /// 重点をおすすめに自動で合わせるか(自分で選ぶと止まる。「おすすめ」を押すと戻る)。
  bool focusAuto = true;

  /// 遊び方を見せた。
  void markHowtoSeen() {
    howtoSeen = true;
    store.saveHowtoSeen();
  }

  void setFocus(Ability a) {
    focus = a;
    // おすすめを選び直したら、自動の追従に戻る。
    focusAuto = game != null && a == recommendedFocus(game!.player);
    notifyListeners();
  }

  /// 年の目標を選ぶ。
  void adoptGoal(int i) {
    game!.adoptGoal(i);
    _commit();
  }

  /// 勝負どころの方針を決める。null で「おまかせ」(成功率の高いプレーを自動で選ぶ)。
  void setClutchPolicy(Clutch? c) {
    clutchPolicy = c;
    askClutch = false;
    notifyListeners();
  }

  /// 勝負どころをその場で選ぶ(既定)。
  void setAskClutch() {
    clutchPolicy = null;
    askClutch = true;
    notifyListeners();
  }

  /// 大会の途中(勝負どころ)で止まっているターンの、これまでの結果の行。
  List<String> _pendingLines = const [];

  /// 止まっているターンのはじめの段階(段階が変わったかを見るため)。
  Stage _pendingStage = Stage.minibasket;

  /// 過ごし方を1つ選んで季節を進める。勝負どころが来て止まったら、その場で選ぶ(`playClutch`)。
  /// [ask] が false なら、勝負どころでは止まらず自動で選ぶ(「おすすめで1年進める」など)。
  TermReport act(Action a, {bool ask = true}) {
    final g = game!;
    lastTournament = null;
    final before = Map<Ability, int>.of(g.player.abilities);
    final ageBefore = g.player.age;
    final stageBefore = g.stage;
    final wasWinter = g.slot == 3;
    final r = g.choose(
      a,
      focus,
      chooseClutch: clutchPolicy == null ? null : (_) => clutchPolicy!,
      askClutch: ask && askClutch && clutchPolicy == null,
    );
    final lines = <String>[
      '${a.label}した。',
      ..._gainLines(before, g.player),
      ..._rankUpLines(before, g.player),
      if (r.gotInjured) '怪我をしてしまった…',
    ];
    if (r.paused) {
      _pendingLines = lines;
      recent = lines;
    } else {
      recent = _termLines(lines, r, wasWinter, ageBefore, stageBefore);
    }
    _pendingStage = stageBefore;
    pathMessage = null;
    recoverMessage = null;
    _commit();
    _haptic(r);
    return r;
  }

  /// 手応えを手に伝える(対応しない端末では何も起きない)。
  /// 勝負どころの成功は強く、失敗は重く。優勝は強く。ふだんは軽く。
  void _haptic(TermReport r) {
    try {
      final t = r.tournament;
      if (t != null && t.champion) {
        HapticFeedback.heavyImpact();
      } else if (t != null && t.matches.any((m) => m.clutchSuccess == true)) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// 能力の増減を「3Pシュート +2」の形で。
  List<String> _gainLines(Map<Ability, int> before, Player now) {
    final up = <String>[], down = <String>[];
    for (final a in Ability.values) {
      final d = now.of(a) - (before[a] ?? 0);
      if (d > 0) up.add('${a.label} +$d');
      if (d < 0) down.add('${a.label} $d');
    }
    return [
      if (up.isNotEmpty) '成長: ${up.join(' / ')}',
      if (down.isNotEmpty) '衰え: ${down.join(' / ')}',
    ];
  }

  /// ランクが上がった能力を「ランクアップ! 3Pシュート D→C」の形で。
  List<String> _rankUpLines(Map<Ability, int> before, Player now) {
    final ups = <String>[];
    for (final a in Ability.values) {
      final b = rankOf(before[a] ?? 0), n = rankOf(now.of(a));
      if (b != n && now.of(a) > (before[a] ?? 0)) ups.add('${a.label} $b→$n');
    }
    return [if (ups.isNotEmpty) 'ランクアップ! ${ups.join(' / ')}'];
  }

  /// 大会の結果と年末の知らせを足した、いまの結果の行。
  List<String> _termLines(
      List<String> head, TermReport r, bool wasWinter, int ageBefore,
      [Stage? stageBefore]) {
    final g = game!;
    final lines = [...head];
    if (r.satOut) lines.add('怪我で大会に出られなかった。');
    final t = r.tournament;
    if (t != null) {
      lastTournament = t;
      lastTournamentWinter = wasWinter;
    }
    if (r.yearEnded && g.lastGoalMessage != null) lines.add(g.lastGoalMessage!);
    if (r.yearEnded && g.player.age != ageBefore) {
      lines.add('${g.player.age}歳になった。身長 ${g.player.heightCm.toStringAsFixed(1)}cm。');
    }
    if (stageBefore != null &&
        g.stage != stageBefore &&
        g.phase != Phase.path &&
        g.phase != Phase.retired) {
      lines.add('${stageLabel(g.stage)}になった。新しい仲間とチームワークを築こう。');
      pending.add(Milestone(MilestoneKind.stage, '${stageLabel(g.stage)}へ',
          '${g.player.age}歳。新しい仲間とコーチが待っている。'));
    }
    // 節目の演出。
    if (t != null && t.champion) {
      pending.add(Milestone(
          MilestoneKind.champion,
          '優勝!',
          '${leagueLabel(t.league)}の${wasWinter ? '冬' : '夏'}の大会を制した。'
              '${t.award == null ? '' : '\n個人賞: ${t.award}'}'));
    } else if (t != null && t.award != null) {
      pending.add(Milestone(MilestoneKind.award, '個人賞: ${t.award}',
          '${leagueLabel(t.league)}の大会で、素晴らしい活躍だった。'));
    }
    final goal = g.lastGoalMessage;
    if (r.yearEnded && goal != null && goal.startsWith('目標達成')) {
      pending.add(Milestone(MilestoneKind.goal, '目標達成!', goal.replaceFirst('目標達成!', '').trim()));
    }
    return lines;
  }

  /// 勝負どころで止まっている大会に、選んだプレーを渡す。大会が終われば広告の数えも進める。
  Future<void> playClutch(Clutch c) async {
    final g = game;
    if (g == null || g.phase != Phase.clutch) return;
    final wasWinter = g.runWinter;
    final ageBefore = g.player.age;
    final r = g.resolveClutch(c);
    if (r.paused) {
      recent = _pendingLines;
    } else {
      recent = _termLines(_pendingLines, r, wasWinter, ageBefore, _pendingStage);
      _pendingLines = const [];
    }
    _commit();
    if (!r.paused) await money?.tournamentPlayed();
    try {
      final m = game?.run?.matches.lastOrNull ?? game?.lastReport?.tournament?.matches.lastOrNull;
      if (m?.clutchSuccess == true) {
        HapticFeedback.mediumImpact();
      } else if (m?.clutchSuccess == false) {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  /// 広告つきで過ごし方を選ぶ。大会が終わった後の次の操作で、番なら全画面広告が出る。
  Future<void> play(Action a) async {
    await money?.beforeAction();
    final r = act(a);
    if (r.paused) return; // 大会はまだ終わっていない(広告の数えは `playClutch` で)
    if (r.tournament != null || r.satOut) await money?.tournamentPlayed();
  }

  /// 動画を見て(広告を消した人はそのまま)元気になる。
  Future<void> recover() async {
    final g = game;
    if (g == null || !g.canRecover || recoverBusy) return;
    final m = money;
    if (m == null) return; // 広告の無い環境ではタダで回復させない
    recoverBusy = true;
    recoverMessage = null;
    notifyListeners();
    RecoverGate gate;
    try {
      gate = await m.beforeRecover();
    } catch (_) {
      gate = RecoverGate.unavailable;
    }
    recoverBusy = false;
    if (gate == RecoverGate.granted && game == g && g.canRecover) {
      g.recover();
      recoverMessage = '元気になった。疲れが取れ、気持ちが上がった。';
      _commit();
      return;
    }
    recoverMessage = gate == RecoverGate.declined
        ? '動画を最後まで見ると回復できる。'
        : '動画を読み込めなかった。あとでもう一度。';
    notifyListeners();
  }

  /// おすすめの過ごし方で、今年(年が変わるまで)を進める。
  Future<void> autoYear() async {
    final g = game;
    if (g == null) return;
    final age = g.player.age;
    final lines = <String>[];
    await money?.beforeAction();
    // 目標は確実なほうを自動で選ぶ(選ぶ前なら)。
    if (g.goal == null && g.goalOptions.isNotEmpty && g.slot <= 2) g.adoptGoal(0);
    while (g.phase == Phase.season && g.player.age == age) {
      focus = recommendedFocus(g.player);
      final r = act(recommendedAction(g), ask: false);
      if (r.tournament != null || r.satOut) await money?.tournamentPlayed();
      lines.addAll(recent.skip(1));
    }
    recent = ['おすすめの過ごし方で1年進めた。', ...lines];
    notifyListeners();
  }

  /// 出来事の選択肢を選ぶ。
  void chooseEvent(int i) {
    final g = game!;
    final e = g.pendingEvent!;
    final label = e.options[i].label;
    final lines = g.resolveEvent(i);
    recent = [
      '${e.title}: 「$label」を選んだ。',
      if (lines.isNotEmpty) lines.join(' / '),
    ];
    _commit();
  }

  void chooseRoute(Route r) {
    final g = game!;
    final ok = g.chooseRoute(r);
    if (r == Route.pro && ok) {
      pending.add(Milestone(MilestoneKind.contract, 'プロ契約!',
          '${g.player.name}は、プロの世界へ飛び込む。'));
    }
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
    pending.add(Milestone(MilestoneKind.abroad, '海外挑戦!',
        '世界最高峰の舞台へ。相手は格段に強い。'));
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
    final g = game;
    if (g != null && focusAuto) focus = recommendedFocus(g.player);
    // 引退したら、殿堂に1度だけ書き込み、実績を解除する。
    if (g != null && g.phase == Phase.retired && !g.archived) {
      g.archived = true;
      history = [HistoryEntry.of(g), ...history].take(historyLimit).toList();
      store.saveHistory(history);
      final earned = earnedBy(g);
      newlyUnlocked = [
        for (final a in achievements)
          if (earned.contains(a.id) && !unlocked.contains(a.id)) a,
      ];
      if (newlyUnlocked.isNotEmpty) {
        unlocked = {...unlocked, ...newlyUnlocked.map((a) => a.id)};
        store.saveAchievements(unlocked);
      }
    }
    notifyListeners();
    if (g != null) store.save(g.toJson());
  }
}
