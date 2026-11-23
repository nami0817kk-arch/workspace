import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game.dart';
import 'guide.dart';
import 'widgets.dart';

/// 前の版（1.0.0+3 まで）の1つだけのセーブの鍵（試作の localStorage と同じ名前）。読み込むときは枠1に移す
const legacySaveKey = 'quad-save-m';

/// セーブ枠の数
const slotCount = 3;

/// 枠ごとのセーブの鍵と、一覧に出す見出しの鍵（中身を全部読まずに一覧を出すため）
String slotKey(int slot) => 'quad-save-$slot';
String slotMetaKey(int slot) => 'quad-meta-$slot';

/// セーブ枠の一覧に出す見出し
class SlotInfo {
  final int slot, year, q, rank;
  final String name, mode, diff;
  final double cap;
  final bool ended;
  const SlotInfo(
      {required this.slot,
      required this.year,
      required this.q,
      required this.name,
      required this.cap,
      required this.rank,
      this.mode = 'world',
      this.diff = 'normal',
      this.ended = false});
  factory SlotInfo.of(int slot, Game g) =>
      SlotInfo(slot: slot, year: g.year, q: g.q, name: g.pres.name, cap: g.cap, rank: g.rank > 0 ? g.rank : g.rankList().indexWhere((x) => x.me) + 1, mode: g.mode, diff: g.diff, ended: g.ended);
  Map<String, dynamic> toJson() => {'year': year, 'q': q, 'name': name, 'cap': cap, 'rank': rank, 'mode': mode, 'diff': diff, 'ended': ended};
  factory SlotInfo.fromJson(int slot, Map<String, dynamic> j) => SlotInfo(
      slot: slot,
      year: (j['year'] as num).round(),
      q: (j['q'] as num? ?? 1).round(),
      name: (j['name'] as String?) ?? '',
      cap: (j['cap'] as num? ?? 0).toDouble(),
      rank: (j['rank'] as num? ?? 0).round(),
      mode: (j['mode'] as String?) ?? 'world',
      diff: (j['diff'] as String?) ?? 'normal',
      ended: j['ended'] == true);
}

/// 画面の状態（どのタブか・小窓・はじめの画面の選択）と、保存・読み込み。
/// 試作の render / act / toast / showSheet / save / load にあたる。
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  SharedPreferences? prefs;
  final math.Random Function() newRandom;
  GameController({this.prefs, math.Random Function()? newRandom, String? lang}) : newRandom = newRandom ?? (() => math.Random()) {
    migrateLegacy();
    final saved = prefs?.getString(langKey);
    L.lang = saved == 'ja' || saved == 'en' ? saved! : (lang ?? systemLang());
  }

  /// 選んだ言語を残す鍵
  static const langKey = 'lang';

  /// 端末の言語が日本語なら 'ja'、それ以外は 'en'
  static String systemLang() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ja' ? 'ja' : 'en';
    } catch (_) {
      return 'ja';
    }
  }

  /// 言語を切り替えて残す
  void setLang(String l) {
    L.lang = l == 'en' ? 'en' : 'ja';
    prefs?.setString(langKey, L.lang);
    notifyListeners();
  }

  /// 今遊んでいる枠（自動保存の行き先）
  int slot = 1;

  /// 新しく始めるときに使う枠（はじめの画面で選ぶ。null なら空いている一番小さい枠）
  int? newSlot;

  Game? game;
  String tab = 'town';

  /// 新しい事業の一覧の絞り込み（can 今の資金で始められる・new 生まれて10年以内・all すべて・分類の id）
  String bizFilter = 'can';

  /// 新しい事業の一覧の並べ替え（cost 元手の安い順・market 市場の大きい順・new 生まれたばかり順・margin 利益率の高い順）
  String bizSort = 'cost';

  /// 新しい事業の一覧の検索の欄（名前で絞る）
  final TextEditingController bizSearch = TextEditingController();

  /// 図鑑で見ているもの（syn シナジー・ind 業種・ach 実績）
  String zukanView = 'syn';

  void setZukan(String v) {
    zukanView = v;
    notifyListeners();
  }

  /// 手が足りないとき true を返し、「今月の手が残っていません」を出す
  bool noAp([int need = 1]) {
    final g = game;
    if (g == null || g.canAP(need)) return false;
    toast(M(g.ap > 0 ? '今月の手が足りません' : '今月の手が残っていません'));
    return true;
  }

  /// 「事業」タブで詳しく開いている事業の id（事業が3つ以上のとき。開けるのは1つだけ）
  int? openBiz;

  /// 事業カードを開く（開いているものを押したら閉じる）
  void toggleBiz(int id) {
    openBiz = openBiz == id ? null : id;
    notifyListeners();
  }

  /// 「街」でたたんでいる欄（rivals 宿敵・news 最近のできごと）。セーブには入れない、画面だけの状態
  final Set<String> folded = {};

  /// 欄をたたむ・開く
  void toggleFold(String id) {
    if (!folded.remove(id)) folded.add(id);
    notifyListeners();
  }

  /// 「街」で詳しく開いている宿敵の会社の id（開けるのは1つだけ）
  int? openRival;

  void toggleRival(int id) {
    openRival = openRival == id ? null : id;
    notifyListeners();
  }

  /// 「人」で詳しく開いている部下の id（部下が4人以上のとき。開けるのは1つだけ）
  int? openStaff;

  void toggleStaff(int id) {
    openStaff = openStaff == id ? null : id;
    notifyListeners();
  }

  /// 開いているもの・たたんでいるものを最初の形に戻す（別の会社を読み込んだとき）
  void _resetOpen() {
    openBiz = null;
    openRival = null;
    openStaff = null;
    folded.clear();
  }

  SetupConfig setup = SetupConfig();

  /// 開いている小窓（null なら閉じている）
  WidgetBuilder? sheet;

  /// 小窓を開き直すたびに増える（中身を一番上から見せるため）
  int sheetSeq = 0;

  /// 終わったときのまとめを閉じて盤面を見ているか
  bool endHidden = false;

  /// 振動させる（テストでは差し替えて数える）。heavy は勝ち負けと乗っ取りの警告
  void Function(bool heavy) buzz = (heavy) => heavy ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();

  // ===== 振動 =====
  /// 手や月送りの前の様子を控える
  BuzzSnap snap() {
    final g = game;
    return BuzzSnap(listed: g?.listed ?? false, won: g?.won, over: g?.over, rivMax: g?.sh.rivMax ?? 0);
  }

  /// 控えと比べて、大きなことが起きていたら軽く振動させる
  void buzzAfter(BuzzSnap b, [List<LogEntry> news = const []]) {
    final g = game;
    if (g == null) return;
    final k = buzzKind(g, b, news);
    if (k != null) buzz(k);
  }

  /// 振動の強さ（null なら振動しない）。勝ち・負け・乗っ取りの警告は強く、大当たり・上場・シナジー発見は中くらい
  static bool? buzzKind(Game g, BuzzSnap b, List<LogEntry> news) {
    if (g.won != null && g.won != b.won) return true;
    if (g.over != null && g.over != b.over) return true;
    if (b.rivMax < 33.4 && g.sh.rivMax >= 33.4) return true;
    if (g.listed && !b.listed) return false;
    if (news.map((n) => msgKey(n.m)).any((k) => k.startsWith('大当たり') || k.startsWith('シナジー発見') || k.startsWith('大シナジー'))) return false;
    return null;
  }

  void render() => notifyListeners();

  // ===== 小窓 =====
  void showSheet(WidgetBuilder b) {
    sheet = b;
    sheetSeq++;
    notifyListeners();
  }

  /// 小窓を閉じて描き直す（試作の closeSheet）
  void closeSheet() {
    sheet = null;
    notifyListeners();
  }

  /// 描き直さずに小窓だけ消す（試作の modal.hidden=true）
  void hideSheet() {
    sheet = null;
  }

  /// 結果の文を小窓で見せる（記録にも残す）
  void toast(String? msg, {VoidCallback? then}) {
    if (msg == null || msg.isEmpty) {
      render();
      return;
    }
    final g = game;
    g?.log.add(LogEntry(msg, '', g.year, g.q));
    showSheet((_) => ToastBody(msg: msg, onOk: then ?? closeSheet));
  }

  /// 手を打つ（結果の文があれば見せる）。[mark] を渡すと、手を使えたときに案内のその段を済みにする
  void act(String? Function() fn, {String? mark}) {
    hideSheet();
    final apBefore = game?.ap;
    final before = snap();
    final m = fn();
    buzzAfter(before, [if (m != null) LogEntry(m)]);
    if (mark != null && apBefore != null && game != null && game!.ap < apBefore) markGuide(game, mark);
    // 始めた・買った業種を、図鑑の「手がけた業種」に控える
    game?.noteInds();
    // 手のたびの保存も、手が止まってから裏で（1.0.0+17。それまでは結果を見せる前にその場で書いていた）
    saveSoon();
    if (m != null) {
      toast(m);
    } else {
      render();
    }
  }

  // ===== 保存 =====
  /// 前の版の1つだけのセーブを枠1に移す（枠1が空いているときだけ。移したら古い鍵は消す）
  void migrateLegacy() {
    final p = prefs;
    final old = p?.getString(legacySaveKey);
    if (p == null || old == null) return;
    if (p.getString(slotKey(1)) == null) {
      p.setString(slotKey(1), old);
      p.remove(slotMetaKey(1));
    }
    p.remove(legacySaveKey);
  }

  bool hasSave([int? s]) => s == null ? [for (var i = 1; i <= slotCount; i++) i].any(hasSave) : prefs?.getString(slotKey(s)) != null;

  /// 枠の見出し（空なら null）。見出しが無い（前の版から移した）ときは中身を読んで作り、控えておく
  SlotInfo? slotInfo(int s) {
    final p = prefs;
    final raw = p?.getString(slotKey(s));
    if (p == null || raw == null) return null;
    try {
      final m = p.getString(slotMetaKey(s));
      if (m != null) return SlotInfo.fromJson(s, jsonDecode(m) as Map<String, dynamic>);
    } catch (_) {}
    try {
      final info = SlotInfo.of(s, Game.fromJson(jsonDecode(raw) as Map<String, dynamic>, rng: newRandom()));
      p.setString(slotMetaKey(s), jsonEncode(info.toJson()));
      return info;
    } catch (_) {
      return null;
    }
  }

  /// 新しく始めるときの枠（選んでいなければ、空いている一番小さい枠。全部埋まっていれば枠1）
  int get startSlot => newSlot ?? [for (var i = 1; i <= slotCount; i++) i].firstWhere((i) => !hasSave(i), orElse: () => 1);

  /// あとで保存する予約があるか（まだ書き出していない変更がある）
  bool savePending = false;

  /// 手を止めてから保存するまでの間（1.0.0+17）。この間に次の手・次の月が来たら、保存は後ろへずらす。
  /// 0 にすると、次の描き終わりにその場で保存する（もとからあるテストはこちら。test/flutter_test_config.dart）
  static Duration saveDelay = const Duration(milliseconds: 350);

  /// 保存を後ろへずらせる回数。連打が続いても、この回数を超えたら1度は書き出す（落ちたときに失う月を限る）
  static const saveDeferMax = 12;

  /// セーブの木を文字にする役。本番は別 Isolate（画面を止めない）。テストでは差し替えられる
  Future<String> Function(Map<String, dynamic> tree) encodeOff = _encodeInIsolate;
  static Future<String> _encodeInIsolate(Map<String, dynamic> tree) => Isolate.run(() => jsonEncode(tree));

  Timer? _saveTimer;
  int _saveDefers = 0;

  /// 保存の通し番号。その場の保存・裏の保存のどちらでも増える。裏の保存は、書き出すときに自分より新しい保存があれば捨てる
  int _saveSeq = 0;

  /// 裏で文字にしている最中の保存の数（テストと点検用）
  int savesInFlight = 0;

  /// 保存にかかった時間の控え（その場の保存・裏の保存のうち画面が止まった分。マイクロ秒）
  int lastSaveBlockUs = 0;

  /// 手を打った・月を進めたあとの保存。会社が900社を超えるとセーブは1MBほどになり、文字にするだけで数十msかかるので、
  /// ・手が止まるまで待つ（[saveDelay]。連打のあいだは1回も書かない。ただし [saveDeferMax] 回まで）
  /// ・文字にするのは別 Isolate で（画面が止まるのは、木にして渡すあいだだけ）
  /// アプリが裏に回るとき・別の保存が走るときは、その場で済ませる（[save]）ので、最新は失われない
  void saveSoon() {
    if (game == null || prefs == null) return;
    final WidgetsBinding b;
    try {
      b = WidgetsBinding.instance;
    } catch (_) {
      // 画面の無いところ（仕組みだけのテスト）では、すぐ保存する
      save();
      return;
    }
    if (saveDelay == Duration.zero) {
      if (savePending) return;
      savePending = true;
      b.addPostFrameCallback((_) {
        if (savePending) save();
      });
      b.ensureVisualUpdate();
      return;
    }
    if (savePending && _saveDefers >= saveDeferMax) return;
    _saveDefers = savePending ? _saveDefers + 1 : 0;
    savePending = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, saveOff);
  }

  /// 裏で保存する。木にするところまでをここで済ませ（この時点の中身が保存される）、文字にするのは別 Isolate。
  /// 文字になったときに、もっと新しい保存が済んでいれば書かない
  Future<void> saveOff() async {
    _clearPending();
    final g = game;
    final p = prefs;
    if (g == null || p == null) return;
    final sw = Stopwatch()..start();
    final seq = ++_saveSeq;
    final k = slot;
    final Map<String, dynamic> tree;
    final String meta;
    try {
      g.noteInds();
      tree = g.toJson();
      meta = jsonEncode(SlotInfo.of(k, g).toJson());
    } catch (_) {
      return;
    }
    savesInFlight++;
    final f = encodeOff(tree);
    lastSaveBlockUs = sw.elapsedMicroseconds;
    try {
      final text = await f;
      if (seq == _saveSeq) {
        p.setString(slotKey(k), text);
        p.setString(slotMetaKey(k), meta);
      }
    } catch (_) {
      // 別 Isolate が使えなかったら、その場で保存し直す（もっと新しい保存が済んでいなければ）
      if (seq == _saveSeq) save();
    } finally {
      savesInFlight--;
    }
  }

  void _clearPending() {
    savePending = false;
    _saveDefers = 0;
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// その場で保存する（枠の切り替え・設定・アプリが裏に回るとき）。予約と、裏で作りかけの古い保存はここで用済みになる
  void save() {
    _clearPending();
    final g = game;
    final p = prefs;
    if (g == null || p == null) return;
    final sw = Stopwatch()..start();
    _saveSeq++;
    g.noteInds();
    try {
      p.setString(slotKey(slot), jsonEncode(g.toJson()));
      p.setString(slotMetaKey(slot), jsonEncode(SlotInfo.of(slot, g).toJson()));
    } catch (_) {}
    lastSaveBlockUs = sw.elapsedMicroseconds;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  /// 枠の続きを読み込む（[s] を省くと今の枠）
  bool load([int? s]) {
    // 今の会社にまだ書き出していない変更があれば、枠を替える前に済ませる
    if (savePending) save();
    final k = s ?? slot;
    final raw = prefs?.getString(slotKey(k));
    if (raw == null) return false;
    try {
      game = Game.fromJson(jsonDecode(raw) as Map<String, dynamic>, rng: newRandom());
      slot = k;
      endHidden = false;
      _resetOpen();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// アプリが裏に回る・閉じられるときに保存する
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      save();
    }
  }

  /// 今の枠のセーブを消す
  void clearSave() {
    // 予約と、裏で作りかけの保存も捨てる（消したセーブがあとから書き戻されないように）
    _clearPending();
    _saveSeq++;
    prefs?.remove(slotKey(slot));
    prefs?.remove(slotMetaKey(slot));
  }

  // ===== はじめる =====
  /// 新しく始める（[startSlot] の枠に保存する。埋まっていれば上書き）
  void startNew() {
    if (savePending) save();
    endHidden = false;
    slot = startSlot;
    newSlot = null;
    _resetOpen();
    game = Game.newGame(setup, rng: newRandom());
    startGuide(game!);
    tab = 'town';
    save();
  }

  void backToSetup() {
    clearSave();
    game = null;
    setup.traits = [];
    sheet = null;
    notifyListeners();
  }

  void setTab(String t) {
    tab = t;
    notifyListeners();
  }
}

/// 振動を決めるための、前の様子の控え
class BuzzSnap {
  final bool listed;
  final String? won, over;
  final double rivMax;
  const BuzzSnap({required this.listed, this.won, this.over, required this.rivMax});
}

/// 結果の文と OK だけの小窓
class ToastBody extends StatelessWidget {
  final String msg;
  final VoidCallback onOk;
  const ToastBody({super.key, required this.msg, required this.onOk});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(tx(msg), style: ts())),
        Btn('OK', onOk, primary: true),
      ]);
}
