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

/// 前の版のセーブを読もうとしたときの知らせ（1.1.0+25 で作り直した）
const oldSaveMsg = 'この枠は前の版のセーブです。新しい版では続きから遊べません。新しく会社を立ち上げてください';

/// 枠ごとのセーブの鍵と、一覧に出す見出しの鍵（中身を全部読まずに一覧を出すため）
String slotKey(int slot) => 'quad-save-$slot';
String slotMetaKey(int slot) => 'quad-meta-$slot';

/// セーブ枠の一覧に出す見出し
class SlotInfo {
  final int slot, year, q, rank;
  final String name, mode, diff;

  /// 自社の名前（無ければ空。1.1.0+37）
  final String co;
  final double cap;
  final bool ended;
  const SlotInfo(
      {required this.slot,
      required this.year,
      required this.q,
      required this.name,
      required this.cap,
      required this.rank,
      this.co = '',
      this.mode = 'world',
      this.diff = 'normal',
      this.ended = false});
  factory SlotInfo.of(int slot, Game g) => SlotInfo(
      slot: slot,
      year: g.year,
      q: g.q,
      name: g.pres.name,
      co: g.myCo,
      cap: g.cap,
      rank: g.rank > 0 ? g.rank : g.rankList().indexWhere((x) => x.me) + 1,
      mode: g.mode,
      diff: g.diff,
      ended: g.ended);
  Map<String, dynamic> toJson() => {'year': year, 'q': q, 'name': name, 'co': co, 'cap': cap, 'rank': rank, 'mode': mode, 'diff': diff, 'ended': ended};
  factory SlotInfo.fromJson(int slot, Map<String, dynamic> j) => SlotInfo(
      slot: slot,
      year: (j['year'] as num).round(),
      q: (j['q'] as num? ?? 1).round(),
      name: (j['name'] as String?) ?? '',
      co: (j['co'] as String?) ?? '',
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

  /// 自社の事業の並べ替え（事業が多いときだけ出る。rev 売上の大きい順・warn 注意があるものを先に・low 利益の少ない順・share シェアの低い順）
  String myBizSort = 'rev';

  /// 新しい事業の一覧の検索の欄（名前で絞る）
  final TextEditingController bizSearch = TextEditingController();

  /// 図鑑で見ているもの（syn シナジー・ind 業種・ach 実績）
  String zukanView = 'syn';

  void setZukan(String v) {
    zukanView = v;
    notifyListeners();
  }

  /// お金の画面で見ているもの（cash 資金繰り・bank 借金と銀行・cost 経費・tax 税金・fs 決算書・seg 事業ごとの損益・book 社史とランキング）
  String moneyView = 'cash';

  void setMoney(String v) {
    moneyView = v;
    notifyListeners();
  }

  /// 決算書（1.1.0+34。画面だけの状態）: 見ている表（pl 損益計算書・bs 貸借対照表・cf キャッシュフロー・trend 推移）・
  /// 年ごとか月ごとか・月ごとの範囲（ytd 今年の各月・last12 直近12か月）・見ている年（null は最新）・事業ごとの損益の並べ方
  String fsTab = 'pl', fsMode = 'year', fsMonths = 'last12', segSort = 'profit';
  int? fsYear;

  void setFs({String? tab, String? mode, String? months, int? year, String? sort}) {
    if (tab != null) fsTab = tab;
    if (mode != null) fsMode = mode;
    if (months != null) fsMonths = months;
    if (year != null) fsYear = year;
    if (sort != null) segSort = sort;
    notifyListeners();
  }

  /// 世界の画面で選んでいる国（null なら自分の国）
  String? worldSel;

  void setWorld(String c) {
    worldSel = c;
    notifyListeners();
  }

  /// 借りるときに選んでいる返す期限（月）
  int loanTerm = 60;

  void setLoanTerm(int m) {
    loanTerm = m;
    notifyListeners();
  }

  /// 社長の時間が足りないとき true を返し、足りない理由を出す（[k] は行動の種類）
  bool noAp([String k = 'act']) {
    final g = game;
    final m = g?.needT(k);
    if (m == null) return false;
    toast(m);
    return true;
  }

  /// 「事業」タブで詳しく開いている事業の id（事業が3つ以上のとき。開けるのは1つだけ）
  int? openBiz;

  /// 2列の事業の画面で、右に「新しい事業」を出しているか（1.1.0+26）
  bool bizNew = false;

  /// 2列の事業の画面で、右に出す事業を選ぶ
  void selectBiz(int id) {
    openBiz = id;
    bizNew = false;
    moreBiz = null;
    pinBiz = null;
    notifyListeners();
  }

  /// 2列の事業の画面で、右に「新しい事業」を出す
  void showNewBiz() {
    bizNew = true;
    notifyListeners();
  }

  // ===== 人の画面（1.1.0+27） =====
  /// 左の一覧の区分（exec 幹部・mgr 責任者・cand 採用の候補・out 社外）
  String peopleSeg = 'exec';

  /// 並べ替え（ab 能力・pay 給料・mood 不満）
  String peopleSort = 'ab';

  /// 採用の候補の絞り込み（all / grad 新卒 / mid 中途 / poach 引き抜き）
  String candSrc = 'all';

  /// 右に出している人（0 は社長。null は区分の先頭）
  int? openPerson;

  void setPeopleSeg(String s, {String src = 'all'}) {
    peopleSeg = s;
    candSrc = src;
    openPerson = null;
    notifyListeners();
  }

  void setPeopleSort(String s) {
    peopleSort = s;
    notifyListeners();
  }

  void selectPerson(int id) {
    openPerson = id;
    notifyListeners();
  }

  // ===== 株の画面（1.1.0+29） =====
  /// 面（own 自社の株・ma 他社の株と買収・ipo 上場）と、右に出している会社
  String stockSeg = 'own';
  int? openCo;

  void setStockSeg(String s) {
    stockSeg = s;
    notifyListeners();
  }

  void selectCo(int id) {
    stockSeg = 'ma';
    openCo = id;
    notifyListeners();
  }

  /// 街の画面で見ている都市圏（自分の国の都市の番号。1.1.0+26）
  int townCity = 0;

  void setTownCity(int i) {
    townCity = i;
    notifyListeners();
  }

  /// 事業カードを開く（開いているものを押したら閉じる）
  void toggleBiz(int id) {
    openBiz = openBiz == id ? null : id;
    moreBiz = null;
    pinBiz = null;
    notifyListeners();
  }

  /// 事業カードで「ほかの手」を開いている事業の id（1.0.0+20。開いたカードには、今いちばん要りそうな手だけを出し、残りはここを押すと出る）
  int? moreBiz;

  void toggleMore(int id) {
    moreBiz = moreBiz == id ? null : id;
    notifyListeners();
  }

  /// 「今月やること」から飛んできた事業の id（その事業のカードを、一覧のいちばん上に開いて出す）
  int? pinBiz;

  /// 「事業」の一覧の位置（「今月やること」から飛んだときに、いちばん上へ戻すため）
  final ScrollController bizScroll = ScrollController();

  /// 「新しい事業」の見出しの場所（「今月やること」から業種を探しに飛ぶ先）
  final GlobalKey newBizKey = GlobalKey();

  /// 描き終わったあとに [f] を動かす（画面の無いところでは何もしない）
  void _afterFrame(VoidCallback f) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) => f());
      WidgetsBinding.instance.ensureVisualUpdate();
    } catch (_) {}
  }

  void _bizTop() {
    if (bizScroll.hasClients) bizScroll.jumpTo(0);
  }

  /// 「事業」の画面で、その事業のカードを開いて、一覧のいちばん上に出す
  void openBizCard(int id) {
    tab = 'biz';
    bizNew = false;
    openBiz = id;
    pinBiz = id;
    moreBiz = null;
    folded.remove('mybiz');
    _autoFold = false;
    notifyListeners();
    _afterFrame(() {
      _bizTop();
      // 一覧を上に並べた形（iPhone の横・1.1.0+31）で事業が多いと、中身が画面の下に押し出されるので、中身の頭まで送る
      final c = bizHeadKey.currentContext;
      if (c != null) Scrollable.ensureVisible(c);
    });
  }

  /// 事業の画面（一覧を上に並べた形）の、中身のカードの並びの場所
  final GlobalKey bizHeadKey = GlobalKey();

  /// 「事業」の画面の「新しい事業」で、その名前の業種を探す
  void goNewInd(String name) {
    tab = 'biz';
    // 2列の事業の画面では、右に「新しい事業」の一覧を出す（1.1.0+26）
    bizNew = true;
    bizFilter = 'all';
    bizSearch.text = name;
    // 事業が多いときは自社の一覧をたたんで、「新しい事業」をすぐ下に出す（ほかの画面へ移ったら、開いた形に戻す）
    if ((game?.biz.length ?? 0) >= bizManyMin && folded.add('mybiz')) _autoFold = true;
    notifyListeners();
    _afterFrame(() {
      _bizTop();
      _afterFrame(() {
        final c = newBizKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c);
      });
    });
  }

  /// [goNewInd] が自社の事業の一覧をたたんだままか（ほかの画面へ移ったら開き直す）
  bool _autoFold = false;

  void _unfoldAuto() {
    if (_autoFold) folded.remove('mybiz');
    _autoFold = false;
  }

  /// 「人」の画面で、その部下を開く
  void goStaff(int id) {
    _unfoldAuto();
    tab = 'people';
    openStaff = id;
    notifyListeners();
  }

  /// 「街」でたたんでいる欄（rivals 宿敵・news 最近のできごと）。セーブには入れない、画面だけの状態
  final Set<String> folded = {};

  /// 欄をたたむ・開く
  void toggleFold(String id) {
    if (id == 'mybiz') _autoFold = false;
    if (!folded.remove(id)) folded.add(id);
    notifyListeners();
  }

  /// 「もっと見る」で全部を出している一覧と、「詳しく」で細かい数字を開いているカード（1.1.0+31。画面だけの状態）
  final Set<String> shown = {};

  /// 一覧の残り・カードの細かい数字を出す・しまう
  void toggleShown(String id) {
    if (!shown.remove(id)) shown.add(id);
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
    moreBiz = null;
    pinBiz = null;
    openRival = null;
    openStaff = null;
    folded.clear();
    shown.clear();
  }

  late SetupConfig setup = _freshSetup();

  /// 始める画面の名前の案（1.1.0+37）。社長の名前は始める国の名前の表から、自社の名前は作り物の冠＋「商会」。
  /// ゲームの乱数は引かない（案のための乱数は別に作る）
  SetupConfig _freshSetup() {
    final st = SetupConfig();
    final r = newRandom();
    st.name = GameNames.presNameIdea(r, st.home);
    st.co = GameNames.myNameIdea(r);
    nameIdea = st.name;
    return st;
  }

  /// 社長の名前の今の案（書き換えていなければ、始める国を替えたときに案も替える）
  String? nameIdea;

  /// 始める年代を替える。選んでいた国がその年にまだ無ければ（2000年のロシア→1980年など）、日本に戻す（1.1.0+38）
  void setYear(int y) {
    setup.year = y;
    if (y < econData.availableFrom(setup.home)) setHome('jp');
  }

  /// 始める国を替える（社長の名前を書き換えていなければ、その国の名前の案にする）
  void setHome(String c) {
    setup.home = c;
    if (setup.name == nameIdea) {
      setup.name = GameNames.presNameIdea(newRandom(), c);
      nameIdea = setup.name;
    }
  }

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
    // 終わったあと（倒産・乗っ取りなど）の盤面は見るだけ。手は打てない（1.1.0+38。前は事業を売るなどができて、保存もされた）
    if (game?.over != null) {
      showSheet((_) => ToastBody(msg: M('ゲームは終わりました。盤面は見るだけで、手は打てません'), onOk: closeSheet));
      return;
    }
    final hBefore = game?.hUsed;
    final before = snap();
    final m = fn();
    buzzAfter(before, [if (m != null) LogEntry(m)]);
    if (mark != null && hBefore != null && game != null && game!.hUsed > hBefore) markGuide(game, mark);
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
  /// 終わった（over）会社を一度保存した控え。終わったあとの盤面で何か動いても、2回目からは書かない（1.1.0+38）
  Game? _overSaved;

  /// この会社は終わっていて、終わった姿をもう保存したか（初めてなら控えて false）
  bool _overLocked(Game g) {
    if (g.over == null) return false;
    if (identical(_overSaved, g)) return true;
    _overSaved = g;
    return false;
  }

  Future<void> saveOff() async {
    _clearPending();
    final g = game;
    final p = prefs;
    if (g == null || p == null || _overLocked(g)) return;
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
    if (g == null || p == null || _overLocked(g)) return;
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
    bizScroll.dispose();
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
    } on OldSaveError {
      // 1.1.0+25 で作り直したので、前の版のセーブは読めない。枠を空けて、新しく始めてもらう
      prefs?.remove(slotKey(k));
      prefs?.remove(slotMetaKey(k));
      showSheet((_) => ToastBody(msg: M(oldSaveMsg), onOk: closeSheet));
      return false;
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
    // その年にまだ無い国のまま始めない（1.1.0+38）
    if (setup.year < econData.availableFrom(setup.home)) setHome('jp');
    game = Game.newGame(setup, rng: newRandom());
    startGuide(game!);
    tab = 'town';
    save();
  }

  void backToSetup() {
    clearSave();
    game = null;
    setup.traits = [];
    // 名前は新しい案にする（前の遊びの名前を、そのまま次の会社に使わない。1.1.0+37）
    final r = newRandom();
    setup.name = GameNames.presNameIdea(r, setup.home);
    setup.co = GameNames.myNameIdea(r);
    nameIdea = setup.name;
    sheet = null;
    notifyListeners();
  }

  void setTab(String t) {
    if (t != 'biz') _unfoldAuto();
    // 「数字」のタブは 1.1.0+25 から「お金」の「決算と記録」（前の版の呼び方でも開けるようにしておく）
    if (t == 'num') {
      t = 'money';
      moneyView = 'book';
    }
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
