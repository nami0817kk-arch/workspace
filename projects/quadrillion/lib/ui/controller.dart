import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game.dart';
import 'widgets.dart';

/// 試作の localStorage の鍵と同じ名前で保存する
const saveKey = 'quad-save-m';

/// 画面の状態（どのタブか・小窓・はじめの画面の選択）と、保存・読み込み。
/// 試作の render / act / toast / showSheet / save / load にあたる。
class GameController extends ChangeNotifier {
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

  /// 手を打つ（結果の文があれば見せる）
  void act(String? Function() fn) {
    hideSheet();
    final m = fn();
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
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearSave() {
    prefs?.remove(saveKey);
  }

  // ===== はじめる =====
  void startNew() {
    game = Game.newGame(setup, rng: newRandom());
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
