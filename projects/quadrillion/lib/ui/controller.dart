import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game.dart';
import 'guide.dart';
import 'widgets.dart';

/// 試作の localStorage の鍵と同じ名前で保存する
const saveKey = 'quad-save-m';

/// 画面の状態（どのタブか・小窓・はじめの画面の選択）と、保存・読み込み。
/// 試作の render / act / toast / showSheet / save / load にあたる。
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  SharedPreferences? prefs;
  final math.Random Function() newRandom;
  GameController({this.prefs, math.Random Function()? newRandom}) : newRandom = newRandom ?? (() => math.Random());

  Game? game;
  String tab = 'town';
  String bizFilter = 'can';
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
    if (news.any((n) => n.m.startsWith('大当たり') || n.m.startsWith('シナジー発見') || n.m.startsWith('大シナジー'))) return false;
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
    save();
    if (m != null) {
      toast(m);
    } else {
      render();
    }
  }

  // ===== 保存 =====
  bool hasSave() => prefs?.getString(saveKey) != null;

  void save() {
    final g = game;
    final p = prefs;
    if (g == null || p == null) return;
    try {
      p.setString(saveKey, jsonEncode(g.toJson()));
    } catch (_) {}
  }

  bool load() {
    final s = prefs?.getString(saveKey);
    if (s == null) return false;
    try {
      game = Game.fromJson(jsonDecode(s) as Map<String, dynamic>, rng: newRandom());
      endHidden = false;
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

  void clearSave() {
    prefs?.remove(saveKey);
  }

  // ===== はじめる =====
  void startNew() {
    endHidden = false;
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
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(msg, style: ts())),
        Btn('OK', onOk, primary: true),
      ]);
}
